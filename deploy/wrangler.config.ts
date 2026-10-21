import { defineWranglerConfig } from "wrangler/experimental-config";

/** The website, with the browser game in play/. `cf deploy` reads this; do not run the Wrangler CLI. */
export default defineWranglerConfig({
  assetsDirectory: "../build/site",
});
