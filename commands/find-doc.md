---
allowed-tools: [Read, Grep, Glob, Bash]
argument-hint: <検索キーワード>
description: 社内Notionドキュメント・Slack会話をローカルインデックスおよびSlack APIから検索します
---

# 社内ドキュメント・Slack 検索 (find-doc)

## 目的
ローカルに保存されたNotionページのインデックスと、Slack search.messages APIを通じたSlack会話を統合的に検索し、該当する情報のURL・出典・日付を返します。Notionはローカルファイルの Grep/Read で高速に、SlackはPythonスクリプト経由で検索します。

## 実行内容

### ステップ1: インデックスの存在確認
- `~/.claude/local/company-docs/metadata.json` を Read する
- ファイルが存在しない場合 → Notionインデックス未作成として記録（Slack検索は続行）
- `last_indexed_at` が7日以上前の場合 → 「インデックスが {N}日前 のものです。`/index-docs` で更新を推奨します」と警告

### ステップ2: キーワード検索（並行実行）
以下を **すべて並行して** 実行:
1. `~/.claude/local/company-docs/index.md` をキーワードで Grep 検索
2. `~/.claude/local/company-docs/aliases.md` をキーワードで Grep 検索
3. Bash: `python3 ~/.claude/bin/search-slack.py "$ARGUMENTS"` を実行（結果上限: 10件）

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
| メッセージ（抜粋） | チャンネル | 日付 | リンク |
|---|---|---|---|
| プロジェクトのAPI仕様について共有しま... | #engineering | 2026-02-10 | [Slack](permalink) |
```

- Slack メッセージは80文字程度で切り詰め、末尾に「...」を付与
- パーマリンクを表示
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
6. 結果を2セクション構成の表形式で出力（Notion: 最大20件、Slack: 最大10件）
   - Slack メッセージは80文字で切り詰め
   - 各セクションは該当結果がある場合のみ表示

**注意**: 出力は日本語で行うこと。
