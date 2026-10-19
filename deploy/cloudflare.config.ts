import { defineConfig } from "cf/config";

const accountId = "3315bb3e7d2e3556bfea6fb3947a890e";

export default defineConfig(({ mode }) => {
  const dev = mode === "dev";

  return {
    accountId,
    worker: {
      name: dev ? "gdot-mario-dev" : "gdot-mario",
      compatibilityDate: "2026-10-19",
      observability: { enabled: true },
      workersDev: true,
      assets: {
        notFoundHandling: "none",
        htmlHandling: "auto-trailing-slash",
      },
      domains: dev
        ? ["dev.gdot.robertlancer.com"]
        : ["gdot.robertlancer.com"],
    },
  };
});
