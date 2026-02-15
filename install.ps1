# ─── Antigravity Toolkit — One-liner Installer (Windows) ─────────────────────
# Usage: iwr -useb https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.ps1 | iex

$Repo   = "EhsanulHaqueSiam/Antigravity-Cleaner"
$Script = "scripts/antigravity-cleaner.ps1"
$URL    = "https://raw.githubusercontent.com/$Repo/main/$Script"
$Dest   = "$env:TEMP\antigravity-cleaner.ps1"

Write-Host "  Downloading Antigravity Toolkit..." -ForegroundColor Cyan
try {
    Invoke-WebRequest -Uri $URL -OutFile $Dest -UseBasicParsing -ErrorAction Stop
} catch {
    Write-Host "  Download failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host "  Launching..." -ForegroundColor Green
& $Dest
