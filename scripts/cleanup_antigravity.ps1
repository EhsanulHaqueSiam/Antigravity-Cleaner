
<#
.SYNOPSIS
    Antigravity Cache Cleanup Utility - Beautiful TUI Edition
.DESCRIPTION
    Cleans Antigravity IDE cache, fixes 403 errors, and optimizes network.
#>

$ErrorActionPreference = "SilentlyContinue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# =============================================================================
# 🎨 Colors & styles
# =============================================================================
$Cyan = "Cyan"
$Green = "Green" 
$Red = "Red"
$Yellow = "Yellow"
$Magenta = "Magenta"
$White = "White"
$Gray = "Gray"
$DarkGray = "DarkGray"

# Paths
$HOME_DIR = $env:USERPROFILE
$GEMINI_DIR = "$HOME_DIR\.gemini"
$ANTIGRAVITY_DIR = "$GEMINI_DIR\antigravity"
$BROWSER_PROFILE_DIR = "$GEMINI_DIR\antigravity-browser-profile"
$BACKUP_DIR = "$GEMINI_DIR\backups"

# =============================================================================
# 🛠️ Helper Functions
# =============================================================================

function Show-Header {
    Clear-Host
    Write-Host ""
    Write-Host "     █████╗ ███╗   ██╗████████╗██╗ ██████╗ ██████╗  █████╗ ██╗   ██╗██╗████████╗██╗   ██╗" -ForegroundColor $Magenta
    Write-Host "    ██╔══██╗████╗  ██║╚══██╔══╝██║██╔════╝ ██╔══██╗██╔══██╗██║   ██║██║╚══██╔══╝╚██╗ ██╔╝" -ForegroundColor $Magenta
    Write-Host "    ███████║██╔██╗ ██║   ██║   ██║██║  ███╗██████╔╝███████║██║   ██║██║   ██║    ╚████╔╝" -ForegroundColor $Magenta
    Write-Host "    ██╔══██║██║╚██╗██║   ██║   ██║██║   ██║██╔══██╗██╔══██║╚██╗ ██╔╝██║   ██║     ╚██╔╝ " -ForegroundColor $Cyan
    Write-Host "    ██║  ██║██║ ╚████║   ██║   ██║╚██████╔╝██║  ██║██║  ██║ ╚████╔╝ ██║   ██║      ██║  " -ForegroundColor $Cyan
    Write-Host "    ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝  ╚═══╝  ╚═╝   ╚═╝      ╚═╝  " -ForegroundColor $Cyan
    Write-Host ""
    Write-Host "                          🚀 Cache Cleanup Utility v2.0 (Windows)" -ForegroundColor $White
    Write-Host ""
    Write-Host ("═" * 80) -ForegroundColor $DarkGray
    Write-Host ""
}

function Get-DirSize {
    param($Path)
    if (Test-Path $Path) {
        $size = (Get-ChildItem $Path -Recurse -File -Force | Measure-Object -Property Length -Sum).Sum
        if ($null -eq $size) { return "0 B" }
        
        if ($size -gt 1GB) { return "{0:N2} GB" -f ($size / 1GB) }
        if ($size -gt 1MB) { return "{0:N2} MB" -f ($size / 1MB) }
        if ($size -gt 1KB) { return "{0:N2} KB" -f ($size / 1KB) }
        return "$size B"
    }
    return "Not Found"
}

function Clean-Dir {
    param($Path, $Name)
    Write-Host "  🧹 Cleaning $Name..." -NoNewline -ForegroundColor $Cyan
    
    if (Test-Path $Path) {
        try {
            Remove-Item "$Path\*" -Recurse -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 300
            Write-Host " Done!" -ForegroundColor $Green
        } catch {
            Write-Host " Failed (Access Denied)" -ForegroundColor $Red
        }
    } else {
        Write-Host " Empty (Skipped)" -ForegroundColor $Gray
    }
}

function Run-NetworkFix {
    Write-Host ""
    Write-Host "  🌐 Running Network Optimization..." -ForegroundColor $Cyan
    
    # DNS Flush
    Write-Host "  Running ipconfig /flushdns..." -NoNewline -ForegroundColor $Gray
    Start-Process -FilePath "ipconfig" -ArgumentList "/flushdns" -NoNewWindow -Wait
    Write-Host " Done." -ForegroundColor $Green
    
    # Reset Winsock (Requires Admin usually, checking if possible)
    Write-Host "  Resetting network adapter..." -NoNewline -ForegroundColor $Gray
    try {
        # Simple ping check instead of heavy reset to avoid breaking connection if not admin
        $ping = Test-NetConnection -ComputerName "google.com" -InformationLevel Quiet
        if ($ping) {
             Write-Host " Internet Connected." -ForegroundColor $Green
        } else {
             Write-Host " Internet Unreachable." -ForegroundColor $Red
        }
    } catch {
        Write-Host " Skipped." -ForegroundColor $Gray
    }
}

function Backup-Browsers {
    Write-Host ""
    Write-Host "  💾 session Safeguard (Backing up browsers)..." -ForegroundColor $Cyan

    if (-not (Test-Path $BACKUP_DIR)) {
        New-Item -ItemType Directory -Force -Path $BACKUP_DIR | Out-Null
    }

    $browsers = @{
        "Chrome" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
        "Edge" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
        "Brave" = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default"
    }

    foreach ($name in $browsers.Keys) {
        $path = $browsers[$name]
        if (Test-Path $path) {
             Write-Host "  • Found $name, backing up..." -NoNewline -ForegroundColor $Gray
             $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
             $dest = "$BACKUP_DIR\${name}_Backup_$timestamp.zip"
             
             try {
                Compress-Archive -Path "$path\*" -DestinationPath $dest -CompressionLevel Optimal -ErrorAction Stop
                Write-Host " Done." -ForegroundColor $Green
             } catch {
                Write-Host " Failed (File/Lock Error)." -ForegroundColor $Red
             }
        }
    }
    Write-Host ""
    Write-Host "  Backup process finished." -ForegroundColor $Green
}


# =============================================================================
# 🚀 Main Logic
# =============================================================================

Show-Header

Write-Host "  📂 Cache Status:" -ForegroundColor $White
Write-Host ""

$dirs = @{
    "Brain (Artifacts)" = "$ANTIGRAVITY_DIR\brain"
    "Browser Recordings" = "$ANTIGRAVITY_DIR\browser_recordings"
    "Conversations" = "$ANTIGRAVITY_DIR\conversations"
    "Context State" = "$ANTIGRAVITY_DIR\context_state"
    "Browser Profile" = "$BROWSER_PROFILE_DIR"
}

foreach ($key in $dirs.Keys) {
    $size = Get-DirSize -Path $dirs[$key]
    Write-Host "  • " -NoNewline -ForegroundColor $Cyan
    Write-Host "$key".PadRight(30) -NoNewline -ForegroundColor $Gray
    Write-Host " : " -NoNewline -ForegroundColor $DarkGray
    Write-Host $size -ForegroundColor $Green
}

Write-Host ""
Write-Host "  [1] Clean All Cache (Recommended)" -ForegroundColor $White
Write-Host "  [2] Network Fix (Flush DNS, Check Connection)" -ForegroundColor $White
Write-Host "  [3] Session Safeguard (Backup Browsers)" -ForegroundColor $White
Write-Host "  [0] Exit" -ForegroundColor $Gray
Write-Host ""

while ($true) {
    Show-Header
    
    # ... (Redraw status could go here but let's keep it simple for TUI loop)
    # Re-display prompts if looping fully, but for simple script loop:
    
    Write-Host "  [1] Clean All Cache" 
    Write-Host "  [2] Network Fix"
    Write-Host "  [3] Backup Browsers" 
    Write-Host "  [0] Exit"
    Write-Host ""
    
    $input = Read-Host "  Enter choice"

    switch ($input) {
        "1" {
            Write-Host ""
            foreach ($key in $dirs.Keys) {
                Clean-Dir -Path $dirs[$key] -Name $key
            }
            Write-Host ""
            Write-Host "  ✨ Cleanup Complete!" -ForegroundColor $Green
            Read-Host "  Press Enter to continue..."
        }
        "2" {
            Run-NetworkFix
            Read-Host "  Press Enter to continue..."
        }
        "3" {
            Backup-Browsers
            Read-Host "  Press Enter to continue..."
        }
        "0" {
            exit
        }
    }
}
