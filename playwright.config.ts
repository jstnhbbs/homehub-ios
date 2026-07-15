import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  retries: process.env.CI ? 2 : 0,
  reporter: "html",
  use: {
    baseURL: "http://127.0.0.1:3000",
    trace: "on-first-retry",
    viewport: { width: 1366, height: 1024 },
  },
  projects: [
    {
      name: "iPad landscape",
      use: {
        ...devices["Desktop Safari"],
        viewport: { width: 1366, height: 1024 },
      },
    },
    {
      name: "iPhone",
      use: {
        ...devices["iPhone 15"],
      },
    },
  ],
  webServer: {
    command:
      "TURSO_DATABASE_URL=file:e2e.db npm run db:migrate && TURSO_DATABASE_URL=file:e2e.db BETTER_AUTH_URL=http://127.0.0.1:3000 BETTER_AUTH_SECRET=e2e-only-secret-that-is-long-and-never-used-elsewhere DISABLE_AUTH_RATE_LIMIT=true npm run dev",
    url: "http://127.0.0.1:3000",
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
});
