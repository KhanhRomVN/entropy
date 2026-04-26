import { resolve } from 'path';
import { defineConfig, externalizeDepsPlugin } from 'electron-vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  main: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        '@main': resolve('src/main'),
      },
    },
    build: {
      outDir: 'out/main',
      rollupOptions: {
        external: [
          'electron',
          'sqlite3',
          // eslint-disable-next-line @typescript-eslint/no-require-imports
          ...Object.keys(require('./package.json').dependencies || {}),
        ],
      },
    },
  },
  preload: {
    plugins: [externalizeDepsPlugin()],
    resolve: {
      alias: {
        '@preload': resolve('src/preload'),
      },
    },
    build: {
      outDir: 'out/preload',
    },
  },
  renderer: {
    resolve: {
      alias: {
        '@': resolve('src/renderer/src'),
        '@renderer': resolve('src/renderer/src'),
        '@shared': resolve('src/renderer/src/shared'),
        '@core': resolve('src/renderer/src/core'),
        '@features': resolve('src/renderer/src/features'),
      },
    },
    plugins: [react()],
    optimizeDeps: {
      include: [
        'react-force-graph-2d',
        'd3-force-3d',
      ],
    },
    build: {
      outDir: 'out/renderer',
      commonjsOptions: {
        include: [/node_modules/],
      },
    },
  },
});
