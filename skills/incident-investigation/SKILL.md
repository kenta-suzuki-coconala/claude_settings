---
name: incident-investigation
description: システム障害・パフォーマンス問題の原因調査とレポート作成を支援します。CloudWatch、BigQuery、GitHub PRを組み合わせて根本原因を特定し、対策を提案します。
invocation: user
---

# /incident-investigation - インシデント原因調査

システム障害・パフォーマンス問題の原因調査とレポート作成を実行します。

## 使い方

```bash
/incident-investigation <問題の説明>
```

### 例

```bash
/incident-investigation 2/25からRedisのメモリ使用率が上昇しています。リリース起因かもしれません。
/incident-investigation Lambda関数のレイテンシが急増しています
/incident-investigation トラフィック急増の原因を調査してください
```

## 処理内容

1. **問題定義**: 症状の明確化と仮説立案
2. **メトリクス分析**: CloudWatch、Datadog、BigQueryでデータ収集
3. **リリース履歴調査**: GitHub PRとデプロイログの確認
4. **仮説検証**: データに基づく根本原因の特定
5. **レポート作成**: テキスト + 視覚化（Mermaid図表、CSV、グラフ）
6. **対策提案**: 短期・中期・長期の対応策を提示

---

## 実行

{{input}} の問題を調査してください。

### 必須手順

#### Step 1: 問題の定義と仮説立案

**1-1. 症状の明確化**

ユーザーの入力から以下を抽出：
- **問題の種別**: パフォーマンス劣化、リソース枯渇、トラフィック異常、エラー率上昇
- **対象システム**: Redis, RDS, Lambda, ECS, API など
- **発生期間**: 開始日時、継続期間
- **影響範囲**: ユーザー影響、システム影響

**1-2. 初期仮説の立案**

問題の種別に応じて3-5個の仮説を列挙：

| 問題種別 | 仮説例 |
|----------|--------|
| メモリ上昇 | トラフィック増加、TTL設定ミス、メモリリーク |
| レイテンシ増加 | クエリ遅延、外部API遅延、リソース不足 |
| エラー率上昇 | コードバグ、依存サービス障害、タイムアウト |
| 接続数上昇 | コネクションリーク、プール設定ミス |

**1-3. 調査方針の決定**

- 優先的に調査するデータソースを決定（CloudWatch優先 or BigQuery優先）
- リリース起因の可能性が高い場合は GitHub PR調査も並行

**表示（必須）**: 以下をユーザーに表示：

```
## 問題定義

**症状**: {症状のサマリ}
**対象システム**: {システム名}
**発生期間**: {開始日〜現在}

**初期仮説**:
1. {仮説1}
2. {仮説2}
3. {仮説3}

**調査方針**:
- メトリクス分析: CloudWatch / Datadog
- トラフィック分析: BigQuery
- リリース履歴: GitHub PR
```

#### Step 2: メトリクス分析

**2-1. CloudWatch メトリクス取得**

対象システムに応じたメトリクスを取得：

| システム | 主要メトリクス |
|----------|--------------|
| ElastiCache (Redis) | DatabaseMemoryUsagePercentage, CPUUtilization, CurrConnections, NetworkBytesIn/Out |
| RDS | DatabaseConnections, CPUUtilization, FreeableMemory, ReadLatency, WriteLatency |
| Lambda | Duration, Errors, Throttles, ConcurrentExecutions |
| ECS | CPUUtilization, MemoryUtilization, TaskCount |

**必要な場合は system-architect スキルを使用**:
```bash
/system-architect で CloudWatch メトリクスを取得
```

**2-2. Datadog メトリクス確認**

アプリケーションレベルのメトリクスを確認：
- APM トレース
- カスタムメトリクス
- エラーログ

**2-3. BigQuery トラフィック分析**

`data_lake.user_action` からトラフィックを分析：
```sql
-- 日次集計
SELECT
  DATE(created_at) AS date,
  COUNT(*) AS total_requests,
  COUNT(DISTINCT user_id) AS unique_users,
  COUNTIF(device = 'pc') AS pc_requests,
  COUNTIF(device = 'sp') AS sp_requests,
  COUNTIF(device = 'app') AS app_requests
FROM `indigo-medium-816.data_lake.user_action`
WHERE created_at BETWEEN '{開始日}' AND '{終了日}'
  AND device != 'bot'
GROUP BY date
ORDER BY date
```

**表示（必須）**: 取得したメトリクスを要約して表示：

```
## メトリクス分析結果

### CloudWatch（{対象システム}）
- {メトリクス1}: {開始時} → {現在} ({変化率}%)
- {メトリクス2}: {開始時} → {現在} ({変化率}%)

### BigQuery（トラフィック）
- 日次リクエスト数: {平均値}（変化なし / +X% / -X%）
- ユニークユーザー数: {平均値}（変化なし / +X% / -X%）
```

#### Step 3: リリース履歴調査

**3-1. GitHub PR履歴取得**

問題発生期間前後のマージPRを取得：
```bash
gh pr list --repo welself/{リポジトリ名} --state merged --limit 50 --json number,title,mergedAt,author
```

**3-2. 疑わしいPRの特定**

問題発生日前後にマージされたPRで以下に該当するものを抽出：
- キャッシュ関連の変更
- データベースクエリの変更
- 外部API呼び出しの変更
- TTL・タイムアウト設定の変更

**3-3. ソースコード確認**

疑わしいPRのdiffを確認：
```bash
gh pr view {PR番号} --repo welself/{リポジトリ名} --json files
gh pr diff {PR番号} --repo welself/{リポジトリ名}
```

**表示（必須）**: 疑わしいPRを表示：

```
## リリース履歴調査

### 該当期間のマージPR（{開始日}〜{現在}）

| PR番号 | タイトル | マージ日時 | 疑わしさ |
|--------|---------|-----------|---------|
| #{番号} | {タイトル} | {日時} | 高/中/低 |

### 詳細確認が必要なPR
- PR #{番号}: {理由}
```

#### Step 4: 仮説検証

**4-1. データの相関分析**

メトリクス変化とリリースタイミングの相関を確認：
- リリース前後でメトリクスが変化したか
- トラフィック変化とメトリクス変化の相関

**4-2. 根本原因の特定**

| パターン | 判定 |
|----------|------|
| リリース直後にメトリクス変化 + トラフィック変化なし | コード変更起因の可能性大 |
| トラフィック急増 + メトリクス悪化 | トラフィック起因 |
| 徐々に悪化 + 特定リリース後 | TTL/設定ミスによる蓄積 |
| 定期的なスパイク | バッチ処理、キャッシュ更新 |

**表示（必須）**: 検証結果を表示：

```
## 仮説検証

### 検証結果
- 仮説1: {検証結果}（○ 支持される / × 否定される）
- 仮説2: {検証結果}（○ 支持される / × 否定される）

### 根本原因
{根本原因の説明}

**エビデンス**:
- {エビデンス1}
- {エビデンス2}
```

#### Step 5: レポート作成

**5-1. テキストレポート出力**

Write ツールで `reports/{日付}_{対象}_{種別}_調査レポート.md` を作成：

```markdown
# {問題タイトル} - 原因調査レポート

実行日時: {YYYY-MM-DD HH:MM}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 1. 問題の定義

**症状**: {症状}
**対象システム**: {システム}
**発生期間**: {期間}
**影響範囲**: {影響}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 2. メトリクス分析

### CloudWatch
{メトリクス表}

### BigQuery
{トラフィック分析結果}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 3. リリース履歴

{マージPR一覧}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 4. 根本原因

{根本原因の説明}

**エビデンス**:
{エビデンス}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## 5. 対策提案

### 短期対策（即時実施）
1. {対策1}
2. {対策2}

### 中期対策（1-2週間）
1. {対策1}
2. {対策2}

### 長期対策（1-3ヶ月）
1. {対策1}
2. {対策2}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**5-2. 視覚化レポート出力**

Mermaid図表を含むレポート `reports/{日付}_{対象}_視覚化レポート.md` を作成：

```markdown
# {問題タイトル} - 視覚化レポート

## メトリクス推移

```mermaid
graph LR
    A[{開始日}] -->|{変化}| B[{中間日}]
    B -->|{変化}| C[{現在}]
```

## タイムライン

```mermaid
gantt
    title インシデントタイムライン
    dateFormat YYYY-MM-DD
    section メトリクス
    正常値 :{開始前日}, {開始日}
    上昇開始 :{開始日}, {ピーク日}
    ピーク :{ピーク日}, {現在}
    section リリース
    PR #{番号} :{マージ日}, 1d
```
```

**完了メッセージ**: レポート出力後、以下を表示：

```
調査レポートを保存しました:
- テキストレポート: reports/{ファイル名}
- 視覚化レポート: reports/{ファイル名}
```

#### Step 6: 対策提案

**6-1. 短期対策（即時実施）**

問題の影響を最小化する対策：
- 監視アラートの設定
- 手動でのリソース増強
- 緊急ロールバック

**6-2. 中期対策（1-2週間）**

根本原因を修正する対策：
- コード修正のPR作成
- 設定変更（TTL、タイムアウト等）
- リソース最適化

**6-3. 長期対策（1-3ヶ月）**

再発を防ぐための対策：
- アーキテクチャ改善
- 自動スケーリング導入
- 負荷テスト実施

**AskUserQuestion での確認**:

緊急性の高い対策が必要な場合は確認：

```
根本原因が特定されました。以下の対策を推奨します。

【短期対策】
1. {対策1}
2. {対策2}

すぐに実施すべき対策はありますか？

選択肢：
1. 対策1を実施する（推奨）
2. 対策2を実施する
3. レポートのみ出力（手動で対応）
```

---

## 対象システム

| システム | メトリクス取得方法 |
|----------|------------------|
| ElastiCache (Redis) | CloudWatch: DatabaseMemoryUsagePercentage, CPUUtilization, CurrConnections |
| RDS | CloudWatch: DatabaseConnections, FreeableMemory, ReadLatency, WriteLatency |
| Lambda | CloudWatch: Duration, Errors, Throttles, ConcurrentExecutions |
| ECS | CloudWatch: CPUUtilization, MemoryUtilization |
| アプリケーション | Datadog: APM, カスタムメトリクス |
| トラフィック | BigQuery: data_lake.user_action |

---

## 関連スキル

- `/system-architect`: CloudWatch Logs の詳細分析
- `/diagnose`: コードエラーの診断と修復
- `/analyze`: BigQuery データ分析
