#!/bin/bash
# SessionStart フック: プロジェクトに LLM Wiki があれば index.md をコンテキストへ注入する。
# docs/wiki/index.md が無いプロジェクトでは何も出力せず終了する。
set -u

root="${CLAUDE_PROJECT_DIR:-$PWD}"
index="$root/docs/wiki/index.md"

[ -f "$index" ] || exit 0

echo "## このプロジェクトの LLM Wiki（自動注入）"
echo
cat "$index"
echo
echo "作業の前提はこの Wiki にある。詳細は docs/wiki/ の各ページを読むこと。"
echo "Wiki に基づいて答えるときは根拠のページ名を引用する。Wiki に無いことは「無い」と明言してから調べる。"
echo "ページの規約は ~/wiki/SCHEMA.md、運用手順は ~/wiki/OPERATIONS.md。"
