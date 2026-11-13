import { defineConfig } from "vitest/config";

// Built with relative paths so it works at /make-it-pop/ on the site and
// anywhere else.
export default defineConfig({
  base: "./",
  build: { outDir: "dist" },
  test: { environment: "happy-dom" },
});
