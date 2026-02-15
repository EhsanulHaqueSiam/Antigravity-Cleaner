<#
.SYNOPSIS
    Antigravity Toolkit v3.0 - TUI Edition (Windows)
.DESCRIPTION
    Cache cleaner, usage monitor, account switcher, network fixer
    and browser backup for the Antigravity IDE.
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
$Host.UI.RawUI.WindowTitle = "Antigravity Toolkit v3.0"

# ═══════════════════════════════════════════════════════════════════════════════
#  Configuration
# ═══════════════════════════════════════════════════════════════════════════════
$VERSION          = "3.0"
$GEMINI_DIR       = "$env:USERPROFILE\.gemini"
$ANTIGRAVITY_DIR  = "$GEMINI_DIR\antigravity"
$BROWSER_PROF_DIR = "$GEMINI_DIR\antigravity-browser-profile"
$BACKUP_DIR       = "$GEMINI_DIR\backups"
$PROFILES_DIR     = "$env:USERPROFILE\.antigravity-profiles"
$ACTIVE_FILE      = "$PROFILES_DIR\.active"
$BOX_W            = 62

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
  Full TUI with cleaner, usage dashboard, reset timer,
  account switcher, network fixer, and browser backup.

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
    Write-Host "  Antigravity cache directory not found at $GEMINI_DIR" -ForegroundColor Red
    Write-Host "  Is Antigravity installed?" -ForegroundColor DarkGray
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

function Wait-Key {
    Write-Host ""
    Write-Host "  Press Enter to continue... " -ForegroundColor DarkGray -NoNewline
    Read-Host | Out-Null
}

function Read-Choice {
    param([string]$Prompt = "  > ")
    Write-Host $Prompt -NoNewline -ForegroundColor Cyan
    $input = Read-Host
    return $input.Trim()
}

function Get-ActiveProfile {
    if (Test-Path $ACTIVE_FILE) {
        return (Get-Content $ACTIVE_FILE -Raw -ErrorAction SilentlyContinue).Trim()
    }
    return "default"
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
    Draw-BoxLine "  v$VERSION  -  Cache Cleaner & System Toolkit" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Cache Status
# ═══════════════════════════════════════════════════════════════════════════════
function Show-CacheStatus {
    $dirs = [ordered]@{
        "Brain (artifacts)"  = "$ANTIGRAVITY_DIR\brain"
        "Browser Recordings" = "$ANTIGRAVITY_DIR\browser_recordings"
        "Conversations"      = "$ANTIGRAVITY_DIR\conversations"
        "Context State"      = "$ANTIGRAVITY_DIR\context_state"
        "Code Tracker"       = "$ANTIGRAVITY_DIR\code_tracker"
        "Implicit Memory"    = "$ANTIGRAVITY_DIR\implicit"
        "Browser Profile"    = $BROWSER_PROF_DIR
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
    $totalText = if     ($totalBytes -gt 1GB) { "{0:N1} GB" -f ($totalBytes / 1GB) }
                 elseif ($totalBytes -gt 1MB) { "{0:N1} MB" -f ($totalBytes / 1MB) }
                 elseif ($totalBytes -gt 1KB) { "{0:N1} KB" -f ($totalBytes / 1KB) }
                 else                         { "$totalBytes B" }
    $padded = "TOTAL".PadRight(30) + $totalText.PadLeft(12)
    Draw-BoxLine "  $padded" -Color White
    Draw-BoxBot
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Cache Cleaner
# ═══════════════════════════════════════════════════════════════════════════════
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
        Draw-BoxLine "  [5]  Code Tracker"
        Draw-BoxLine "  [6]  Implicit Memory"
        Draw-BoxLine "  [7]  Browser Profile"
        Draw-BoxEmpty
        Draw-BoxLine "  [8]  Clean ALL cache (recommended)" -Color Green
        Draw-BoxLine "  [9]  Deep clean (everything)" -Color Red
        Draw-BoxEmpty
        Draw-BoxLine "  [b]  Back to main menu" -Color DarkGray
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
            "5" { Clean-Dir "$ANTIGRAVITY_DIR\code_tracker" "Code Tracker"; Wait-Key }
            "6" { Clean-Dir "$ANTIGRAVITY_DIR\implicit" "Implicit Memory"; Wait-Key }
            "7" { Clean-Dir $BROWSER_PROF_DIR "Browser Profile"; Wait-Key }
            "8" {
                Clean-Dir "$ANTIGRAVITY_DIR\brain" "Brain Artifacts"
                Clean-Dir "$ANTIGRAVITY_DIR\browser_recordings" "Browser Recordings"
                Clean-Dir "$ANTIGRAVITY_DIR\conversations" "Conversations"
                Clean-Dir "$ANTIGRAVITY_DIR\context_state" "Context State"
                Clean-Dir "$ANTIGRAVITY_DIR\code_tracker" "Code Tracker"
                Clean-Dir "$ANTIGRAVITY_DIR\implicit" "Implicit Memory"
                Write-Host ""; Write-Host "  All cache cleaned." -ForegroundColor Green
                Wait-Key
            }
            "9" {
                Write-Host "  WARNING: Deep clean removes ALL data including browser profile." -ForegroundColor Yellow
                $yn = Read-Choice "  Continue? [y/N] "
                if ($yn -match "^[Yy]$") {
                    Write-Host ""
                    Clean-Dir "$ANTIGRAVITY_DIR\brain" "Brain Artifacts"
                    Clean-Dir "$ANTIGRAVITY_DIR\browser_recordings" "Browser Recordings"
                    Clean-Dir "$ANTIGRAVITY_DIR\conversations" "Conversations"
                    Clean-Dir "$ANTIGRAVITY_DIR\context_state" "Context State"
                    Clean-Dir "$ANTIGRAVITY_DIR\code_tracker" "Code Tracker"
                    Clean-Dir "$ANTIGRAVITY_DIR\implicit" "Implicit Memory"
                    Clean-Dir $BROWSER_PROF_DIR "Browser Profile"
                    Write-Host ""; Write-Host "  Deep clean complete." -ForegroundColor Green
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
#  Feature: Usage Dashboard
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Usage {
    Show-Header

    $convN  = Get-ItemCount "$ANTIGRAVITY_DIR\conversations" -Dirs
    $brainN = Get-ItemCount "$ANTIGRAVITY_DIR\brain"
    $recN   = Get-ItemCount "$ANTIGRAVITY_DIR\browser_recordings" -Dirs
    $ctxN   = Get-ItemCount "$ANTIGRAVITY_DIR\context_state"
    $codeN  = Get-ItemCount "$ANTIGRAVITY_DIR\code_tracker"

    $convI  = Get-DirSizeInfo "$ANTIGRAVITY_DIR\conversations"
    $brainI = Get-DirSizeInfo "$ANTIGRAVITY_DIR\brain"
    $recI   = Get-DirSizeInfo "$ANTIGRAVITY_DIR\browser_recordings"
    $ctxI   = Get-DirSizeInfo "$ANTIGRAVITY_DIR\context_state"
    $profI  = Get-DirSizeInfo $BROWSER_PROF_DIR
    $totalB = $convI.Bytes + $brainI.Bytes + $recI.Bytes + $ctxI.Bytes + $profI.Bytes

    Draw-BoxTop
    Draw-BoxTitle "Usage Dashboard"
    Draw-BoxEmpty
    Draw-BoxLine "  Conversations            $convN sessions"
    Draw-BoxLine "  Brain Artifacts          $brainN files"
    Draw-BoxLine "  Browser Recordings       $recN sessions"
    Draw-BoxLine "  Context Snapshots        $ctxN files"
    Draw-BoxLine "  Code Tracker             $codeN files"
    Draw-BoxSep
    $totalText = if     ($totalB -gt 1GB) { "{0:N1} GB" -f ($totalB / 1GB) }
                 elseif ($totalB -gt 1MB) { "{0:N1} MB" -f ($totalB / 1MB) }
                 elseif ($totalB -gt 1KB) { "{0:N1} KB" -f ($totalB / 1KB) }
                 else                     { "$totalB B" }
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

    # Size breakdown
    if ($totalB -gt 0) {
        Write-Host ""
        Draw-BoxTop
        Draw-BoxTitle "Size Breakdown"
        Draw-BoxEmpty

        $items = @(
            @{ Name = "Conversations"; Bytes = $convI.Bytes },
            @{ Name = "Brain"; Bytes = $brainI.Bytes },
            @{ Name = "Recordings"; Bytes = $recI.Bytes },
            @{ Name = "Context"; Bytes = $ctxI.Bytes },
            @{ Name = "Browser Profile"; Bytes = $profI.Bytes }
        )

        foreach ($item in $items) {
            $pct = [math]::Floor($item.Bytes * 100 / $totalB)
            $bw = [math]::Floor($item.Bytes * 28 / $totalB)
            $ew = 28 - $bw
            $fill = "=" * [math]::Max($bw, 0)
            $empty = "-" * [math]::Max($ew, 0)
            $line = "  " + $item.Name.PadRight(16) + " " + $fill + $empty + " " + "${pct}%"
            Draw-BoxLine $line
        }

        Draw-BoxEmpty
        Draw-BoxBot
    }

    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Reset Timer
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Reset {
    Show-Header

    $now = Get-Date
    $dim = [DateTime]::DaysInMonth($now.Year, $now.Month)
    $dayNum = $now.Day
    $remaining = $dim - $dayNum
    $monthName = $now.ToString("MMMM")
    $nextMonth = $now.AddMonths(1).ToString("MMMM yyyy")
    $pct = [math]::Floor($dayNum * 100 / $dim)

    # Progress bar
    $bw = [math]::Floor($dayNum * 32 / $dim)
    $ew = 32 - $bw
    $fill = "=" * [math]::Max($bw, 0)
    $empty = "-" * [math]::Max($ew, 0)
    $pbar = "[$fill$empty] ${pct}%"

    Draw-BoxTop
    Draw-BoxTitle "Usage Reset Timer"
    Draw-BoxEmpty
    Draw-BoxLine "  Current Cycle       $monthName $($now.Year)"
    Draw-BoxLine "  Reset Date          $nextMonth 1"
    Draw-BoxLine "  Days Remaining      $remaining days"
    Draw-BoxEmpty
    Draw-BoxLine "  $pbar" -Color Green
    Draw-BoxEmpty
    Draw-BoxBot

    # Stats
    $monthConvos = 0
    if (Test-Path "$ANTIGRAVITY_DIR\conversations") {
        Get-ChildItem "$ANTIGRAVITY_DIR\conversations" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $age = ($now - $_.LastWriteTime).TotalSeconds
            if ($age -lt 2592000) { $script:monthConvos++ }
        }
    }

    Write-Host ""
    Draw-BoxTop
    Draw-BoxTitle "Cycle Statistics"
    Draw-BoxEmpty
    Draw-BoxLine "  Sessions this cycle    $monthConvos" -Color Cyan

    if ($dayNum -gt 0) {
        $rate = [math]::Round($monthConvos / $dayNum, 1)
        $proj = [math]::Round($rate * $dim)
        Draw-BoxLine "  Avg per day            $rate" -Color Cyan
        Draw-BoxLine "  Projected this month   $proj" -Color Cyan
    }

    Draw-BoxEmpty
    Draw-BoxLine "  Usage typically resets on the 1st of each month." -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Account Switcher
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Accounts {
    while ($true) {
        Show-Header

        $active = Get-ActiveProfile

        if (-not (Test-Path $PROFILES_DIR)) {
            New-Item -ItemType Directory -Force -Path $PROFILES_DIR | Out-Null
        }

        Draw-BoxTop
        Draw-BoxTitle "Account Switcher"
        Draw-BoxEmpty
        Draw-BoxLine "  Active: $active" -Color Green
        Draw-BoxEmpty

        $profiles = @()
        $idx = 1
        Get-ChildItem $PROFILES_DIR -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $pname = $_.Name
            $profiles += $pname
            $pinfo = Get-DirSizeInfo -Path $_.FullName
            $mark = if ($pname -eq $active) { " *" } else { "" }
            $line = "  [$idx]  " + $pname.PadRight(20) + " " + $pinfo.Text + $mark
            Draw-BoxLine $line
            $idx++
        }

        if ($profiles.Count -eq 0) {
            Draw-BoxLine "  No saved profiles yet." -Color DarkGray
        }

        Draw-BoxEmpty
        Draw-BoxSep
        Draw-BoxEmpty
        Draw-BoxLine "  [s]  Save current as new profile"
        Draw-BoxLine "  [d]  Delete a profile" -Color Red
        Draw-BoxLine "  [b]  Back to main menu" -Color DarkGray
        Draw-BoxEmpty
        Draw-BoxBot

        Write-Host ""
        $ch = Read-Choice

        if ([string]::IsNullOrWhiteSpace($ch)) { continue }

        Write-Host ""
        switch -Regex ($ch) {
            "^[sS]$" {
                $pname = Read-Choice "  Profile name: "
                $pname = $pname -replace '[^a-zA-Z0-9_-]', ''
                if ([string]::IsNullOrEmpty($pname)) {
                    Write-Host "  Invalid name." -ForegroundColor Red
                    Wait-Key; continue
                }
                $profPath = "$PROFILES_DIR\$pname"
                if (Test-Path $profPath) {
                    $yn = Read-Choice "  Profile '$pname' exists. Overwrite? [y/N] "
                    if ($yn -notmatch "^[Yy]$") {
                        Write-Host "  Cancelled." -ForegroundColor Yellow
                        Wait-Key; continue
                    }
                    Remove-Item $profPath -Recurse -Force
                }
                Write-Host "  Saving current session as '$pname'..." -ForegroundColor Cyan
                New-Item -ItemType Directory -Force -Path $profPath | Out-Null
                if (Test-Path $GEMINI_DIR) {
                    Copy-Item "$GEMINI_DIR\*" $profPath -Recurse -Force -ErrorAction SilentlyContinue
                }
                Set-Content $ACTIVE_FILE $pname -NoNewline
                Write-Host "  Saved profile '$pname'." -ForegroundColor Green
                Wait-Key
            }
            "^[dD]$" {
                if ($profiles.Count -eq 0) {
                    Write-Host "  No profiles to delete." -ForegroundColor Yellow
                    Wait-Key; continue
                }
                $dn = Read-Choice "  Profile number to delete: "
                if ($dn -match "^\d+$" -and [int]$dn -ge 1 -and [int]$dn -le $profiles.Count) {
                    $tgt = $profiles[[int]$dn - 1]
                    if ($tgt -eq $active) {
                        Write-Host "  Cannot delete the active profile. Switch first." -ForegroundColor Red
                    } else {
                        Remove-Item "$PROFILES_DIR\$tgt" -Recurse -Force
                        Write-Host "  Deleted profile '$tgt'." -ForegroundColor Green
                    }
                } else {
                    Write-Host "  Invalid selection." -ForegroundColor Red
                }
                Wait-Key
            }
            "^[bB]$" { return }
            "^\d+$" {
                $num = [int]$ch
                if ($num -ge 1 -and $num -le $profiles.Count) {
                    $tgt = $profiles[$num - 1]
                    if ($tgt -eq $active) {
                        Write-Host "  Already on '$tgt'." -ForegroundColor Cyan
                        Wait-Key; continue
                    }

                    Write-Host "  Switching will close any running Antigravity session." -ForegroundColor Yellow
                    $yn = Read-Choice "  Switch to '$tgt'? [y/N] "
                    if ($yn -notmatch "^[Yy]$") {
                        Write-Host "  Cancelled." -ForegroundColor Yellow
                        Wait-Key; continue
                    }

                    Write-Host "  Saving current session as '$active'..." -ForegroundColor Cyan
                    if (Test-Path "$PROFILES_DIR\$active") {
                        Remove-Item "$PROFILES_DIR\$active" -Recurse -Force
                    }
                    Rename-Item $GEMINI_DIR "$PROFILES_DIR\$active"

                    Write-Host "  Restoring profile '$tgt'..." -ForegroundColor Cyan
                    Rename-Item "$PROFILES_DIR\$tgt" $GEMINI_DIR

                    Set-Content $ACTIVE_FILE $tgt -NoNewline
                    $script:ANTIGRAVITY_DIR = "$GEMINI_DIR\antigravity"
                    $script:BROWSER_PROF_DIR = "$GEMINI_DIR\antigravity-browser-profile"
                    $script:BACKUP_DIR = "$GEMINI_DIR\backups"
                    Write-Host "  Switched to '$tgt'." -ForegroundColor Green
                    Wait-Key
                } else {
                    Write-Host "  Invalid selection." -ForegroundColor Red
                    Wait-Key
                }
            }
            default { continue }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Network Fixer
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Network {
    Show-Header

    Draw-BoxTop
    Draw-BoxTitle "Network Fixer"
    Draw-BoxEmpty

    # DNS flush
    Write-Host "  │  DNS  Flushing cache... " -NoNewline -ForegroundColor DarkGray
    try {
        $null = Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait -PassThru 2>$null
        Write-Host "Done" -ForegroundColor Green
    } catch {
        Write-Host "Failed" -ForegroundColor Red
    }

    # Google
    Write-Host "  │  NET  google.com... " -NoNewline -ForegroundColor DarkGray
    try {
        $r = Test-NetConnection -ComputerName "google.com" -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($r) { Write-Host "OK" -ForegroundColor Green }
        else    { Write-Host "Unreachable" -ForegroundColor Red }
    } catch { Write-Host "Error" -ForegroundColor Red }

    # Gemini
    Write-Host "  │  NET  gemini.google.com... " -NoNewline -ForegroundColor DarkGray
    try {
        $r = Test-NetConnection -ComputerName "gemini.google.com" -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($r) { Write-Host "OK" -ForegroundColor Green }
        else    { Write-Host "Unreachable (check region/VPN)" -ForegroundColor Red }
    } catch { Write-Host "Error" -ForegroundColor Red }

    # Alkalimetal
    Write-Host "  │  API  alkalimetal endpoint... " -NoNewline -ForegroundColor DarkGray
    try {
        $r = Test-NetConnection -ComputerName "alkalimetal-pa.clients6.google.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($r) { Write-Host "Reachable" -ForegroundColor Green }
        else    { Write-Host "Blocked" -ForegroundColor Red }
    } catch { Write-Host "Error" -ForegroundColor Red }

    Draw-BoxEmpty
    Draw-BoxSep
    Draw-BoxLine "  Common 403 Fixes" -Color Yellow
    Draw-BoxEmpty
    Draw-BoxLine "  1. Restart Antigravity after DNS flush" -Color DarkGray
    Draw-BoxLine "  2. Clear browser profile (Cleaner > 7)" -Color DarkGray
    Draw-BoxLine "  3. Disable VPN / proxy if active" -Color DarkGray
    Draw-BoxLine "  4. Try switching Google account" -Color DarkGray
    Draw-BoxEmpty
    Draw-BoxBot

    Wait-Key
}

# ═══════════════════════════════════════════════════════════════════════════════
#  Feature: Browser Backup
# ═══════════════════════════════════════════════════════════════════════════════
function Menu-Backup {
    Show-Header

    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
    }

    $browsers = [ordered]@{}
    $paths = [ordered]@{
        "chrome"    = "$env:LOCALAPPDATA\Google\Chrome\User Data"
        "edge"      = "$env:LOCALAPPDATA\Microsoft\Edge\User Data"
        "brave"     = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"
        "firefox"   = "$env:APPDATA\Mozilla\Firefox\Profiles"
        "opera"     = "$env:APPDATA\Opera Software\Opera Stable"
        "vivaldi"   = "$env:LOCALAPPDATA\Vivaldi\User Data"
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
    Draw-BoxLine "  [b]  Back to main menu" -Color DarkGray
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
    Clean-Dir "$ANTIGRAVITY_DIR\brain" "Brain Artifacts"
    Clean-Dir "$ANTIGRAVITY_DIR\browser_recordings" "Browser Recordings"
    Clean-Dir "$ANTIGRAVITY_DIR\conversations" "Conversations"
    Clean-Dir "$ANTIGRAVITY_DIR\context_state" "Context State"
    Clean-Dir "$ANTIGRAVITY_DIR\code_tracker" "Code Tracker"
    Clean-Dir "$ANTIGRAVITY_DIR\implicit" "Implicit Memory"
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
        Draw-BoxLine "  [1]  Cache Cleaner          Clean cache"
        Draw-BoxLine "  [2]  Usage Dashboard         View statistics"
        Draw-BoxLine "  [3]  Reset Timer             Next usage reset"
        Draw-BoxLine "  [4]  Account Switcher        Manage profiles"
        Draw-BoxLine "  [5]  Network Fixer           Fix DNS & 403s"
        Draw-BoxLine "  [6]  Browser Backup          Backup browsers"
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
            "2" { Menu-Usage }
            "3" { Menu-Reset }
            "4" { Menu-Accounts }
            "5" { Menu-Network }
            "6" { Menu-Backup }
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
