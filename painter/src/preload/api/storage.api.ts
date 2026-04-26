import { ipcRenderer } from 'electron';

export const storageAPI = {
  set: (key: string, value: any) => ipcRenderer.invoke('storage:set', key, value),
  get: (key: string) => ipcRenderer.invoke('storage:get', key),
  remove: (key: string) => ipcRenderer.invoke('storage:remove', key)
};
