import { defineConfig } from "vite";
import { cloudflare } from "@cloudflare/vite-plugin";
import { tanstackStart } from "@tanstack/react-start/plugin/vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  // The dashboard lives at ember-trail.robertlancer.com/admin, behind Access.
  base: "/admin/",
  // The Worker answers CORS itself; keep Vite from answering preflights first.
  server: { cors: false },
  preview: { cors: false },
  plugins: [cloudflare({ viteEnvironment: { name: "ssr" } }), tanstackStart(), react()],
});
