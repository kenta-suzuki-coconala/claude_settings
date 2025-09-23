---
allowed-tools: [bash, git, gh, Read, Grep, Glob]
argument-hint: "[PR Title] [Base Branch (optional)] [Additional gh pr create options]"
description: GitHub上でドラフトプルリクエストを作成
model: claude-3-5-haiku-20241022
---
# create-pr

## 目的
GitHub上でドラフトプルリクエストを作成し、.github/PULL_REQUEST_TEMPLATE.mdに従ったフォーマットでPRボディを生成します。

## 実行内容

### ステップ1: PRテンプレートの確認
- .github/PULL_REQUEST_TEMPLATE.mdファイルを読み込み、テンプレート構造を理解
- テンプレートが存在しない場合は基本的な構造を使用

### ステップ2: 現在のブランチと変更の確認
- 現在のブランチ名を取得
- git statusとgit diffでコミット予定の変更を確認
- ベースブランチ（デフォルト: main）からの差分を確認

### ステップ3: PRタイトルとボディの生成
- 変更内容に基づいてPRタイトルを生成
- .github/PULL_REQUEST_TEMPLATE.mdの構造に従ってPRボディを作成
- コミット履歴から関連情報を抽出

### ステップ4: ドラフトPRの作成
- gh pr create --draft コマンドでドラフトPRを作成
- 生成されたタイトルとボディを使用

## パラメータ
- $1: PRタイトル（必須）
- $2: ベースブランチ（省略時は main を使用）
- $ARGUMENTS: 追加のgh pr createオプション

## 使用例
```
/create-pr "Add user authentication feature"
/create-pr "Fix database connection issue" develop
/create-pr "Update API documentation" main --assignee @me
```

## 実装

現在のブランチとコミット情報を確認し、PRテンプレートに従ってドラフトプルリクエストを作成します。

```bash
#!/bin/bash

# 現在のブランチを確認
current_branch=$(git branch --show-current)
base_branch=${2:-main}

# PRテンプレートの確認と読み込み
if [ -f ".github/PULL_REQUEST_TEMPLATE.md" ]; then
    template_content=$(cat .github/PULL_REQUEST_TEMPLATE.md)
else
    template_content="# 目的

このプルリクで何を解決するのかを記述します。

# 変更内容

- 変更点1
- 変更点2

# セルフチェック項目
- [ ] コードレビューの準備ができている
- [ ] テストが通過している
- [ ] ドキュメントが更新されている"
fi

# コミット情報の取得
recent_commits=$(git log --oneline -5 ${base_branch}..HEAD)

# 追加のgh pr create オプションを抽出
shift 2
additional_options="$@"

# PRの作成
gh pr create --draft \
    --title "$1" \
    --base "$base_branch" \
    --body "$(cat <<EOF
$template_content

---

## Recent Commits
$recent_commits

🤖 Generated with [Claude Code](https://claude.ai/code)
EOF
)" $additional_options
```