
# Antigravity Cleaner Installer for Windows
# Usage: iwr -useb ... | iex

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "🚀 Antigravity Cleaner Installer" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor DarkGray
Write-Host ""

# Repo Info
$Repo = "EhsanulHaqueSiam/antigravity-cleaner"
$LatestReleaseUrl = "https://api.github.com/repos/$Repo/releases/latest"

$DownloadUrl = "https://raw.githubusercontent.com/$Repo/main/scripts/cleanup_antigravity.ps1"
$DestPath = "$env:TEMP\cleanup_antigravity.ps1"

Write-Host "  • Downloading script..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestPath -ErrorAction Stop
    Write-Host "  ✔ Download complete." -ForegroundColor Green
} catch {
    Write-Host "  ❌ Download failed: $_" -ForegroundColor Red
    exit
}

Write-Host "  • Launching TUI..." -ForegroundColor Green
& $DestPath

Write-Host ""
Write-Host "✔ Setup initiated!" -ForegroundColor Green
Write-Host ""
