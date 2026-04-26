import { app, shell, BrowserWindow, ipcMain, dialog } from 'electron';
import fs from 'fs';
import { join } from 'path';
import { electronApp, optimizer, is } from '@electron-toolkit/utils';
import icon from '../../resources/icon.png?asset';

function createWindow(): void {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 1280,
    height: 720,
    show: false,
    autoHideMenuBar: true,
    ...(process.platform === 'linux' ? { icon } : {}),
    webPreferences: {
      preload: join(__dirname, '../preload/index.js'),
      sandbox: false,
    },
  });

  mainWindow.on('ready-to-show', () => {
    mainWindow.show();
  });

  mainWindow.webContents.setWindowOpenHandler((details) => {
    shell.openExternal(details.url);
    return { action: 'deny' };
  });

  // HMR for renderer base on electron-vite cli.
  // Load the remote URL for development or the local html file for production.
  if (is.dev && process.env['ELECTRON_RENDERER_URL']) {
    mainWindow.loadURL(process.env['ELECTRON_RENDERER_URL']);
  } else {
    mainWindow.loadFile(join(__dirname, '../renderer/index.html'));
  }
}

app.whenReady().then(() => {
  electronApp.setAppUserModelId('com.electron');

  app.on('browser-window-created', (_, window) => {
    optimizer.watchWindowShortcuts(window);
  });

  createWindow();

  app.on('activate', function () {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// IPC Handlers
ipcMain.handle('ping', () => 'pong');

ipcMain.handle('dialog:open', async (_, options) => {
  return await dialog.showOpenDialog(options);
});

ipcMain.handle('dialog:save', async (_, options) => {
  return await dialog.showSaveDialog(options);
});

ipcMain.handle('fs:exists', (_, path) => {
  return fs.existsSync(path);
});

ipcMain.handle('fs:readFile', (_, path) => {
  return fs.readFileSync(path, 'utf8');
});

ipcMain.handle('fs:readFileBase64', (_, path) => {
  return fs.readFileSync(path, 'base64');
});

ipcMain.handle('fs:writeFile', (_, { path, data }) => {
  fs.writeFileSync(path, data, 'utf8');
  return true;
});
