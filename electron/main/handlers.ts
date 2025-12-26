import { ipcMain, shell } from 'electron'
import * as fs from 'fs/promises'
import * as path from 'path'
import * as os from 'os'
import { exec } from 'child_process'
import { promisify } from 'util'
import archiver from 'archiver'
import { createWriteStream } from 'fs'

const execAsync = promisify(exec)

// Paths
const HOME = os.homedir()
const GEMINI_DIR = path.join(HOME, '.gemini')
const ANTIGRAVITY_DIR = path.join(GEMINI_DIR, 'antigravity')
const BROWSER_PROFILE_DIR = path.join(GEMINI_DIR, 'antigravity-browser-profile')
const BACKUP_DIR = path.join(GEMINI_DIR, 'backups')

// Helper to get directory size
async function getDirSize(dirPath: string): Promise<number> {
    let size = 0
    try {
        const files = await fs.readdir(dirPath)
        for (const file of files) {
            const filePath = path.join(dirPath, file)
            const stats = await fs.stat(filePath)
            if (stats.isDirectory()) {
                size += await getDirSize(filePath)
            } else {
                size += stats.size
            }
        }
    } catch (error) {
        return 0 // Directory might not exist or be accessible
    }
    return size
}

// Helper to remove directory contents
async function cleanDirectory(dirPath: string): Promise<boolean> {
    try {
        const exists = await fs
            .access(dirPath)
            .then(() => true)
            .catch(() => false)
        if (!exists) return false

        const files = await fs.readdir(dirPath)
        for (const file of files) {
            // preserve the dir itself, remove contents
            await fs.rm(path.join(dirPath, file), { recursive: true, force: true })
        }
        return true
    } catch (error) {
        console.error(`Failed to clean ${dirPath}:`, error)
        return false
    }
}

// Browser Paths (Common locations)
const BROWSERS = {
    chrome: {
        linux: path.join(HOME, '.config/google-chrome'),
        darwin: path.join(HOME, 'Library/Application Support/Google/Chrome'),
        win32: path.join(os.homedir(), 'AppData/Local/Google/Chrome/User Data')
    },
    edge: {
        linux: path.join(HOME, '.config/microsoft-edge'),
        darwin: path.join(HOME, 'Library/Application Support/Microsoft Edge'),
        win32: path.join(os.homedir(), 'AppData/Local/Microsoft/Edge/User Data')
    },
    firefox: {
        linux: path.join(HOME, '.mozilla/firefox'),
        darwin: path.join(HOME, 'Library/Application Support/Firefox/Profiles'),
        win32: path.join(os.homedir(), 'AppData/Roaming/Mozilla/Firefox/Profiles')
    },
    brave: {
        linux: path.join(HOME, '.config/BraveSoftware/Brave-Browser'),
        darwin: path.join(HOME, 'Library/Application Support/BraveSoftware/Brave-Browser'),
        win32: path.join(os.homedir(), 'AppData/Local/BraveSoftware/Brave-Browser/User Data')
    },
    opera: {
        linux: path.join(HOME, '.config/opera'),
        darwin: path.join(HOME, 'Library/Application Support/com.operasoftware.Opera'),
        win32: path.join(os.homedir(), 'AppData/Roaming/Opera Software/Opera Stable')
    },
    vivaldi: {
        linux: path.join(HOME, '.config/vivaldi'),
        darwin: path.join(HOME, 'Library/Application Support/Vivaldi'),
        win32: path.join(os.homedir(), 'AppData/Local/Vivaldi/User Data')
    },
    arc: {
        darwin: path.join(HOME, 'Library/Application Support/Arc'),
        linux: null,
        win32: null
    },
    safari: {
        darwin: path.join(HOME, 'Library/Safari'),
        linux: null,
        win32: null
    }
}

export function registerHandlers() {
    // System Health / Cache Status
    ipcMain.handle('get-cache-status', async () => {
        const dirs = [
            'brain',
            'browser_recordings',
            'conversations',
            'context_state',
            'code_tracker',
            'implicit'
        ]

        const status: Record<string, number> = {}

        for (const d of dirs) {
            status[d] = await getDirSize(path.join(ANTIGRAVITY_DIR, d))
        }
        status['browser_profile'] = await getDirSize(BROWSER_PROFILE_DIR)

        return status
    })

    // Clean Specific
    ipcMain.handle('clean-cache', async (_, type: string) => {
        if (type === 'all') {
            const dirs = ['brain', 'browser_recordings', 'conversations', 'context_state', 'code_tracker', 'implicit']
            for (const d of dirs) await cleanDirectory(path.join(ANTIGRAVITY_DIR, d))
            await cleanDirectory(BROWSER_PROFILE_DIR) // Check if user wants this separately usually
            return true
        }

        // Map friendly names to paths if needed, or just use dirname
        const targetPath = type === 'browser_profile'
            ? BROWSER_PROFILE_DIR
            : path.join(ANTIGRAVITY_DIR, type)

        return await cleanDirectory(targetPath)
    })

    // Network Ops
    ipcMain.handle('network-op', async (_, op: string) => {
        try {
            if (op === 'flush-dns') {
                if (process.platform === 'darwin') {
                    await execAsync('sudo killall -HUP mDNSResponder') // Might fail without password
                } else if (process.platform === 'linux') {
                    await execAsync('resolvectl flush-caches || systemd-resolve --flush-caches')
                } else if (process.platform === 'win32') {
                    await execAsync('ipconfig /flushdns')
                }
                return { success: true, message: 'DNS Cache Flushed' }
            }

            if (op === 'check-connectivity') {
                const google = await fetch('https://www.google.com', { method: 'HEAD' }).then(() => true).catch(() => false)
                const gemini = await fetch('https://gemini.google.com', { method: 'HEAD' }).then(() => true).catch(() => false)
                return {
                    success: true,
                    data: { google, gemini, internet: google || gemini }
                }
            }

            return { success: false, message: 'Unknown operation' }
        } catch (error: any) {
            return { success: false, message: error.message }
        }
    })

    // Detect and Backup Browsers
    ipcMain.handle('get-browsers', async () => {
        const detected: any[] = []
        const platform = process.platform as keyof typeof BROWSERS.chrome

        for (const [name, paths] of Object.entries(BROWSERS)) {
            const browserPath = (paths as any)[platform]
            if (browserPath) {
                const exists = await fs.access(browserPath).then(() => true).catch(() => false)
                if (exists) {
                    detected.push({ id: name, path: browserPath, name: name.charAt(0).toUpperCase() + name.slice(1) })
                }
            }
        }
        return detected
    })

    ipcMain.handle('backup-browser', async (_, browserId: string) => {
        try {
            const platform = process.platform as keyof typeof BROWSERS.chrome
            const sourcePath = (BROWSERS as any)[browserId]?.[platform]

            if (!sourcePath) throw new Error('Browser path not found')

            await fs.mkdir(BACKUP_DIR, { recursive: true })
            const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
            const destPath = path.join(BACKUP_DIR, `backup-${browserId}-${timestamp}.zip`)

            return new Promise((resolve, reject) => {
                const output = createWriteStream(destPath)
                const archive = archiver('zip', { zlib: { level: 9 } })

                output.on('close', () => resolve({ success: true, path: destPath }))
                archive.on('error', (err: any) => reject(err))

                archive.pipe(output)
                archive.directory(sourcePath, false)
                archive.finalize()
            })
        } catch (error: any) {
            console.error('Backup failed:', error)
            return { success: false, error: error.message }
        }
    })

    // Open External
    ipcMain.handle('open-external', async (_, url: string) => {
        await shell.openExternal(url)
    })
}
