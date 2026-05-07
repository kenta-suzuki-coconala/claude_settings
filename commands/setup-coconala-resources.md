---
description: ココナラドメイン知識リソース（ubiquitous-dict）を ~/.claude/local/ に自動セットアップします。オプションでフック機能も設定可能です。
allowed-tools: [Bash]
---

# ココナラ AI リソースのセットアップ

ココナラのドメイン知識リソース（**ubiquitous-dict**）を Claude Code で使用可能な場所に自動配置します。

## ステップ 1: リソースのセットアップ

まず、セットアップ先ディレクトリを確認・準備します：

!  mkdir -p ~/.claude/local/

既存のリソースがあれば削除（常に最新版を保つため）：

! rm -rf ~/.claude/local/coconala-resources/

現在のディレクトリから `resource/ubiquitous-dict/` をセットアップ先にコピー：

! cp -r resource/ubiquitous-dict/ ~/.claude/local/coconala-resources/

## ステップ 2: フック機能のセットアップ（オプション）

セッション終了時に辞書を自動更新するフック機能をセットアップします。

フック実行スクリプトをセットアップ：

! mkdir -p ~/.claude/bin/
! mkdir -p ~/.claude/hook-work/
! mkdir -p ~/.claude/hook-logs/

メインフックスクリプトのコピー：

! cp .claude/bin/create-dictionary-update-pr.sh ~/.claude/bin/ 2>/dev/null || echo "フックスクリプトが見つかりません（スキップ）"

フック設定を settings.json に追加：

! bash -c 'if [ ! -f "$HOME/.claude/settings.json" ]; then echo "{}"; fi' > /tmp/settings-check.txt

フック設定が まだ追加されていない場合は、以下の内容を `~/.claude/settings.json` に手動で追加してください：

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/bin/create-dictionary-update-pr.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/bin/create-dictionary-update-pr.sh"
          }
        ]
      }
    ]
  }
}
```

## ✅ セットアップ完了！

リソースが以下の場所に配置されました：

```
~/.claude/local/coconala-resources/
└── ubiquitous-dict/
    ├── README.md              # AI向けの検索ノウハウ
    ├── index.md               # 全201用語の五十音順索引
    ├── aliases.md             # ユーザー表現⇔システム表現マッピング
    ├── general/               # ドメイン全体像・関係性
    └── domain-specific/       # 10ドメイン別詳細
```

### Claude で自動参照可能

このプロジェクトの Claude Code 内で、以下のパスからリソースが自動参照されます：

- `~/.claude/local/coconala-resources/ubiquitous-dict/index.md`
- `~/.claude/local/coconala-resources/ubiquitous-dict/aliases.md`
- `~/.claude/local/coconala-resources/ubiquitous-dict/general/`
- `~/.claude/local/coconala-resources/ubiquitous-dict/domain-specific/`

### フック機能について

フック機能をセットアップした場合、セッション終了時に以下が自動実行されます：

- 📊 会話履歴を自動分析
- ❓ ローカルの辞書を編集するか確認
- 📝 ユーザーの承認のもとで辞書を更新
- 🔀 GitHub PR を作成するか確認

詳細は `README.md` の「🤖 (オプション) セッション終了時の自動辞書更新フック」セクションを参照してください。

### 更新方法

リポジトリが更新されたら、同じコマンドを再実行してください。既存ディレクトリは自動削除され、最新版がセットアップされます。

```bash
/setup-coconala-resources
```

---

詳細は `README.md` を参照してください。
