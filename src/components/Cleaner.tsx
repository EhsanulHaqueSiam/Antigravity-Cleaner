import { useState } from 'react'
import { motion } from 'framer-motion'
import { Trash2, CheckCircle, RefreshCcw, Folder } from 'lucide-react'
import { clsx } from 'clsx'

const cleanOptions = [
    { id: 'brain', label: 'Brain Artifacts', desc: 'Implementation plans & task lists' },
    { id: 'browser_recordings', label: 'Browser Recordings', desc: 'Video recordings of browser sessions' },
    { id: 'conversations', label: 'Conversations', desc: 'Chat history logs' },
    { id: 'context_state', label: 'Context State', desc: 'Agent working memory' },
    { id: 'browser_profile', label: 'Browser Profile', desc: 'Temporary profile data' },
]

export function Cleaner() {
    const [cleaning, setCleaning] = useState(false)
    const [completed, setCompleted] = useState(false)
    const [selected, setSelected] = useState<string[]>(cleanOptions.map(o => o.id))

    const toggle = (id: string) => {
        setSelected(prev => prev.includes(id) ? prev.filter(x => x !== id) : [...prev, id])
    }

    const handleClean = async () => {
        setCleaning(true)
        try {
            // Clean sequentially or could be parallel
            for (const type of selected) {
                await window.api.cleanCache(type)
            }
            setTimeout(() => {
                setCleaning(false)
                setCompleted(true)
            }, 800)
        } catch (e) {
            console.error(e)
            setCleaning(false)
        }
    }

    return (
        <div className="max-w-3xl mx-auto">
            <div className="mb-8">
                <h2 className="text-3xl font-bold text-white mb-2">Precision Cleaner</h2>
                <p className="text-zinc-400">Select components to clean from the Antigravity system.</p>
            </div>

            <div className="grid gap-3 mb-8">
                {cleanOptions.map((opt) => (
                    <motion.div
                        key={opt.id}
                        layout
                        onClick={() => toggle(opt.id)}
                        className={clsx(
                            "flex items-center p-4 rounded-xl border cursor-pointer transition-colors",
                            selected.includes(opt.id)
                                ? "bg-zinc-900/60 border-primary/30"
                                : "bg-zinc-900/20 border-zinc-800 hover:bg-zinc-900/40"
                        )}
                    >
                        <div className={clsx(
                            "w-5 h-5 rounded border flex items-center justify-center mr-4 transition-colors",
                            selected.includes(opt.id) ? "bg-primary border-primary" : "border-zinc-600"
                        )}>
                            {selected.includes(opt.id) && <CheckCircle size={14} className="text-white" />}
                        </div>
                        <div className="flex-1">
                            <h3 className="font-medium text-white">{opt.label}</h3>
                            <p className="text-sm text-zinc-500">{opt.desc}</p>
                        </div>
                        <Folder size={18} className="text-zinc-600" />
                    </motion.div>
                ))}
            </div>

            <div className="flex justify-end">
                <button
                    onClick={handleClean}
                    disabled={cleaning || selected.length === 0}
                    className="relative overflow-hidden group bg-primary hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed text-white px-8 py-3 rounded-xl font-medium transition-all"
                >
                    <span className={clsx("flex items-center gap-2 relative z-10", cleaning && "opacity-0")}>
                        <Trash2 size={18} />
                        Clean Selected ({selected.length})
                    </span>

                    {cleaning && (
                        <div className="absolute inset-0 flex items-center justify-center z-20">
                            <RefreshCcw size={20} className="animate-spin" />
                        </div>
                    )}
                </button>
            </div>

            {completed && (
                <motion.div
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    className="mt-6 p-4 bg-green-500/10 border border-green-500/20 rounded-xl flex items-center gap-3"
                >
                    <CheckCircle className="text-green-500" />
                    <div>
                        <h4 className="font-medium text-green-500">Cleanup Complete</h4>
                        <p className="text-sm text-green-500/70">Selected items have been removed successfully.</p>
                    </div>
                </motion.div>
            )}
        </div>
    )
}
