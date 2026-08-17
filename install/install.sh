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

  # 配布元リポジトリ自身を接続した場合、githooks/ が実体なので複製しない。
  # 複製すると同じフックを2箇所で保守することになり、片方だけ古くなる。
  if [ "$PROJ_DIR" -ef "$REPO" ]; then
    IS_SELF=1
    HOOKS_DIR="githooks"
  else
    IS_SELF=0
    HOOKS_DIR=".githooks"
  fi

  # --- VCS を検出して安全策を入れる -------------------------------------
  # Git / SVN のどちらでも、両方が入った作業コピーでも動く。
  VCS_FOUND=0

  # ---- Git ----
  if git -C "$PROJ_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    VCS_FOUND=1
    echo
    info "Git リポジトリを検出しました"

    # 生資料は追跡しない。鍵や個人情報が混ざりやすく、履歴からは消せないため。
    IGNORE="$PROJ_DIR/.gitignore"
    if ! grep -qF 'docs/raw/*' "$IGNORE" 2>/dev/null; then
      { [ -f "$IGNORE" ] && [ -s "$IGNORE" ] && echo ""; cat <<'EOF'
# 生資料とローカルメモは追跡しない。加工前のセッション記録・議事録には
# API キーや個人情報が混ざりやすく、一度コミットすると履歴から消せないため。
# 置き場のルール(README)だけ共有し、中身はローカルに留める。
docs/raw/*
!docs/raw/README.md
docs/local/
EOF
      } >> "$IGNORE"
      ok "docs/raw/ と docs/local/ を .gitignore に追加しました（README のみ追跡）"
    else
      info "docs/raw/ は既に .gitignore 済みです"
    fi

    # 秘密情報の pre-commit 検査。パターン定義も一緒に置く。
    if [ "$IS_SELF" = "1" ]; then
      info "配布元リポジトリ自身のため githooks/ をそのまま使います（複製しません）"
    else
      mkdir -p "$PROJ_DIR/.githooks"
      cp "$REPO/githooks/pre-commit"     "$PROJ_DIR/.githooks/pre-commit"
      cp "$REPO/lib/secret-patterns.txt" "$PROJ_DIR/.githooks/secret-patterns.txt"
      chmod +x "$PROJ_DIR/.githooks/pre-commit"
    fi

    CURRENT_HOOKS="$(git -C "$PROJ_DIR" config --local core.hooksPath || true)"
    if [ -z "$CURRENT_HOOKS" ]; then
      git -C "$PROJ_DIR" config --local core.hooksPath "$HOOKS_DIR"
      ok "pre-commit フックを有効化しました（core.hooksPath = $HOOKS_DIR）"
    elif [ "$CURRENT_HOOKS" = "$HOOKS_DIR" ]; then
      info "pre-commit フックは既に有効です"
    else
      warn "core.hooksPath が既に '$CURRENT_HOOKS' に設定されています"
      info "  $HOOKS_DIR/pre-commit は配置済みです。既存の設定を壊さないため自動では切り替えません"
      info "  有効化する場合: git -C \"$PROJ_DIR\" config core.hooksPath $HOOKS_DIR"
    fi
  fi

  # ---- SVN ----
  if [ -d "$PROJ_DIR/.svn" ]; then
    VCS_FOUND=1
    echo
    info "SVN 作業コピーを検出しました"

    # svn:ignore は親ディレクトリに対して子のパターンを設定する。
    # 明示的に追加済みのファイル(README.md)は ignore に関係なく追跡され続ける。
    set_ignore() {
      local target="$1" pattern="$2" cur
      [ -d "$target" ] || return 0
      cur="$(svn propget svn:ignore "$target" 2>/dev/null || true)"
      if echo "$cur" | grep -qxF "$pattern"; then
        info "  svn:ignore は設定済みです（${target#$PROJ_DIR/} → $pattern）"
      elif printf '%s\n%s\n' "$cur" "$pattern" | sed '/^$/d' | svn propset svn:ignore -F - "$target" >/dev/null 2>&1; then
        ok "  svn:ignore を設定しました（${target#$PROJ_DIR/} → $pattern）"
      else
        warn "  svn:ignore を設定できませんでした（${target#$PROJ_DIR/} が未追跡の可能性）"
        info "    手動で: svn add --depth=empty ${target#$PROJ_DIR/} && svn propset svn:ignore '$pattern' ${target#$PROJ_DIR/}"
      fi
    }
    set_ignore "$PROJ_DIR/docs/raw" '*'
    set_ignore "$PROJ_DIR/docs"     'local'

    # SVN のフックはサーバ側にあるため、作業コピーからは設置できない。
    # 配置物と手順を出力するに留める。
    REPOS_URL="$(svn info --show-item repos-root-url "$PROJ_DIR" 2>/dev/null || echo '<repos>')"
    echo
    warn "SVN のフックはサーバ側に設置します（要管理者権限）"
    info "  対象リポジトリ: $REPOS_URL"
    info ""
    info "  サーバ上で以下を実行してください:"
    info "    cp $REPO/svnhooks/pre-commit      <repos>/hooks/pre-commit"
    info "    cp $REPO/lib/secret-patterns.txt  <repos>/hooks/secret-patterns.txt"
    info "    chmod +x                          <repos>/hooks/pre-commit"
    info ""
    info "  設置すると次が有効になります:"
    info "    - docs/raw/ と docs/local/ のコミットを拒否"
    info "    - .env の混入を拒否"
    info "    - 秘密情報のパターン検査"
    info "    - docs/wiki/ のコミット者制限（既定は無効。フック内のコメント参照）"
    info ""
    info "  SVN には PR が無いため、書き込みのゲートはこのフックが担います。"
  fi

  if [ "$VCS_FOUND" = 0 ]; then
    warn "git リポジトリでも SVN 作業コピーでもないため、除外設定とフックはスキップしました"
  fi

  echo
  info "次の手順:"
  info "  1. Claude Code で /llm-wiki ingest README.md"
  info "  2. 差分レビュー:  $REPO/bin/llm-wiki-diff"
  info "  3. コミット（Git なら .gitignore と $HOOKS_DIR も一緒に）"
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
cp "$REPO/hooks/llm-wiki-context.sh"     "$CLAUDE_DIR/hooks/llm-wiki-context.sh"
cp "$REPO/hooks/llm-wiki-session-end.sh" "$CLAUDE_DIR/hooks/llm-wiki-session-end.sh"
chmod +x "$CLAUDE_DIR/hooks/llm-wiki-context.sh" "$CLAUDE_DIR/hooks/llm-wiki-session-end.sh"
ok "スキル・ルール・フックを配置しました"

# --- settings.json へのフック追加 ---------------------------------------
# SessionStart: Wiki の注入と取り込みの促し
# SessionEnd:   未取り込みの記録（resume は「後で再開」なので対象外）
SETTINGS="$CLAUDE_DIR/settings.json"
START_CMD='bash ~/.claude/hooks/llm-wiki-context.sh'
END_CMD='bash ~/.claude/hooks/llm-wiki-session-end.sh'

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
    ],
    "SessionEnd": [
      {
        "matcher": "clear|logout|prompt_input_exit|other",
        "hooks": [
          { "type": "command", "command": "bash ~/.claude/hooks/llm-wiki-session-end.sh", "timeout": 10 }
        ]
      }
    ]
  }
JSON
else
  [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
  cp "$SETTINGS" "$SETTINGS.bak"

  if jq -e --arg c "$START_CMD" '.hooks.SessionStart[]?.hooks[]? | select(.command == $c)' "$SETTINGS" >/dev/null 2>&1; then
    info "SessionStart フックは既に設定済みです"
  else
    jq --arg c "$START_CMD" '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{
          matcher: "startup|resume|clear|compact",
          hooks: [{ type: "command", command: $c, timeout: 10, statusMessage: "LLM Wiki を読み込み中" }]
        }])' "$SETTINGS.bak" > "$SETTINGS"
    cp "$SETTINGS" "$SETTINGS.bak"
    ok "SessionStart フックを追加しました"
  fi

  if jq -e --arg c "$END_CMD" '.hooks.SessionEnd[]?.hooks[]? | select(.command == $c)' "$SETTINGS" >/dev/null 2>&1; then
    info "SessionEnd フックは既に設定済みです"
  else
    jq --arg c "$END_CMD" '.hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{
          matcher: "clear|logout|prompt_input_exit|other",
          hooks: [{ type: "command", command: $c, timeout: 10 }]
        }])' "$SETTINGS.bak" > "$SETTINGS"
    ok "SessionEnd フックを追加しました"
  fi

  info "バックアップ: $SETTINGS.bak"
fi

echo
ok "完了しました"
echo
info "次の手順:"
info "  1. Claude Code を再起動（または /hooks を一度開く）"
info "  2. プロジェクトで:  $REPO/install/install.sh --connect ."
info "  3. 使い方は $REPO/docs/README.md"
