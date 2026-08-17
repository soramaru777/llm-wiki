# SessionEnd フック（Windows / PowerShell）
# 未取り込みの作業を1行記録する。
#
# **ingest そのものは実行しない。** SessionEnd の出力は Claude に渡らず、
# セッションも既に終わっているため、ここから取り込ませることはできない。
# 仮にできたとしても、差分レビューが効かない時間帯に Wiki へ書き込むことになり、
# 「何を入れないか」の選別も失われる。
#
# ここでは印を残すだけにし、次回のセッション開始時に llm-wiki-context.ps1 が
# 閾値を見て取り込みを促す。判断と実行は人間に残す。

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }

# 接続済みプロジェクトのみ対象
if (-not (Test-Path -LiteralPath (Join-Path $root 'docs/wiki/index.md'))) { exit 0 }
if (-not (Test-Path -LiteralPath (Join-Path $root 'docs/raw')))           { exit 0 }

# フック入力（JSON）から session_id を取り出す
$sid = $null
try {
  $raw = [Console]::In.ReadToEnd()
  if ($raw) { $sid = ($raw | ConvertFrom-Json).session_id }
} catch { $sid = $null }
if ([string]::IsNullOrWhiteSpace($sid)) { $sid = "unknown-$([int][double]::Parse((Get-Date -UFormat %s)))" }

$pending = Join-Path $root 'docs/raw/.pending-sessions'

# 同一セッションの重複記録を避ける（/clear などで複数回発火しうる）
if (Test-Path -LiteralPath $pending) {
  if (Select-String -LiteralPath $pending -SimpleMatch -Pattern $sid -Quiet) { exit 0 }
}

$line = "{0}`t{1}" -f (Get-Date -Format 'yyyy-MM-dd'), $sid
Add-Content -LiteralPath $pending -Value $line -Encoding UTF8

$n = @(Get-Content -LiteralPath $pending | Where-Object { $_ -ne '' }).Count
Write-Output "LLM Wiki: 未取り込みの作業を記録しました（累計 $n 件）。/llm-wiki ingest で取り込めます。"
