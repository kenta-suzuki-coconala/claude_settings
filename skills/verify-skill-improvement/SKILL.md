---
name: verify-skill-improvement
description: >-
  スキルの最適化効果を検証する。optimize-skill の解析→計画作成→修正適用→計測→比較の
  一連フローを自動化し、reports/ ディレクトリに結果を記録する。
  「スキルの改善効果を検証」「最適化が効いているか確認」などの文脈に反応する。
argument-hint: "<target-skill-name> <test-input>"
invocation: user
---

# /verify-skill-improvement - スキル改善効果検証

`$ARGUMENTS` の第1引数で対象スキル、第2引数以降をテスト入力として受け取り、
最適化の計画・修正・計測・実行結果比較を一貫して実行する。

## 使い方

```
/verify-skill-improvement translate "トークルームのクローズ率を分析したい"
/verify-skill-improvement diagnose "ModuleNotFoundError: No module named 'qrcode'"
/verify-skill-improvement optimize-skill translate
```

## 実行フロー

### Step 1: 対象スキルの特定とテスト入力の確認

`$ARGUMENTS` をパースする：
- 第1引数: `TARGET_SKILL`（スキル名またはファイルパス）
- 第2引数以降: `TEST_INPUT`（スキルの実行に渡す入力）

スキルファイルを以下の優先順で探す：

| 入力形式 | 探索先 |
|---------|--------|
| スキル名 | `.claude/skills/<name>/SKILL.md` → `.claude/skills/<name>.md` → `~/.claude/skills/<name>/SKILL.md` |
| ファイルパス | そのまま使用 |

見つからない場合は Glob で `.claude/skills/**/*.md` を検索して候補を提示して止まる。
`TEST_INPUT` が空の場合はユーザーに確認して止まる。

### Step 2: 作業ディレクトリの作成

`TARGET_SKILL` と今日の日付（YYYY-MM-DD）を使って `reports/YYYY-MM-DD_<TARGET_SKILL>_improvement/` を Bash で作成する。以降の全ファイルはこの `WORK_DIR` に作成する。スキルファイルのバックアップを `<元のパス>.bak` に作成する。

### Step 3: 修正前スキル実行 → before_result.md

**Agent ツールで独立したサブエージェントを起動し**、以下を指示する（メインセッションのコンテキスト蓄積を除外するため）：

> `<スキルファイルパス>` を Read し、`TEST_INPUT` を `$ARGUMENTS` として渡した場合と同様にスキルの手順をツール呼び出しも含めて実際に実行せよ。結果を `WORK_DIR/before_result.md` に以下の形式で書き出して終了せよ：
> - ヘッダー: スキル名・入力・実行日時・ファイルサイズ・推定トークン数
> - 実行ログ: Claude応答・ツール呼び出し・出力をそのまま記載
> - 実行サマリ: 完了 Yes/No・出力品質の気になった点

### Step 4: optimize-skill 解析 → plan.md

対象スキルに対して optimize-skill と同等の解析を実行し、`WORK_DIR/plan.md` に改善計画を書き出す。

**トークン推定**: `ファイルサイズ(bytes) ÷ 3`

アンチパターン検出カテゴリ・検出方法・改善案は optimize-skill/SKILL.md の定義に従う。`WORK_DIR/plan.md` に解析サマリ・修正タスクテーブル（ID・優先度・内容・推定削減tok・状態）を書き出す。

### Step 5: 修正の反復適用 → results_log.md

`WORK_DIR/results_log.md` を作成し、plan.md のタスクを優先度順に適用する。

各タスクごとに：
1. Edit でスキルファイルを修正（コードブロック内など動作に影響しうる変更は適用前にユーザーに確認する）
2. `wc -c <ファイルパス>` でファイルサイズを取得してトークン数を再計算
3. results_log.md に「タスクID・修正内容・修正前後のサイズ/トークン・削減率」を追記
4. plan.md の「状態」列を「完了」に更新

### Step 6: 修正後スキル実行 → after_result.md

全タスク適用後、Step 3 と同様に **Agent ツールで独立したサブエージェントを起動**し、同じ指示を渡す（`WORK_DIR/after_result.md` に書き出す点のみ異なる）。フォーマットは before_result.md と同一とする。

### Step 7: 比較レポート → comparison.md

`WORK_DIR/comparison.md` に以下を書き出す：

- **トークン変化テーブル**: Before/After のサイズ・推定トークン・検出問題数と削減率
- **累積削減効果**: results_log.md の各タスク適用後のサイズ/トークン推移テーブル
- **実行結果の変化**: before_result.md / after_result.md の特徴的な出力を抜粋して比較し、品質・正確さ・簡潔さの変化を評価
- **総合評価**: Good / Bad / Mixed の判定と理由（トークン削減と出力品質の両面から）

### Step 8: 完了報告

以下をユーザーに報告する：

1. **総評（comparison.md より抜粋）**: 総合評価（Good / Bad / Mixed）・トークン削減率・出力品質の変化を2〜3文で要約し、**詳細は `WORK_DIR/comparison.md` を参照** と案内する
2. **数値サマリ**: トークン削減量・適用修正件数・残存問題数
3. **推定トークン使用量（概算）**: `wc -c` で読み込み済みファイルのサイズを取得し、合計 ÷ 3 を入力トークン推定とする（対象ファイル: verify-skill-improvement/SKILL.md・対象スキル・optimize-skill/SKILL.md・before_result.md・after_result.md）。出力推定は入力合計 × 0.5 を加算。Agent 2回分は対象スキルファイルサイズ ÷ 3 × 2 として別途加算する。**あくまでファイルサイズベースの目安であり、実際のAPI使用量とは異なる。**

4. **生成ファイル一覧**: `WORK_DIR/` 配下のファイルパスを列挙（before_result.md / plan.md / results_log.md / after_result.md / comparison.md）
