// The site's Worker. Static files (every page, every game) are served
// straight from the assets and never reach this code; only the paths listed
// in `runWorkerFirst` in cloudflare.config.ts do: the social API under /api/,
// and the pages about one player, /u/, /c/ and /s/.

import { handleApi, json } from "./api";
import { type Env, ensureSchema } from "./db";
import { certPage, certPng, profileImage, profilePage, shotImage, shotPage } from "./pages";

export type { Env };

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    try {
      if (path.startsWith("/api/")) {
        await ensureSchema(env.DB);
        return await handleApi(request, env, url);
      }
      const m = /^\/([ucs])\/([a-z0-9]{6,16})(\.png|\.jpg)?\/?$/.exec(path);
      if (m && (request.method === "GET" || request.method === "HEAD")) {
        await ensureSchema(env.DB);
        const [, kind, id, ext] = m;
        if (kind === "c") return ext === ".png" ? await certPng(env, url, id) : await certPage(env, url, id);
        if (kind === "u") return ext === ".png" ? await profileImage(env, url, id, ctx) : await profilePage(env, url, id);
        if (kind === "s") return ext ? await shotImage(env, id) : await shotPage(env, url, id);
      }
      return env.ASSETS.fetch(request);
    } catch (err) {
      console.error(err);
      if (path.startsWith("/api/")) return json({ error: "Something went wrong on our side." }, 500);
      return new Response("Something went wrong on our side.", { status: 500 });
    }
  },
};
