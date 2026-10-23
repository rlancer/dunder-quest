import handler from "@tanstack/react-start/server-entry";
import { env } from "cloudflare:workers";
import { checkAccess } from "./server/access";
import { handleEvents } from "./server/events";

const ADMIN_URL = "https://dunderquest.com/admin/";
const ASSET_PREFIX = "/admin/assets/";

// The game reports to /api/events without signing in. Everything else is the
// admin area at dunderquest.com/admin, which only an allowed
// Access viewer may load. The stats hosts are kept for the game's endpoint and
// send anything else on to /admin. stats.ember-trail.robertlancer.com stays
// up for builds that shipped before the rename.
export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/api/events") return handleEvents(request, env);
    if (url.hostname.startsWith("stats.")) return Response.redirect(ADMIN_URL, 301);
    const viewer = await checkAccess(request, env);
    if (viewer instanceof Response) return viewer;
    // The build sits at the root of the assets directory, but the pages ask
    // for it under /admin.
    if (url.pathname.startsWith(ASSET_PREFIX)) {
      return env.ASSETS.fetch(new URL(url.pathname.slice("/admin".length), url));
    }
    return handler.fetch(request);
  },
};
