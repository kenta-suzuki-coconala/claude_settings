# Custom Slash Command 作成支援 ユーザーが指定した「$ARGUMENTS」に基づいて、新しいCustom Slash Commandを作成します。
## 作成プロセス
### 1. 要件の確認 まず、以下の情報を整理します：
- コマンド名: $1
- スコープ: $2 (project または user、省略時は project)
- どのような処理を自動化したいですか？
- どのようなパラメータが必要ですか？
- どのツール（bash、git等）へのアクセスが必要ですか？
### 2. ディレクトリ構造の確認と作成 スコープに応じてディレクトリを作成：
- Project scope: .claude/commands/
- User scope: ~/.claude/commands/
!mkdir -p .claude/commands
### 3. コマンドテンプレートの生成
以下のテンプレート構造でコマンドファイルを作成します：
markdown
---
allowed-tools: [必要なツール権限]
argument-hint: [パラメータのヒント]
description: [コマンドの説明]
model: claude-3-5-haiku-20241022 # 軽量タスクの場合
---
# コマンド名
## 目的
このコマンドの主な目的と用途を記述
## 実行内容
### ステップ1: [アクション名]
- 具体的な処理内容
- 期待される結果
### ステップ2: [アクション名]
- 具体的な処理内容
- 期待される結果
## パラメータ
- $1: [第1引数の説明]
- $2: [第2引数の説明]
- $ARGUMENTS: [全引数の説明]
## 使用例
> /project:command-name 引数1 引数2