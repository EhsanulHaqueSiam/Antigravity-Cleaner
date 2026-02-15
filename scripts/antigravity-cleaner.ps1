<#
.SYNOPSIS
    Antigravity Toolkit v3.1 - TUI Edition (Windows)
.DESCRIPTION
    Complete system toolkit for the Antigravity IDE.
    Cache cleaner, browser toolkit, troubleshooter, usage monitor,
    account switcher, network fixer, and browser backup.
.PARAMETER Quick
    Non-interactive mode - clean all cache safely
.PARAMETER DryRun
    Preview deletions without removing anything
.PARAMETER Help
    Show help message
#>

param(
    [switch]$Quick,
    [switch]$DryRun,
    [Alias("h")]
    [switch]$Help
)

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = "Antigravity Toolkit v3.1"

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuration
# ═══════════════════════════════════════════════════════════════════════════════
$VERSION = "3.1"
$BOX_W   = 76

# Discover the .gemini directory — check multiple possible locations
$GEMINI_DIR = ""
$_candidates = @()

# 1. Official override: GEMINI_CLI_HOME environment variable
if ($env:GEMINI_CLI_HOME -and (Test-Path $env:GEMINI_CLI_HOME)) {
    $_candidates += $env:GEMINI_CLI_HOME
}

# 2. Standard locations
$_candidates += "$env:USERPROFILE\.gemini"
if ($env:APPDATA)     { $_candidates += "$env:APPDATA\.gemini" }
if ($env:LOCALAPPDATA) { $_candidates += "$env:LOCALAPPDATA\.gemini" }
if ($env:APPDATA)     { $_candidates += "$env:APPDATA\gemini" }
if ($env:LOCALAPPDATA) { $_candidates += "$env:LOCALAPPDATA\gemini" }
if ($env:HOMEDRIVE -and $env:HOMEPATH) {
    $_candidates += "$env:HOMEDRIVE$env:HOMEPATH\.gemini"
}
if ($env:HOME -and $env:HOME -ne $env:USERPROFILE) {
    $_candidates += "$env:HOME\.gemini"
}

foreach ($_c in $_candidates) {
    if (Test-Path $_c) {
        $GEMINI_DIR = $_c
        break
    }
}

# Fallback if nothing found — use the standard path for error messaging
if ([string]::IsNullOrEmpty($GEMINI_DIR)) { $GEMINI_DIR = "$env:USERPROFILE\.gemini" }

$ANTIGRAVITY_DIR  = "$GEMINI_DIR\antigravity"
$BROWSER_PROF_DIR = "$GEMINI_DIR\antigravity-browser-profile"
$BP_DEF           = "$BROWSER_PROF_DIR\Default"
$BACKUP_DIR       = "$GEMINI_DIR\backups"

# ═══════════════════════════════════════════════════════════════════════════════
#  Help
# ═══════════════════════════════════════════════════════════════════════════════
if ($Help) {
    Write-Host @"

Antigravity Toolkit v$VERSION (Windows)

Usage:  .\antigravity-cleaner.ps1 [OPTIONS]

Options:
  -Quick      Non-interactive mode (clean all cache safely)
  -DryRun     Preview deletions without removing anything
  -Help       Show this help

Interactive mode (default):
  Full TUI with cache cleaner, browser toolkit, troubleshooter,
  usage dashboard, account switcher, network fixer, browser backup,
  and one-click Fix Everything.

One-liner:
  iwr -useb https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.ps1 | iex

"@
    exit 0
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Check for Antigravity
# ═══════════════════════════════════════════════════════════════════════════════
if (-not (Test-Path $GEMINI_DIR)) {
    Write-Host ""
    Write-Host "  Antigravity data directory not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "  Searched these locations:" -ForegroundColor DarkGray
    foreach ($_c in $_candidates) {
        $mark = if (Test-Path $_c) { "+" } else { "-" }
        Write-Host "    $mark  $_c" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Is Antigravity installed? If your data is elsewhere," -ForegroundColor DarkGray
    Write-Host "  set GEMINI_CLI_HOME to point to it." -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Box-drawing primitives (rounded corners)
# ═══════════════════════════════════════════════════════════════════════════════
function Draw-BoxTop    { Write-Host ("  " + [char]0x256D + ([string][char]0x2500 * ($BOX_W-2)) + [char]0x256E) -ForegroundColor DarkGray }
function Draw-BoxBot    { Write-Host ("  " + [char]0x2570 + ([string][char]0x2500 * ($BOX_W-2)) + [char]0x256F) -ForegroundColor DarkGray }
function Draw-BoxSep    { Write-Host ("  " + [char]0x251C + ([string][char]0x2500 * ($BOX_W-2)) + [char]0x2524) -ForegroundColor DarkGray }
function Draw-BoxEmpty  { Write-Host ("  " + [char]0x2502 + (" " * ($BOX_W-2)) + [char]0x2502) -ForegroundColor DarkGray }

function Draw-BoxLine {
    param([string]$Text, [ConsoleColor]$Color = "White")
    $padLen = $BOX_W - 4 - $Text.Length
    if ($padLen -lt 0) { $padLen = 0 }
    $pad = " " * $padLen
    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host "${Text}${pad}" -NoNewline -ForegroundColor $Color
    Write-Host (" " + [char]0x2502) -ForegroundColor DarkGray
}

function Draw-BoxTitle {
    param([string]$Title)
    $dashes = $BOX_W - 6 - $Title.Length
    if ($dashes -lt 2) { $dashes = 2 }
    $line = [string][char]0x2500 * $dashes
    Write-Host ("  " + [char]0x251C + [char]0x2500 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host $Title -NoNewline -ForegroundColor Cyan
    Write-Host (" " + $line + [char]0x2524) -ForegroundColor DarkGray
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Utility functions
# ═══════════════════════════════════════════════════════════════════════════════
function Get-DirSizeInfo {
    param([string]$Path)
    if (Test-Path $Path) {
        $bytes = (Get-ChildItem $Path -Recurse -File -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum
        if ($null -eq $bytes) { $bytes = 0 }
    } else { $bytes = 0 }

    $text = if     ($bytes -gt 1GB) { "{0:N1} GB" -f ($bytes / 1GB) }
            elseif ($bytes -gt 1MB) { "{0:N1} MB" -f ($bytes / 1MB) }
            elseif ($bytes -gt 1KB) { "{0:N1} KB" -f ($bytes / 1KB) }
            else                    { "$bytes B" }

    $color = if     ($bytes -gt 1GB) { "Red" }
             elseif ($bytes -gt 1MB) { "DarkYellow" }
             elseif ($bytes -gt 1KB) { "Yellow" }
             else                    { "Green" }

    return @{ Text = $text; Bytes = [long]$bytes; Color = $color }
}

function Format-Bytes {
    param([long]$Bytes)
    if     ($Bytes -gt 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -gt 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -gt 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    else                    { return "$Bytes B" }
}

function Get-ItemCount {
    param([string]$Path, [switch]$Dirs)
    if (-not (Test-Path $Path)) { return 0 }
    if ($Dirs) {
        return @(Get-ChildItem $Path -Directory -ErrorAction SilentlyContinue).Count
    }
    return @(Get-ChildItem $Path -File -Recurse -Force -ErrorAction SilentlyContinue).Count
}

function Clean-Dir {
    param([string]$Path, [string]$Name)
    if ((Test-Path $Path) -and @(Get-ChildItem $Path -Force -ErrorAction SilentlyContinue).Count -gt 0) {
        $info = Get-DirSizeInfo -Path $Path
        if ($DryRun) {
            Write-Host "  DRY  Would clean $Name - $($info.Text)" -ForegroundColor Yellow
            return
        }
        Write-Host "  ...  Cleaning $Name" -NoNewline -ForegroundColor DarkGray
        try {
            Remove-Item "$Path\*" -Recurse -Force -ErrorAction Stop
            Start-Sleep -Milliseconds 150
            Write-Host "`r  OK   $Name - $($info.Text) freed   " -ForegroundColor Green
        } catch {
            Write-Host "`r  !!   $Name - Access denied   " -ForegroundColor Red
        }
    } else {
        Write-Host "  -    $Name is empty" -ForegroundColor DarkGray
    }
}

function Clean-File {
    param([string]$Path, [string]$Name)
    if (Test-Path $Path -PathType Leaf) {
        if ($DryRun) {
            Write-Host "  DRY  Would remove $Name" -ForegroundColor Yellow
            return
        }
        try {
            Remove-Item $Path -Force -ErrorAction Stop
            Write-Host "  OK   $Name removed" -ForegroundColor Green
        } catch {
            Write-Host "  !!   $Name - Access denied" -ForegroundColor Red
        }
    }
}

function Wait-Key {
    Write-Host ""
    Write-Host "  Press Enter to continue... " -ForegroundColor DarkGray -NoNewline
    Read-Host | Out-Null
}

function Read-Choice {
    param([string]$Prompt = "  > ")
    Write-Host $Prompt -NoNewline -ForegroundColor Cyan
    $userInput = Read-Host
    return $userInput.Trim()
}

function Draw-ProgressBar {
    param([int]$Current, [int]$Total, [int]$Width = 32)
    if ($Total -le 0) { $Total = 1 }
    $pct = [math]::Floor($Current * 100 / $Total)
    $fill = [math]::Floor($Current * $Width / $Total)
    if ($fill -gt $Width) { $fill = $Width }
    $empty = $Width - $fill
    $bar = ("=" * [math]::Max($fill, 0)) + ("-" * [math]::Max($empty, 0))
    return "[$bar] ${pct}%"
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Header
# ═══════════════════════════════════════════════════════════════════════════════
function Show-Header {
    Clear-Host
    Write-Host ""
    Draw-BoxTop
    Draw-BoxEmpty
    Draw-BoxLine "  A N T I G R A V I T Y" -Color Magenta
    Draw-BoxLine "  T O O L K I T" -Color Cyan
    Draw-BoxEmpty
    Draw-BoxLine "  v$VERSION  -  Windows  -  Complete System Toolkit" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  1. Cache Cleaner
# ═══════════════════════════════════════════════════════════════════════════════
function Show-CacheStatus {
    $dirs = [ordered]@{
        "Brain (artifacts/plans)"  = "$ANTIGRAVITY_DIR\brain"
        "Conversations"            = "$ANTIGRAVITY_DIR\conversations"
        "Browser Recordings"       = "$ANTIGRAVITY_DIR\browser_recordings"
        "Context State"            = "$ANTIGRAVITY_DIR\context_state"
        "Code Tracker"             = "$ANTIGRAVITY_DIR\code_tracker"
        "Implicit Memory"          = "$ANTIGRAVITY_DIR\implicit"
        "Annotations"              = "$ANTIGRAVITY_DIR\annotations"
        "Knowledge Base"           = "$ANTIGRAVITY_DIR\knowledge"
        "Playground"               = "$ANTIGRAVITY_DIR\playground"
        "Scratch Space"            = "$ANTIGRAVITY_DIR\scratch"
        "Browser Profile (full)"   = $BROWSER_PROF_DIR
    }

    Draw-BoxTop
    Draw-BoxTitle "Cache Status"
    Draw-BoxEmpty

    $totalBytes = 0
    foreach ($key in $dirs.Keys) {
        $info = Get-DirSizeInfo -Path $dirs[$key]
        $totalBytes += $info.Bytes
        $padded = $key.PadRight(30) + $info.Text.PadLeft(12)
        Draw-BoxLine "  $padded" -Color White
    }

    Draw-BoxSep
    $totalText = Format-Bytes -Bytes $totalBytes
    $padded = "TOTAL".PadRight(30) + $totalText.PadLeft(12)
    Draw-BoxLine "  $padded" -Color White
    Draw-BoxBot
    Write-Host ""
}

function Menu-Cleaner {
    while ($true) {
        Show-Header
        Show-CacheStatus

        Draw-BoxTop
        Draw-BoxTitle "Clean Options"
        Draw-BoxEmpty
        Draw-BoxLine "  [1]  Browser Recordings"
        Draw-BoxLine "  [2]  Conversations"
        Draw-BoxLine "  [3]  Brain Artifacts"
        Draw-BoxLine "  [4]  Context State"
        Draw-BoxLine "  [5]  Code Tracker + Annotations"
        Draw-BoxLine "  [6]  Implicit Memory + Knowledge"
        Draw-BoxLine "  [7]  Playground + Scratch"
        Draw-BoxEmpty
        Draw-BoxLine "  [8]  Clean ALL cache (safe)" -Color Green
        Draw-BoxLine "  [9]  Aggressive clean (nuclear)" -Color Red
        Draw-BoxEmpty
        Draw-BoxLine "  [b]  Back" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        Write-Host ""
        $ch = Read-Choice

        if ([string]::IsNullOrWhiteSpace($ch)) { continue }

        Write-Host ""
        switch ($ch) {
            "1" { Clean-Dir "$ANTIGRAVITY_DIR\browser_recordings" "Browser Recordings"; Wait-Key }
            "2" { Clean-Dir "$ANTIGRAVITY_DIR\conversations" "Conversations"; Wait-Key }
            "3" { Clean-Dir "$ANTIGRAVITY_DIR\brain" "Brain Artifacts"; Wait-Key }
            "4" { Clean-Dir "$ANTIGRAVITY_DIR\context_state" "Context State"; Wait-Key }
            "5" {
                Clean-Dir "$ANTIGRAVITY_DIR\code_tracker" "Code Tracker"
                Clean-Dir "$ANTIGRAVITY_DIR\annotations" "Annotations"
                Wait-Key
            }
            "6" {
                Clean-Dir "$ANTIGRAVITY_DIR\implicit" "Implicit Memory"
                Clean-Dir "$ANTIGRAVITY_DIR\knowledge" "Knowledge Base"
                Wait-Key
            }
            "7" {
                Clean-Dir "$ANTIGRAVITY_DIR\playground" "Playground"
                Clean-Dir "$ANTIGRAVITY_DIR\scratch" "Scratch Space"
                Wait-Key
            }
            "8" {
                foreach ($d in @("brain","conversations","browser_recordings","context_state","code_tracker","implicit","annotations","knowledge","playground","scratch")) {
                    Clean-Dir "$ANTIGRAVITY_DIR\$d" $d
                }
                Write-Host ""; Write-Host "  All cache cleaned." -ForegroundColor Green
                Wait-Key
            }
            "9" {
                Write-Host "  NUCLEAR CLEAN: This removes ALL data including" -ForegroundColor Red
                Write-Host "  browser profile, config, installation ID - everything." -ForegroundColor Red
                Write-Host "  Antigravity will be fully reset." -ForegroundColor Red
                Write-Host ""
                $confirm = Read-Choice "  Type NUKE to confirm: "
                if ($confirm -eq "NUKE") {
                    Write-Host ""
                    foreach ($d in @("brain","conversations","browser_recordings","context_state","code_tracker","implicit","annotations","knowledge","playground","scratch")) {
                        Clean-Dir "$ANTIGRAVITY_DIR\$d" $d
                    }
                    Clean-Dir $BROWSER_PROF_DIR "Browser Profile"
                    Clean-File "$ANTIGRAVITY_DIR\mcp_config.json" "MCP Config"
                    Clean-File "$ANTIGRAVITY_DIR\user_settings.pb" "User Settings"
                    Clean-File "$ANTIGRAVITY_DIR\browserOnboardingStatus.txt" "Onboarding Status"
                    Clean-File "$GEMINI_DIR\GEMINI.md" "GEMINI.md"
                    Write-Host ""; Write-Host "  Nuclear clean complete. Restart Antigravity." -ForegroundColor Green
                } else {
                    Write-Host "  Cancelled." -ForegroundColor Yellow
                }
                Wait-Key
            }
            { $_ -in "b","B" } { return }
            default { continue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  2. Browser Toolkit (Antigravity's built-in Chromium browser)
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Browser {
    while ($true) {
        Show-Header

        Draw-BoxTop
        Draw-BoxTitle "Antigravity Browser Toolkit"
        Draw-BoxEmpty

        # Sizes
        $cacheSz = Get-DirSizeInfo "$BP_DEF\Cache"
        $codeSz  = Get-DirSizeInfo "$BP_DEF\Code Cache"
        $gpuSz   = Get-DirSizeInfo "$BP_DEF\GPUCache"
        $lsSz    = Get-DirSizeInfo "$BP_DEF\Local Storage"
        $ssSz    = Get-DirSizeInfo "$BP_DEF\Session Storage"
        $swSz    = Get-DirSizeInfo "$BP_DEF\Service Worker"
        $shaderSz = Get-DirSizeInfo "$BROWSER_PROF_DIR\ShaderCache"
        $compSz  = Get-DirSizeInfo "$BROWSER_PROF_DIR\component_crx_cache"
        $sbSz    = Get-DirSizeInfo "$BROWSER_PROF_DIR\Safe Browsing"
        $profTotal = Get-DirSizeInfo $BROWSER_PROF_DIR

        Draw-BoxLine "  Browser profile:          $($profTotal.Text)"
        Draw-BoxLine "    Default\Cache:           $($cacheSz.Text)" -Color DarkGray
        Draw-BoxLine "    Default\Code Cache:      $($codeSz.Text)" -Color DarkGray
        Draw-BoxLine "    Default\GPUCache:        $($gpuSz.Text)" -Color DarkGray
        Draw-BoxLine "    Default\Local Storage:   $($lsSz.Text)" -Color DarkGray
        Draw-BoxLine "    ShaderCache:             $($shaderSz.Text)" -Color DarkGray
        Draw-BoxLine "    component_crx_cache:     $($compSz.Text)" -Color DarkGray
        Draw-BoxLine "    Safe Browsing:           $($sbSz.Text)" -Color DarkGray

        $hasLock = "No"
        if ((Test-Path "$BP_DEF\SingletonLock") -or (Test-Path "$BP_DEF\LOCK")) {
            $hasLock = "YES"
        }
        Draw-BoxLine "    Lock files:              $hasLock"
        Draw-BoxEmpty
        Draw-BoxSep
        Draw-BoxEmpty

        Draw-BoxLine "  [1]  Clean browser cache (Cache/Code/GPU)"
        Draw-BoxLine "  [2]  Clean cookies & sessions"
        Draw-BoxLine "  [3]  Clean local/session storage"
        Draw-BoxLine "  [4]  Clean Service Workers & IndexedDB"
        Draw-BoxLine "  [5]  Clean shader/GPU caches"
        Draw-BoxLine "  [6]  Clean component cache & Safe Browsing"
        Draw-BoxLine "  [7]  Fix lock files (SingletonLock/LOCK)"
        Draw-BoxLine "  [8]  Clean browsing history"
        Draw-BoxEmpty
        Draw-BoxLine "  [9]  Clean ALL browser data" -Color Green
        Draw-BoxLine "  [0]  Full browser profile reset" -Color Red
        Draw-BoxEmpty
        Draw-BoxLine "  [b]  Back" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        Write-Host ""
        $ch = Read-Choice

        if ([string]::IsNullOrWhiteSpace($ch)) { continue }

        Write-Host ""
        switch ($ch) {
            "1" {
                Clean-Dir "$BP_DEF\Cache" "Browser Cache"
                Clean-Dir "$BP_DEF\Code Cache" "Code Cache"
                Clean-Dir "$BP_DEF\GPUCache" "GPU Cache"
                Clean-Dir "$BP_DEF\DawnGraphiteCache" "Dawn Graphite Cache"
                Clean-Dir "$BP_DEF\DawnWebGPUCache" "Dawn WebGPU Cache"
                Wait-Key
            }
            "2" {
                Clean-File "$BP_DEF\Cookies" "Cookies"
                Clean-File "$BP_DEF\Cookies-journal" "Cookies journal"
                Clean-File "$BP_DEF\Safe Browsing Cookies" "Safe Browsing Cookies"
                Clean-File "$BP_DEF\Safe Browsing Cookies-journal" "SB Cookies journal"
                Clean-Dir "$BP_DEF\Sessions" "Sessions"
                Wait-Key
            }
            "3" {
                Clean-Dir "$BP_DEF\Local Storage" "Local Storage"
                Clean-Dir "$BP_DEF\Session Storage" "Session Storage"
                Clean-Dir "$BP_DEF\WebStorage" "WebStorage"
                Clean-Dir "$BP_DEF\SharedStorage" "Shared Storage"
                Wait-Key
            }
            "4" {
                Clean-Dir "$BP_DEF\Service Worker" "Service Workers"
                Clean-Dir "$BP_DEF\blob_storage" "Blob Storage"
                Clean-Dir "$BP_DEF\Shared Dictionary" "Shared Dictionary"
                Wait-Key
            }
            "5" {
                Clean-Dir "$BROWSER_PROF_DIR\ShaderCache" "ShaderCache"
                Clean-Dir "$BROWSER_PROF_DIR\GrShaderCache" "GrShaderCache"
                Clean-Dir "$BROWSER_PROF_DIR\GraphiteDawnCache" "GraphiteDawnCache"
                Clean-Dir "$BP_DEF\GPUCache" "Default GPUCache"
                Clean-Dir "$BP_DEF\DawnGraphiteCache" "Dawn Graphite"
                Clean-Dir "$BP_DEF\DawnWebGPUCache" "Dawn WebGPU"
                Wait-Key
            }
            "6" {
                Clean-Dir "$BROWSER_PROF_DIR\component_crx_cache" "Component CRX Cache"
                Clean-Dir "$BROWSER_PROF_DIR\Safe Browsing" "Safe Browsing Data"
                Clean-Dir "$BROWSER_PROF_DIR\extensions_crx_cache" "Extensions Cache"
                Clean-Dir "$BROWSER_PROF_DIR\WidevineCdm" "Widevine DRM"
                Clean-Dir "$BROWSER_PROF_DIR\WasmTtsEngine" "WASM TTS Engine"
                Wait-Key
            }
            "7" {
                Write-Host "  Removing lock files..." -ForegroundColor Cyan
                Clean-File "$BP_DEF\SingletonLock" "SingletonLock"
                Clean-File "$BP_DEF\LOCK" "LOCK"
                Clean-File "$BP_DEF\lockfile" "lockfile"
                Write-Host "  Lock files cleared. Try restarting Antigravity." -ForegroundColor Green
                Wait-Key
            }
            "8" {
                Clean-File "$BP_DEF\History" "History"
                Clean-File "$BP_DEF\History-journal" "History journal"
                Clean-File "$BP_DEF\Favicons" "Favicons"
                Clean-File "$BP_DEF\Favicons-journal" "Favicons journal"
                Clean-File "$BP_DEF\Top Sites" "Top Sites"
                Clean-File "$BP_DEF\Top Sites-journal" "Top Sites journal"
                Clean-File "$BP_DEF\Shortcuts" "Shortcuts"
                Clean-File "$BP_DEF\Shortcuts-journal" "Shortcuts journal"
                Clean-File "$BP_DEF\Network Action Predictor" "Network Predictor"
                Wait-Key
            }
            "9" {
                Write-Host "  Cleaning all browser data..." -ForegroundColor Cyan
                # Caches in Default
                foreach ($d in @("Cache","Code Cache","GPUCache","DawnGraphiteCache","DawnWebGPUCache",
                                 "Local Storage","Session Storage","WebStorage","SharedStorage",
                                 "Service Worker","blob_storage","Sessions","Shared Dictionary",
                                 "Download Service","Feature Engagement Tracker")) {
                    Clean-Dir "$BP_DEF\$d" $d
                }
                # GPU caches at top level
                foreach ($d in @("ShaderCache","GrShaderCache","GraphiteDawnCache")) {
                    Clean-Dir "$BROWSER_PROF_DIR\$d" $d
                }
                # Files
                foreach ($f in @("Cookies","Cookies-journal","History","History-journal",
                                 "Favicons","Favicons-journal","Top Sites","Top Sites-journal",
                                 "Shortcuts","Shortcuts-journal","Safe Browsing Cookies",
                                 "Safe Browsing Cookies-journal","Network Action Predictor",
                                 "Network Action Predictor-journal","DIPS")) {
                    Clean-File "$BP_DEF\$f" $f
                }
                Clean-File "$BP_DEF\SingletonLock" "SingletonLock"
                Clean-File "$BP_DEF\LOCK" "LOCK"
                Clean-File "$BROWSER_PROF_DIR\BrowserMetrics-spare.pma" "BrowserMetrics"
                Write-Host ""; Write-Host "  All browser data cleaned." -ForegroundColor Green
                Wait-Key
            }
            "0" {
                Write-Host "  WARNING: Full reset deletes the entire browser profile." -ForegroundColor Red
                Write-Host "  You will lose all browser cookies, history, extensions." -ForegroundColor Red
                Write-Host ""
                $confirm = Read-Choice "  Type RESET to confirm: "
                if ($confirm -eq "RESET") {
                    Write-Host ""
                    Clean-Dir $BROWSER_PROF_DIR "Entire Browser Profile"
                    Write-Host "  Browser profile reset. Restart Antigravity." -ForegroundColor Green
                } else {
                    Write-Host "  Cancelled." -ForegroundColor Yellow
                }
                Wait-Key
            }
            { $_ -in "b","B" } { return }
            default { continue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  3. Network Fixer
# ═══════════════════════════════════════════════════════════════════════════════
function Flush-DnsCache {
    try {
        $null = Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait -PassThru 2>$null
        return $true
    } catch {
        return $false
    }
}

function Test-Endpoint {
    param([string]$Url, [string]$Label)
    Write-Host "  $([char]0x2502)  $Label  $Url... " -NoNewline -ForegroundColor DarkGray
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 8 -MaximumRedirection 5 -ErrorAction Stop
        $code = $response.StatusCode
        if ($code -in 200,301,302,303) {
            Write-Host "OK ($code)" -ForegroundColor Green
            return $true
        } elseif ($code -eq 403) {
            Write-Host "403 Forbidden" -ForegroundColor Red
            return $false
        } elseif ($code -eq 429) {
            Write-Host "429 Rate Limited" -ForegroundColor DarkYellow
            return $false
        } else {
            Write-Host "Failed ($code)" -ForegroundColor Red
            return $false
        }
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 403) {
            Write-Host "403 Forbidden" -ForegroundColor Red
        } elseif ($status -eq 429) {
            Write-Host "429 Rate Limited" -ForegroundColor DarkYellow
        } else {
            Write-Host "Failed ($status)" -ForegroundColor Red
        }
        return $false
    }
}

function Menu-Network {
    Show-Header

    Draw-BoxTop
    Draw-BoxTitle "Network Fixer (Windows)"
    Draw-BoxEmpty

    Write-Host "  $([char]0x2502)  DNS   Flushing cache... " -NoNewline -ForegroundColor DarkGray
    if (Flush-DnsCache) { Write-Host "Done" -ForegroundColor Green }
    else                { Write-Host "Failed" -ForegroundColor Red }

    Test-Endpoint "https://www.google.com" "NET  "
    Test-Endpoint "https://gemini.google.com" "GEM  "
    Test-Endpoint "https://alkalimetal-pa.clients6.google.com" "API  "
    Test-Endpoint "https://generativelanguage.googleapis.com" "GAPI "

    Draw-BoxEmpty
    Draw-BoxSep
    Draw-BoxLine "  Common Fixes" -Color Yellow
    Draw-BoxEmpty
    Draw-BoxLine "  1. Restart Antigravity after DNS flush" -Color DarkGray
    Draw-BoxLine "  2. Clean browser cache (Browser Toolkit > 1)" -Color DarkGray
    Draw-BoxLine "  3. Reset browser profile (Browser Toolkit > 0)" -Color DarkGray
    Draw-BoxLine "  4. Disable VPN / proxy" -Color DarkGray
    Draw-BoxLine "  5. Switch Google account (Account Switcher)" -Color DarkGray
    Draw-BoxLine "  6. Check firewall rules for Google domains" -Color DarkGray
    Draw-BoxLine "  7. Try 'Fix Everything' (main menu > 8)" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  4. Troubleshooter
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Troubleshoot {
    Show-Header

    Draw-BoxTop
    Draw-BoxTitle "Troubleshooter"
    Draw-BoxEmpty
    Draw-BoxLine "  Running diagnostics..." -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot
    Write-Host ""

    $issues = 0
    $fixes = @()

    # 1. Antigravity directory
    Write-Host "  [1/9] Antigravity directory... " -NoNewline -ForegroundColor Cyan
    if ((Test-Path $GEMINI_DIR) -and (Test-Path $ANTIGRAVITY_DIR)) {
        Write-Host "OK" -ForegroundColor Green
    } else {
        Write-Host "Missing" -ForegroundColor Red
        $issues++
    }

    # 2. Internet
    Write-Host "  [2/9] Internet connectivity... " -NoNewline -ForegroundColor Cyan
    try {
        $null = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "No internet" -ForegroundColor Red
        $issues++
        $fixes += "flush_dns"
    }

    # 3. DNS
    Write-Host "  [3/9] DNS resolution... " -NoNewline -ForegroundColor Cyan
    try {
        $null = Resolve-DnsName "gemini.google.com" -ErrorAction Stop
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "Uncertain" -ForegroundColor Yellow
    }

    # 4. Gemini API
    Write-Host "  [4/9] Gemini API access... " -NoNewline -ForegroundColor Cyan
    $apiCode = 0
    try {
        $r = Invoke-WebRequest -Uri "https://gemini.google.com" -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        $apiCode = $r.StatusCode
        Write-Host "OK ($apiCode)" -ForegroundColor Green
    } catch {
        $apiCode = $_.Exception.Response.StatusCode.value__
        if ($apiCode -eq 403) {
            Write-Host "403 Forbidden" -ForegroundColor Red
            $issues++
            $fixes += "flush_dns"
            $fixes += "clean_browser_cache"
        } elseif ($apiCode -eq 429) {
            Write-Host "429 Rate Limited - wait for reset" -ForegroundColor DarkYellow
            $issues++
        } else {
            Write-Host "Failed ($apiCode)" -ForegroundColor Red
            $issues++
            $fixes += "flush_dns"
        }
    }

    # 5. Alkalimetal API
    Write-Host "  [5/9] Alkalimetal endpoint... " -NoNewline -ForegroundColor Cyan
    try {
        $r = Test-NetConnection -ComputerName "alkalimetal-pa.clients6.google.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($r) { Write-Host "Reachable" -ForegroundColor Green }
        else    { Write-Host "Blocked" -ForegroundColor Red; $issues++; $fixes += "flush_dns" }
    } catch { Write-Host "Error" -ForegroundColor Red; $issues++ }

    # 6. Browser profile
    Write-Host "  [6/9] Browser profile... " -NoNewline -ForegroundColor Cyan
    if (Test-Path $BROWSER_PROF_DIR) {
        if (Test-Path "$BP_DEF\SingletonLock") {
            Write-Host "Lock file present" -ForegroundColor Yellow
            $issues++
            $fixes += "fix_locks"
        } else {
            Write-Host "OK" -ForegroundColor Green
        }
    } else {
        Write-Host "Not found (will be created)" -ForegroundColor DarkGray
    }

    # 7. Disk space
    Write-Host "  [7/9] Disk space... " -NoNewline -ForegroundColor Cyan
    try {
        $drive = (Get-Item $env:USERPROFILE).PSDrive.Name
        $freeGB = [math]::Round((Get-PSDrive $drive).Free / 1GB, 1)
        $freeMB = [math]::Round((Get-PSDrive $drive).Free / 1MB)
        if ($freeMB -gt 500) {
            Write-Host "OK (${freeGB}GB free)" -ForegroundColor Green
        } else {
            Write-Host "Low (${freeMB}MB free)" -ForegroundColor Yellow
            $issues++
            $fixes += "clean_all_cache"
        }
    } catch {
        Write-Host "Unknown" -ForegroundColor DarkGray
    }

    # 8. Cache size
    Write-Host "  [8/9] Cache size... " -NoNewline -ForegroundColor Cyan
    $cacheInfo = Get-DirSizeInfo $ANTIGRAVITY_DIR
    if ($cacheInfo.Bytes -gt 2GB) {
        Write-Host "Large ($($cacheInfo.Text)) - consider cleaning" -ForegroundColor DarkYellow
        $fixes += "clean_all_cache"
    } else {
        Write-Host "OK ($($cacheInfo.Text))" -ForegroundColor Green
    }

    # 9. Rate limit check
    Write-Host "  [9/9] Rate limit status... " -NoNewline -ForegroundColor Cyan
    if ($apiCode -eq 429) {
        Write-Host "Rate limited - check Reset Timer" -ForegroundColor Red
    } else {
        Write-Host "Not rate limited" -ForegroundColor Green
    }

    # Summary
    Write-Host ""
    Draw-BoxTop
    Draw-BoxEmpty
    if ($issues -eq 0) {
        Draw-BoxLine "  All checks passed! No issues detected." -Color Green
    } else {
        Draw-BoxLine "  $issues issue(s) detected." -Color Yellow
    }
    Draw-BoxEmpty

    if ($fixes.Count -gt 0) {
        Draw-BoxSep
        Draw-BoxEmpty
        Draw-BoxLine "  [f]  Auto-fix all detected issues"
    }
    Draw-BoxLine "  [b]  Back" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Write-Host ""
    $ch = Read-Choice

    if ($ch -in "f","F" -and $fixes.Count -gt 0) {
        Write-Host ""
        Write-Host "  Applying fixes..." -ForegroundColor Cyan
        $uniqueFixes = $fixes | Select-Object -Unique
        foreach ($fix in $uniqueFixes) {
            switch ($fix) {
                "flush_dns" {
                    if (Flush-DnsCache) { Write-Host "  OK   DNS flushed" -ForegroundColor Green }
                    else                { Write-Host "  !!   DNS flush failed" -ForegroundColor Yellow }
                }
                "clean_browser_cache" {
                    Clean-Dir "$BP_DEF\Cache" "Browser Cache"
                    Clean-Dir "$BP_DEF\Code Cache" "Code Cache"
                }
                "fix_locks" {
                    Clean-File "$BP_DEF\SingletonLock" "SingletonLock"
                    Clean-File "$BP_DEF\LOCK" "LOCK"
                }
                "clean_all_cache" {
                    foreach ($d in @("brain","conversations","browser_recordings","context_state","code_tracker","implicit","annotations","knowledge","playground","scratch")) {
                        Clean-Dir "$ANTIGRAVITY_DIR\$d" $d
                    }
                }
            }
        }
        Write-Host ""; Write-Host "  Fixes applied. Restart Antigravity." -ForegroundColor Green
        Wait-Key
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  5. Usage & Rate Limits
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Usage {
    Show-Header

    $convN  = Get-ItemCount "$ANTIGRAVITY_DIR\conversations" -Dirs
    $brainN = Get-ItemCount "$ANTIGRAVITY_DIR\brain"
    $recN   = Get-ItemCount "$ANTIGRAVITY_DIR\browser_recordings" -Dirs
    $ctxN   = Get-ItemCount "$ANTIGRAVITY_DIR\context_state"
    $codeN  = Get-ItemCount "$ANTIGRAVITY_DIR\code_tracker"
    $annoN  = Get-ItemCount "$ANTIGRAVITY_DIR\annotations"
    $knowN  = Get-ItemCount "$ANTIGRAVITY_DIR\knowledge"

    $convI  = Get-DirSizeInfo "$ANTIGRAVITY_DIR\conversations"
    $brainI = Get-DirSizeInfo "$ANTIGRAVITY_DIR\brain"
    $recI   = Get-DirSizeInfo "$ANTIGRAVITY_DIR\browser_recordings"
    $profI  = Get-DirSizeInfo $BROWSER_PROF_DIR
    $totalB = $convI.Bytes + $brainI.Bytes + $recI.Bytes + $profI.Bytes

    Draw-BoxTop
    Draw-BoxTitle "Usage Dashboard"
    Draw-BoxEmpty
    Draw-BoxLine "  Conversations            $convN sessions"
    Draw-BoxLine "  Brain Artifacts          $brainN files"
    Draw-BoxLine "  Browser Recordings       $recN sessions"
    Draw-BoxLine "  Context Snapshots        $ctxN files"
    Draw-BoxLine "  Code Tracker             $codeN files"
    Draw-BoxLine "  Annotations              $annoN files"
    Draw-BoxLine "  Knowledge                $knowN files"
    Draw-BoxSep
    $totalText = Format-Bytes -Bytes $totalB
    Draw-BoxLine "  Total Cache              $totalText"
    Draw-BoxBot

    # Activity
    $now = Get-Date
    $todayN = 0; $weekN = 0; $monthN = 0

    if (Test-Path "$ANTIGRAVITY_DIR\conversations") {
        Get-ChildItem "$ANTIGRAVITY_DIR\conversations" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $age = ($now - $_.LastWriteTime).TotalSeconds
            if ($age -lt 86400)   { $script:todayN++ }
            if ($age -lt 604800)  { $script:weekN++ }
            if ($age -lt 2592000) { $script:monthN++ }
        }
    }

    Write-Host ""
    Draw-BoxTop
    Draw-BoxTitle "Activity"
    Draw-BoxEmpty
    Draw-BoxLine "  Today          $todayN sessions" -Color Cyan
    Draw-BoxLine "  This week      $weekN sessions" -Color Cyan
    Draw-BoxLine "  This month     $monthN sessions" -Color Cyan
    Draw-BoxBot

    # Rate Limit / Reset Timer
    $dim = [DateTime]::DaysInMonth($now.Year, $now.Month)
    $dayNum = $now.Day
    $monthName = $now.ToString("MMMM")

    # Exact reset: 1st of next month at midnight
    $resetDate = (Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0).AddMonths(1)
    $resetDateStr = $resetDate.ToString("MMMM dd, yyyy 'at' hh:mm tt")
    $timeLeft = $resetDate - $now
    $dLeft = [math]::Floor($timeLeft.TotalDays)
    $hLeft = $timeLeft.Hours
    $mLeft = $timeLeft.Minutes
    $countdown = "${dLeft}d ${hLeft}h ${mLeft}m"

    Write-Host ""
    Draw-BoxTop
    Draw-BoxTitle "Rate Limit Reset Timer"
    Draw-BoxEmpty
    Draw-BoxLine "  Current Cycle       $monthName $($now.Year)"
    Draw-BoxEmpty
    Draw-BoxLine "  Available On        $resetDateStr" -Color Green
    Draw-BoxLine "  Countdown           $countdown" -Color Yellow
    Draw-BoxEmpty
    $pbar = Draw-ProgressBar -Current $dayNum -Total $dim -Width 32
    Draw-BoxLine "  $pbar" -Color Green
    Draw-BoxEmpty

    if ($dayNum -gt 0 -and $monthN -gt 0) {
        $rate = [math]::Round($monthN / $dayNum, 1)
        $proj = [math]::Round($rate * $dim)
        Draw-BoxSep
        Draw-BoxEmpty
        Draw-BoxLine "  Avg sessions/day    $rate" -Color Cyan
        Draw-BoxLine "  Projected monthly   $proj" -Color Cyan
        Draw-BoxEmpty
    }

    Draw-BoxLine "  Rate limit resets at midnight on the 1st." -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  6. Account Dashboard (API-based per-model quota)
# ═══════════════════════════════════════════════════════════════════════════════

function Draw-QuotaBar {
    param([int]$Fill, [int]$Empty, [string]$BarCol)
    $barColor = switch ($BarCol) { "g" {"Green"} "y" {"Yellow"} "o" {"DarkYellow"} "r" {"Red"} default {"Green"} }
    if ($Fill -gt 0) { Write-Host ([string][char]0x2588 * $Fill) -NoNewline -ForegroundColor $barColor }
    if ($Empty -gt 0) { Write-Host ([string][char]0x2591 * $Empty) -NoNewline -ForegroundColor DarkGray }
}

function Draw-ModelLine {
    param([string]$Name, [int]$Fill, [int]$Empty, [string]$Pct, [string]$Reset, [string]$BarCol)
    $paddedName = $Name.PadRight(26)
    $paddedPct = $Pct.PadLeft(9)
    $pctColor = if ($Pct -eq "Exhausted") { "Red" } else { "White" }

    # Calculate visible length for padding
    $visLen = 4 + 26 + 1 + ($Fill + $Empty) + 2 + 9
    if ($Reset) { $visLen += 3 + $Reset.Length }
    $padLen = $BOX_W - 4 - $visLen
    if ($padLen -lt 0) { $padLen = 0 }

    Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
    Write-Host ("    " + $paddedName + " ") -NoNewline -ForegroundColor DarkGray
    Draw-QuotaBar -Fill $Fill -Empty $Empty -BarCol $BarCol
    Write-Host ("  " + $paddedPct) -NoNewline -ForegroundColor $pctColor
    if ($Reset) {
        Write-Host (" " + [char]0x2192 + " ") -NoNewline -ForegroundColor DarkGray
        Write-Host $Reset -NoNewline -ForegroundColor Yellow
    }
    Write-Host (" " * [math]::Max($padLen, 0) + " " + [char]0x2502) -ForegroundColor DarkGray
}

function Fetch-AllQuotas {
    param([string]$AccountsFile)

    $CLIENT_ID = "1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com"
    $CLIENT_SECRET = "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"
    $TOKEN_URL = "https://oauth2.googleapis.com/token"
    $QUOTA_URL = "https://daily-cloudcode-pa.googleapis.com/v1internal:fetchAvailableModels"
    $BAR_W = 10

    $SKIP_PREFIXES = @("tab_", "chat_")
    $GROUP_DEFS = @(
        @{ Name = "Gemini 3"; Prefix = "gemini-3"; Order = @("gemini-3-pro-high","gemini-3-pro-low","gemini-3-flash","gemini-3-pro-image") },
        @{ Name = "Gemini 2.5"; Prefix = "gemini-2.5"; Order = @("gemini-2.5-pro","gemini-2.5-flash","gemini-2.5-flash-thinking","gemini-2.5-flash-lite") },
        @{ Name = "Claude"; Prefix = "claude"; Order = @("claude-sonnet-4-5","claude-sonnet-4-5-thinking","claude-opus-4-5-thinking","claude-opus-4-6-thinking") }
    )

    try {
        $data = Get-Content $AccountsFile -Raw | ConvertFrom-Json
    } catch {
        return @("ERROR:Failed to parse accounts file", "END")
    }

    $accounts = $data.accounts
    $activeIdx = if ($null -ne $data.activeIndex) { $data.activeIndex } else { 0 }
    $results = @()

    for ($i = 0; $i -lt $accounts.Count; $i++) {
        $acct = $accounts[$i]
        $email = $acct.email
        $isActive = ($i -eq $activeIdx)
        $results += "ACCOUNT:${email}`t${isActive}"

        if ([string]::IsNullOrEmpty($acct.refreshToken)) {
            $results += "ERROR:No refresh token"
            continue
        }

        # Exchange token
        $tokenBody = "client_id=$CLIENT_ID&client_secret=$CLIENT_SECRET&refresh_token=$($acct.refreshToken)&grant_type=refresh_token"
        try {
            $tokenResp = Invoke-RestMethod -Uri $TOKEN_URL -Method POST -Body $tokenBody -ContentType "application/x-www-form-urlencoded" -TimeoutSec 10 -ErrorAction Stop
            $accessToken = $tokenResp.access_token
        } catch {
            $results += "ERROR:Authentication failed"
            continue
        }

        if ([string]::IsNullOrEmpty($accessToken)) {
            $results += "ERROR:Authentication failed"
            continue
        }

        # Fetch quotas
        $headers = @{
            "Authorization" = "Bearer $accessToken"
            "User-Agent" = "antigravity/1.11.5 windows/x86_64"
            "X-Goog-Api-Client" = "google-cloud-sdk vscode_cloudshelleditor/0.1"
            "Client-Metadata" = '{"ideType":"IDE_UNSPECIFIED","platform":"PLATFORM_UNSPECIFIED","pluginType":"GEMINI"}'
        }
        $quotaData = $null
        foreach ($ep in @($QUOTA_URL, $QUOTA_URL.Replace("daily-cloudcode-pa", "cloudcode-pa"))) {
            try {
                $quotaData = Invoke-RestMethod -Uri $ep -Method POST -Headers $headers -Body "{}" -ContentType "application/json" -TimeoutSec 15 -ErrorAction Stop
                break
            } catch { continue }
        }

        if ($null -eq $quotaData) {
            $results += "ERROR:Failed to fetch quotas"
            continue
        }

        # Categorize models
        $groups = @{}
        foreach ($gd in $GROUP_DEFS) { $groups[$gd.Name] = @() }
        $groups["Other"] = @()

        $modelNames = $quotaData.models.PSObject.Properties.Name
        foreach ($mname in $modelNames) {
            $skip = $false
            foreach ($sp in $SKIP_PREFIXES) {
                if ($mname.StartsWith($sp)) { $skip = $true; break }
            }
            if ($skip) { continue }

            $minfo = $quotaData.models.$mname
            $qi = $minfo.quotaInfo
            $rf = $qi.remainingFraction
            $rt = $qi.resetTime

            $placed = $false
            foreach ($gd in $GROUP_DEFS) {
                if ($mname.StartsWith($gd.Prefix)) {
                    $groups[$gd.Name] += @{ Name = $mname; RF = $rf; RT = $rt }
                    $placed = $true
                    break
                }
            }
            if (-not $placed) {
                $groups["Other"] += @{ Name = $mname; RF = $rf; RT = $rt }
            }
        }

        # Sort by predefined order
        foreach ($gd in $GROUP_DEFS) {
            $gn = $gd.Name
            $order = $gd.Order
            $groups[$gn] = $groups[$gn] | Sort-Object {
                $idx = [array]::IndexOf($order, $_.Name)
                if ($idx -lt 0) { 999 } else { $idx }
            }
        }

        # Output
        $groupOrder = @($GROUP_DEFS | ForEach-Object { $_.Name }) + @("Other")
        foreach ($gn in $groupOrder) {
            $entries = $groups[$gn]
            if ($entries.Count -eq 0) { continue }
            $results += "GROUP:$gn"
            foreach ($entry in $entries) {
                $rf = $entry.RF
                $rt = $entry.RT
                if ($null -eq $rf) {
                    $pct = "Exhausted"; $fv = 0.0
                } else {
                    $fv = [double]$rf
                    $pct = "{0:F1}%" -f ($fv * 100)
                }
                $fill = [math]::Max(0, [math]::Min($BAR_W, [math]::Round($fv * $BAR_W)))
                $empty = $BAR_W - $fill
                $color = if ($null -eq $rf) { "r" } elseif ($fv -lt 0.3) { "o" } elseif ($fv -lt 0.6) { "y" } else { "g" }

                $resetStr = ""
                if ($rt) {
                    try {
                        $rdt = [datetime]::Parse($rt).ToUniversalTime()
                        $secs = [int]($rdt - [datetime]::UtcNow).TotalSeconds
                        if ($secs -gt 0) {
                            $h = [math]::Floor($secs / 3600)
                            $m = [math]::Floor(($secs % 3600) / 60)
                            $localReset = $rdt.ToLocalTime().ToString("HH:mm")
                            $countdown = if ($h -gt 0) { "${h}h ${m}m" } else { "${m}m" }
                            $resetStr = "$countdown ($localReset)"
                        }
                    } catch {}
                }
                $results += "MODEL:$($entry.Name)`t$fill`t$empty`t$pct`t$resetStr`t$color"
            }
            $results += "GROUPEND"
        }
    }

    $results += "END"
    return $results
}

function Menu-Accounts {
    # Find accounts JSON — check all known Windows + cross-platform locations
    $acctJson = ""
    $_acctPaths = @(
        "$env:APPDATA\opencode\antigravity-accounts.json"
        "$env:APPDATA\antigravity-proxy\accounts.json"
        "$env:LOCALAPPDATA\opencode\antigravity-accounts.json"
        "$env:LOCALAPPDATA\antigravity-proxy\accounts.json"
        "$env:USERPROFILE\.config\opencode\antigravity-accounts.json"
        "$env:USERPROFILE\.config\antigravity-proxy\accounts.json"
    )
    foreach ($p in $_acctPaths) {
        if ($p -and (Test-Path $p)) { $acctJson = $p; break }
    }

    if ([string]::IsNullOrEmpty($acctJson)) {
        Show-Header
        Draw-BoxTop
        Draw-BoxTitle "Account Dashboard"
        Draw-BoxEmpty
        Draw-BoxLine "  No accounts found." -Color Yellow
        Draw-BoxEmpty
        Draw-BoxLine "  Expected config at one of:" -Color DarkGray
        Draw-BoxLine "    %APPDATA%\opencode\antigravity-accounts.json" -Color DarkGray
        Draw-BoxLine "    %APPDATA%\antigravity-proxy\accounts.json" -Color DarkGray
        Draw-BoxLine "    %USERPROFILE%\.config\opencode\antigravity-accounts.json" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot
        Wait-Key; return
    }

    while ($true) {
        Show-Header
        Draw-BoxTop
        Draw-BoxTitle "Account Dashboard"
        Draw-BoxEmpty
        Draw-BoxLine "  Fetching quotas..." -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        # Fetch all quotas
        $quotaLines = Fetch-AllQuotas -AccountsFile $acctJson

        # Redraw with results
        Show-Header
        Draw-BoxTop
        Draw-BoxTitle "Account Dashboard"
        Draw-BoxEmpty

        $acctIdx = 0
        foreach ($line in $quotaLines) {
            if ($line.StartsWith("ACCOUNT:")) {
                if ($acctIdx -gt 0) { Draw-BoxSep; Draw-BoxEmpty }
                $parts = $line.Substring(8).Split("`t")
                $acctEmail = $parts[0]
                $acctActive = $parts[1] -eq "True"
                $marker = if ($acctActive) { [char]0x25CF } else { [char]0x25CB }  # ● or ○
                $markerColor = if ($acctActive) { "Green" } else { "DarkGray" }
                $activeStr = if ($acctActive) { " (active)" } else { "" }

                # Custom colored line for account
                $visText = "  $marker  ${acctEmail}${activeStr}"
                $padLen = $BOX_W - 4 - $visText.Length
                if ($padLen -lt 0) { $padLen = 0 }
                Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
                Write-Host "  $marker  " -NoNewline -ForegroundColor $markerColor
                Write-Host $acctEmail -NoNewline -ForegroundColor White
                if ($acctActive) {
                    Write-Host " (active)" -NoNewline -ForegroundColor DarkGray
                }
                Write-Host (" " * $padLen + " " + [char]0x2502) -ForegroundColor DarkGray
                Draw-BoxEmpty
                $acctIdx++
            }
            elseif ($line.StartsWith("GROUP:")) {
                $gn = $line.Substring(6)
                $gc = switch -Wildcard ($gn) {
                    "Claude*" { "Cyan" }
                    "Gemini*" { "Magenta" }
                    "Other*" { "DarkYellow" }
                    default { "White" }
                }
                # Bold group header
                $visLen = 4 + $gn.Length
                $padLen = $BOX_W - 4 - $visLen
                if ($padLen -lt 0) { $padLen = 0 }
                Write-Host ("  " + [char]0x2502 + " ") -NoNewline -ForegroundColor DarkGray
                Write-Host ("    " + $gn) -NoNewline -ForegroundColor $gc
                Write-Host (" " * $padLen + " " + [char]0x2502) -ForegroundColor DarkGray
            }
            elseif ($line.StartsWith("MODEL:")) {
                $parts = $line.Substring(6).Split("`t")
                $mname = $parts[0]; $fill = [int]$parts[1]; $empty = [int]$parts[2]
                $pctStr = $parts[3]; $resetStr = $parts[4]; $colorCode = $parts[5]
                Draw-ModelLine -Name $mname -Fill $fill -Empty $empty -Pct $pctStr -Reset $resetStr -BarCol $colorCode
            }
            elseif ($line -eq "GROUPEND") {
                Draw-BoxEmpty
            }
            elseif ($line.StartsWith("ERROR:")) {
                Draw-BoxLine "    $($line.Substring(6))" -Color Red
            }
            elseif ($line -eq "END") {
                break
            }
        }

        Draw-BoxSep
        Draw-BoxEmpty
        Draw-BoxLine "  [r]  Refresh"
        Draw-BoxLine "  [b]  Back" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        Write-Host ""
        $ch = Read-Choice

        switch -Regex ($ch) {
            "^[rR]$" { continue }
            "^[bB]$" { return }
            default { continue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  7. Browser Backup
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Backup {
    Show-Header

    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
    }

    $browsers = [ordered]@{}
    $paths = [ordered]@{
        "chrome"      = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        "edge"        = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        "brave"       = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        "firefox"     = "$env:APPDATA\Mozilla\Firefox\Profiles"
        "opera"       = "$env:APPDATA\Opera Software\Opera Stable"
        "vivaldi"     = "$env:LOCALAPPDATA\Vivaldi\User Data"
        "antigravity" = $BROWSER_PROF_DIR
    }

    foreach ($name in $paths.Keys) {
        if (Test-Path $paths[$name]) {
            $browsers[$name] = $paths[$name]
        }
    }

    Draw-BoxTop
    Draw-BoxTitle "Browser Backup"
    Draw-BoxEmpty

    if ($browsers.Count -eq 0) {
        Draw-BoxLine "  No browsers detected." -Color Yellow
        Draw-BoxEmpty
        Draw-BoxBot
        Wait-Key; return
    }

    $keys = @($browsers.Keys)
    $idx = 1
    foreach ($name in $keys) {
        $info = Get-DirSizeInfo -Path $browsers[$name]
        $line = "  [$idx]  " + $name.PadRight(22) + " " + $info.Text
        Draw-BoxLine $line
        $idx++
    }

    Draw-BoxEmpty
    Draw-BoxLine "  [a]  Backup ALL detected browsers"
    Draw-BoxLine "  [b]  Back" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Write-Host ""
    $ch = Read-Choice

    if ([string]::IsNullOrWhiteSpace($ch)) { return }

    Write-Host ""

    function Backup-Browser {
        param([string]$Name, [string]$Path)
        $ts = Get-Date -Format "yyyyMMdd_HHmmss"
        $dest = "$BACKUP_DIR\${Name}_backup_${ts}.zip"
        Write-Host "  ...  Backing up $Name" -NoNewline -ForegroundColor DarkGray
        try {
            $tempDir = "$env:TEMP\ag_backup_$ts"
            New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
            Get-ChildItem $Path -Force -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notin @("Cache","Code Cache","GPUCache","Service Worker") } |
                ForEach-Object { Copy-Item $_.FullName "$tempDir\$($_.Name)" -Recurse -Force -ErrorAction SilentlyContinue }
            Compress-Archive -Path "$tempDir\*" -DestinationPath $dest -CompressionLevel Optimal -Force
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "`r  OK   $Name -> $(Split-Path $dest -Leaf)   " -ForegroundColor Green
        } catch {
            Write-Host "`r  !!   $Name - Backup failed   " -ForegroundColor Red
        }
    }

    switch -Regex ($ch) {
        "^[aA]$" {
            foreach ($name in $keys) {
                Backup-Browser -Name $name -Path $browsers[$name]
            }
            Write-Host ""; Write-Host "  All backups saved to $BACKUP_DIR" -ForegroundColor Green
            Wait-Key
        }
        "^[bB]$" { return }
        "^\d+$" {
            $num = [int]$ch
            if ($num -ge 1 -and $num -le $keys.Count) {
                $tgt = $keys[$num - 1]
                Backup-Browser -Name $tgt -Path $browsers[$tgt]
                Write-Host ""; Write-Host "  Backup saved to $BACKUP_DIR" -ForegroundColor Green
            } else {
                Write-Host "  Invalid selection." -ForegroundColor Red
            }
            Wait-Key
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  8. Fix Everything (one-click)
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-FixAll {
    Show-Header

    Draw-BoxTop
    Draw-BoxTitle "Fix Everything"
    Draw-BoxEmpty
    Draw-BoxLine "  This will apply ALL fixes in one go:"
    Draw-BoxLine "    - Flush DNS" -Color DarkGray
    Draw-BoxLine "    - Clean all Antigravity caches" -Color DarkGray
    Draw-BoxLine "    - Clean browser cache/cookies/storage" -Color DarkGray
    Draw-BoxLine "    - Fix browser lock files" -Color DarkGray
    Draw-BoxLine "    - Clean shader caches" -Color DarkGray
    Draw-BoxLine "    - Test connectivity" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Write-Host ""
    $yn = Read-Choice "  Run? [y/N] "
    if ($yn -notmatch "^[Yy]$") {
        Write-Host "  Cancelled." -ForegroundColor Yellow
        Wait-Key; return
    }

    Write-Host ""
    Write-Host "  Step 1/6: Flushing DNS..." -ForegroundColor Cyan
    if (Flush-DnsCache) { Write-Host "  OK   DNS flushed" -ForegroundColor Green }
    else                { Write-Host "  !!   DNS flush skipped" -ForegroundColor Yellow }

    Write-Host "  Step 2/6: Cleaning Antigravity caches..." -ForegroundColor Cyan
    foreach ($d in @("brain","conversations","browser_recordings","context_state","code_tracker","implicit","annotations","knowledge","playground","scratch")) {
        Clean-Dir "$ANTIGRAVITY_DIR\$d" $d
    }

    Write-Host "  Step 3/6: Cleaning browser cache..." -ForegroundColor Cyan
    foreach ($d in @("Cache","Code Cache","GPUCache","DawnGraphiteCache","DawnWebGPUCache","Service Worker","blob_storage","Sessions")) {
        Clean-Dir "$BP_DEF\$d" $d
    }
    foreach ($d in @("ShaderCache","GrShaderCache","GraphiteDawnCache")) {
        Clean-Dir "$BROWSER_PROF_DIR\$d" $d
    }

    Write-Host "  Step 4/6: Cleaning cookies & storage..." -ForegroundColor Cyan
    foreach ($f in @("Cookies","Cookies-journal","Safe Browsing Cookies","Safe Browsing Cookies-journal")) {
        Clean-File "$BP_DEF\$f" $f
    }
    foreach ($d in @("Local Storage","Session Storage","WebStorage")) {
        Clean-Dir "$BP_DEF\$d" $d
    }

    Write-Host "  Step 5/6: Fixing lock files..." -ForegroundColor Cyan
    Clean-File "$BP_DEF\SingletonLock" "SingletonLock"
    Clean-File "$BP_DEF\LOCK" "LOCK"
    Clean-File "$BROWSER_PROF_DIR\BrowserMetrics-spare.pma" "BrowserMetrics"

    Write-Host "  Step 6/6: Testing connectivity..." -ForegroundColor Cyan
    Test-Endpoint "https://www.google.com" "NET  "
    Test-Endpoint "https://gemini.google.com" "GEM  "

    Write-Host ""
    Draw-BoxTop
    Draw-BoxEmpty
    Draw-BoxLine "  All fixes applied!" -Color Green
    Draw-BoxLine "  Restart Antigravity to apply changes." -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot
    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Quick mode
# ═══════════════════════════════════════════════════════════════════════════════
function Run-Quick {
    Write-Host ""
    Write-Host "  Antigravity Quick Clean" -ForegroundColor Cyan
    Write-Host ""
    if ($DryRun) {
        Write-Host "  DRY RUN - no files will be deleted." -ForegroundColor Yellow
        Write-Host ""
    }
    foreach ($d in @("brain","conversations","browser_recordings","context_state","code_tracker","implicit","annotations","knowledge","playground","scratch")) {
        Clean-Dir "$ANTIGRAVITY_DIR\$d" $d
    }
    if (-not $DryRun) {
        Write-Host ""
        Write-Host "  All cache cleaned." -ForegroundColor Green
    }
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Main Menu
# ═══════════════════════════════════════════════════════════════════════════════
function Main-Menu {
    while ($true) {
        Show-Header

        Draw-BoxTop
        Draw-BoxTitle "Main Menu"
        Draw-BoxEmpty
        Draw-BoxLine "  [1]  Cache Cleaner          Clean Antigravity caches"
        Draw-BoxLine "  [2]  Browser Toolkit        Fix AG's built-in browser"
        Draw-BoxLine "  [3]  Network Fixer          DNS, connectivity, 403"
        Draw-BoxLine "  [4]  Troubleshooter         Diagnose & auto-fix"
        Draw-BoxLine "  [5]  Usage & Rate Limits    Stats + reset timer"
        Draw-BoxLine "  [6]  Account Dashboard      Per-model quota status"
        Draw-BoxLine "  [7]  Browser Backup         Backup system browsers"
        Draw-BoxEmpty
        Draw-BoxLine "  [8]  Fix Everything         One-click comprehensive fix" -Color Green
        Draw-BoxEmpty
        Draw-BoxLine "  [0]  Exit" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        Write-Host ""
        $choice = Read-Choice

        # Empty input = redraw
        if ([string]::IsNullOrWhiteSpace($choice)) { continue }

        switch ($choice) {
            "1" { Menu-Cleaner }
            "2" { Menu-Browser }
            "3" { Menu-Network }
            "4" { Menu-Troubleshoot }
            "5" { Menu-Usage }
            "6" { Menu-Accounts }
            "7" { Menu-Backup }
            "8" { Menu-FixAll }
            { $_ -in "0","q","Q" } {
                Write-Host ""
                Write-Host "  Goodbye!" -ForegroundColor Cyan
                Write-Host ""
                exit 0
            }
            default { continue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Entry
# ═══════════════════════════════════════════════════════════════════════════════
if ($Quick) {
    Run-Quick
} else {
    Main-Menu
}
