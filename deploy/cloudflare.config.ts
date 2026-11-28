import { bindings, defineConfig } from "cf/config";

const accountId = "3315bb3e7d2e3556bfea6fb3947a890e";

/**
 * The OAuth client ID for "Sign in with Google" (Google Cloud Console, a Web
 * client with dunderquest.com, dev.dunderquest.com and http://localhost:8788
 * as JavaScript origins). It isn't secret. Empty hides the Google button and
 * everything else still works, with players anonymous by default.
 */
const GOOGLE_CLIENT_ID = "907567662959-8egdjo19gucnb8pbidnod3epmcuo2mqt.apps.googleusercontent.com";

/**
 * Cloudflare Turnstile's site key for the feedback form (Turnstile in the
 * Cloudflare dashboard, a widget for dunderquest.com, dev.dunderquest.com and
 * localhost). It isn't secret; its secret key is the Worker secret
 * TURNSTILE_SECRET. Empty (or no secret) leaves the form on the honeypot and
 * the rate limit alone. See README.md.
 */
const TURNSTILE_SITE_KEY = "";

export default defineConfig(({ mode }) => {
  const dev = mode === "dev";

  return {
    accountId,
    worker: {
      name: dev ? "ember-trail-dev" : "ember-trail",
      compatibilityDate: "2026-10-19",
      observability: { enabled: true },
      workersDev: true,
      // The social layer: the API, and the pages about one player. Every
      // other request is a static file and never runs the Worker.
      entrypoint: "./src/worker.ts",
      assets: {
        notFoundHandling: "404-page",
        htmlHandling: "auto-trailing-slash",
        runWorkerFirst: ["/api/*", "/u/*", "/c/*", "/s/*"],
      },
      env: {
        ASSETS: bindings.assets(),
        // `cf deploy` makes each database the first time; the Worker makes its tables.
        DB: bindings.d1({ name: dev ? "dunderquest-social-dev" : "dunderquest-social" }),
        GOOGLE_CLIENT_ID: { type: "text", value: GOOGLE_CLIENT_ID },
        TURNSTILE_SITE_KEY: { type: "text", value: TURNSTILE_SITE_KEY },
        WRITE_LIMITER: bindings.rateLimit({ namespace: dev ? "4302" : "4301", simple: { limit: 20, period: 60 } }),
      },
      // The old host stays attached so a redirect rule on robertlancer.com
      // has something to answer for it, and old links keep working.
      domains: dev
        ? ["dev.dunderquest.com"]
        : ["dunderquest.com", "www.dunderquest.com", "ember-trail.robertlancer.com"],
    },
  };
});
