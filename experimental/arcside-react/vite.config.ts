import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import sirv from 'sirv';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const cwd = path.dirname(fileURLToPath(import.meta.url));
const repoWeb = path.resolve(cwd, '../../web');
const assets = (server: {middlewares: {use: (prefix: string, middleware: any) => void}}) => {
  // Serve the SAME local corpus and ORIGINAL Labs, not demo copies or remote API data.
  server.middlewares.use('/data/nba_static', sirv(path.join(repoWeb, 'data/nba_static'), { dev: true, etag: true }));
  server.middlewares.use('/labs', sirv(path.join(repoWeb, 'labs'), { dev: true, etag: true, single: false }));
};
export default defineConfig({
  plugins: [react(), { name: 'arcside-original-static-resources', configureServer: assets, configurePreviewServer: assets }],
  publicDir: false,
  server: { host: '127.0.0.1', port: 5173, strictPort: true },
  preview: { host: '127.0.0.1', port: 4173, strictPort: true },
  build: { outDir: 'dist', emptyOutDir: true },
  test: { environment: 'node', include: process.env.ARCSIDE_RUN_PARITY === '1' ? ['tests/parity.test.ts'] : ['tests/**/*.test.ts'],
    exclude: process.env.ARCSIDE_RUN_PARITY === '1' ? [] : ['tests/parity.test.ts'] }
});
