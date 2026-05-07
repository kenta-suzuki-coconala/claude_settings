---
allowed-tools: [WebSearch, WebFetch, Write, Bash]
argument-hint: "[論文のURL or キーワード] (オプション)"
description: "ArXivから機械学習論文を検索・要約し、落合陽一フォーマットでまとめます"
---

# ML Paper Summary

## 目的
機械学習関連の論文をArXivから検索し、落合陽一フォーマットで要約してDocuments/ml-papersディレクトリに保存します。

## 実行内容

### ステップ1: 論文の検索・特定
- 引数が提供された場合：
  - URLの場合：そのURL先の論文を直接取得
  - キーワードの場合：そのキーワードで検索
- 引数が未提供の場合：最新の主要カンファレンス論文を検索
  - 優先カンファレンス：RecSys, AAAI, NeurIPS, ICML
  - 最近投稿された論文またはbest paper受賞論文を優先

### ステップ2: 論文内容の取得・解析
- ArXivから論文のPDFまたは詳細情報を取得
- 論文の主要な内容を抽出・解析

### ステップ3: 落合陽一フォーマットでの要約作成
以下の6項目で構造化：
1. どんなもの？
2. 先行研究と比べてどこがすごい？
3. 技術や手法のキモはどこ？
4. どうやって有効だと検証した？
5. 議論はある？
6. 次に読むべき論文は？

### ステップ4: Markdownファイルの生成
- ファイル名：`<論文のタイトル>.md`
- 保存先：`Documents/ml-papers/`
- フォーマット：見出し、本文、引用情報を含む

## パラメータ
- $1: [オプション] 論文のURL または 検索キーワード
  - URL例：https://arxiv.org/abs/2301.12345
  - キーワード例：attention mechanism, transformer, recommendation system
- $ARGUMENTS: 引数が未提供の場合、最新の主要論文を自動検索

## 使用例

### 特定の論文URLを指定
```
/ml-paper-summary https://arxiv.org/abs/2301.12345
```

### キーワードで検索
```
/ml-paper-summary transformer attention
```

### 最新論文の自動検索
```
/ml-paper-summary
```

## 処理フロー

1. **引数解析**: URLかキーワードか、または自動検索かを判定
2. **論文検索/取得**: ArXivから適切な論文を取得
3. **内容解析**: 論文の主要セクションを読み取り
4. **要約生成**: 落合陽一フォーマットに沿って構造化
5. **各章の要約生成**: 論文の各セクションを要約する（必要に応じて数式をlatex形式で記載する）
6. **ファイル出力**: Documents/ml-papers/に保存

---

## 実行コード

論文の検索と要約を開始します。

# 引数の確認
if [ -n "$1" ]; then
    if [[ "$1" == https://arxiv.org/* ]]; then
        echo "指定されたURL から論文を取得します: $1"
        PAPER_SOURCE="url"
        PAPER_URL="$1"
    else
        echo "キーワード '$ARGUMENTS' で論文を検索します"
        PAPER_SOURCE="keyword"
        SEARCH_KEYWORDS="$ARGUMENTS"
    fi
else
    echo "最新の主要カンファレンス論文を検索します"
    PAPER_SOURCE="auto"
fi

# 論文の検索・取得
case $PAPER_SOURCE in
    "url")
        # 指定URLから論文を直接取得
        echo "論文を取得中..."
        ;;
    "keyword")
        # キーワードで検索
        echo "ArXivでキーワード検索中..."
        ;;
    "auto")
        # 最新の主要論文を自動検索
        echo "最新の機械学習論文を検索中..."
        ;;
esac

echo "論文の解析と要約作成を開始します..."
echo "落合陽一フォーマットで要約を作成し、Documents/ml-papers/ に保存します。"