---
name: search-provider
description: 出品者Agentic検索
invocation: user
---

# /search-provider - 出品者Agentic検索

ココナラの出品者をAgentic検索で探します。ユーザーの要望を分析し、出品者プロフィール検索とサービスEmbedding検索を自動選択して最適な出品者3名を推薦します。

## 使い方

```bash
/search-provider Rustも機械学習もできるエンジニア
/search-provider ポケモンカード風の結婚式ウェルカムボード
/search-provider Webサイト作れる人、プラチナ希望
/search-provider ペットの似顔絵を描いてほしい
```

## 処理フロー

```
Step 0: 要望の分解（固有名詞 / 一般スキル / フィルタ / サービス記述 に分類）
    ↓
Step 1: 検索戦略の決定（Mode A/B/D/SA/SB を自動選択）
    ↓
Step 2: クエリ設計と検索実行（BigQuery / bqコマンド）
    ↓
Step 3: カバレッジ分析と再探索判断（最大3回）
    ↓
Step 4: 最適な3名を選出（ゴールド/プラチナ優先）
    ↓
Step 5: 結果を整形して出力
```

---
# 出品者Agentic検索

ユーザーの要望: $ARGUMENTS

## あなたの役割

あなたはココナラの出品者を探すAgentic検索エージェントです。
ユーザーの要望を理解し、最適な検索戦略を選択して**最大3回**探索を繰り返し、最適な出品者3名を見つけ出します。

## データソース

### 出品者プロフィール: `embedding_v2.provider_text_embedding`
約41,000名の出品者プロフィールがembeddingされています。
各レコードの `prompt` フィールドは以下の構造です:

```
<name>出品者名</name>
<occupation>職業</occupation>
-----
<catchphrase>キャッチフレーズ</catchphrase>
<message>自己紹介メッセージ</message>
-----
<経験職種>["職種1", "職種2"]</経験職種>
<得意分野:カテゴリ名>["分野1:説明", "分野2:説明"]</得意分野>
<資格・検定>["資格1", "資格2"]</資格・検定>
```

### サービス情報: `embedding_v2.service_text_embedding`
約103,000件のサービス（出品）がembeddingされています。
各レコードの `prompt` フィールドは以下の構造です:

```
<title>サービスタイトル</title>
<meta_info>
  <parent_category>大カテゴリ</parent_category>
  <category>カテゴリ</category>
  <category_type>タイプ</category_type>
  <facets>[facet情報]</facets>
</meta_info>
<content>サービス説明文</content>
```

**注意:** service_text_embedding には `user_id` がなく `service_id` のみ。`coconala.services` テーブル（`provider_id`）経由で出品者を特定する。

### サービスマスタ: `coconala.services`
全出品サービスのマスタテーブル（約464,000出品者）。
主要カラム: `id`（service_id）, `provider_id`（user_id）, `name`（サービスタイトル）, `catchphrase`, `price`, `opened`, `stop_fg`

### エンリッチメント用テーブル

| テーブル | JOINキー | 取得情報 |
|---|---|---|
| `coconala.providers_levels` | `provider_id` | ランク (`new_level`: 1=レギュラー〜5=プラチナ) |
| `coconala.last_logins` | `user_id` | 最終ログイン日時 (`login_time`) |
| `coconala.orders` (status=2) | `provider_id` | 完了取引数 |
| `coconala.rating_providers` | `provider_id` | 平均評価 (`overall_rate`)、レビュー数 |
| `coconala.users` | `id` | 本人確認 (`identification_fg`)、NDA (`nda_conclusion_fg`)、名前 (`name`) |
| `coconala.favorites` | `provider_id` | 総お気に入り数 |

## 実行手順

### Step 0: 要望の分解（最重要）

ユーザーの要望を以下の4カテゴリに分解してください。**この分解が検索の成否を決めます。**

#### カテゴリA: 固有名詞キーワード（ハード条件）
プロフィールに**文字列として含まれていなければならない**固有名詞。
ベクトル検索では捕捉できないため、**必ずキーワード検索（LIKE）で担保する**。

| 種類 | 例 |
|---|---|
| プログラミング言語名 | Rust, Go, Kotlin, Swift, Haskell, Scala |
| フレームワーク/ライブラリ | PyTorch, TensorFlow, React, Laravel, Rails |
| ツール/プラットフォーム | Docker, Kubernetes, AWS, Figma, Unity |
| 資格名 | 簿記1級, TOEIC900, 宅建, PMP |
| 企業/サービス名 | Salesforce, SAP, Shopify |

**判定基準:** 「その単語がプロフィールに書かれていなければ、スキルを持っていると判断できない」→ 固有名詞キーワード

#### カテゴリB: 一般スキル/分野（ソフト条件）
プロフィール全体の意味的類似性で捕捉できる、広い概念。
ベクトル検索が得意な領域。

| 種類 | 例 |
|---|---|
| 技術分野 | 機械学習, Web制作, データ分析, セキュリティ |
| 業務領域 | 業務自動化, ECサイト構築, 動画編集 |
| 職種 | デザイナー, エンジニア, コンサルタント |
| スキルレベル | 上級者, 10年以上の経験 |

**判定基準:** 「プロフィールに別の表現で書かれていても、同じスキルを持っている可能性がある」→ 一般スキル

#### カテゴリC: フィルタ条件
検索後のフィルタリングで適用する条件。

- **ランクフィルタ**: 「プラチナ限定」「ゴールド以上」等
- **アクティブ度**: 「最近ログインしている人」等
- **実績**: 「取引件数が多い人」等

#### カテゴリD: サービス・成果物の具体的記述
**出品者のスキルではなく、具体的なサービスや商品を指す表現。**
サービスEmbedding検索が最も効果的。

| 種類 | 例 |
|---|---|
| 具体的な成果物 | ポケモンカード風ウェルカムボード, トレカ風名刺 |
| サービス形態 | 結婚式オープニングムービー, ドット絵アイコン |
| 商品カテゴリ | ペット似顔絵, 風水鑑定, 占い |

**判定基準:** 「出品者の能力より、提供されるサービスの内容が重要」→ サービス検索

#### 分解の例

| ユーザーの要望 | 固有名詞（A） | 一般スキル（B） | フィルタ（C） | サービス記述（D） |
|---|---|---|---|---|
| 「Rustも機械学習もできるエンジニア」 | Rust | 機械学習, エンジニア | - | - |
| 「ポケモンカード風の結婚式ウェルカムボード」 | - | - | - | ポケモンカード風 ウェルカムボード 結婚式 |
| 「Shopifyに強くてSEOもできる人」 | Shopify | SEO, ECサイト | - | - |
| 「結婚式のオープニングムービー、ゴールド以上」 | - | - | ゴールド以上 | 結婚式 オープニングムービー |
| 「PyTorchに詳しいAIエンジニア、プラチナ希望」 | PyTorch | AIエンジニア | プラチナ | - |

### Step 1: 検索戦略の決定

Step 0の分解結果から、以下のフローチャートで戦略を決定してください:

```
サービス・成果物の具体的記述（D）がある？
├── YES → 【Mode SA: サービスベクトル検索】★サービス系はこれが最強
│         （固有名詞（A）もあれば、サービスタイトルへのLIKEフィルタを追加）
│
└── NO → 固有名詞キーワード（A）はある？
          ├── NO → 一般スキル（B）のみ
          │         → 【Mode A: 出品者ベクトル検索】
          │
          └── YES → 一般スキル（B）もある？
                    ├── NO → 固有名詞のみ
                    │         → 【Mode B: 出品者キーワード検索】
                    │
                    └── YES → 固有名詞 + 一般スキルの組み合わせ
                              → 【Mode D: キーワード先行カスケード】★推奨
```

**重要:**
- **Mode SA** はサービスEmbeddingを使うため、出品者プロフィールEmbedding（41,660名）にいない出品者も発見できる（464,000名カバー）。
- 出品者プロフィール検索で結果が不十分な場合、**Mode SA/SB で補完検索**することを検討する。

### Step 2: クエリの設計と検索実行

---

#### Mode A: 出品者ベクトル検索（一般スキルのみの場合）

ユーザーの要望を、**出品者が自分のプロフィールに書きそうな文章**に変換してください。

**クエリ変換のルール:**
1. キーワード羅列ではなく、プロフィールの `<message>` セクションに書かれそうな文体にする
2. 類義語・関連語を含める（職種名、ツール名、業務内容の具体例）
3. 日本語と英語の両方を含める（プロフィールには両方ある）

**変換例:**

| ユーザーの要望 | ❌ 悪いクエリ | ✅ 良いクエリ |
|---|---|---|
| Webサイト作れる人 | `Webサイト 作成` | `Webデザイナー ホームページ制作 WordPress コーディング HTML CSS レスポンシブ対応 LP制作 フロントエンドエンジニア` |
| ロゴを作ってほしい | `ロゴ 作成` | `ロゴデザイン グラフィックデザイナー ブランディング CI VI ロゴ制作 Adobe Illustrator` |
| データ分析できる人 | `データ分析` | `データサイエンティスト データ分析 Python SQL 統計分析 可視化 BIツール 機械学習 予測モデル` |

**SQLテンプレート（基本形）:**

```bash
bq query --use_legacy_sql=false --format=json --max_rows=30 --parameter='query::<YOUR_QUERY>' "
WITH vector_results AS (
  SELECT base.user_id, base.profile_id, base.prompt, distance
  FROM VECTOR_SEARCH(
    TABLE \`indigo-medium-816.embedding_v2.provider_text_embedding\`,
    'text_embedding',
    (SELECT text_embedding FROM ML.GENERATE_TEXT_EMBEDDING(
      MODEL \`indigo-medium-816.embedding_v2.text_embedding_model_multilingual\`,
      (SELECT @query AS content)
    )),
    top_k => 100,
    distance_type => 'COSINE'
  )
),
provider_rank AS (
  SELECT provider_id,
    MAX(new_level) AS provider_level,
    CASE
      WHEN MAX(new_level) = 5 THEN 'プラチナ'
      WHEN MAX(new_level) = 4 THEN 'ゴールド'
      WHEN MAX(new_level) = 3 THEN 'シルバー'
      WHEN MAX(new_level) = 2 THEN 'ブロンズ'
      ELSE 'レギュラー'
    END AS provider_rank
  FROM \`indigo-medium-816.coconala.providers_levels\`
  GROUP BY provider_id
),
provider_last_login AS (
  SELECT user_id, MAX(login_time) AS last_login_time
  FROM \`indigo-medium-816.coconala.last_logins\`
  GROUP BY user_id
),
provider_sales AS (
  SELECT provider_id, COUNT(*) AS completed_orders
  FROM \`indigo-medium-816.coconala.orders\`
  WHERE status = 2
  GROUP BY provider_id
),
provider_ratings AS (
  SELECT provider_id,
    ROUND(AVG(overall_rate), 2) AS avg_rating,
    COUNT(*) AS review_count
  FROM \`indigo-medium-816.coconala.rating_providers\`
  GROUP BY provider_id
),
provider_favorites AS (
  SELECT provider_id, COUNT(*) AS total_favorites
  FROM \`indigo-medium-816.coconala.favorites\`
  GROUP BY provider_id
)
SELECT
  vr.user_id,
  CONCAT('https://coconala.com/users/', CAST(vr.user_id AS STRING)) AS profile_url,
  REGEXP_EXTRACT(vr.prompt, r'<name>(.*?)</name>') AS name,
  REGEXP_EXTRACT(vr.prompt, r'<occupation>(.*?)</occupation>') AS occupation,
  REGEXP_EXTRACT(vr.prompt, r'<catchphrase>(.*?)</catchphrase>') AS catchphrase,
  SUBSTR(REGEXP_EXTRACT(vr.prompt, r'<message>([\s\S]*?)</message>'), 1, 500) AS message,
  REGEXP_EXTRACT(vr.prompt, r'<経験職種>(.*?)</経験職種>') AS experience,
  REGEXP_EXTRACT(vr.prompt, r'<得意分野[^>]*>(.*?)</得意分野>') AS specialties,
  REGEXP_EXTRACT(vr.prompt, r'<資格・検定>(.*?)</資格・検定>') AS certifications,
  IFNULL(pr.provider_rank, 'レギュラー') AS provider_rank,
  IFNULL(pr.provider_level, 0) AS provider_level,
  ll.last_login_time,
  DATE_DIFF(CURRENT_DATE(), DATE(ll.last_login_time), DAY) AS days_since_last_login,
  IFNULL(ps.completed_orders, 0) AS completed_orders,
  rt.avg_rating,
  IFNULL(rt.review_count, 0) AS review_count,
  u.identification_fg AS identity_verified,
  u.nda_conclusion_fg AS nda_concluded,
  IFNULL(fv.total_favorites, 0) AS total_favorites,
  vr.distance
FROM vector_results vr
LEFT JOIN provider_rank pr ON vr.user_id = pr.provider_id
LEFT JOIN provider_last_login ll ON vr.user_id = ll.user_id
LEFT JOIN provider_sales ps ON vr.user_id = ps.provider_id
LEFT JOIN provider_ratings rt ON vr.user_id = rt.provider_id
LEFT JOIN \`indigo-medium-816.coconala.users\` u ON vr.user_id = u.id
LEFT JOIN provider_favorites fv ON vr.user_id = fv.provider_id
WHERE vr.distance < 0.45
ORDER BY ROUND(vr.distance, 2) ASC, IFNULL(pr.provider_level, 0) DESC, IFNULL(ps.completed_orders, 0) DESC
LIMIT 30
"
```

**ソート戦略（ゴールド/プラチナ優先）:**
- `ROUND(vr.distance, 2) ASC` で距離を0.01幅のバンドに丸め、同程度のマッチ度を「同列」と見なす
- 同バンド内では `provider_level DESC` でゴールド/プラチナを優先表示
- 特に理由がない限り、この「タイブレーカー方式」をデフォルトとする

**ランクフィルタ**: WHERE句に `AND IFNULL(pr.provider_level, 0) >= N` を追加
（レギュラー=1, ブロンズ=2, シルバー=3, ゴールド=4, プラチナ=5）

---

#### Mode B: 出品者キーワード検索（固有名詞のみの場合）

特定のキーワードがプロフィールに含まれることが必須の場合に使用します。

**SQLテンプレート:**

基本形の `vector_results` CTEを以下に差し替え、`FROM vector_results vr` を `FROM keyword_matches vr` に変更:

```sql
WITH keyword_matches AS (
  SELECT user_id, profile_id, prompt, 0.0 AS distance
  FROM \`indigo-medium-816.embedding_v2.provider_text_embedding\`
  WHERE LOWER(prompt) LIKE '%keyword1%'
    AND LOWER(prompt) LIKE '%keyword2%'
),
```

WHERE句の `vr.distance < 0.45` は削除し、ORDER BYを以下に変更:
`ORDER BY IFNULL(pr.provider_level, 0) DESC, IFNULL(ps.completed_orders, 0) DESC`

**キーワード検索のコツ:**
- AND条件: `WHERE LOWER(prompt) LIKE '%a%' AND LOWER(prompt) LIKE '%b%'`
- OR条件: `WHERE LOWER(prompt) LIKE '%a%' OR LOWER(prompt) LIKE '%b%'`
- 特定セクション内: `WHERE REGEXP_EXTRACT(prompt, r'<資格・検定>(.*?)</資格・検定>') LIKE '%簿記1級%'`
- 常に `LOWER()` で大文字小文字を統一する

---

#### Mode D: キーワード先行カスケード（固有名詞 + 一般スキルの場合）★最重要

**固有名詞は必ずプロフィールに書かれている必要があるが、一般スキルは意味的に近ければよい。**
この2つの性質の異なる要件を、2フェーズで処理します。

##### フェーズ1: キーワード検索で固有名詞を確実に捕捉

固有名詞キーワードでキーワード検索を実行します。

```bash
bq query --use_legacy_sql=false --format=json --max_rows=50 --parameter='soft_query::<ソフト条件のクエリ文>' "
WITH keyword_filtered AS (
  SELECT user_id, profile_id, prompt, 0.0 AS distance
  FROM \`indigo-medium-816.embedding_v2.provider_text_embedding\`
  WHERE LOWER(prompt) LIKE '%<固有名詞1（小文字）>%'
),
provider_rank AS (
  SELECT provider_id,
    MAX(new_level) AS provider_level,
    CASE
      WHEN MAX(new_level) = 5 THEN 'プラチナ'
      WHEN MAX(new_level) = 4 THEN 'ゴールド'
      WHEN MAX(new_level) = 3 THEN 'シルバー'
      WHEN MAX(new_level) = 2 THEN 'ブロンズ'
      ELSE 'レギュラー'
    END AS provider_rank
  FROM \`indigo-medium-816.coconala.providers_levels\`
  GROUP BY provider_id
),
provider_last_login AS (
  SELECT user_id, MAX(login_time) AS last_login_time
  FROM \`indigo-medium-816.coconala.last_logins\`
  GROUP BY user_id
),
provider_sales AS (
  SELECT provider_id, COUNT(*) AS completed_orders
  FROM \`indigo-medium-816.coconala.orders\`
  WHERE status = 2
  GROUP BY provider_id
),
provider_ratings AS (
  SELECT provider_id,
    ROUND(AVG(overall_rate), 2) AS avg_rating,
    COUNT(*) AS review_count
  FROM \`indigo-medium-816.coconala.rating_providers\`
  GROUP BY provider_id
),
provider_favorites AS (
  SELECT provider_id, COUNT(*) AS total_favorites
  FROM \`indigo-medium-816.coconala.favorites\`
  GROUP BY provider_id
),
soft_match AS (
  SELECT kf.*,
    CASE
      WHEN LOWER(kf.prompt) LIKE '%機械学習%' OR LOWER(kf.prompt) LIKE '%deep learning%' OR LOWER(kf.prompt) LIKE '%machine learning%' THEN 1
      ELSE 0
    END AS soft_keyword_hit
  FROM keyword_filtered kf
)
SELECT
  sm.user_id,
  CONCAT('https://coconala.com/users/', CAST(sm.user_id AS STRING)) AS profile_url,
  REGEXP_EXTRACT(sm.prompt, r'<name>(.*?)</name>') AS name,
  REGEXP_EXTRACT(sm.prompt, r'<occupation>(.*?)</occupation>') AS occupation,
  REGEXP_EXTRACT(sm.prompt, r'<catchphrase>(.*?)</catchphrase>') AS catchphrase,
  SUBSTR(REGEXP_EXTRACT(sm.prompt, r'<message>([\s\S]*?)</message>'), 1, 500) AS message,
  REGEXP_EXTRACT(sm.prompt, r'<経験職種>(.*?)</経験職種>') AS experience,
  REGEXP_EXTRACT(sm.prompt, r'<得意分野[^>]*>(.*?)</得意分野>') AS specialties,
  REGEXP_EXTRACT(sm.prompt, r'<資格・検定>(.*?)</資格・検定>') AS certifications,
  IFNULL(pr.provider_rank, 'レギュラー') AS provider_rank,
  IFNULL(pr.provider_level, 0) AS provider_level,
  ll.last_login_time,
  DATE_DIFF(CURRENT_DATE(), DATE(ll.last_login_time), DAY) AS days_since_last_login,
  IFNULL(ps.completed_orders, 0) AS completed_orders,
  rt.avg_rating,
  IFNULL(rt.review_count, 0) AS review_count,
  u.identification_fg AS identity_verified,
  u.nda_conclusion_fg AS nda_concluded,
  IFNULL(fv.total_favorites, 0) AS total_favorites,
  sm.soft_keyword_hit
FROM soft_match sm
LEFT JOIN provider_rank pr ON sm.user_id = pr.provider_id
LEFT JOIN provider_last_login ll ON sm.user_id = ll.user_id
LEFT JOIN provider_sales ps ON sm.user_id = ps.provider_id
LEFT JOIN provider_ratings rt ON sm.user_id = rt.provider_id
LEFT JOIN \`indigo-medium-816.coconala.users\` u ON sm.user_id = u.id
LEFT JOIN provider_favorites fv ON sm.user_id = fv.provider_id
ORDER BY sm.soft_keyword_hit DESC, IFNULL(pr.provider_level, 0) DESC, IFNULL(ps.completed_orders, 0) DESC
LIMIT 50
"
```

**soft_match CTEのカスタマイズ:**
- 一般スキル（ソフト条件）の関連キーワードを LIKE で列挙し、`soft_keyword_hit` としてカウント
- 一般スキルの関連語を幅広く含める（類義語、英語表記、略語）
- 例:「機械学習」→ `'%機械学習%' OR '%deep learning%' OR '%machine learning%' OR '%ディープラーニング%' OR '%深層学習%' OR '%AI開発%' OR '%人工知能%' OR '%データサイエンス%'`
- ヒット数が多い順にランキングすることで、固有名詞を持ちかつ一般スキルにも該当する人が上位に来る

##### フェーズ2: 結果の評価と補完

フェーズ1の結果を確認:
- **候補が10名以上 & soft_keyword_hit=1が3名以上**: フェーズ1の結果だけで十分。Step 3へ。
- **候補が少ない（< 5名）**: 固有名詞の条件を OR に緩和するか、一般スキル側のベクトル検索（Mode A）で補完。
- **soft_keyword_hit=1が0名**: 固有名詞スキルと一般スキルの組み合わせがニッチ。
  → ユーザーに「完全一致は0名でした。固有名詞スキルを持つ人の中で最も近い候補を提示します」と報告。

---

#### Mode SA: サービスベクトル検索（具体的なサービス・成果物を探す場合）★カバレッジ最大

**サービスの `prompt`（タイトル+説明）に対してベクトル検索し、service_id → provider_id で出品者を特定する。**

出品者プロフィールEmbedding（41,660名）では見つからない出品者も、サービスEmbedding経由で発見できる。

**クエリ変換のルール:**
1. ユーザーが求める**成果物・サービスそのもの**を記述する
2. サービスタイトルや説明文に書かれそうな表現にする
3. 関連する成果物の種類、用途、スタイルを含める

**変換例:**

| ユーザーの要望 | ✅ 良いクエリ |
|---|---|
| ポケモンカード風結婚式ウェルカムボード | `ポケモンカード風 トレーディングカード イラスト ウェルカムボード 結婚式 かわいい` |
| 会社紹介の動画を作りたい | `会社紹介 企業VP 動画制作 映像制作 モーショングラフィックス プロモーション` |
| ペットの似顔絵が欲しい | `ペット 似顔絵 犬 猫 イラスト 動物 かわいい アイコン` |

**SQLテンプレート:**

```bash
bq query --use_legacy_sql=false --format=json --max_rows=30 --parameter='query::<YOUR_QUERY>' "
WITH service_vector AS (
  SELECT base.service_id, base.prompt AS service_prompt, distance
  FROM VECTOR_SEARCH(
    TABLE \`indigo-medium-816.embedding_v2.service_text_embedding\`,
    'text_embedding',
    (SELECT text_embedding FROM ML.GENERATE_TEXT_EMBEDDING(
      MODEL \`indigo-medium-816.embedding_v2.text_embedding_model_multilingual\`,
      (SELECT @query AS content)
    )),
    top_k => 100,
    distance_type => 'COSINE'
  )
),
service_with_provider AS (
  SELECT
    sv.*,
    s.provider_id AS user_id,
    s.name AS service_title,
    s.catchphrase AS service_catchphrase,
    s.price AS service_price
  FROM service_vector sv
  JOIN \`indigo-medium-816.coconala.services\` s ON sv.service_id = s.id
  WHERE s.opened = 1 AND s.stop_fg = 0
),
-- 同一出品者の複数サービスがヒットする場合、最も近いものを代表にする
best_service_per_provider AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY distance ASC) AS rn
  FROM service_with_provider
),
provider_rank AS (
  SELECT provider_id,
    MAX(new_level) AS provider_level,
    CASE
      WHEN MAX(new_level) = 5 THEN 'プラチナ'
      WHEN MAX(new_level) = 4 THEN 'ゴールド'
      WHEN MAX(new_level) = 3 THEN 'シルバー'
      WHEN MAX(new_level) = 2 THEN 'ブロンズ'
      ELSE 'レギュラー'
    END AS provider_rank
  FROM \`indigo-medium-816.coconala.providers_levels\`
  GROUP BY provider_id
),
provider_last_login AS (
  SELECT user_id, MAX(login_time) AS last_login_time
  FROM \`indigo-medium-816.coconala.last_logins\`
  GROUP BY user_id
),
provider_sales AS (
  SELECT provider_id, COUNT(*) AS completed_orders
  FROM \`indigo-medium-816.coconala.orders\`
  WHERE status = 2
  GROUP BY provider_id
),
provider_ratings AS (
  SELECT provider_id,
    ROUND(AVG(overall_rate), 2) AS avg_rating,
    COUNT(*) AS review_count
  FROM \`indigo-medium-816.coconala.rating_providers\`
  GROUP BY provider_id
),
provider_favorites AS (
  SELECT provider_id, COUNT(*) AS total_favorites
  FROM \`indigo-medium-816.coconala.favorites\`
  GROUP BY provider_id
),
-- 該当出品者の全アクティブサービスのタイトルを集約
all_services AS (
  SELECT provider_id,
    STRING_AGG(name, ' | ' ORDER BY id LIMIT 5) AS all_service_titles,
    COUNT(*) AS total_active_services
  FROM \`indigo-medium-816.coconala.services\`
  WHERE opened = 1 AND stop_fg = 0
  GROUP BY provider_id
)
SELECT
  bs.user_id,
  CONCAT('https://coconala.com/users/', CAST(bs.user_id AS STRING)) AS profile_url,
  u.name AS provider_name,
  bs.service_title,
  bs.service_catchphrase,
  bs.service_price,
  CONCAT('https://coconala.com/services/', CAST(bs.service_id AS STRING)) AS service_url,
  als.all_service_titles,
  als.total_active_services,
  IFNULL(pr.provider_rank, 'レギュラー') AS provider_rank,
  IFNULL(pr.provider_level, 0) AS provider_level,
  ll.last_login_time,
  DATE_DIFF(CURRENT_DATE(), DATE(ll.last_login_time), DAY) AS days_since_last_login,
  IFNULL(ps.completed_orders, 0) AS completed_orders,
  rt.avg_rating,
  IFNULL(rt.review_count, 0) AS review_count,
  u.identification_fg AS identity_verified,
  u.nda_conclusion_fg AS nda_concluded,
  IFNULL(fv.total_favorites, 0) AS total_favorites,
  bs.distance
FROM best_service_per_provider bs
LEFT JOIN provider_rank pr ON bs.user_id = pr.provider_id
LEFT JOIN provider_last_login ll ON bs.user_id = ll.user_id
LEFT JOIN provider_sales ps ON bs.user_id = ps.provider_id
LEFT JOIN provider_ratings rt ON bs.user_id = rt.provider_id
LEFT JOIN \`indigo-medium-816.coconala.users\` u ON bs.user_id = u.id
LEFT JOIN provider_favorites fv ON bs.user_id = fv.provider_id
LEFT JOIN all_services als ON bs.user_id = als.provider_id
WHERE bs.rn = 1
ORDER BY ROUND(bs.distance, 2) ASC, IFNULL(pr.provider_level, 0) DESC, IFNULL(ps.completed_orders, 0) DESC
LIMIT 30
"
```

---

#### Mode SB: サービスキーワード検索（サービスタイトルでの直接検索）

サービスEmbeddingに入っていないサービスも含め、`coconala.services` テーブル（全464,000出品者）のタイトルをLIKE検索。

```bash
bq query --use_legacy_sql=false --format=json --max_rows=30 "
WITH service_matches AS (
  SELECT
    s.provider_id AS user_id,
    s.id AS service_id,
    s.name AS service_title,
    s.catchphrase AS service_catchphrase,
    s.price AS service_price,
    0.0 AS distance
  FROM \`indigo-medium-816.coconala.services\` s
  WHERE s.opened = 1 AND s.stop_fg = 0
    AND (LOWER(s.name) LIKE '%keyword1%' OR LOWER(s.name) LIKE '%keyword2%')
),
best_service_per_provider AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY service_id ASC) AS rn
  FROM service_matches
),
provider_rank AS (
  SELECT provider_id,
    MAX(new_level) AS provider_level,
    CASE
      WHEN MAX(new_level) = 5 THEN 'プラチナ'
      WHEN MAX(new_level) = 4 THEN 'ゴールド'
      WHEN MAX(new_level) = 3 THEN 'シルバー'
      WHEN MAX(new_level) = 2 THEN 'ブロンズ'
      ELSE 'レギュラー'
    END AS provider_rank
  FROM \`indigo-medium-816.coconala.providers_levels\`
  GROUP BY provider_id
),
provider_last_login AS (
  SELECT user_id, MAX(login_time) AS last_login_time
  FROM \`indigo-medium-816.coconala.last_logins\`
  GROUP BY user_id
),
provider_sales AS (
  SELECT provider_id, COUNT(*) AS completed_orders
  FROM \`indigo-medium-816.coconala.orders\`
  WHERE status = 2
  GROUP BY provider_id
),
provider_ratings AS (
  SELECT provider_id,
    ROUND(AVG(overall_rate), 2) AS avg_rating,
    COUNT(*) AS review_count
  FROM \`indigo-medium-816.coconala.rating_providers\`
  GROUP BY provider_id
),
provider_favorites AS (
  SELECT provider_id, COUNT(*) AS total_favorites
  FROM \`indigo-medium-816.coconala.favorites\`
  GROUP BY provider_id
),
all_services AS (
  SELECT provider_id,
    STRING_AGG(name, ' | ' ORDER BY id LIMIT 5) AS all_service_titles,
    COUNT(*) AS total_active_services
  FROM \`indigo-medium-816.coconala.services\`
  WHERE opened = 1 AND stop_fg = 0
  GROUP BY provider_id
)
SELECT
  bs.user_id,
  CONCAT('https://coconala.com/users/', CAST(bs.user_id AS STRING)) AS profile_url,
  u.name AS provider_name,
  bs.service_title,
  bs.service_catchphrase,
  bs.service_price,
  CONCAT('https://coconala.com/services/', CAST(bs.service_id AS STRING)) AS service_url,
  als.all_service_titles,
  als.total_active_services,
  IFNULL(pr.provider_rank, 'レギュラー') AS provider_rank,
  IFNULL(pr.provider_level, 0) AS provider_level,
  ll.last_login_time,
  DATE_DIFF(CURRENT_DATE(), DATE(ll.last_login_time), DAY) AS days_since_last_login,
  IFNULL(ps.completed_orders, 0) AS completed_orders,
  rt.avg_rating,
  IFNULL(rt.review_count, 0) AS review_count,
  u.identification_fg AS identity_verified,
  u.nda_conclusion_fg AS nda_concluded,
  IFNULL(fv.total_favorites, 0) AS total_favorites
FROM best_service_per_provider bs
LEFT JOIN provider_rank pr ON bs.user_id = pr.provider_id
LEFT JOIN provider_last_login ll ON bs.user_id = ll.user_id
LEFT JOIN provider_sales ps ON bs.user_id = ps.provider_id
LEFT JOIN provider_ratings rt ON bs.user_id = rt.provider_id
LEFT JOIN \`indigo-medium-816.coconala.users\` u ON bs.user_id = u.id
LEFT JOIN provider_favorites fv ON bs.user_id = fv.provider_id
LEFT JOIN all_services als ON bs.user_id = als.provider_id
WHERE bs.rn = 1
ORDER BY IFNULL(pr.provider_level, 0) DESC, IFNULL(ps.completed_orders, 0) DESC
LIMIT 30
"
```

---

#### Mode C: ハイブリッド検索（ベクトル + キーワード絞り込み）

ベクトル検索の結果をキーワードで後フィルタする方式。
**注意: 固有名詞がニッチな場合、top_kの範囲内にキーワード該当者がいない可能性がある。その場合はMode Dを使うこと。**

`vector_results` CTEのVECTOR_SEARCH後にWHEREを追加:

```sql
WITH vector_results AS (
  SELECT base.user_id, base.profile_id, base.prompt, distance
  FROM VECTOR_SEARCH(
    TABLE \`indigo-medium-816.embedding_v2.provider_text_embedding\`,
    'text_embedding',
    (SELECT text_embedding FROM ML.GENERATE_TEXT_EMBEDDING(
      MODEL \`indigo-medium-816.embedding_v2.text_embedding_model_multilingual\`,
      (SELECT @query AS content)
    )),
    top_k => 300,
    distance_type => 'COSINE'
  )
  WHERE LOWER(base.prompt) LIKE '%<KEYWORD>%'
),
```

### Step 3: 結果の評価と再探索の判断

取得した結果に対して、以下の**キーワードカバレッジ分析**を行ってください。

#### カバレッジ分析

Step 0で分解した各要望要素について、上位10件の結果の中で何名がその要素を満たしているかを数えます。

**分析テンプレート:**

```
要望要素の充足状況:
- [固有名詞] Rust: ○名/10名 がプロフィールに記載
- [一般スキル] 機械学習: ○名/10名 が関連スキルを保有
- 両方を満たす候補: ○名/10名
```

#### 再探索の判断基準

| 状況 | 判断 | アクション |
|---|---|---|
| 全要素が70%以上カバー | 探索完了 | Step 4へ |
| 固有名詞のカバーが低い（< 30%） | 再探索 | Mode B（キーワード検索）で固有名詞を直接検索 |
| 一般スキルのカバーが低い（< 30%） | 再探索 | Mode A（ベクトル検索）で類義語を追加してリトライ |
| 組み合わせのカバーが低い | 再探索 | Mode D（キーワード先行カスケード）を試行 |
| 出品者プロフィール検索で不十分 | 再探索 | **Mode SA/SB（サービス検索）で補完** |
| 候補が3名未満 & 3回探索済み | 探索完了 | 条件を緩和して最善の候補を報告 |

#### 再探索時の角度変更

前回とは異なるアプローチを選んでください:
- 固有名詞の別表記を試す（例: `rust` → `Rust` → `rust-lang`）
- 一般スキルの類義語を使う（例: 「機械学習」→「データサイエンス」「AI開発」）
- 検索モードを切り替える（Mode A ⇔ Mode B ⇔ Mode D）
- **出品者検索 → サービス検索に切り替える（Mode A/B/D → Mode SA/SB）**
- フィルタ条件を緩和する（AND → OR）

### Step 4: 最適な3名の選出

全探索結果（重複排除済み）から、ユーザーの要望に最も適した**3名**を選出してください。

**選出基準（優先度順）:**
1. **要望充足度**: 固有名詞キーワードと一般スキルの両方を満たすか
2. **専門性の深さ**: 得意分野、経験職種、資格の充実度 / サービスタイトルの合致度
3. **信頼性シグナル**: 実績数、評価、ランクの高さ
4. **ゴールド/プラチナ優先**: 同程度の要望充足度であれば、ランクが高い出品者を優先
5. **アクティブ度**: 最終ログインが最近か（30日以内が望ましい）

**ニッチな要望の場合:**
完全一致の候補がいない場合は、以下の方針で選出:
- 1名目: 固有名詞スキルを持ち、一般スキルに最も近い人
- 2名目: 一般スキルの専門家で、固有名詞スキルの習得ポテンシャルが高い人
- 3名目: 両方のスキル領域に部分的に該当する人

### Step 5: 結果の表示

以下のフォーマットで出力してください:

```
## 出品者Agentic検索結果

**検索ワード:** 「(ユーザーの元の要望)」
**探索回数:** N回
**検索戦略:** (使用した戦略の説明。例: 「Mode SA: サービスベクトル検索 → ポケモンカード風ウェルカムボード」)

### 要望分解
| カテゴリ | 要素 | 充足状況 |
|---|---|---|
| 固有名詞 | ... | ○名中○名が該当 |
| 一般スキル | ... | ○名中○名が該当 |
| サービス記述 | ... | ○名中○名が該当 |
| フィルタ | ... | 適用済/なし |

---

### 1. (出品者名) (user_id: XXXX)
**ランク:** プラチナ / ゴールド / ...
**職業:** ...（出品者プロフィール検索の場合）
**キャッチフレーズ:** ...
**マッチしたサービス:** [サービスタイトル](https://coconala.com/services/XXXX)（¥XX,XXX）（サービス検索の場合）
**出品サービス一覧:** サービス1 | サービス2 | ...（サービス検索の場合）
**経験職種:** ...（出品者プロフィール検索の場合）
**資格・検定:** ...（出品者プロフィール検索の場合）
**実績:** 完了取引 XX件 / 評価 X.XX (XX件) / お気に入り XX件
**本人確認:** 済 / 未  |  **NDA:** 締結済 / 未
**最終ログイン:** YYYY-MM-DD（N日前）
**推薦理由:** (なぜこの出品者がユーザーの要望に合うか、2-3文で)
**プロフィール:** https://coconala.com/users/XXXX

---

### 2. ...

---

### 3. ...
```

**ニッチな要望の場合の追加出力:**
完全一致が0名の場合、結果の末尾に以下を追加:

```
---

### 補足
「(固有名詞)」と「(一般スキル)」の両方をプロフィールに明記している出品者は現在 0名 です。
上記の候補は (固有名詞) のスキルを持つ出品者の中から、(一般スキル) に最も近い方を選出しています。
ご依頼の際は、メッセージで直接「(一般スキル) の対応可否」をご確認されることをお勧めします。
```
