import handler from "@tanstack/react-start/server-entry";
import { env } from "cloudflare:workers";
import { checkAccess } from "./server/access";
import { handleEvents } from "./server/events";

// The game reports to /api/events without signing in. Everything else is the
// dashboard, which only an allowed Access viewer may load.
export default {
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/api/events") return handleEvents(request, env);
    const viewer = await checkAccess(request, env);
    if (viewer instanceof Response) return viewer;
    return handler.fetch(request);
  },
};
