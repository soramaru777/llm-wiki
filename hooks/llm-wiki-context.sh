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

# --- 取り込みの促し -----------------------------------------------------
# 毎回促すと無視されるようになるため、溜まったときだけ出す。
# 閾値は環境変数で変更できる。
#
# ここから下は「経過日数」と「絶対パス」で出力が変わる。Wiki の内容が1バイトも
# 変わらなくても、7日跨いだだけで注入される文字列が変わってしまう。
# 同一条件の再実行（Replay）でこれが起きると、比較したい差分以外のところで
# 指示が食い違い、結果を比較できなくなる。Replay 中は出さない。
[ "${LLM_WIKI_REPLAY:-0}" = "1" ] && exit 0

PENDING_THRESHOLD="${LLM_WIKI_PENDING_THRESHOLD:-5}"
STALE_DAYS="${LLM_WIKI_STALE_DAYS:-7}"

pending="$root/docs/raw/.pending-sessions"
# grep -c は該当0行でも終了コード1を返す。`|| echo 0` と併用すると
# 出力が "0\n0" になり整数比較が壊れるため、代入の失敗時に 0 を入れる。
n=0
if [ -f "$pending" ]; then
  n=$(grep -c . "$pending" 2>/dev/null) || n=0
fi

# STALE_DAYS 日以内に更新された .md が1つも無ければ「停滞」とみなす
stale=0
if [ -z "$(find "$root/docs/wiki" -name '*.md' -mtime "-${STALE_DAYS}" 2>/dev/null | head -1)" ]; then
  stale=1
fi

if [ "$n" -ge "$PENDING_THRESHOLD" ] || [ "$stale" = 1 ]; then
  echo
  echo "### 取り込みの促し（自動判定）"
  [ "$n" -ge "$PENDING_THRESHOLD" ] && echo "- 未取り込みの作業が ${n} 件たまっている（閾値 ${PENDING_THRESHOLD}）"
  [ "$stale" = 1 ] && echo "- docs/wiki/ が ${STALE_DAYS} 日以上更新されていない"
  echo
  echo "作業に入る前に一度だけ /llm-wiki ingest を提案すること。"
  echo "断られた場合、このセッション中は再度促さない。取り込み後は $pending を空にする。"
fi
