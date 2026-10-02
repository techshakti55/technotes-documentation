import { defineConfig } from '@playwright/test';
export default defineConfig({
  testDir: './tests', timeout: 90000, workers: 1, retries: 0,
  reporter: [['list']],
  use: { browserName: 'chromium', baseURL: 'http://localhost:25173',
    trace: 'off', screenshot: 'off', video: 'off' },
});
