---
name: find-doc
description: 社内Notionドキュメント・Slack会話をローカルインデックスおよびSlack APIから検索します
allowed-tools: [Read, Grep, Glob, Bash]
argument-hint: <検索キーワード>
invocation: user
---

# 社内ドキュメント・Slack 検索 (find-doc)

## 目的
ローカルに保存されたNotionページのインデックスと、Slack search.messages APIを通じたSlack会話を統合的に検索し、該当する情報のURL・出典・日付を返します。Notionはローカルファイルの Grep/Read で高速に、SlackはPythonスクリプト経由で検索します。ヒットしたSlackメッセージがスレッドに属する場合は、`conversations.replies` を使ってスレッド全体（親メッセージ＋返信）を自動取得し、文脈ごと提示します。

## 実行内容

### ステップ1: インデックスの存在確認
- `~/.claude/local/company-docs/metadata.json` を Read する
- ファイルが存在しない場合 → Notionインデックス未作成として記録（Slack検索は続行）
- `last_indexed_at` が7日以上前の場合 → 「インデックスが {N}日前 のものです。`/index-docs` で更新を推奨します」と警告

### ステップ2: キーワード検索（並行実行）
以下を **すべて並行して** 実行:
1. `~/.claude/local/company-docs/index.md` をキーワードで Grep 検索
2. `~/.claude/local/company-docs/aliases.md` をキーワードで Grep 検索
3. Bash: `python3 ~/.claude/bin/search-slack.py "$ARGUMENTS"` を実行（検索結果上限: 10件、スレッド展開上限: 10件）
   - スクリプトは `(channel_id, thread_ts)` でヒットをグルーピングし、同一スレッド内の複数ヒットは1エントリに集約する。`conversations.replies` はスレッドごとに1回だけ呼び出される。
   - 出力エントリは `type` で区別される:
     - `type: "thread"` — スレッド集約エントリ。`thread_parent`（親メッセージ）、`matched_ts`（ヒットした ts の配列）、`matched_count`、`thread`（全返信配列）、`thread_total`、`period`（first/last）を含む
     - `type: "message"` — スレッドに属さない単発メッセージ。`text`、`timestamp`、`permalink` を含む
   - `thread` 配列の各要素は `{ts, text, user, timestamp}` を持ち、`matched_ts` と `ts` を突き合わせてヒット行をマーキングできる

### ステップ3: 詳細情報の取得
- ステップ2でNotionにヒットしたページについて、`~/.claude/local/company-docs/by-database/` 配下の該当ファイルを Read
- 該当エントリの詳細情報（タグ、所属DB）を取得

### ステップ4: 結果の出力
以下のフォーマットで出力:

```
## 検索結果: 「{検索キーワード}」

### Notion ドキュメント
| ドキュメント名 | データベース/セクション | 最終更新 | URL |
|---|---|---|---|
| APIドキュメント | 技術ドキュメントDB | 2026-01-15 | [Notion](url) |

### Slack 会話
| # | スレッド親（抜粋） | チャンネル | 期間 | ヒット/全件 | リンク |
|---|---|---|---|---|---|
| 1 | プロジェクトのAPI仕様について共有しま... | #engineering | 2026-02-10 10:05 | 2/5 | [Slack](permalink) |
| 2 | 週次ミーティング議事録 | #general | 2026-02-09 | - | [Slack](permalink) |

#### #1 スレッド抜粋: プロジェクトのAPI仕様について共有しま... (#engineering, 全5件)
- **2026-02-10 10:05** @user1: 親メッセージ本文...
▶ **2026-02-10 10:12** @user2: ヒットした返信1...
- **2026-02-10 10:18** @user3: 返信2...
▶ **2026-02-10 10:30** @user4: ヒットした返信2...
- **2026-02-10 10:45** @user5: 返信3...
```

- テーブルの「スレッド親（抜粋）」列は:
  - `type: "thread"` → `thread_parent.text` を 80 文字で切り詰めて表示
  - `type: "message"` → そのメッセージ本文を 80 文字で切り詰めて表示
- 「期間」列は:
  - `type: "thread"` → `period.first`（スレッド開始時刻）を表示（必要に応じて `period.first〜period.last` の範囲も可）
  - `type: "message"` → `timestamp` を表示
- 「ヒット/全件」列は:
  - `type: "thread"` → `{matched_count}/{thread_total}`
  - `type: "message"` → `-`
- スレッド抜粋ブロック:
  - `type: "thread"` で `thread` 配列がある結果について、テーブル直下に「#{N} スレッド抜粋」ブロックを出力する
  - `matched_ts` と各スレッドメッセージの `ts` を突き合わせ、ヒット行の先頭マーカーを `▶` に、それ以外は `-` にする
  - スレッド本文は 200 文字で切り詰め
  - スレッドが 6 件以上の場合は「先頭3件 + 末尾1件」に省略し、省略部分は `- … (N 件省略)` と明示する。ただし、省略対象にヒット行（`▶`）が含まれる場合は、そのヒット行も必ず表示する（前後の省略数をそれぞれ明示）
- 同じ親（同一 `thread_ts`）が複数スレッドエントリに分割されることはない（スクリプト側で集約済み）
- 各セクションは該当結果がある場合のみ表示

### ステップ5: ヒット0件の場合
- Notion: キーワードを単語に分割して各単語で再検索（例: "API仕様書" → "API" と "仕様"）
- `~/.claude/local/company-docs/by-database/_database-list.md` を Read してDB一覧を提示
- 「見つかりませんでした。別の表現で試すか、以下のデータベースを確認してください」と案内

## エラーハンドリング

| 状況 | 動作 |
|------|------|
| SLACK_USER_TOKEN 未設定 | Notion結果のみ表示 + 「SLACK_USER_TOKEN が未設定です。~/.claude/settings.json の env に設定してください」と注記 |
| Slack API エラー/タイムアウト | Notion結果のみ表示 + 「Slack検索で一時的なエラーが発生しました」と注記 |
| スレッド取得失敗（`thread_error` あり） | メッセージ本体のみ表示 + 末尾に「スレッド取得失敗: {error}（トークンの `channels:history` / `groups:history` スコープを確認してください）」と注記 |
| Notion インデックス未作成 | Slack結果のみ表示 + 「`/index-docs` でNotionインデックスを作成してください」と注記 |
| 両方失敗 | 「検索ソースに接続できませんでした。Notionインデックス（`/index-docs`）とSLACK_USER_TOKEN の設定を確認してください」と表示 |

## パラメータ
- $ARGUMENTS: 検索キーワード（日本語・英語・部分一致対応）

## 使用例
```
/find-doc API仕様
/find-doc デプロイ手順
/find-doc 評価制度
/find-doc onboarding
```

## 検索フロー（AIへの指示）

検索キーワード「$ARGUMENTS」に対して以下を実行:

1. まず `~/.claude/local/company-docs/metadata.json` を Read して最終更新日を確認
   - ファイルが存在しない場合は `notion_available = false` として記録し、ステップ2へ進む
   - 存在する場合は `notion_available = true`
2. 以下を**すべて並行で**実行:
   - **Notion検索**（`notion_available = true` の場合のみ）:
     - pattern="$ARGUMENTS" path="$HOME/.claude/local/company-docs/index.md"
     - pattern="$ARGUMENTS" path="$HOME/.claude/local/company-docs/aliases.md"
   - **Slack検索**: Bash で `python3 ~/.claude/bin/search-slack.py "$ARGUMENTS"` を実行
     - 結果の JSON をパースし、`ok` が `false` の場合は `slack_available = false` として記録
3. **エラー判定**:
   - `notion_available = false` かつ `slack_available = false` → エラーメッセージを出力して終了
   - いずれか片方のみ失敗 → 成功したソースの結果を表示し、失敗したソースについて注記を追加
4. Notionでヒット件数が0の場合:
   - キーワードを分割して再検索（例: "API仕様書" → "API" と "仕様"）
   - `$HOME/.claude/local/company-docs/by-database/_database-list.md` を Read してDB名一覧を提示
5. ヒットしたNotionページの URL に対応する by-database/ ファイルを Read して詳細取得
6. 結果を2セクション構成の表形式で出力（Notion: 最大20件、Slack: スレッド集約後の全エントリ）
   - Slack テーブルの列は「# / スレッド親（抜粋） / チャンネル / 期間 / ヒット/全件 / リンク」
   - `type: "thread"` エントリは `thread_parent.text` を 80 文字で切り詰めて抜粋列に表示。`matched_count/thread_total` を「ヒット/全件」列に表示
   - `type: "message"` エントリは本文を 80 文字で切り詰めて抜粋列に表示。「ヒット/全件」列は `-`、「期間」列は `timestamp`
   - `type: "thread"` かつ `thread` 配列がある結果は、テーブル直下に「#{N} スレッド抜粋: {親本文80文字} (#{channel}, 全{thread_total}件)」ブロックを続けて出力
     - 各メッセージは `[マーカー] **{timestamp}** @{user}: {本文200文字}` の形式
     - `matched_ts` に含まれる ts の行はマーカーを `▶`、それ以外は `-`
     - スレッドが 6 件以上の場合は「先頭3件＋末尾1件」に省略し、`- … (N 件省略)` で明示。ただし省略対象にヒット行が含まれる場合はヒット行を必ず残し、前後の省略数を分けて表記
   - `thread_error` が含まれるスレッドエントリは、本体表示＋末尾に「スレッド取得失敗: {error}（トークンの `channels:history` / `groups:history` スコープを確認してください）」を注記
   - 各セクションは該当結果がある場合のみ表示

**注意**: 出力は日本語で行うこと。
