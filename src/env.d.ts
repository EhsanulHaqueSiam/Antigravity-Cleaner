/// <reference types="vite/client" />

interface Window {
    api: {
        getCacheStatus: () => Promise<Record<string, number>>
        cleanCache: (type: string) => Promise<boolean>
        networkOp: (op: string) => Promise<{ success: boolean; message?: string; data?: any }>
        openExternal: (url: string) => Promise<void>
        getBrowsers: () => Promise<Array<{ id: string; name: string; path: string }>>
        backupBrowser: (id: string) => Promise<{ success: boolean; path?: string; error?: string }>
    }
}
