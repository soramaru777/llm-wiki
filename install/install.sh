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

  [ -f "$PROJ_DIR/docs/raw/README.md" ] || cp "$REPO/template/raw-README.md" "$PROJ_DIR/docs/raw/README.md"
  [ -f "$PROJ_DIR/CLAUDE.md" ] || sed "s/<PROJECT>/$PROJ_NAME/g" "$REPO/template/CLAUDE.md.example" > "$PROJ_DIR/CLAUDE.md"

  ok "$PROJ_NAME を接続しました"
  info "docs/raw/ と docs/wiki/ を作成し、$VAULT/mounts/$PROJ_NAME から繋ぎました"

  # --- git リポジトリなら安全策も入れる ---------------------------------
  if git -C "$PROJ_DIR" rev-parse --git-dir >/dev/null 2>&1; then

    # 生資料は追跡しない。鍵や個人情報が混ざりやすく、履歴からは消せないため。
    IGNORE="$PROJ_DIR/.gitignore"
    if ! grep -qF 'docs/raw/*' "$IGNORE" 2>/dev/null; then
      { [ -f "$IGNORE" ] && [ -s "$IGNORE" ] && echo ""; cat <<'EOF'
# 生資料は追跡しない。加工前のセッション記録・議事録には API キーや個人情報が
# 混ざりやすく、一度コミットすると履歴から消せないため。
# 置き場のルール(README)だけ共有し、中身はローカルに留める。
docs/raw/*
!docs/raw/README.md
EOF
      } >> "$IGNORE"
      ok "docs/raw/ を .gitignore に追加しました（README のみ追跡）"
    else
      info "docs/raw/ は既に .gitignore 済みです"
    fi

    # 秘密情報の pre-commit 検査
    mkdir -p "$PROJ_DIR/.githooks"
    cp "$REPO/githooks/pre-commit" "$PROJ_DIR/.githooks/pre-commit"
    chmod +x "$PROJ_DIR/.githooks/pre-commit"

    CURRENT_HOOKS="$(git -C "$PROJ_DIR" config --local core.hooksPath || true)"
    if [ -z "$CURRENT_HOOKS" ]; then
      git -C "$PROJ_DIR" config --local core.hooksPath .githooks
      ok "pre-commit フックを有効化しました（core.hooksPath = .githooks）"
    elif [ "$CURRENT_HOOKS" = ".githooks" ]; then
      info "pre-commit フックは既に有効です"
    else
      warn "core.hooksPath が既に '$CURRENT_HOOKS' に設定されています"
      info "  .githooks/pre-commit は配置済みです。既存の設定を壊さないため自動では切り替えません"
      info "  有効化する場合: git -C \"$PROJ_DIR\" config core.hooksPath .githooks"
    fi
  else
    warn "git リポジトリではないため、.gitignore とフックの設定はスキップしました"
  fi

  echo
  info "次の手順:"
  info "  1. Claude Code で /llm-wiki ingest README.md"
  info "  2. git add .gitignore .githooks docs/wiki docs/raw/README.md CLAUDE.md"
  info "  3. git commit -m \"LLM Wiki を導入\""
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
