# LLM Wiki セットアップ（Windows / PowerShell）
#
#   .\install\install.ps1              vault とスキル・ルール・フックを配置
#   .\install\install.ps1 -Connect .   カレントのプロジェクトを接続
#
# 実行ポリシーで止まる場合:
#   powershell -ExecutionPolicy Bypass -File .\install\install.ps1

param(
  [string]$Connect,
  [string]$Vault = "$env:USERPROFILE\wiki"
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Repo      = Split-Path -Parent $PSScriptRoot
$ClaudeDir = "$env:USERPROFILE\.claude"

function Write-Ok   { param($m) Write-Host "[OK] $m" -ForegroundColor Green }
function Write-Warn { param($m) Write-Host "[!] $m"  -ForegroundColor Yellow }
function Write-Info { param($m) Write-Host "    $m" }

# --- プロジェクト接続モード ---------------------------------------------
if ($Connect) {
  $ProjDir  = (Resolve-Path $Connect).Path
  $ProjName = Split-Path -Leaf $ProjDir

  New-Item -ItemType Directory -Force -Path "$ProjDir\docs\raw", "$ProjDir\docs\wiki", "$Vault\mounts" | Out-Null

  $mount = "$Vault\mounts\$ProjName"
  if (Test-Path $mount) { Remove-Item $mount -Force -Recurse }

  # symlink ではなくジャンクションを使う（管理者権限も開発者モードも不要）
  New-Item -ItemType Junction -Path $mount -Target "$ProjDir\docs\wiki" | Out-Null

  if (-not (Test-Path "$ProjDir\CLAUDE.md")) {
    (Get-Content "$Repo\template\CLAUDE.md.example" -Raw -Encoding UTF8).Replace('<PROJECT>', $ProjName) |
      Set-Content "$ProjDir\CLAUDE.md" -Encoding UTF8
  }

  Write-Ok "$ProjName を接続しました"
  Write-Info "docs\raw\ と docs\wiki\ を作成し、$mount から繋ぎました（ジャンクション）"
  Write-Host ""
  Write-Info "次の手順:"
  Write-Info "  1. Claude Code で /llm-wiki ingest README.md"
  Write-Info "  2. git add docs CLAUDE.md; git commit -m `"LLM Wiki を導入`""
  exit 0
}

# --- 初期セットアップ ---------------------------------------------------
Write-Host "LLM Wiki をセットアップします"
Write-Host "  vault: $Vault"
Write-Host ""

New-Item -ItemType Directory -Force -Path `
  "$Vault\knowledge", "$Vault\projects", "$Vault\mounts",
  "$ClaudeDir\skills\llm-wiki", "$ClaudeDir\rules", "$ClaudeDir\hooks" | Out-Null

foreach ($f in 'SCHEMA.md', 'OPERATIONS.md', 'index.md', 'log.md') {
  if (Test-Path "$Vault\$f") {
    Write-Warn "$Vault\$f は既にあるので上書きしません"
  } else {
    Copy-Item "$Repo\template\$f" "$Vault\$f"
    Write-Info "$Vault\$f を作成"
  }
}
Write-Ok "vault を作成しました"

Copy-Item "$Repo\skill\SKILL.md"                "$ClaudeDir\skills\llm-wiki\SKILL.md" -Force
Copy-Item "$Repo\rules\llm-wiki.md"             "$ClaudeDir\rules\llm-wiki.md" -Force
Copy-Item "$Repo\hooks\llm-wiki-context.ps1"    "$ClaudeDir\hooks\llm-wiki-context.ps1" -Force
Write-Ok "スキル・ルール・フックを配置しました"

# --- settings.json への SessionStart フック追加 -------------------------
$Settings = "$ClaudeDir\settings.json"
$HookCmd  = '& "$env:USERPROFILE\.claude\hooks\llm-wiki-context.ps1"'

$json = if (Test-Path $Settings) {
  Copy-Item $Settings "$Settings.bak" -Force
  Get-Content $Settings -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
  [PSCustomObject]@{}
}

if (-not $json.PSObject.Properties['hooks']) {
  $json | Add-Member -NotePropertyName hooks -NotePropertyValue ([PSCustomObject]@{})
}

$existing = @($json.hooks.PSObject.Properties['SessionStart'].Value)
$already  = $existing | Where-Object { $_.hooks.command -contains $HookCmd }

if ($already) {
  Write-Info "SessionStart フックは既に設定済みです"
} else {
  $entry = [PSCustomObject]@{
    matcher = 'startup|resume|clear|compact'
    hooks   = @([PSCustomObject]@{
      type          = 'command'
      command       = $HookCmd
      shell         = 'powershell'
      timeout       = 10
      statusMessage = 'LLM Wiki を読み込み中'
    })
  }
  $merged = @($existing | Where-Object { $_ }) + $entry
  if ($json.hooks.PSObject.Properties['SessionStart']) {
    $json.hooks.SessionStart = $merged
  } else {
    $json.hooks | Add-Member -NotePropertyName SessionStart -NotePropertyValue $merged
  }
  $json | ConvertTo-Json -Depth 20 | Set-Content $Settings -Encoding UTF8
  Write-Ok "SessionStart フックを追加しました（バックアップ: $Settings.bak）"
}

Write-Host ""
Write-Ok "完了しました"
Write-Host ""
Write-Info "次の手順:"
Write-Info "  1. Claude Code を再起動（または /hooks を一度開く）"
Write-Info "  2. プロジェクトで:  $Repo\install\install.ps1 -Connect ."
Write-Info "  3. 使い方は $Repo\docs\README.md"
