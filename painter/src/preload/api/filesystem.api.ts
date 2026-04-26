import { ipcRenderer } from 'electron';

export const fileSystemAPI = {
  showSaveDialog: (options: any) => ipcRenderer.invoke('dialog:save', options),
  showOpenDialog: (options: any) => ipcRenderer.invoke('dialog:open', options),
  exists: (path: string) => ipcRenderer.invoke('fs:exists', path),
  createDirectory: (path: string) => ipcRenderer.invoke('fs:createDirectory', path),
  readFile: (path: string) => ipcRenderer.invoke('fs:readFile', path),
  readFileBase64: (path: string) => ipcRenderer.invoke('fs:readFileBase64', path),
  writeFile: (path: string, data: string) => ipcRenderer.invoke('fs:writeFile', { path, data }),
};
