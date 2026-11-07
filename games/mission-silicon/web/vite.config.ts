import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

// The game reads its words from ../data and its art from ../assets, the same
// files the Godot prototype used. Built with relative paths so it works at
// /mission-silicon/play/ on the site and anywhere else.
export default defineConfig({
  base: "./",
  plugins: [react()],
  server: { fs: { allow: [".."] } },
  build: { outDir: "dist", assetsInlineLimit: 0 },
  test: { environment: "happy-dom" },
});
