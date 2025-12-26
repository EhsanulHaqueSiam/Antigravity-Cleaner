import { contextBridge, ipcRenderer } from 'electron'
import { electronAPI } from '@electron-toolkit/preload'

// Custom APIs for renderer
const api = {
    getCacheStatus: () => ipcRenderer.invoke('get-cache-status'),
    cleanCache: (type: string) => ipcRenderer.invoke('clean-cache', type),
    networkOp: (op: string) => ipcRenderer.invoke('network-op', op),
    openExternal: (url: string) => ipcRenderer.invoke('open-external', url),
    getBrowsers: () => ipcRenderer.invoke('get-browsers'),
    backupBrowser: (id: string) => ipcRenderer.invoke('backup-browser', id)
}

// Use `contextBridge` APIs to expose Electron APIs to
// renderer only if context isolation is enabled, otherwise
// just add to the DOM global.
if (process.contextIsolated) {
    try {
        contextBridge.exposeInMainWorld('electron', electronAPI)
        contextBridge.exposeInMainWorld('api', api)
    } catch (error) {
        console.error(error)
    }
} else {
    // @ts-ignore (define in dts)
    window.electron = electronAPI
    // @ts-ignore (define in dts)
    window.api = api
}
