#!/bin/bash
# LLM Wiki セットアップ（macOS / Linux）
#
#   ./install/install.sh              vault とスキル・ルール・フックを配置
#   ./install/install.sh --connect .  カレントのプロジェクトを接続
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT="${LLM_WIKI_VAULT:-$HOME/wiki}"
CLAUDE_DIR="$HOME/.claude"

info() { printf '  %s\n' "$*"; }
ok()   { printf '\033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[33m!\033[0m %s\n' "$*"; }

# --- プロジェクト接続モード ---------------------------------------------
if [ "${1:-}" = "--connect" ]; then
  PROJ_DIR="$(cd "${2:-.}" && pwd)"
  PROJ_NAME="$(basename "$PROJ_DIR")"

  mkdir -p "$PROJ_DIR/docs/raw" "$PROJ_DIR/docs/wiki"
  mkdir -p "$VAULT/mounts"
  ln -sfn "$PROJ_DIR/docs/wiki" "$VAULT/mounts/$PROJ_NAME"

  [ -f "$PROJ_DIR/CLAUDE.md" ] || sed "s/<PROJECT>/$PROJ_NAME/g" "$REPO/template/CLAUDE.md.example" > "$PROJ_DIR/CLAUDE.md"

  ok "$PROJ_NAME を接続しました"
  info "docs/raw/ と docs/wiki/ を作成し、$VAULT/mounts/$PROJ_NAME から繋ぎました"
  echo
  info "次の手順:"
  info "  1. Claude Code で /llm-wiki ingest README.md"
  info "  2. git add docs CLAUDE.md && git commit -m \"LLM Wiki を導入\""
  exit 0
fi

# --- 初期セットアップ ---------------------------------------------------
echo "LLM Wiki をセットアップします"
echo "  vault: $VAULT"
echo

mkdir -p "$VAULT/knowledge" "$VAULT/projects" "$VAULT/mounts"
mkdir -p "$CLAUDE_DIR/skills/llm-wiki" "$CLAUDE_DIR/rules" "$CLAUDE_DIR/hooks"

for f in SCHEMA.md OPERATIONS.md index.md log.md; do
  if [ -f "$VAULT/$f" ]; then
    warn "$VAULT/$f は既にあるので上書きしません"
  else
    cp "$REPO/template/$f" "$VAULT/$f"
    info "$VAULT/$f を作成"
  fi
done
ok "vault を作成しました"

cp "$REPO/skill/SKILL.md"  "$CLAUDE_DIR/skills/llm-wiki/SKILL.md"
cp "$REPO/rules/llm-wiki.md" "$CLAUDE_DIR/rules/llm-wiki.md"
cp "$REPO/hooks/llm-wiki-context.sh" "$CLAUDE_DIR/hooks/llm-wiki-context.sh"
chmod +x "$CLAUDE_DIR/hooks/llm-wiki-context.sh"
ok "スキル・ルール・フックを配置しました"

# --- settings.json への SessionStart フック追加 -------------------------
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD='bash ~/.claude/hooks/llm-wiki-context.sh'

if ! command -v jq >/dev/null 2>&1; then
  warn "jq が無いため settings.json は自動更新しません。以下を手動で追加してください:"
  cat <<'JSON'

  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/llm-wiki-context.sh", "timeout": 10 }
        ]
      }
    ]
  }
JSON
elif [ -f "$SETTINGS" ] && jq -e --arg c "$HOOK_CMD" '.hooks.SessionStart[]?.hooks[]? | select(.command == $c)' "$SETTINGS" >/dev/null 2>&1; then
  info "SessionStart フックは既に設定済みです"
else
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak"
  jq '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{
        matcher: "startup|resume|clear|compact",
        hooks: [{ type: "command", command: "bash ~/.claude/hooks/llm-wiki-context.sh", timeout: 10, statusMessage: "LLM Wiki を読み込み中" }]
      }])' "$SETTINGS.bak" > "$SETTINGS"
  ok "SessionStart フックを追加しました（バックアップ: $SETTINGS.bak）"
fi

echo
ok "完了しました"
echo
info "次の手順:"
info "  1. Claude Code を再起動（または /hooks を一度開く）"
info "  2. プロジェクトで:  $REPO/install/install.sh --connect ."
info "  3. 使い方は $REPO/docs/README.md"
