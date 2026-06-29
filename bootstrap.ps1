# bootstrap.ps1 — Claude Code 환경 원클릭 셋업 (Windows 10/11)
#
# 새 머신에서 실행 (PowerShell):
#   irm https://raw.githubusercontent.com/UETG/Claude-config/main/bootstrap.ps1 | iex
#
# 또는 repo clone 후:
#   .\bootstrap.ps1
#
# 자동화 항목:
#   1) Node.js / Git / VSCode 체크 + 동의 후 winget 자동 설치
#   2) claude-config repo 자동 clone (이미 있으면 git pull)
#   3) VSCode Claude Code 확장 자동 설치 (동의 시)
#   4) CLAUDE.md, settings.local.json, mcp-servers.json 적절한 위치로 배치
#   5) 작업 폴더 표준화: C:\Users\<유저>\paper-research\
#   6) Playwright Chromium 자동 설치 (동의 시)
#   7) pdf-parse 자동 설치 (동의 시)

$ErrorActionPreference = "Stop"
$RepoUrl  = "https://github.com/UETG/Claude-config.git"
$RepoDir  = "$env:USERPROFILE\claude-config"
$WorkRoot = "$env:USERPROFILE\paper-research"

# ---------- 유틸 ----------
function Write-Step($num, $title) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host "  [Step $num] $title" -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
}

function Confirm-Action($message) {
    $r = Read-Host "  $message [Y/n]"
    return ($r -eq '' -or $r -match '^[yY]')
}

function Update-EnvPath {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
}

function Install-RequiredTool($name, $exeName, $wingetId, $purpose) {
    $found = Get-Command $exeName -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  [OK] $name 이미 설치됨 ($($found.Source))" -ForegroundColor Green
        return $true
    }
    Write-Host "  [없음] $name — $purpose" -ForegroundColor Yellow
    if (-not (Confirm-Action "$name 자동으로 설치할까요? (winget)")) {
        Write-Host "  스킵합니다. 직접 설치하신 후 다시 실행해 주세요." -ForegroundColor Red
        return $false
    }
    Write-Host "  설치 중이에요 (몇 분 걸릴 수 있어요)..." -ForegroundColor Cyan
    winget install --id $wingetId --silent --accept-source-agreements --accept-package-agreements
    Update-EnvPath
    $found = Get-Command $exeName -ErrorAction SilentlyContinue
    if ($found) {
        Write-Host "  [OK] $name 설치 완료" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [실패] PATH 인식이 안 돼요. PowerShell 새로 열고 다시 실행해 주세요." -ForegroundColor Red
        return $false
    }
}

# ---------- 시작 ----------
Write-Host ""
Write-Host "######################################################" -ForegroundColor Cyan
Write-Host "#  Claude Code 환경 자동 셋업 (bootstrap)            #" -ForegroundColor Cyan
Write-Host "#  대상: Windows 10/11                                #" -ForegroundColor Cyan
Write-Host "######################################################" -ForegroundColor Cyan

# ---------- Step 1: 필수 도구 ----------
Write-Step 1 "필수 도구 체크 / 설치"

if (-not (Install-RequiredTool "Node.js" "node" "OpenJS.NodeJS.LTS" "Playwright / pdf-parse 실행에 필요")) { exit 1 }
if (-not (Install-RequiredTool "Git"     "git"  "Git.Git"          "설정 repo clone 에 필요"))             { exit 1 }
if (-not (Install-RequiredTool "VSCode"  "code" "Microsoft.VisualStudioCode" "Claude Code 확장 호스트"))     { exit 1 }

# ---------- Step 2: Repo clone ----------
Write-Step 2 "설정 repo 다운로드"

if (Test-Path $RepoDir) {
    Write-Host "  [OK] 이미 존재해요 — git pull 시도할게요: $RepoDir" -ForegroundColor Green
    Push-Location $RepoDir
    try { git pull } catch { Write-Host "  (pull 실패 — 무시하고 진행할게요)" -ForegroundColor Yellow }
    Pop-Location
} else {
    Write-Host "  Clone: $RepoUrl" -ForegroundColor Cyan
    Write-Host "  Dest:  $RepoDir" -ForegroundColor Cyan
    git clone $RepoUrl $RepoDir
    if (-not (Test-Path $RepoDir)) {
        Write-Host "  [실패] clone 에 실패했어요" -ForegroundColor Red
        exit 1
    }
    Write-Host "  [OK] clone 완료했어요" -ForegroundColor Green
}

# ---------- Step 3: VSCode Claude Code 확장 ----------
Write-Step 3 "VSCode Claude Code 확장"

$ext = (code --list-extensions 2>$null) | Where-Object { $_ -match "anthropic.*claude" }
if ($ext) {
    Write-Host "  [OK] Claude Code 확장이 이미 설치되어 있어요: $ext" -ForegroundColor Green
} else {
    if (Confirm-Action "Claude Code 확장을 자동으로 설치할까요?") {
        code --install-extension anthropic.claude-code
        Write-Host "  [OK] 확장 설치를 시도했어요" -ForegroundColor Green
    }
    Write-Host ""
    Write-Host "  >> VSCode 를 열고, Claude Code 확장에서 본인 Anthropic 계정으로 로그인해 주세요." -ForegroundColor Yellow
    Write-Host "  >> 로그인이 끝나면 [Enter] 를 눌러주세요." -ForegroundColor Yellow
    Read-Host
}

# ---------- Step 4: 설정 파일 배치 ----------
Write-Step 4 "설정 파일 배치 (~/.claude/, ~/.claude.json)"

$ClaudeDir = "$env:USERPROFILE\.claude"
if (-not (Test-Path $ClaudeDir)) {
    New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null
}

# CLAUDE.md
Copy-Item "$RepoDir\CLAUDE.md" "$ClaudeDir\CLAUDE.md" -Force
Write-Host "  [OK] CLAUDE.md -> $ClaudeDir\CLAUDE.md" -ForegroundColor Green

# settings.local.json (백업 후 덮어쓰기)
$SettingsPath = "$ClaudeDir\settings.local.json"
if (Test-Path $SettingsPath) {
    $bak = "$SettingsPath.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $SettingsPath $bak
    Write-Host "  (기존 settings.local.json 백업해뒀어요: $bak)" -ForegroundColor DarkGray
}
Copy-Item "$RepoDir\settings.local.json" $SettingsPath -Force
Write-Host "  [OK] settings.local.json -> $SettingsPath" -ForegroundColor Green

# ~/.claude.json (mcpServers 머지)
$ClaudeJson = "$env:USERPROFILE\.claude.json"
if (Test-Path $ClaudeJson) {
    $bak = "$ClaudeJson.bak.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    Copy-Item $ClaudeJson $bak
    Write-Host "  (기존 ~/.claude.json 백업해뒀어요: $bak)" -ForegroundColor DarkGray
    try {
        $existing = Get-Content $ClaudeJson -Raw | ConvertFrom-Json
        $newMcp   = (Get-Content "$RepoDir\mcp-servers.json" -Raw | ConvertFrom-Json).mcpServers
        if ($existing.PSObject.Properties.Name -contains "mcpServers") {
            $existing.mcpServers | Add-Member -NotePropertyName "playwright" -NotePropertyValue $newMcp.playwright -Force
        } else {
            $existing | Add-Member -NotePropertyName "mcpServers" -NotePropertyValue $newMcp -Force
        }
        $existing | ConvertTo-Json -Depth 100 | Set-Content $ClaudeJson -Encoding UTF8
        Write-Host "  [OK] Playwright MCP 등록 -> $ClaudeJson" -ForegroundColor Green
    } catch {
        Write-Host "  [!] ~/.claude.json 머지에 실패했어요 — 수동으로 mcp-servers.json 내용을 머지해 주세요." -ForegroundColor Yellow
    }
} else {
    Write-Host "  [!] ~/.claude.json 이 없어요. VSCode 에서 Claude Code 를 한 번 실행하신 후 이 스크립트를 다시 돌려주세요." -ForegroundColor Yellow
}

# ---------- Step 5: 작업 폴더 + extract.js ----------
Write-Step 5 "작업 폴더 + PDF 추출 도구"

$DownloadDir = "$WorkRoot\download_tmp"
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir -Force | Out-Null
    Write-Host "  [OK] 작업 폴더를 생성했어요: $DownloadDir" -ForegroundColor Green
} else {
    Write-Host "  [OK] 작업 폴더가 이미 있어요: $DownloadDir" -ForegroundColor Green
}

# extract.js 복사 (PDF -> 텍스트 변환용 Node 스크립트)
Copy-Item "$RepoDir\extract.js" "$DownloadDir\extract.js" -Force
Write-Host "  [OK] extract.js -> $DownloadDir\extract.js" -ForegroundColor Green

# pdf-parse 설치 (동의 시)
Push-Location $DownloadDir
if (Test-Path "node_modules\pdf-parse") {
    Write-Host "  [OK] pdf-parse 가 이미 설치되어 있어요" -ForegroundColor Green
} else {
    Write-Host "  [없음] pdf-parse — PDF 텍스트 추출 Node.js 패키지" -ForegroundColor Yellow
    if (Confirm-Action "pdf-parse 를 설치할까요? (~10초)") {
        npm install --silent pdf-parse 2>&1 | Out-Null
        if (Test-Path "node_modules\pdf-parse") {
            Write-Host "  [OK] pdf-parse 설치를 완료했어요" -ForegroundColor Green
        } else {
            Write-Host "  [실패] npm install pdf-parse 에 실패했어요" -ForegroundColor Red
        }
    }
}
Pop-Location

# ---------- Step 6: Playwright Chromium ----------
Write-Step 6 "Playwright Chromium (브라우저 자동화용)"

$PwCache = "$env:LOCALAPPDATA\ms-playwright"
$ChromiumDirs = if (Test-Path $PwCache) { Get-ChildItem $PwCache -Directory -Filter "chromium-*" -ErrorAction SilentlyContinue } else { @() }
if ($ChromiumDirs.Count -gt 0) {
    Write-Host "  [OK] Chromium 이 이미 설치되어 있어요 ($($ChromiumDirs.Count) 버전)" -ForegroundColor Green
} else {
    Write-Host "  [없음] Playwright Chromium (~200MB 다운로드 필요)" -ForegroundColor Yellow
    if (Confirm-Action "Chromium 을 설치할까요? (1-3분 정도 걸려요)") {
        npx -y playwright install chromium
        Write-Host "  [OK] Chromium 설치를 완료했어요" -ForegroundColor Green
    }
}

# ---------- 마무리 ----------
Write-Host ""
Write-Host "######################################################" -ForegroundColor Green
Write-Host "#  셋업 완료!                                         #" -ForegroundColor Green
Write-Host "######################################################" -ForegroundColor Green
Write-Host ""
Write-Host "다음 단계예요:" -ForegroundColor Cyan
Write-Host "  1. VSCode 를 완전히 재시작해 주세요 (Playwright MCP 로드 위해서)."
Write-Host "  2. Claude Code 사이드바를 열고 새 대화를 시작해 주세요."
Write-Host "  3. 작업 폴더: $WorkRoot"
Write-Host "  4. 첫 메시지로 '논문 찾아줘' 또는 '안녕!' 등 보내시면 돼요."
Write-Host ""
Write-Host "업데이트 시: cd $RepoDir; git pull; .\bootstrap.ps1" -ForegroundColor DarkGray
Write-Host ""
