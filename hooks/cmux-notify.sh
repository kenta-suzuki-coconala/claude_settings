#!/bin/bash
# cmux通知スクリプト
if [ -S /tmp/cmux.sock ] || [ -n "${CMUX_WORKSPACE_ID:-}" ]; then
  cmux notify \
    --title "Claude Code" \
    --body "タスクが完了しました" 2>/dev/null || true
fi
