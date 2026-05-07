---
name: ab-test-design
description: ABテストの設計支援。ファクトデータに基づくサンプルサイズ計算と必要期間を提案します。
invocation: user
---

# /ab-test-design - ABテスト設計支援

ABテストの設計を支援します。BigQueryでファクトデータを取得し、サンプルサイズを計算し、テスト期間を提案します。

## 使い方

```bash
/ab-test-design サービス詳細ページでポップアップを出すABテスト
/ab-test-design 検索結果ページのレイアウト変更ABテスト、CVRは検索→購入
/ab-test-design トップページのバナー変更、CTRを計測
```

## 処理フロー

```
Step 1: 要件整理
    ↓
Step 2: ファクトデータ取得（BigQuery / bqコマンド）
    ↓
Step 3: サンプルサイズ計算（Python）
    ↓
Step 4: パワーシミュレーション（Python）
    ↓
Step 5: 提案レポート出力
```

## 関連スキル

- `/analyze` - データ分析スキル。複雑なクエリや追加分析が必要な場合に利用

---

## 実行

{{input}} のABテスト設計を支援してください。

### 必須手順

---

#### Step 1: 要件整理

**1-1. ABテストの要件を整理**

ユーザーの入力から以下を特定してください。不明な場合は AskUserQuestion で確認：

| 項目 | 説明 | 例 |
|------|------|-----|
| **テスト対象ページ** | どのページでテストするか | サービス詳細、検索結果、トップ |
| **施策内容** | 何を変更するか | ポップアップ表示、レイアウト変更 |
| **主要KPI** | 何を計測するか | CVR、CTR、購入率 |
| **CVRの定義** | 分母と分子の定義 | ページ訪問UU → 7日以内購入UU |
| **分割比率** | A/Bの割り当て比率 | 50:50（デフォルト） |

**1-2. アクション名の特定**

`.claude/resources/coconala/user-action-guide.md` を参照し、対象ページのアクション名を特定：

| ページ | 表示アクション | CVアクション |
|--------|---------------|-------------|
| サービス詳細 | `view_service` | `action_service_order_add` |
| 検索結果 | `view_service_search` | `view_service` |
| トークルーム | `view_talkroom` | `action_talkroom_deliver` |

**表示（必須）**: 要件整理結果を表示

```
【ABテスト要件】
- テスト対象: {ページ名}
- 施策内容: {施策の説明}
- 主要KPI: {CVR/CTRなど}
- CVR定義: {分母} → {分子}（{期間}以内）
- 分割比率: {50:50など}
- 対象アクション:
  - 分母: {action名}
  - 分子: {action名}
```

---

#### Step 2: ファクトデータ取得（BigQuery / bqコマンド）

**重要**: BigQueryへのアクセスは必ず `bq` コマンドを使用してください。

**補足**: 複雑な分析が必要な場合は `/analyze` スキルを併用できます。

**2-1. SQLクエリの生成**

以下のテンプレートをベースにクエリを生成：

```sql
-- ABテスト設計用: {KPI名}の日次データ取得
WITH base_action AS (
  -- 分母: {アクション説明}
  SELECT
    local_date AS action_date,
    COALESCE(CAST(user_id AS STRING), ccuid) AS uid
  FROM `indigo-medium-816.data_lake.user_action`
  WHERE
    local_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL {期間+観測期間} DAY)
                   AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL {観測期間+1} DAY)
    AND action = "{分母アクション}"
    AND device != "bot"
  GROUP BY local_date, uid
),
conversion_action AS (
  -- 分子: {アクション説明}
  SELECT
    local_date AS conversion_date,
    COALESCE(CAST(user_id AS STRING), ccuid) AS uid
  FROM `indigo-medium-816.data_lake.user_action`
  WHERE
    local_date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL {期間+観測期間} DAY)
                   AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
    AND action IN ({分子アクション})
    AND device != "bot"
  GROUP BY local_date, uid
),
daily_stats AS (
  SELECT
    ba.action_date,
    COUNT(DISTINCT ba.uid) AS base_uu,
    COUNT(DISTINCT CASE
      WHEN EXISTS (
        SELECT 1 FROM conversion_action ca
        WHERE ca.uid = ba.uid
          AND ca.conversion_date BETWEEN ba.action_date
              AND DATE_ADD(ba.action_date, INTERVAL {観測期間} DAY)
      ) THEN ba.uid
    END) AS conversion_uu
  FROM base_action ba
  GROUP BY ba.action_date
)
SELECT
  "直近30日平均" AS period,
  ROUND(AVG(base_uu), 0) AS avg_daily_base_uu,
  ROUND(AVG(conversion_uu), 0) AS avg_daily_conversion_uu,
  ROUND(SAFE_DIVIDE(SUM(conversion_uu), SUM(base_uu)) * 100, 3) AS overall_cvr_pct,
  MIN(base_uu) AS min_daily_base_uu,
  MAX(base_uu) AS max_daily_base_uu
FROM daily_stats
```

**2-2. クエリ実行**

```bash
bq query --use_legacy_sql=false --format=prettyjson '{クエリ}'
```

**表示（必須）**: 実行結果を表示

```
【ファクトデータ取得結果】

実行SQL:
```sql
{実行したSQL}
```

結果:
| 指標 | 値 |
|------|-----|
| 日次{分母}UU | {値} UU/日 |
| 日次{分子}UU | {値} UU/日 |
| ベースラインCVR | {値}% |
| 日次変動幅 | {min} 〜 {max} UU |
```

---

#### Step 3: サンプルサイズ計算（Python）

**3-1. Pythonコードの実行**

以下のコードをBashで実行：

```python
import math

# ========================================
# ABテスト サンプルサイズ計算
# ========================================

# Step 2 で取得したファクトデータ
baseline_cvr = {取得したCVR}  # 例: 0.03365
daily_traffic = {取得した日次UU}  # 例: 230000

# 統計的パラメータ（標準設定）
alpha = 0.05  # 有意水準（両側検定）
power = 0.80  # 検出力

# Z値
z_alpha_2 = 1.96  # α=0.05 両側検定
z_beta = 0.84     # β=0.20 (検出力80%)

def calculate_sample_size(p1, mde_relative):
    """
    二項検定のサンプルサイズ計算（各群）

    公式: n = 2 × (Z_α/2 + Z_β)² × p̄(1-p̄) / δ²
    """
    p2 = p1 * (1 + mde_relative)
    delta = p2 - p1
    p_pooled = (p1 + p2) / 2
    numerator = 2 * ((z_alpha_2 + z_beta) ** 2) * p_pooled * (1 - p_pooled)
    denominator = delta ** 2
    return math.ceil(numerator / denominator)

def calculate_test_days(n_per_group, daily_traffic, split_ratio=0.5):
    """必要なテスト日数を計算"""
    daily_per_group = daily_traffic * split_ratio
    return math.ceil(n_per_group / daily_per_group)

# MDE別計算
print("=" * 60)
print("サンプルサイズ計算結果")
print("=" * 60)
print(f"ベースラインCVR: {baseline_cvr * 100:.3f}%")
print(f"日次トラフィック: {daily_traffic:,} UU")
print()

for mde in [0.05, 0.10, 0.20]:
    n = calculate_sample_size(baseline_cvr, mde)
    days = calculate_test_days(n, daily_traffic)
    p2 = baseline_cvr * (1 + mde)
    print(f"MDE={mde*100:.0f}%: 効果後CVR={p2*100:.3f}%, 各群={n:,}, 統計日数={days}日")
```

**表示（必須）**: 計算結果を表示

```
【サンプルサイズ計算結果】

入力パラメータ:
- ベースラインCVR: {値}%
- 日次トラフィック: {値} UU
- 有意水準(α): 0.05（両側検定）
- 検出力(1-β): 80%

計算式:
n = 2 × (Z_α/2 + Z_β)² × p̄(1-p̄) / δ²

MDE別結果:
| MDE | 効果後CVR | 各群サンプル | 統計的必要日数 |
|-----|----------|-------------|--------------|
| 5%  | {値}%    | {値}        | {値}日       |
| 10% | {値}%    | {値}        | {値}日       |
| 20% | {値}%    | {値}        | {値}日       |
```

---

#### Step 4: パワーシミュレーション（Python）

**4-1. シミュレーションの目的**

Step 3で算出した**推奨案（推奨テスト期間・想定MDE）**に対して、モンテカルロシミュレーションで検出力を検証します。

**重要**: シミュレーションは推奨案の妥当性を確認するために行います。汎用的なマトリックスではなく、提案する具体的な条件でシミュレーションしてください。

**4-2. 推奨案の確定**

Step 3の結果から、以下の推奨案を確定：

```
推奨案:
- 推奨テスト期間: {Step 3で決定した日数}日間
- 想定MDE: {ユーザーの期待または標準的な10%}
- 各群サンプルサイズ: {日次UU × 0.5 × 推奨日数}
```

**4-3. 推奨案に対するシミュレーション実行**

以下のコードをBashで実行：

```python
import numpy as np
import math

np.random.seed(42)

# ========================================
# 推奨案に対するパワーシミュレーション
# ========================================

# Step 2 で取得したファクトデータ
baseline_cvr = {取得したCVR}  # 例: 0.03365
daily_traffic = {取得した日次UU}  # 例: 230000

# Step 3 で決定した推奨案
recommended_days = {推奨テスト期間}  # 例: 14
target_mde = {想定MDE}  # 例: 0.10

# 統計的パラメータ
alpha = 0.05
z_alpha_2 = 1.96
z_beta = 0.84

def calculate_sample_size(p1, mde_relative):
    """理論的なサンプルサイズを計算"""
    p2 = p1 * (1 + mde_relative)
    delta = p2 - p1
    p_pooled = (p1 + p2) / 2
    numerator = 2 * ((z_alpha_2 + z_beta) ** 2) * p_pooled * (1 - p_pooled)
    denominator = delta ** 2
    return math.ceil(numerator / denominator)

def simulate_ab_test(p_control, p_treatment, n_per_group, n_simulations=10000):
    """モンテカルロシミュレーションで検出力を計算"""
    significant_count = 0
    for _ in range(n_simulations):
        control_conv = np.random.binomial(n_per_group, p_control)
        treatment_conv = np.random.binomial(n_per_group, p_treatment)
        control_cvr = control_conv / n_per_group
        treatment_cvr = treatment_conv / n_per_group
        pooled = (control_conv + treatment_conv) / (2 * n_per_group)
        se = math.sqrt(2 * pooled * (1 - pooled) / n_per_group) if pooled > 0 else 0.0001
        z_stat = abs(treatment_cvr - control_cvr) / se
        if z_stat > z_alpha_2:
            significant_count += 1
    return significant_count / n_simulations

# 推奨案のパラメータ
actual_n = int(daily_traffic * 0.5 * recommended_days)
theoretical_n = calculate_sample_size(baseline_cvr, target_mde)
p_treatment = baseline_cvr * (1 + target_mde)

print("=" * 70)
print("推奨案に対するシミュレーション結果")
print("=" * 70)
print()
print(f"【推奨案】")
print(f"  テスト期間: {recommended_days}日間")
print(f"  想定MDE: {target_mde*100:.0f}%")
print(f"  ベースラインCVR: {baseline_cvr*100:.3f}%")
print(f"  効果後CVR: {p_treatment*100:.3f}%")
print(f"  各群サンプルサイズ: {actual_n:,}")
print(f"  理論的必要サンプル: {theoretical_n:,}")
print(f"  サンプル充足率: {actual_n/theoretical_n:.1f}倍")
print()

# 推奨案の検出力シミュレーション
print("【シミュレーション実行中...】")
power = simulate_ab_test(baseline_cvr, p_treatment, actual_n)
print(f"  検出力（Power）: {power*100:.1f}%")
print(f"  判定: {'✓ 十分（80%以上）' if power >= 0.80 else ('△ やや不足（60-80%）' if power >= 0.60 else '× 不足（60%未満）')}")
print()

# AAテスト（偽陽性率）
print("【AAテスト（偽陽性率の確認）】")
fpr = simulate_ab_test(baseline_cvr, baseline_cvr, actual_n)
print(f"  偽陽性率: {fpr*100:.1f}%（期待値: 5.0%）")
print(f"  判定: {'✓ 正常' if 4.0 <= fpr*100 <= 6.0 else '△ 要確認'}")
```

**表示（必須）**: シミュレーション結果を表示

```
【推奨案シミュレーション結果】

推奨案:
- テスト期間: {推奨日数}日間
- 想定MDE: {値}%
- 各群サンプルサイズ: {値}

シミュレーション結果（10,000回）:
- 検出力: {値}%（判定: ✓/△/×）
- 偽陽性率: {値}%（期待値: 5.0%）
- サンプル充足率: 理論値の{X}倍
```

**4-4. サニティチェック（必須）**

**シミュレーション結果をユーザーに提示する前に、以下のチェックを必ず実施してください。**

| チェック項目 | 異常の兆候 | 対処 |
|-------------|-----------|------|
| **検出力が100%** | 100.0%になっている | サンプル充足率を確認。10倍超なら妥当だが、より小さいMDEでも検証 |
| **検出力が80%未満** | 推奨案なのに検出力不足 | テスト期間の延長、またはMDEの見直しを提案 |
| **偽陽性率が5%から大きく乖離** | 1%未満 or 10%超 | シミュレーションコードのバグの可能性 |

**検出力100%の場合の追加検証**:

```python
# より小さいMDEでの検出力を確認
print("【追加検証: 小さいMDEでの検出力】")
for mde in [0.01, 0.02, 0.03, 0.05]:
    p_treat = baseline_cvr * (1 + mde)
    theoretical = calculate_sample_size(baseline_cvr, mde)
    ratio = actual_n / theoretical
    power = simulate_ab_test(baseline_cvr, p_treat, actual_n, n_simulations=5000)
    print(f"  MDE={mde*100:.0f}%: 検出力={power*100:.1f}%, 充足率={ratio:.1f}倍")
```

**表示（必須）**: サニティチェック結果

```
【サニティチェック結果】

1. 推奨案の検出力: {値}%
   - 判定: ✓ 十分 / △ やや不足 / × 不足

2. 検出力100%の場合の追加検証:
   - サンプル充足率: 理論値の{X}倍（10倍超なら100%は妥当）
   - 小さいMDEでの検出力:
     - MDE=1%: {値}%
     - MDE=2%: {値}%
     - MDE=3%: {値}%

3. 偽陽性率: {値}%
   - 判定: ✓ 正常（4-6%の範囲内） / △ 要確認

4. 総合判定: ✓ 推奨案は妥当 / △ 注意事項あり / × 推奨案の見直しが必要
```

**検出力が不足している場合**:
1. テスト期間の延長を提案（例: 14日→21日）
2. MDEの見直しを提案（例: 10%→20%）
3. ユーザーに判断を求める

---

#### Step 5: 提案レポート出力

以下の形式で最終レポートを出力：

```markdown
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## ABテスト設計 提案結果
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

### 概要
{施策の説明}（{分割比率}分割）

---

### 分析に基づく数値

| 指標 | 値 | データソース |
|------|-----|-------------|
| 日次{分母}UU | **{値} UU/日** | BigQuery（直近30日平均） |
| ベースラインCVR | **{値}%** | {CVR定義} |
| 日次変動幅 | {min} 〜 {max} UU | - |

---

### 推奨テスト期間

| 項目 | 推奨値 |
|------|--------|
| **テスト期間** | **{推奨日数}日間** |
| 結果確定日 | テスト終了から{観測期間}日後 |

---

### MDE別サンプルサイズ

| MDE（相対） | 効果後CVR | 各群必要サンプル | 統計的必要日数 |
|------------|----------|-----------------|--------------|
| 5% | {値}% | {値} | {値}日 |
| 10% | {値}% | {値} | {値}日 |
| 20% | {値}% | {値} | {値}日 |

※ 統計条件: α=0.05（両側）、検出力80%

---

### {推奨日数}日間を推奨する理由

1. **{理由1のタイトル}**: {理由1の説明}
2. **{理由2のタイトル}**: {理由2の説明}
3. **{理由3のタイトル}**: {理由3の説明}

---

### 計算に使用した前提条件

| パラメータ | 値 |
|-----------|-----|
| 有意水準（α） | 0.05（両側検定） |
| 検出力（1-β） | 80% |
| Z_α/2 | 1.96 |
| Z_β | 0.84 |
| 分割比率 | {分割比率} |

---

### 利用したSQL

```sql
{Step 2で実行したSQL}
```

---

### 利用したPythonコード（サンプルサイズ計算）

```python
{Step 3で実行したPythonコード}
```

---

### パワーシミュレーション結果（推奨案の検証）

推奨案に対するシミュレーション（10,000回）:

| 項目 | 値 |
|------|-----|
| テスト期間 | {推奨日数}日間 |
| 想定MDE | {値}% |
| 各群サンプルサイズ | {値} |
| **検出力** | **{値}%** {✓/△/×} |
| 偽陽性率 | {値}%（期待値: 5.0%） |
| サンプル充足率 | 理論値の{X}倍 |

サニティチェック:
- 小さいMDEでの検出力: MDE=1%→{値}%, MDE=2%→{値}%, MDE=3%→{値}%
- 総合判定: {✓ 推奨案は妥当 / △ 注意事項あり}

---

### 利用したPythonコード（シミュレーション）

```python
{Step 4で実行したPythonコード}
```

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 連続指標（GMV等）のABテスト設計 ★重要

### ⚠️ 連続指標と二項指標の違い

| 項目 | 二項指標（CVR等） | 連続指標（GMV等） |
|------|------------------|------------------|
| 値の分布 | 0 or 1 | 連続値（0含む） |
| 計算公式 | 二項検定ベース | t検定ベース |
| サンプル単位の注意 | 特になし | **ゼロ過多問題に注意** |

---

### UUを単位とする場合の問題（ゼロ過多分布）

**重要**: GMVをUU（ユーザー）単位で計算すると、正規近似が困難になります。

**理由**:
- 1日のサイト訪問者のうち、購入するのは約3〜5%程度
- つまり、95〜97%のユーザーのGMV = 0円
- このような「ゼロ過多分布（Zero-Inflated Distribution）」は正規分布から大きく乖離
- 中心極限定理による正規近似には膨大なサンプルが必要

**対処法**: **日次を単位として設計する**

---

### 日次単位での連続指標ABテスト設計

日次単位であれば、中心極限定理により正規近似が可能です。

#### 計算公式（t検定ベース）

```
n = 2 × (Z_α/2 + Z_β)² × σ² / δ²

ここで:
- n: 各群の必要サンプルサイズ（日数）
- Z_α/2: 有意水準に対応するZ値（α=0.05 → 1.96）
- Z_β: 検出力に対応するZ値（80% → 0.84）
- σ: 日次GMVの標準偏差
- δ: 検出したい差（MDE × 平均日次GMV）
```

#### ファクトデータ取得クエリ（GMV用）

**⚠️ 重要**: 流通高の計算には `segmented_payment_kpi_daily_latest` を使用すること。
`user_action` テーブルを使うと大幅に過小評価される。

```sql
-- 日次GMVの統計量取得（ABテスト設計用）
WITH daily_gmv AS (
  SELECT
    date,
    SUM(CASE WHEN kind = "paid" THEN amount ELSE -amount END) AS gmv
  FROM `indigo-medium-816.data_warehouse.segmented_payment_kpi_daily_latest`
  WHERE
    date BETWEEN DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 60 DAY)
              AND DATE_SUB(CURRENT_DATE("Asia/Tokyo"), INTERVAL 1 DAY)
    AND kind IN ("paid", "cancelled")
  GROUP BY date
)
SELECT
  AVG(gmv) AS avg_daily_gmv,
  STDDEV(gmv) AS stddev_daily_gmv,
  STDDEV(gmv) / AVG(gmv) AS cv,  -- 変動係数
  MIN(gmv) AS min_daily_gmv,
  MAX(gmv) AS max_daily_gmv,
  COUNT(*) AS days
FROM daily_gmv
```

**期待される結果（2026年2月時点）**:
- avg_daily_gmv: 約4,555万円
- stddev_daily_gmv: 約776万円
- cv（変動係数）: 約0.17

---

#### サンプルサイズ計算コード（連続指標用）

```python
import math

# ========================================
# ABテスト サンプルサイズ計算（連続指標・日次単位）
# ========================================

# ファクトデータ（BigQueryから取得した値を使用）
avg_daily_gmv = 45550000  # 例: 約4,555万円
stddev_daily_gmv = 7760000  # 例: 約776万円

# 統計的パラメータ
alpha = 0.05
power = 0.80
z_alpha_2 = 1.96
z_beta = 0.84

def calculate_sample_size_continuous(sigma, delta):
    """
    連続指標のサンプルサイズ計算（各群、日数）

    公式: n = 2 × (Z_α/2 + Z_β)² × σ² / δ²
    """
    numerator = 2 * ((z_alpha_2 + z_beta) ** 2) * (sigma ** 2)
    denominator = delta ** 2
    return math.ceil(numerator / denominator)

print("=" * 60)
print("サンプルサイズ計算結果（連続指標・日次単位）")
print("=" * 60)
print(f"平均日次GMV: {avg_daily_gmv / 10000:,.0f}万円")
print(f"標準偏差: {stddev_daily_gmv / 10000:,.0f}万円")
print(f"変動係数(CV): {stddev_daily_gmv / avg_daily_gmv:.2f}")
print()

for mde in [0.05, 0.10, 0.20]:
    delta = avg_daily_gmv * mde  # 絶対差
    n_days = calculate_sample_size_continuous(stddev_daily_gmv, delta)
    gmv_after = avg_daily_gmv * (1 + mde)
    print(f"MDE={mde*100:.0f}%: 効果後GMV={gmv_after/10000:,.0f}万円/日, 各群={n_days}日")
```

**計算例**（上記パラメータの場合）:
| MDE | 効果後GMV | 各群必要日数 | 合計必要日数 |
|-----|----------|-------------|-------------|
| 5% | 4,783万円/日 | 182日 | 非現実的 |
| 10% | 5,011万円/日 | 46日 | 92日（並行実施なら46日） |
| 20% | 5,466万円/日 | 12日 | 24日（並行実施なら12日） |

---

#### 連続指標の注意事項

1. **日数が長くなりがち**:
   - CVRと比べて、必要日数が長くなる傾向
   - MDE=10%でも46日必要など

2. **ベンチマーク検証を必ず実施**:
   - 日次GMVが4,000〜5,000万円の範囲内か確認
   - 範囲外の場合はデータソースの誤りを疑う

3. **並行実施の場合**:
   - A/B群を同時に実施するなら、必要日数は「各群必要日数」と同じ
   - 逐次実施（A期間→B期間）なら、必要日数は「各群必要日数 × 2」

4. **外部要因の影響**:
   - GMVは季節性・キャンペーン等の影響を強く受ける
   - 曜日効果を排除するため、最低でも1週間単位で設計

---

## 推奨期間の判断ロジック

| CVR定義に含まれる観測期間 | 最低テスト期間 | 推奨テスト期間 |
|--------------------------|---------------|---------------|
| 即時（クリックなど） | 7日 | 14日（曜日効果排除） |
| 1日以内 | 7日 | 14日 |
| 7日以内 | 7日 | 14日 |
| 30日以内 | 14日 | 28日 |

**追加考慮事項**:
- 曜日効果: 最低1週間、推奨2週間
- 新規性効果: ポップアップなど目新しい施策は減衰を観測するため2週間以上
- 季節性: 大型連休・セール時期を避ける or 含める判断

---

## パラメータ調整

ユーザーが指定した場合、以下のパラメータを調整：

| パラメータ | デフォルト | 調整例 |
|-----------|----------|--------|
| 有意水準（α） | 0.05 | 0.01（より厳密） |
| 検出力（1-β） | 0.80 | 0.90（より高い検出力） |
| MDE | 5%, 10%, 20% | ユーザー指定値 |
| 分割比率 | 50:50 | 80:20（低リスク） |

---

## エラーハンドリング

| 状況 | 対応 |
|------|------|
| アクション名が不明 | user-action-guide.md を検索、なければユーザーに確認 |
| BigQueryエラー | エラー内容を表示し、クエリを修正 |
| CVRが0%に近い | MDEを大きく設定するか、サンプル期間を延長 |
| トラフィックが少ない | 長期間のテストを提案、または別KPIを検討 |

---

## 関連リソース

### ドキュメント
- `.claude/resources/coconala/user-action-guide.md` - アクション名一覧
- `.claude/resources/coconala/sanity-check-benchmarks.md` - 数値ベンチマーク
- `.claude/resources/ubiquitous-dict/domain-specific/business_metrics_domain.md` - KPI定義

### ツール・コマンド
- `bq` コマンド - BigQueryへのアクセスに使用（必須）
  ```bash
  # クエリ実行
  bq query --use_legacy_sql=false --format=prettyjson '{SQL}'

  # ドライラン（コスト確認）
  bq query --dry_run --use_legacy_sql=false '{SQL}'
  ```

### 関連スキル
- `/analyze` - ココナラデータ分析スキル
  - 複雑なクエリ生成・実行・考察が必要な場合に利用
  - 数値検証やベンチマーク比較を自動で実施
  - 使用例: `/analyze 直近30日のサービス詳細PV UUを日別で`
