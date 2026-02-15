# Antigravity Toolkit

> **TUI-only system toolkit for the Antigravity IDE.**
> Cache cleaner, browser toolkit, troubleshooter, network fixer, account dashboard with per-model status, usage monitor, browser backup, and one-click Fix Everything.

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

| # | Feature | Description |
|---|---|---|
| 1 | **Cache Cleaner** | Selective or bulk cleanup of brain, conversations, recordings, context, code tracker, implicit memory, annotations, knowledge, playground, scratch |
| 2 | **Browser Toolkit** | 10 options for Antigravity's built-in Chromium browser — clean cache, cookies, storage, history, service workers, shader caches, lock files, or full reset |
| 3 | **Network Fixer** | DNS flush (distro-aware), Google/Gemini/API connectivity checks, 403 fix guide |
| 4 | **Troubleshooter** | 9-point diagnostic scan with auto-fix — checks dirs, internet, DNS, API access, lock files, disk space, cache size, rate limits |
| 5 | **Usage & Rate Limits** | Session counts, file counts, activity breakdown, monthly cycle progress bar, days until reset, session rate projections |
| 6 | **Account Dashboard** | Auto-detects accounts from config files, per-model quota with progress bars (Gemini 3/2.5, Claude), live API-based quota checking with reset countdown |
| 7 | **Browser Backup** | Auto-detects Chrome, Edge, Brave, Firefox, Opera, Vivaldi, Arc — creates timestamped archives |
| 8 | **Fix Everything** | One-click comprehensive fix: DNS flush + cache clean + browser clean + lock fix + connectivity test |

### Aggressive / Nuclear Clean

The Cache Cleaner includes a **Nuclear Clean** option (type `NUKE` to confirm) that removes all Antigravity data including browser profile, config, and installation ID — a full factory reset.

### Supported Platforms

- **Linux**: Arch, Manjaro, EndeavourOS, Garuda, Ubuntu, Debian, Pop!_OS, Linux Mint, Fedora, RHEL, CentOS, Rocky, openSUSE, and other distros
- **macOS**: All versions
- **Windows**: Windows 10/11 (PowerShell 5.1+)

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

## How Account Dashboard Works

Accounts are auto-detected from config files:
- `~/.config/opencode/antigravity-accounts.json` (primary)
- `~/.config/antigravity-proxy/accounts.json` (fallback)

**Per-model quota display:**
- Shows remaining quota as progress bars for every model (Gemini 3, Gemini 2.5, Claude)
- Percentage remaining (e.g., "100.0%", "45.3%", or "Exhausted")
- Reset countdown for rate-limited models (e.g., "→ 5h 30m")
- Active account is marked with `●`, others with `○`

**How it works:**
1. Reads accounts and refresh tokens from the config JSON
2. Exchanges each refresh token for an access token via Google OAuth
3. Calls the `fetchAvailableModels` API to get per-model quota data
4. Displays grouped results with color-coded progress bars

**Requirements:** `python3` (Linux/macOS) for the bash version; PowerShell 5.1+ for Windows.
Press `[r]` to refresh quotas.

## License

MIT
