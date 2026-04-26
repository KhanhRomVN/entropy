import { ipcRenderer } from 'electron';

export const sqliteAPI = {
  createDatabase: (path: string) => ipcRenderer.invoke('sqlite:create', path),
  openDatabase: (path: string) => ipcRenderer.invoke('sqlite:open', path),
  closeDatabase: () => ipcRenderer.invoke('sqlite:close'),
  runQuery: (query: string, params?: any[]) => ipcRenderer.invoke('sqlite:run', query, params),
  getAllRows: (query: string, params?: any[]) => ipcRenderer.invoke('sqlite:all', query, params),
  getOneRow: (query: string, params?: any[]) => ipcRenderer.invoke('sqlite:get', query, params)
};
