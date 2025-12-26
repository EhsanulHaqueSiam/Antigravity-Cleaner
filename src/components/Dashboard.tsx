import { useEffect, useState } from 'react'
import { motion } from 'framer-motion'
import { Activity, HardDrive, Cpu, CheckCircle2 } from 'lucide-react'
import { clsx } from 'clsx'

const container = {
    hidden: { opacity: 0 },
    show: {
        opacity: 1,
        transition: {
            staggerChildren: 0.1
        }
    }
}

const item = {
    hidden: { opacity: 0, y: 20 },
    show: { opacity: 1, y: 0 }
}

function StatCard({ label, value, icon, color }: any) {
    return (
        <motion.div
            variants={item}
            className="bg-zinc-900/40 border border-zinc-800/50 p-5 rounded-2xl backdrop-blur-sm"
        >
            <div className="flex items-center gap-4 mb-3">
                <div className={clsx("p-2.5 rounded-xl bg-zinc-900 border border-zinc-800/80", color)}>
                    {icon}
                </div>
                <h3 className="text-sm font-medium text-zinc-400">{label}</h3>
            </div>
            <div className="text-2xl font-bold text-white tracking-tight">{value}</div>
        </motion.div>
    )
}

export function Dashboard() {
    const [cacheSize, setCacheSize] = useState<string>("Calculating...")
    const [status, setStatus] = useState<Record<string, number>>({})

    useEffect(() => {
        loadData()
    }, [])

    const loadData = async () => {
        try {
            const data = await window.api.getCacheStatus()
            setStatus(data)
            const total = Object.values(data).reduce((a, b) => a + b, 0)
            setCacheSize(formatSize(total))
        } catch (e) {
            console.error(e)
            setCacheSize("Unknown")
        }
    }

    const formatSize = (bytes: number) => {
        if (bytes === 0) return '0 B'
        const k = 1024
        const sizes = ['B', 'KB', 'MB', 'GB']
        const i = Math.floor(Math.log(bytes) / Math.log(k))
        return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
    }

    return (
        <div className="max-w-4xl mx-auto space-y-8">
            <div>
                <h2 className="text-3xl font-bold bg-gradient-to-r from-white to-zinc-400 bg-clip-text text-transparent mb-2">System Overview</h2>
                <p className="text-zinc-400">Real-time system health and performance metrics.</p>
            </div>

            <motion.div
                variants={container}
                initial="hidden"
                animate="show"
                className="grid grid-cols-1 md:grid-cols-3 gap-4"
            >
                <StatCard
                    label="System Status"
                    value="Optimal"
                    icon={<Activity size={20} />}
                    color="text-green-500"
                />
                <StatCard
                    label="Cache Detected"
                    value={cacheSize}
                    icon={<HardDrive size={20} />}
                    color="text-blue-500"
                />
                <StatCard
                    label="Processes"
                    value="Active"
                    icon={<Cpu size={20} />}
                    color="text-purple-500"
                />
            </motion.div>

            <motion.div
                initial={{ opacity: 0, scale: 0.95 }}
                animate={{ opacity: 1, scale: 1 }}
                transition={{ delay: 0.2 }}
                className="bg-zinc-900/20 border border-zinc-800/50 rounded-3xl p-8 relative overflow-hidden group"
            >
                <div className="absolute inset-0 bg-gradient-to-br from-green-500/5 to-blue-500/5 opacity-0 group-hover:opacity-100 transition-opacity duration-500" />

                <div className="relative z-10 flex items-center justify-between">
                    <div>
                        <div className="flex items-center gap-3 mb-2">
                            <div className="p-2 rounded-full bg-green-500/10 text-green-500">
                                <CheckCircle2 size={24} />
                            </div>
                            <h3 className="text-xl font-bold text-white">All Systems Operational</h3>
                        </div>
                        <p className="text-zinc-400 max-w-lg">
                            Your development environment is running smoothly. No critical issues detected in Antigravity IDE configuration.
                        </p>
                    </div>

                    <div className="hidden md:block">
                        <div className="w-32 h-32 relative flex items-center justify-center">
                            <svg className="absolute inset-0 w-full h-full transform -rotate-90">
                                <circle cx="64" cy="64" r="56" stroke="currentColor" strokeWidth="8" fill="transparent" className="text-zinc-800" />
                                <circle cx="64" cy="64" r="56" stroke="currentColor" strokeWidth="8" fill="transparent" strokeDasharray="351.86" strokeDashoffset="35" className="text-green-500" />
                            </svg>
                            <span className="text-2xl font-bold">98%</span>
                        </div>
                    </div>
                </div>
            </motion.div>
        </div>
    )
}
