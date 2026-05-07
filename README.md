claude codeの設定ファイルやカスタムコマンドを置いておくリポジトリです

## 構成

- `CLAUDE.md` / `CLAUDE-omc.md` — グローバル指示
- `settings.json.template` — `~/.claude/settings.json` のテンプレート（秘匿情報は `REPLACE_WITH_*` プレースホルダ）
- `commands/` — カスタムスラッシュコマンド
- `skills/` — カスタムスキル

## 新PCへの移植手順

```bash
# 1. クローン
git clone https://github.com/kenta-suzuki-coconala/claude_settings.git ~/Documents/claude_settings
cd ~/Documents/claude_settings

# 2. 配置
cp CLAUDE.md CLAUDE-omc.md ~/.claude/
cp -r commands/ ~/.claude/commands/
cp -r skills/ ~/.claude/skills/

# 3. settings.json は手動でテンプレートをコピーし、秘匿情報を埋める
cp settings.json.template ~/.claude/settings.json
# ~/.claude/settings.json を開いて REPLACE_WITH_* を実値に置換
```

## 秘匿情報の取り扱い

`settings.json` 本体には Slack Webhook / Notion API Token / Slack User Token が含まれるため、リポジトリにはコミットしない。1Password 等で別管理する。
