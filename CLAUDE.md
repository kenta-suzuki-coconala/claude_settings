# Guidelines

This document defines the project's rules, objectives, and progress management methods. Please proceed with the project according to the following content.

## コア原則

- **シンプル第一**: 最小限の変更で目的を達成する。
- **手を抜かない**: 一時的修正ではなく根本解決を行う。
- **影響最小化**: 必要箇所のみを変更し、新規バグを排除する。

## Top-Level Rules

- To maximize efficiency, **if you need to execute multiple independent processes, invoke those tools concurrently, not sequentially**.
- **You must think exclusively in English**. However, you are required to **respond in Japanese**.
- To understand how to use a library, **always use the Contex7 MCP** to retrieve the latest information.

## ワークフロー原則

- **Planモード活用**: 3ステップ以上またはアーキテクチャに関わるタスクは必ずPlanモードで開始する。問題が生じたら無理に続行せず再計画する。
- **サブエージェント活用**: リサーチ・調査・並列分析は専門サブエージェントに委託し、メインコンテキストをクリーンに保つ。各エージェントには1つのタスクを割り当てる。
- **自律的バグ対応**: バグレポートに対して質問を返さず、ログとエラーから自力で解決を試みる。ユーザーのコンテキスト切り替えを最小化する。

## タスク管理

- 非自明なタスクは「計画→確認→進捗記録→変更説明→ドキュメント化→学びの記録」の6ステップで進める。
- `tasks/` ディレクトリでセッションをまたいだ履歴を管理する。

## 自己改善ループ

- ユーザーからの修正を受けたら `tasks/lessons.md` に記録し、同じミスを防ぐルールを自動生成する。
- セッション開始時に `tasks/lessons.md` を参照し、過去の学びを活かす。

## Programming Rules

- Avoid hard-coding values unless absolutely necessary.
- Do not use `any` or `unknown` types in TypeScript.
- You must not use a TypeScript `class` unless it is absolutely necessary (e.g., extending the `Error` class for custom error handling that requires `instanceof` checks).

## テスト・検証

- コード変更後は、関連するテストを実行して動作を検証すること。
- テストスイート全体ではなく、関連する単一テストを優先的に実行すること（パフォーマンスのため）。
- UIの変更時は、スクリーンショットを撮って視覚的に確認すること。
- **動作を証明できるまで完了とマークしない**。品質基準はスタッフエンジニアが承認するレベルを目指す。

## コンパクション指示

- コンパクション時は、変更したファイルの一覧・テストコマンド・重要な設計判断を必ず保持すること。

## コミット・PR規約

- コミットメッセージは日本語で、変更の「なぜ」を簡潔に記述すること。
- PRは `.github/PULL_REQUEST_TEMPLATE.md` テンプレートに従うこと。

## ココナラ分析機能（coconala-ai-resource）

ココナラのデータ分析・用語変換機能です。

### 重要なルール

**分析を行う際は、ほぼ必ず `/analyze` コマンドを利用してください。**

`/analyze` コマンドは、用語解釈・クエリ生成・実行・数値検証・レポート作成を一貫して行い、品質の高い分析結果を保証します。

### 利用可能なコマンド

| コマンド | 説明 |
|---------|------|
| `/analyze <質問>` | ココナラデータを分析してクエリ生成・実行 |
| `/translate <依頼>` | ココナラ用語を技術仕様に変換 |
| `/diagnose` | エラー診断 |
| `/da-request <依頼の概要>` | データ分析依頼書を対話形式で作成 |
| `/find-doc <キーワード>` | 社内 Notion + Slack 統合検索 |
| `/index-docs` | Notion ドキュメントインデックス再構築 |

### 詳細

`.claude/resources/index.md` を参照してください。

## ココナラドメイン用語辞書（coconala-ai-resource）

ココナラのドメイン用語辞書（201用語、10ドメイン）です。

### 参照方法

1. `.claude/resources/ubiquitous-dict/aliases.md` でユーザー表現を正規化
2. `.claude/resources/ubiquitous-dict/index.md` でドメインを特定
3. `.claude/resources/ubiquitous-dict/domain-specific/` で詳細を確認

### 詳細

`.claude/resources/ubiquitous-dict/README.md` を参照してください。

## ココナラシステム・運用知識（coconala-ai-resource）

障害対応・ログ調査・システム構成理解に必要な知識です。

### 参照方法

1. `.claude/resources/coconala/system-architecture.md` でシステム構成を確認
2. `.claude/resources/coconala/log-investigation.md` で障害対応手順を確認
3. `.claude/resources/coconala/service-repo-map.md` でリポジトリ・ロググループを特定
4. `.claude/resources/coconala/sre-operations.md` でSRE運用知識を確認

### 困ったときの参照先

**developer_tools リポジトリ** (https://github.com/welself/developer_tools) に最新のツール・スキル・調査パターンが蓄積されている。ここにある知識で解決できない場合や、最新情報が必要な場合はこのリポジトリを参照すること。


<!-- OMC:IMPORT:START -->
@CLAUDE-omc.md
<!-- OMC:IMPORT:END -->
