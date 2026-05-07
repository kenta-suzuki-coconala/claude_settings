---
allowed-tools: [Bash, Read]
description: Notionから社内ドキュメントのインデックスを再構築します
---

# ドキュメントインデックス再構築 (index-docs)

## 目的
Notion API を使用して社内ドキュメントのメタデータを収集し、`~/.claude/local/company-docs/` 配下のインデックスファイルを再生成します。

## 前提条件
- 環境変数 `NOTION_API_TOKEN` が設定されていること
- Python 3 がインストールされていること
- `notion-client` パッケージがインストールされていること

## 実行内容

### ステップ1: 環境確認
- `python3 --version` で Python の存在確認
- `python3 -c "import notion_client"` で必要パッケージの確認
- パッケージが未インストールの場合 → `pip install notion-client` の実行を案内

### ステップ2: インデックス生成スクリプトの実行
以下を実行:

! python3 ~/.claude/bin/index-company-docs.py

※ 1000+ページの場合、Notion API のレートリミットにより数分かかることがあります。

### ステップ3: 結果確認
- `~/.claude/local/company-docs/metadata.json` を Read して統計情報を表示
- 生成されたファイル一覧を Glob で確認
- エラーがあった場合はスクリプトの出力を確認

## 完了後の出力

以下の情報を表示:
- 総ページ数（アクティブ / アーカイブ）
- データベース数
- 所要時間
- 出力ファイル一覧

## トラブルシューティング

- `notion-client` がない → `pip install notion-client`
- `NOTION_API_TOKEN` エラー → `~/.claude/settings.json` の `env` に設定されているか確認
- ページが少ない → Notion Integration がワークスペース全体に接続されているか確認
  - Notion の Settings → Connections で Integration のアクセス範囲を確認

## 使用例
```
/index-docs
```
