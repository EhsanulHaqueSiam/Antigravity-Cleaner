import { ReactNode } from 'react'
import { Activity, Trash2, Globe, Shield, Home } from 'lucide-react'
import { clsx } from 'clsx'
import { motion } from 'framer-motion'

interface SidebarItemProps {
    icon: ReactNode
    label: string
    active?: boolean
    onClick: () => void
}

function SidebarItem({ icon, label, active, onClick }: SidebarItemProps) {
    return (
        <div
            onClick={onClick}
            className={clsx(
                "flex items-center gap-3 p-3 rounded-lg cursor-pointer transition-all duration-200 group no-drag",
                active
                    ? "bg-primary/10 text-primary border border-primary/20 shadow-md shadow-primary/5"
                    : "text-zinc-400 hover:text-white hover:bg-zinc-800/50"
            )}
        >
            <div className={clsx("transition-transform duration-200 group-hover:scale-110", active && "scale-110")}>
                {icon}
            </div>
            <span className="font-medium text-sm">{label}</span>
            {active && (
                <motion.div
                    layoutId="active-pill"
                    className="absolute left-0 w-1 h-8 bg-primary rounded-r-full"
                />
            )}
        </div>
    )
}

interface LayoutProps {
    children: ReactNode
    currentTab: string
    onTabChange: (tab: string) => void
}

export function Layout({ children, currentTab, onTabChange }: LayoutProps) {
    return (
        <div className="flex h-screen bg-black/90 text-white overflow-hidden bg-[radial-gradient(ellipse_at_top,_var(--tw-gradient-stops))] from-zinc-900 via-background to-background">
            {/* Sidebar */}
            <div className="w-64 border-r border-zinc-800/50 p-4 flex flex-col bg-zinc-900/20 backdrop-blur-xl">
                <div className="p-2 mb-8 flex items-center gap-3 draggable">
                    <div className="w-8 h-8 rounded-lg bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
                        <Activity className="w-5 h-5 text-white" />
                    </div>
                    <div>
                        <h1 className="font-bold text-lg leading-tight tracking-tight">Antigravity</h1>
                        <p className="text-xs text-zinc-500 font-medium tracking-wider">CLEANER</p>
                    </div>
                </div>

                <div className="space-y-1 flex-1">
                    <SidebarItem
                        icon={<Home size={18} />}
                        label="Dashboard"
                        active={currentTab === 'dashboard'}
                        onClick={() => onTabChange('dashboard')}
                    />
                    <SidebarItem
                        icon={<Trash2 size={18} />}
                        label="Precision Cleaner"
                        active={currentTab === 'cleaner'}
                        onClick={() => onTabChange('cleaner')}
                    />
                    <SidebarItem
                        icon={<Globe size={18} />}
                        label="Network Tools"
                        active={currentTab === 'network'}
                        onClick={() => onTabChange('network')}
                    />
                    <SidebarItem
                        icon={<Shield size={18} />}
                        label="Session Backup"
                        active={currentTab === 'backup'}
                        onClick={() => onTabChange('backup')}
                    />
                </div>

                <div className="p-4 rounded-xl bg-zinc-900/50 border border-zinc-800/50 mt-auto">
                    <div className="flex items-center gap-2 mb-2">
                        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                        <span className="text-xs font-medium text-zinc-400">System Active</span>
                    </div>
                    <p className="text-[10px] text-zinc-600">v1.2.0 • Stable</p>
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 flex flex-col h-full relative">
                <div className="h-8 draggable w-full" /> {/* Window handle */}
                <main className="flex-1 p-8 overflow-y-auto no-scrollbar">
                    <motion.div
                        key={currentTab}
                        initial={{ opacity: 0, y: 10 }}
                        animate={{ opacity: 1, y: 0 }}
                        transition={{ duration: 0.3, ease: "easeOut" }}
                        className="h-full"
                    >
                        {children}
                    </motion.div>
                </main>
            </div>
        </div>
    )
}
