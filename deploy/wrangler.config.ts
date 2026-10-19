import { defineWranglerConfig } from "wrangler/experimental-config";

/** Static web export. `cf deploy` reads this; do not run the Wrangler CLI. */
export default defineWranglerConfig({
  assetsDirectory: "../build/web",
});
