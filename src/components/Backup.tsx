import { useState, useEffect } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
import { HardDrive, Save, CheckCircle, AlertCircle, RefreshCw, FolderLock } from 'lucide-react'
import { clsx } from 'clsx'

export function Backup() {
    const [browsers, setBrowsers] = useState<Array<{ id: string; name: string; path: string }>>([])
    const [loading, setLoading] = useState(true)
    const [backingUp, setBackingUp] = useState<string | null>(null)
    const [status, setStatus] = useState<{ type: 'success' | 'error', msg: string } | null>(null)

    useEffect(() => {
        loadBrowsers()
    }, [])

    const loadBrowsers = async () => {
        try {
            const list = await window.api.getBrowsers()
            setBrowsers(list)
        } catch (e) {
            console.error(e)
        } finally {
            setLoading(false)
        }
    }

    const handleBackup = async (id: string) => {
        setBackingUp(id)
        setStatus(null)
        try {
            const res = await window.api.backupBrowser(id)
            if (res.success) {
                setStatus({ type: 'success', msg: `Backup saved to: ${res.path}` })
            } else {
                setStatus({ type: 'error', msg: res.error || 'Backup failed' })
            }
        } catch (e: any) {
            setStatus({ type: 'error', msg: e.message })
        } finally {
            setBackingUp(null)
        }
    }

    return (
        <div className="max-w-3xl mx-auto space-y-8">
            <div>
                <h2 className="text-3xl font-bold text-white mb-2">Session Safeguard</h2>
                <p className="text-zinc-400">Securely backup your browser sessions and profiles.</p>
            </div>

            {loading ? (
                <div className="text-center py-12">
                    <RefreshCw className="animate-spin w-8 h-8 text-zinc-600 mx-auto" />
                    <p className="text-zinc-500 mt-4">Scanning for browsers...</p>
                </div>
            ) : browsers.length === 0 ? (
                <div className="text-center py-12 bg-zinc-900/20 rounded-2xl border border-zinc-800">
                    <AlertCircle className="w-12 h-12 text-zinc-600 mx-auto mb-4" />
                    <h3 className="text-lg font-medium">No Browsers Detected</h3>
                    <p className="text-zinc-500">Could not find standard installations of Chrome, Edge, Firefox, etc.</p>
                </div>
            ) : (
                <div className="grid gap-4">
                    {browsers.map(b => (
                        <motion.div
                            key={b.id}
                            layout
                            className="flex items-center justify-between p-5 rounded-xl border border-zinc-800 bg-zinc-900/40 hover:bg-zinc-900/60 transition-colors"
                        >
                            <div className="flex items-center gap-4">
                                <div className="w-10 h-10 rounded-lg bg-zinc-800 flex items-center justify-center">
                                    <FolderLock className="text-zinc-400" size={20} />
                                </div>
                                <div>
                                    <h3 className="font-bold text-white">{b.name}</h3>
                                    <p className="text-xs text-zinc-500 truncate max-w-xs" title={b.path}>{b.path}</p>
                                </div>
                            </div>

                            <button
                                onClick={() => handleBackup(b.id)}
                                disabled={!!backingUp}
                                className={clsx(
                                    "px-4 py-2 rounded-lg text-sm font-medium transition-all flex items-center gap-2",
                                    backingUp === b.id
                                        ? "bg-zinc-800 text-zinc-400 cursor-wait"
                                        : "bg-primary/10 text-primary hover:bg-primary/20"
                                )}
                            >
                                {backingUp === b.id ? (
                                    <>
                                        <RefreshCw size={14} className="animate-spin" />
                                        Backing up...
                                    </>
                                ) : (
                                    <>
                                        <Save size={16} />
                                        Backup
                                    </>
                                )}
                            </button>
                        </motion.div>
                    ))}
                </div>
            )}

            <AnimatePresence>
                {status && (
                    <motion.div
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        exit={{ opacity: 0 }}
                        className={clsx(
                            "p-4 rounded-xl border flex items-start gap-3",
                            status.type === 'success'
                                ? "bg-green-500/10 border-green-500/20 text-green-400"
                                : "bg-red-500/10 border-red-500/20 text-red-400"
                        )}
                    >
                        {status.type === 'success' ? <CheckCircle size={20} /> : <AlertCircle size={20} />}
                        <div>
                            <h4 className="font-bold text-sm">{status.type === 'success' ? 'Backup Successful' : 'Backup Failed'}</h4>
                            <p className="text-sm opacity-90 break-all">{status.type === 'success' ? status.msg : `Error: ${status.msg}`}</p>
                            {status.type === 'success' && (
                                <button
                                    onClick={() => window.api.openExternal('file://' + status.msg.split(': ')[1].trim())}
                                    className="text-xs underline mt-1 hover:text-white"
                                >
                                    Open Location
                                </button>
                            )}
                        </div>
                    </motion.div>
                )}
            </AnimatePresence>
        </div>
    )
}
