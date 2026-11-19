import {defineConfig,devices} from '@playwright/test';
export default defineConfig({
 testDir:'./tests',testMatch:'**/*.spec.ts',
 timeout:90000,expect:{timeout:20000},
 use:{baseURL:'http://127.0.0.1:5173',trace:'retain-on-failure',screenshot:'only-on-failure'},
 projects:[
  {name:'chromium',use:{...devices['Desktop Chrome']}},
  {name:'firefox',use:{...devices['Desktop Firefox']}},
  {name:'webkit',use:{...devices['Desktop Safari']}}
 ],
 webServer:{command:'npm run dev',url:'http://127.0.0.1:5173',reuseExistingServer:!process.env.CI,
  timeout:30000},
 reporter:process.env.CI?[['list'],['html',{open:'never'}]]:'list'
});
