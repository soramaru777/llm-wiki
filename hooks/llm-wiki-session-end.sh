#!/bin/bash
# SessionEnd フック: 未取り込みの作業を1行記録する。
#
# **ingest そのものは実行しない。** SessionEnd の出力は Claude に渡らず、
# セッションも既に終わっているため、ここから取り込ませることはできない。
# 仮にできたとしても、差分レビューが効かない時間帯に Wiki へ書き込むことになり、
# 「何を入れないか」の選別も失われる。
#
# ここでは印を残すだけにし、次回のセッション開始時に llm-wiki-context.sh が
# 閾値を見て取り込みを促す。判断と実行は人間に残す。
set -uo pipefail

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# 接続済みプロジェクトのみ対象
[ -f "$root/docs/wiki/index.md" ] || exit 0
[ -d "$root/docs/raw" ] || exit 0

# フック入力（JSON）から session_id を取り出す。jq への依存を避けるため sed で拾う。
input=$(cat 2>/dev/null || true)
sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
[ -n "$sid" ] || sid="unknown-$(date +%s)"

pending="$root/docs/raw/.pending-sessions"

# 同一セッションの重複記録を避ける（/clear などで複数回発火しうる）
if [ -f "$pending" ] && grep -qF "	$sid" "$pending" 2>/dev/null; then
  exit 0
fi

printf '%s\t%s\n' "$(date +%F)" "$sid" >> "$pending"

n=$(grep -c . "$pending" 2>/dev/null) || n=0
echo "LLM Wiki: 未取り込みの作業を記録しました（累計 ${n} 件）。/llm-wiki ingest で取り込めます。"
