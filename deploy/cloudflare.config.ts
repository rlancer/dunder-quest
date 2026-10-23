import { defineConfig } from "cf/config";

const accountId = "3315bb3e7d2e3556bfea6fb3947a890e";

export default defineConfig(({ mode }) => {
  const dev = mode === "dev";

  return {
    accountId,
    worker: {
      name: dev ? "ember-trail-dev" : "ember-trail",
      compatibilityDate: "2026-10-19",
      observability: { enabled: true },
      workersDev: true,
      assets: {
        notFoundHandling: "404-page",
        htmlHandling: "auto-trailing-slash",
      },
      // The old host stays attached so a redirect rule on robertlancer.com
      // has something to answer for it, and old links keep working.
      domains: dev
        ? ["dev.dunderquest.com"]
        : ["dunderquest.com", "www.dunderquest.com", "ember-trail.robertlancer.com"],
    },
  };
});
