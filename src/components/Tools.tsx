import { useState } from 'react'
import { motion } from 'framer-motion'
import { Globe, Wifi, RefreshCw, Layers } from 'lucide-react'
import { clsx } from 'clsx'

export function Tools() {
    const [loading, setLoading] = useState<string | null>(null)
    const [result, setResult] = useState<any>(null)

    const runOp = async (op: string) => {
        setLoading(op)
        setResult(null)
        try {
            const res = await window.api.networkOp(op)
            setResult(res)
        } catch (e) {
            console.error(e)
        } finally {
            setLoading(null)
        }
    }

    return (
        <div className="max-w-3xl mx-auto space-y-8">
            <div>
                <h2 className="text-3xl font-bold text-white mb-2">Network Tools</h2>
                <p className="text-zinc-400">Utilities to fix connectivity and network issues.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {/* Connectivity Check */}
                <div className="bg-zinc-900/40 border border-zinc-800 p-6 rounded-2xl">
                    <div className="w-12 h-12 rounded-xl bg-blue-500/10 flex items-center justify-center mb-4 text-blue-500">
                        <Globe />
                    </div>
                    <h3 className="text-xl font-bold mb-2">Connectivity Check</h3>
                    <p className="text-zinc-500 text-sm mb-6">Ping Google services to verify internet access and region locks.</p>
                    <button
                        onClick={() => runOp('check-connectivity')}
                        disabled={!!loading}
                        className="w-full py-2 bg-blue-500/10 hover:bg-blue-500/20 text-blue-400 rounded-lg font-medium transition-colors"
                    >
                        {loading === 'check-connectivity' ? 'Checking...' : 'Run Diagnostics'}
                    </button>
                </div>

                {/* DNS Flush */}
                <div className="bg-zinc-900/40 border border-zinc-800 p-6 rounded-2xl">
                    <div className="w-12 h-12 rounded-xl bg-purple-500/10 flex items-center justify-center mb-4 text-purple-500">
                        <Wifi />
                    </div>
                    <h3 className="text-xl font-bold mb-2">Flush DNS Cache</h3>
                    <p className="text-zinc-500 text-sm mb-6">Clear local DNS resolver cache to fix resolution errors.</p>
                    <button
                        onClick={() => runOp('flush-dns')}
                        disabled={!!loading}
                        className="w-full py-2 bg-purple-500/10 hover:bg-purple-500/20 text-purple-400 rounded-lg font-medium transition-colors"
                    >
                        {loading === 'flush-dns' ? 'Flushing...' : 'Flush DNS'}
                    </button>
                </div>
            </div>

            {/* Result Display */}
            {result && (
                <motion.div
                    initial={{ opacity: 0, height: 0 }}
                    animate={{ opacity: 1, height: 'auto' }}
                    className="bg-zinc-950 border border-zinc-800 p-4 rounded-xl font-mono text-sm"
                >
                    <div className="flex items-center gap-2 mb-2 pb-2 border-b border-zinc-800">
                        <div className={clsx("w-2 h-2 rounded-full", result.success ? "bg-green-500" : "bg-red-500")} />
                        <span className="font-bold text-zinc-300">{result.success ? "Operation Successful" : "Operation Failed"}</span>
                    </div>
                    <pre className="text-zinc-500 whitespace-pre-wrap">
                        {JSON.stringify(result.data || result.message, null, 2)}
                    </pre>
                </motion.div>
            )}

            {/* Other Fixes List */}
            <div className="pt-8 border-t border-zinc-800">
                <h3 className="text-lg font-bold mb-4 flex items-center gap-2">
                    <Layers size={18} className="text-zinc-400" />
                    Common Fixes
                </h3>
                <div className="space-y-2">
                    <div className="flex items-center justify-between p-3 bg-zinc-900/20 rounded-lg border border-zinc-800/50">
                        <span className="text-zinc-400">Fix 403 Forbidden (Reset Token)</span>
                        <button className="text-xs px-3 py-1 bg-zinc-800 hover:bg-zinc-700 rounded transition-colors text-white">Apply</button>
                    </div>
                    <div className="flex items-center justify-between p-3 bg-zinc-900/20 rounded-lg border border-zinc-800/50">
                        <span className="text-zinc-400">Reset Chrome Profile Lock</span>
                        <button className="text-xs px-3 py-1 bg-zinc-800 hover:bg-zinc-700 rounded transition-colors text-white">Apply</button>
                    </div>
                </div>
            </div>
        </div>
    )
}
