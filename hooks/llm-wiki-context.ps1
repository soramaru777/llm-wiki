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
