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

  if (-not (Test-Path "$ProjDir\docs\raw\README.md")) {
    Copy-Item "$Repo\template\raw-README.md" "$ProjDir\docs\raw\README.md"
  }
  if (-not (Test-Path "$ProjDir\CLAUDE.md")) {
    (Get-Content "$Repo\template\CLAUDE.md.example" -Raw -Encoding UTF8).Replace('<PROJECT>', $ProjName) |
      Set-Content "$ProjDir\CLAUDE.md" -Encoding UTF8
  }

  Write-Ok "$ProjName を接続しました"
  Write-Info "docs\raw\ と docs\wiki\ を作成し、$mount から繋ぎました（ジャンクション）"

  # --- VCS を検出して安全策を入れる -------------------------------------
  # Git / SVN のどちらでも、両方が入った作業コピーでも動く。
  $isGit = $false
  try { git -C $ProjDir rev-parse --git-dir *> $null; $isGit = ($LASTEXITCODE -eq 0) } catch { $isGit = $false }
  $isSvn = Test-Path (Join-Path $ProjDir '.svn')

  # 配布元リポジトリ自身を接続した場合、githooks\ が実体なので複製しない。
  # 複製すると同じフックを2箇所で保守することになり、片方だけ古くなる。
  $repoPath = [System.IO.Path]::GetFullPath($Repo).TrimEnd('\')
  $projPath = [System.IO.Path]::GetFullPath($ProjDir).TrimEnd('\')
  $isSelf   = ($projPath -eq $repoPath)
  $hooksDir = if ($isSelf) { 'githooks' } else { '.githooks' }

  if ($isGit) {
    # 生資料は追跡しない。鍵や個人情報が混ざりやすく、履歴からは消せないため。
    $ignorePath = Join-Path $ProjDir '.gitignore'
    $ignoreText = if (Test-Path $ignorePath) { Get-Content $ignorePath -Raw -Encoding UTF8 } else { '' }

    if ($ignoreText -notmatch [regex]::Escape('docs/raw/*')) {
      $block = @'

# 生資料とローカルメモは追跡しない。加工前のセッション記録・議事録には
# API キーや個人情報が混ざりやすく、一度コミットすると履歴から消せないため。
# 置き場のルール(README)だけ共有し、中身はローカルに留める。
docs/raw/*
!docs/raw/README.md
docs/local/
'@
      Add-Content -Path $ignorePath -Value $block -Encoding UTF8
      Write-Ok "docs/raw/ と docs/local/ を .gitignore に追加しました（README のみ追跡）"
    } else {
      Write-Info "docs/raw/ は既に .gitignore 済みです"
    }

    # 秘密情報の pre-commit 検査。パターン定義も一緒に置く。
    # フックは bash スクリプトだが、Git for Windows に bash が同梱されるため動作する
    if ($isSelf) {
      Write-Info "配布元リポジトリ自身のため githooks\ をそのまま使います（複製しません）"
    } else {
      New-Item -ItemType Directory -Force -Path "$ProjDir\.githooks" | Out-Null
      Copy-Item "$Repo\githooks\pre-commit"     "$ProjDir\.githooks\pre-commit" -Force
      Copy-Item "$Repo\lib\secret-patterns.txt" "$ProjDir\.githooks\secret-patterns.txt" -Force
    }

    $currentHooks = (git -C $ProjDir config --local core.hooksPath 2>$null)
    if ([string]::IsNullOrEmpty($currentHooks)) {
      git -C $ProjDir config --local core.hooksPath $hooksDir
      Write-Ok "pre-commit フックを有効化しました（core.hooksPath = $hooksDir）"
    } elseif ($currentHooks -eq $hooksDir) {
      Write-Info "pre-commit フックは既に有効です"
    } else {
      Write-Warn "core.hooksPath が既に '$currentHooks' に設定されています"
      Write-Info "  $hooksDir\pre-commit は配置済みです。既存の設定を壊さないため自動では切り替えません"
      Write-Info "  有効化する場合: git -C `"$ProjDir`" config core.hooksPath $hooksDir"
    }
  }

  # ---- SVN ----
  if ($isSvn) {
    Write-Host ""
    Write-Info "SVN 作業コピーを検出しました"

    # svn:ignore は親ディレクトリに対して子のパターンを設定する。
    # 明示的に追加済みのファイル(README.md)は ignore に関係なく追跡され続ける。
    function Set-SvnIgnore {
      param($Target, $Pattern, $Label)
      if (-not (Test-Path $Target)) { return }
      $cur = (svn propget svn:ignore $Target 2>$null) -join "`n"
      if (($cur -split "`n") -contains $Pattern) {
        Write-Info "  svn:ignore は設定済みです（$Label → $Pattern）"
        return
      }
      $new = (@($cur -split "`n") + $Pattern | Where-Object { $_ -ne '' }) -join "`n"
      $tmp = [System.IO.Path]::GetTempFileName()
      Set-Content -Path $tmp -Value $new -Encoding UTF8 -NoNewline
      svn propset svn:ignore -F $tmp $Target *> $null
      if ($LASTEXITCODE -eq 0) {
        Write-Ok "  svn:ignore を設定しました（$Label → $Pattern）"
      } else {
        Write-Warn "  svn:ignore を設定できませんでした（$Label が未追跡の可能性）"
        Write-Info "    手動で: svn add --depth=empty $Label; svn propset svn:ignore '$Pattern' $Label"
      }
      Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
    Set-SvnIgnore "$ProjDir\docs\raw" '*'     'docs/raw'
    Set-SvnIgnore "$ProjDir\docs"     'local' 'docs'

    # SVN のフックはサーバ側にあるため、作業コピーからは設置できない。
    # 配置物と手順を出力するに留める。
    $reposUrl = (svn info --show-item repos-root-url $ProjDir 2>$null)
    if ([string]::IsNullOrWhiteSpace($reposUrl)) { $reposUrl = '<repos>' }

    Write-Host ""
    Write-Warn "SVN のフックはサーバ側に設置します（要管理者権限）"
    Write-Info "  対象リポジトリ: $reposUrl"
    Write-Info ""
    Write-Info "  サーバ上で以下を実行してください:"
    Write-Info "    cp $Repo/svnhooks/pre-commit      <repos>/hooks/pre-commit"
    Write-Info "    cp $Repo/lib/secret-patterns.txt  <repos>/hooks/secret-patterns.txt"
    Write-Info "    chmod +x                          <repos>/hooks/pre-commit"
    Write-Info ""
    Write-Info "  設置すると次が有効になります:"
    Write-Info "    - docs/raw/ と docs/local/ のコミットを拒否"
    Write-Info "    - .env の混入を拒否"
    Write-Info "    - 秘密情報のパターン検査"
    Write-Info "    - docs/wiki/ のコミット者制限（既定は無効。フック内のコメント参照）"
    Write-Info ""
    Write-Info "  SVN には PR が無いため、書き込みのゲートはこのフックが担います。"
  }

  if (-not $isGit -and -not $isSvn) {
    Write-Warn "git リポジトリでも SVN 作業コピーでもないため、除外設定とフックはスキップしました"
  }

  Write-Host ""
  Write-Info "次の手順:"
  Write-Info "  1. Claude Code で /llm-wiki ingest README.md"
  Write-Info "  2. 差分レビュー:  bash $Repo/bin/llm-wiki-diff"
  Write-Info "  3. コミット（Git なら .gitignore と $hooksDir も一緒に）"
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
