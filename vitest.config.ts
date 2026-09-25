import { defineConfig } from "vitest/config";
import path from "node:path";

export default defineConfig({
  test: {
    environment: "node",
    exclude: ["e2e/**", "node_modules/**"],
    // Tests that sign users up through Better Auth hash passwords, and the first request to a
    // route loads a large module graph cold. Both are slow when the whole suite runs in parallel
    // on a busy machine, so the default 10s hook and 5s test limits are too tight.
    hookTimeout: 60_000,
    testTimeout: 30_000,
    coverage: {
      provider: "v8",
      reporter: ["text", "html"],
      include: ["src/lib/**/*.ts"],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
