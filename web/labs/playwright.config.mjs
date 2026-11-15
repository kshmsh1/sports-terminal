import { defineConfig, devices } from '@playwright/test';

const staticServer={
  command: 'python3 -m http.server 8765 --bind 127.0.0.1 --directory web',
  cwd: '../..',
  url: 'http://127.0.0.1:8765/labs/sheets/',
  reuseExistingServer: !process.env.CI,
  timeout: 30000,
};
const nativeServer={
  command: 'python3 tools/arcside_companion/tests/browser_server.py',
  cwd: '../..',
  url: 'http://127.0.0.1:8766/',
  reuseExistingServer: !process.env.CI,
  timeout: 30000,
};
export default defineConfig({
  testDir: './tests',
  testMatch: '**/*.browser.spec.mjs',
  timeout: 180000,
  expect: { timeout: 30000 },
  retries: process.env.CI ? 1 : 0,
  reporter: process.env.CI ? [['list'], ['html', { open: 'never' }]] : 'list',
  use: {
    baseURL: 'http://127.0.0.1:8765/labs',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    actionTimeout: 20000,
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: process.env.ARCSIDE_NATIVE_TEST ? [staticServer,nativeServer] : staticServer,
});
