# Antigravity Cleaner 🚀

> **The Ultimate System Maintenance Tool for Power Users.**  
> *Clean Cache. Safe Backups. Network Optimization.*

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

Antigravity Cleaner is a robust utility designed to keep your development environment and browser sessions healthy. It offers deep cleaning for AI artifacts, fixes common network connectivity issues (403/Region Lock), and safeguards your browser profiles with one-click backups.

## ✨ Features

- **🧹 Precision Cleaning**:
    - Selectively clean specific caches (Brain, Conversation, Context).
    - "Deep Clean" mode for total reset.
- **💾 Session Safeguard**:
    - Automatically detects and backs up profiles for **Chrome, Edge, Brave, Opera, Vivaldi**.
    - Creates timestamped `.zip` or `.tar.gz` archives.
- **🔧 Network Optimizer**:
    - One-click **DNS Flush**.
    - Connectivity diagnostics for **Google Services & Gemini AI**.
    - Fixes common "Region Lock" or "403 Forbidden" errors.
- **💻 Cross-Platform TUI**:
    - Beautiful, colorful Terminal User Interface for **Windows, Linux, and macOS**.
    - No GUI required—runs instantly in your terminal.
    - **New CLI Flags**:
        - `--quick` / `-q`: Non-interactive mode (cleans all safely).
        - `--dry-run` / `-d`: Preview what will be deleted.
        - `--help`: Show usage information.

---

## 🚀 Quick Start (No Install Required)

The easiest way to use Antigravity Cleaner is via our one-line terminal command. This works without installing anything!

### 🐧 Linux & 🍎 macOS
Copy and paste this into your terminal:

```bash
curl -sSL https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.sh | bash
```

### 🪟 Windows (PowerShell)
Copy and paste this into PowerShell:

```powershell
iwr -useb https://raw.githubusercontent.com/EhsanulHaqueSiam/Antigravity-Cleaner/main/install.ps1 | iex
```

---

## 🛠️ Manual Installation (For Developers)

If you prefer to build the Electron GUI version or run from source:

1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/EhsanulHaqueSiam/Antigravity-Cleaner.git
    cd antigravity-cleaner
    ```

2.  **Install Dependencies**:
    ```bash
    npm install
    ```

3.  **Run Development Mode**:
    ```bash
    npm run dev
    ```

4.  **Build Binary**:
    - **Linux**: `npm run build:linux` (Output: `dist/*.AppImage`)
    - **Windows**: `npm run build:win` (Output: `dist/*.exe`)
    - **macOS**: `npm run build:mac` (Output: `dist/*.dmg`)

---

## 📂 Project Structure

- **`scripts/`**: Contains the core logic scripts.
    - `cleanup_antigravity_cache.sh`: The Bash TUI engine (Linux/macOS).
    - `cleanup_antigravity.ps1`: The PowerShell TUI engine (Windows).
- **`src/`**: React frontend code for the Electron GUI.
- **`electron/`**: Main process code for the Electron App.
- **`install.sh` / `install.ps1`**: Lightweight wrappers for one-line execution.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

---
*Built with ❤️ by Ehsanul Haque Siam.*
