import { contextBridge } from 'electron';
import { electronAPI } from '@electron-toolkit/preload';
import { appAPI, sqliteAPI, fileSystemAPI, storageAPI } from './api';

const api = {
  app: appAPI,
  sqlite: sqliteAPI,
  fileSystem: fileSystemAPI,
  storage: storageAPI
};

if (process.contextIsolated) {
  try {
    contextBridge.exposeInMainWorld('electron', electronAPI);
    contextBridge.exposeInMainWorld('api', api);
    contextBridge.exposeInMainWorld('electronAPI', api); // For compatibility
  } catch (error) {
    console.error(error);
  }
} else {
  // @ts-expect-error (define in d.ts)
  window.electron = electronAPI;
  // @ts-expect-error (api is defined in d.ts)
  window.api = api;
  // @ts-expect-error (electronAPI is defined in d.ts)
  window.electronAPI = api;
}
