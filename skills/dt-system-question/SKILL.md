---
name: dt-system-question
description: >
  ココナラの検索・推薦・サジェスト・データ基盤・AI生成システムに関する質問に回答し、
  コードベースを調査します。「レコメンド」「データフロー」「検索パイプライン」「ES」
  「Elasticsearch」「Airflow」「Embulk」「ダッシュボード」「推薦」「スコア」
  「エンベディング」「サジェスト」等のキーワードに反応します。

  対象リポジトリ: coconala-api-rails, search-rails, search-rails-batch,
  dataplatform, coconala-embulk, dt-algorithm-api, suggest。

  対象ドメイン: 検索パイプライン（Elasticsearch クエリ構築、13段パラメータパイプライン、
  ソート戦略、日本語形態素解析）、推薦システム（協調フィルタリング、デモグラフィック推薦、
  ルールベース推薦、ベクトル検索、コンテンツベース推薦）、サジェスト（オートコンプリート、
  キーワード補完）、データ基盤（Aurora↔BigQuery ETL、Embulk同期、Airflowワークフロー、
  スコア計算、エンベディング生成、CloudSQLエクスポート）、AI生成（Geminiテキスト生成、
  カテゴリサジェスト）。

  .claude/resources/dt-system/knowledge/ 配下の14ファイルのドメイン知識と、
  .claude/resources/dt-system/_repos/ への実行時クローンによるコード探索を組み合わせて調査を実施します。
invocation: user
---

# /dt-system-question - DT System 調査

ココナラの検索・推薦・データ基盤システムに関する質問に回答し、コードベースを調査します。

## 使い方

```bash
/dt-system-question 購入者ダッシュボードのレコメンドについて教えて
/dt-system-question サービスのESインデクシングはどの頻度で実行される？
/dt-system-question Embulkの日次バッチスケジュールを教えて
/dt-system-question ベクトル検索の実装方式を比較して
```

## 処理手順

{{input}} の質問に対して、以下の手順で調査・回答してください。

### Step 1: ナレッジ索引からファイルを特定

質問キーワードに基づき、以下のルーティングテーブルから参照すべきファイルを特定してください。
**必ず該当するknowledgeファイルを Read ツールで読み込んでから回答してください。**

| 質問キーワード | 参照ファイル（.claude/resources/dt-system/knowledge/ 配下） |
|-------------|----------------------------------------|
| 検索、ES、Elasticsearch、クエリ構築、function_score | `domain-search.md`, `search-rails.md` |
| Elastic Cloud、クラスタ、スペック、プラグイン、Extension、Sudachi、バージョンアップ | `elastic-cloud-clusters.md` |
| レコメンド、推薦、協調フィルタリング、ダッシュボード | `domain-recommendation.md` |
| スコア、ランキング、service_score、ni_score | `domain-search.md`, `dataplatform.md` |
| エンベディング、ベクトル検索、ANN、VECTOR_SEARCH | `domain-recommendation.md`, `dt-algorithm-api.md` |
| Embulk、ETL、同期、データ転送、Digdag | `domain-data-infrastructure.md`, `coconala-embulk.md` |
| Airflow、ワークフロー、バッチ計算、DAG | `dataplatform.md` |
| サジェスト、オートコンプリート、キーワード補完 | `domain-suggest.md`, `suggest.md` |
| AI生成、Gemini、カテゴリサジェスト、テキスト生成 | `domain-ai-generation.md`, `dt-algorithm-api.md` |
| インデクシング、Sidekiq、Uploader、ES同期 | `search-rails-batch.md` |
| API、エンドポイント、Grape、coconala-api | `coconala-api-rails-search.md` |
| 全体像、パイプライン、アーキテクチャ、データフロー全体 | `search_pipeline_knowledge.md`（knowledge/ と同階層） |
| 機能別の詳細（feature-*.md が存在する場合） | `knowledge/feature-*.md` |

### Step 2: 調査パターンの選択

質問の種類に応じて、以下の3パターンから適切なアプローチを選択してください。

#### パターン A: 知識参照型

「仕組みを教えて」「データフローは？」「どんなアルゴリズム？」系の質問。

1. ルーティングテーブルから該当 knowledge ファイルを読み込む
2. ファイルの内容を基に回答を構成する
3. 必要に応じて複数ファイルを横断参照する

#### パターン B: コード調査型

「実装を見せて」「このクラスは何をしている？」「コードの詳細を教えて」系の質問。

1. まず knowledge ファイルで概要を把握
2. knowledge ファイル末尾の「キーファイルパス」セクションで対象ファイルを特定
3. `.claude/resources/dt-system/_repos/` に該当リポジトリがなければ clone（下記「_repos/ 利用ガイド」参照）
4. 実コードを読み込んで詳細を確認・回答

#### パターン C: 横断調査型

「この機能の全データフローを追って」「エンドツーエンドで説明して」系の質問。

1. `.claude/resources/dt-system/search_pipeline_knowledge.md` で全体像を把握
2. 関連する複数の knowledge ファイルを読み込む
3. 必要に応じて `.claude/resources/dt-system/_repos/` から複数リポジトリのコードを探索
4. **調査結果を `.claude/resources/dt-system/knowledge/feature-<テーマ名>.md` に保存する**

### Step 3: 回答の構成

- knowledge ファイルの情報を基に、質問に対して構造化された回答を提供
- データフローは図（テキスト図またはMermaid）で示す
- 関連するファイルパス・クラス名・メソッド名を具体的に記載
- 参照した knowledge ファイル名を明示する

---

## _repos/ 利用ガイド

`.claude/resources/dt-system/_repos/` はコード調査時の作業ディレクトリです。
必要なリポジトリがなければ以下のコマンドでクローンしてください。

```bash
gh repo clone welself/<repo-name> .claude/resources/dt-system/_repos/<repo-name> -- --depth=1
```

### 利用可能リポジトリ

| リポジトリ | 役割 | 主要技術 |
|-----------|------|---------|
| `coconala-api-rails` | メインAPI、検索のフロント窓口 | Rails + Grape |
| `search-rails` | ES検索APIサーバー | Rails + Grape + Elasticsearch 7.x |
| `search-rails-batch` | Aurora → ES インデクシングバッチ | Rails + Sidekiq |
| `dataplatform` | Airflowワークフロー（スコア計算、エンベディング生成、推薦計算） | Python + Airflow + BigQuery |
| `coconala-embulk` | Aurora ↔ BigQuery ETLパイプライン | Digdag + Embulk |
| `dt-algorithm-api` | 推薦・AI API（ベクトル検索、Gemini統合） | Python + FastAPI |
| `suggest` | サジェストシステム | Python |

### 各リポジトリのキーファイルパス

**coconala-api-rails**（検索関連）:
- `app/apis/api/v1/dashboard.rb` — ダッシュボードAPI
- `app/apis/api/v2/search_services.rb` — V2 サービス検索
- `app/models/service_es_search_v2.rb` — V2 検索実装
- `app/models/service_recommend_es_search_v2.rb` — レコメンド検索
- `app/models/recommend/` — レコメンドモデル群
- `app/services/dashboard/` — ダッシュボードサービス群

**search-rails**:
- `app/apis/api/v1/search_services.rb` — 検索API
- `app/apis/api/v1/recommend_services.rb` — 推奨API
- `app/models/elasticsearch_params/` — 34個のESパラメータクラス
- `app/models/concerns/service_es_search_parameter.rb` — 13段パイプライン

**search-rails-batch**:
- `app/models/coconala_elastic_search/` — 6つのUploader
- `app/jobs/` — ESアップロードジョブ
- `config/schedule.rb` — Cronスケジュール

**dataplatform**:
- `workflow/` — 23個のAirflow DAG定義
- `sql/` — BigQuery SQLスクリプト
- `module/bq_to_cloudsql_base.py` — CloudSQLエクスポート基盤

**coconala-embulk**:
- `projects/load_bigquery/` — Aurora → BQ（696テーブル）
- `projects/load_aurora/` — BQ → Aurora（8テーブル）
- `projects/etl_recommend/` — BQ ↔ rad-recommend（双方向）

**dt-algorithm-api**:
- `recommends/handlers/v1/` — レコメンドAPI
- `services/handlers/` — サービス推薦API
- `common/models/` — SQLAlchemyモデル

---

## ナレッジファイルの命名規則

| プレフィックス | 用途 | 例 |
|-------------|------|------|
| `domain-` | ドメイン全体の概要（リポジトリ横断） | `domain-recommendation.md` |
| `feature-` | 特定機能の詳細調査結果 | `feature-buyer-dashboard-recommend.md` |
| (なし) | 単一リポジトリの技術ナレッジ | `search-rails.md` |
