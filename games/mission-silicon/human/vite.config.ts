import { defineConfig } from "vitest/config";

// The Human Backend borrows the cast's portraits and the music from
// ../assets, the files the other versions use. Built with relative paths so
// it works at /mission-silicon/human/ on the site and anywhere else.
export default defineConfig({
  base: "./",
  server: { fs: { allow: [".."] } },
  build: { outDir: "dist", assetsInlineLimit: 0 },
  test: { environment: "happy-dom" },
});
