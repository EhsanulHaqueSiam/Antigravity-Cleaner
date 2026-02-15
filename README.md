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
| 6 | **Account Dashboard** | Multi-account management with Gmail labels, per-model (Gemini/Claude) live API status, session counts, exact rate limit countdown, and profile switching |
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

Profiles are stored in `~/.antigravity-profiles/`. Each profile has a `.antigravity-label` file for the Gmail address.

**Switching profiles:**
1. Current `~/.gemini/` is moved to `~/.antigravity-profiles/<current>/`
2. Target profile is moved from `~/.antigravity-profiles/<target>/` to `~/.gemini/`
3. Active profile name is tracked in `~/.antigravity-profiles/.active`
4. Gmail label travels with the profile during switches

**Model status checks:**
- **Gemini**: Checks `gemini.google.com` for 429 (rate limited) / 200 (available) / 403 (forbidden)
- **Claude**: Checks `alkalimetal-pa.clients6.google.com` for API availability
- Results are cached for 30 seconds; press `[r]` to force refresh

Close Antigravity before switching profiles.

## License

MIT
