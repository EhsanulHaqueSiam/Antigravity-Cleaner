# Antigravity Toolkit

> **TUI-only system toolkit for the Antigravity IDE.**
> Cache cleaner, usage monitor, reset timer, account switcher, network fixer, browser backup.

![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

## Quick Start (No Install Required)

### Linux / macOS

```bash
curl -sL https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.sh | bash
```

### Windows (PowerShell)

```powershell
iwr -useb https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.ps1 | iex
```

## Features

| Feature | Description |
|---|---|
| **Cache Cleaner** | Selective or bulk cleanup of brain artifacts, conversations, recordings, context state, browser profile |
| **Usage Dashboard** | Session counts, file counts, size breakdown with visual bars |
| **Reset Timer** | Monthly cycle progress bar, days remaining, session rate projections |
| **Account Switcher** | Save, switch, and delete Antigravity profiles (swaps `~/.gemini`) |
| **Network Fixer** | DNS flush, Google/Gemini/API connectivity checks, 403 fix guide |
| **Browser Backup** | Auto-detects Chrome, Edge, Brave, Firefox, Opera, Vivaldi, Arc — creates timestamped archives |

## CLI Flags

```
# Bash (Linux/macOS)
./antigravity-cleaner.sh -q          # Quick clean (non-interactive)
./antigravity-cleaner.sh -d -q       # Dry run (preview only)
./antigravity-cleaner.sh -h          # Help

# PowerShell (Windows)
.\antigravity-cleaner.ps1 -Quick     # Quick clean
.\antigravity-cleaner.ps1 -DryRun -Quick  # Dry run
.\antigravity-cleaner.ps1 -Help      # Help
```

## Project Structure

```
scripts/
  antigravity-cleaner.sh      Bash TUI (Linux/macOS)
  antigravity-cleaner.ps1     PowerShell TUI (Windows)
install.sh                    One-liner installer (curl | bash)
install.ps1                   One-liner installer (iwr | iex)
```

## How Account Switching Works

Profiles are stored in `~/.antigravity-profiles/`. When you switch:

1. Current `~/.gemini/` is moved to `~/.antigravity-profiles/<current>/`
2. Target profile is moved from `~/.antigravity-profiles/<target>/` to `~/.gemini/`
3. Active profile name is tracked in `~/.antigravity-profiles/.active`

Close Antigravity before switching profiles.

## License

MIT
