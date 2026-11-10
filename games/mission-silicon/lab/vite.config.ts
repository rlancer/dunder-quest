import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// The cast's portraits come from ../assets, the same files the rest of
// Mission Silicon uses. Built with relative paths so it works at
// /mission-silicon/lab/ on the site and anywhere else.
export default defineConfig({
  base: "./",
  plugins: [react()],
  server: { fs: { allow: [".."] } },
  build: { outDir: "dist" },
  test: { environment: "happy-dom" },
});
