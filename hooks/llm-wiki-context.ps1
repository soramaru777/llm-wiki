# SessionStart フック（Windows / PowerShell）
# プロジェクトに LLM Wiki があれば index.md をコンテキストへ注入する。
# docs/wiki/index.md が無いプロジェクトでは何も出力せず終了する。

# 日本語が化けないよう出力を UTF-8 に固定する（PowerShell 5.1 対策）
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
$index = Join-Path $root 'docs/wiki/index.md'

if (-not (Test-Path -LiteralPath $index)) { exit 0 }

Write-Output '## このプロジェクトの LLM Wiki（自動注入）'
Write-Output ''
Get-Content -LiteralPath $index -Raw -Encoding UTF8
Write-Output ''
Write-Output '作業の前提はこの Wiki にある。詳細は docs/wiki/ の各ページを読むこと。'
Write-Output 'Wiki に基づいて答えるときは根拠のページ名を引用する。Wiki に無いことは「無い」と明言してから調べる。'
Write-Output 'ページの規約は ~/wiki/SCHEMA.md、運用手順は ~/wiki/OPERATIONS.md。'

# --- 取り込みの促し -----------------------------------------------------
# 毎回促すと無視されるようになるため、溜まったときだけ出す。
# 閾値は環境変数で変更できる。
$threshold = if ($env:LLM_WIKI_PENDING_THRESHOLD) { [int]$env:LLM_WIKI_PENDING_THRESHOLD } else { 5 }
$staleDays = if ($env:LLM_WIKI_STALE_DAYS)        { [int]$env:LLM_WIKI_STALE_DAYS }        else { 7 }

$pending = Join-Path $root 'docs/raw/.pending-sessions'
$n = 0
if (Test-Path -LiteralPath $pending) {
  $n = @(Get-Content -LiteralPath $pending | Where-Object { $_ -ne '' }).Count
}

# staleDays 日以内に更新された .md が1つも無ければ「停滞」とみなす
$cutoff = (Get-Date).AddDays(-$staleDays)
$recent = Get-ChildItem -LiteralPath (Join-Path $root 'docs/wiki') -Filter *.md -Recurse -ErrorAction SilentlyContinue |
          Where-Object { $_.LastWriteTime -gt $cutoff }
$stale = (@($recent).Count -eq 0)

if ($n -ge $threshold -or $stale) {
  Write-Output ''
  Write-Output '### 取り込みの促し（自動判定）'
  if ($n -ge $threshold) { Write-Output "- 未取り込みの作業が $n 件たまっている（閾値 $threshold）" }
  if ($stale)            { Write-Output "- docs/wiki/ が $staleDays 日以上更新されていない" }
  Write-Output ''
  Write-Output '作業に入る前に一度だけ /llm-wiki ingest を提案すること。'
  Write-Output "断られた場合、このセッション中は再度促さない。取り込み後は $pending を空にする。"
}
