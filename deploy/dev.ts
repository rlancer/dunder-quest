/**
 * Runs the site Worker locally with Bun: the built site from build/site, the
 * social API on a SQLite file standing in for D1. No Cloudflare account and
 * no Wrangler needed, which makes it the quickest way to try the social
 * layer or run its tests.
 *
 *     bun site/build.ts build/site      # once, or scripts/export_web.sh for the games too
 *     bun deploy/dev.ts                 # http://localhost:8788
 *
 * Options: --port 8788, --site <dir>, --db <file> (":memory:" for a throwaway one),
 * GOOGLE_CLIENT_ID=... in the environment to try Google sign-in on localhost.
 */

import { Database } from "bun:sqlite";
import { existsSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import worker, { type Env } from "./src/worker";

/** Just enough of D1's API over bun:sqlite for the Worker. */
export function d1(file: string): D1Database {
  const db = new Database(file, { create: true });
  db.exec("PRAGMA journal_mode = WAL;");
  const clean = (args: unknown[]) => args.map((a) => (a instanceof ArrayBuffer ? new Uint8Array(a) : a === undefined ? null : a));
  class Statement {
    constructor(readonly sql: string, readonly args: unknown[] = []) {}
    bind(...args: unknown[]) {
      return new Statement(this.sql, clean(args));
    }
    async first<T>(column?: string): Promise<T | null> {
      const row = db.query(this.sql).get(...(this.args as never[])) as Record<string, unknown> | null;
      if (!row) return null;
      return (column ? row[column] : row) as T;
    }
    async all<T>() {
      return { results: db.query(this.sql).all(...(this.args as never[])) as T[], success: true, meta: {} };
    }
    async run() {
      const r = db.query(this.sql).run(...(this.args as never[]));
      return { success: true, results: [], meta: { changes: r.changes, last_row_id: Number(r.lastInsertRowid) } };
    }
    runSync() {
      return db.query(this.sql).run(...(this.args as never[]));
    }
  }
  return {
    prepare: (sql: string) => new Statement(sql),
    batch: async (statements: Statement[]) => {
      const results: unknown[] = [];
      db.transaction(() => {
        for (const s of statements) {
          const r = s.runSync();
          results.push({ success: true, results: [], meta: { changes: r.changes } });
        }
      })();
      return results;
    },
    exec: async (sql: string) => {
      db.exec(sql);
      return { count: 1, duration: 0 };
    },
  } as unknown as D1Database;
}

/** Serves a folder the way Workers static assets do with auto-trailing-slash and a 404 page. */
export function assets(root: string): Fetcher {
  const file = (path: string) => (existsSync(path) && statSync(path).isFile() ? path : null);
  return {
    async fetch(input: RequestInfo | URL) {
      const url = new URL(input instanceof Request ? input.url : String(input));
      const path = decodeURIComponent(url.pathname);
      const direct = file(join(root, path));
      if (direct && !path.endsWith("/")) {
        // Godot's .wasm.gz must stay compressed; the page unzips it itself.
        return new Response(Bun.file(direct));
      }
      const index = file(join(root, path, "index.html"));
      if (index) {
        if (!path.endsWith("/")) return Response.redirect(`${url.origin}${path}/${url.search}`, 307);
        return new Response(Bun.file(index), { headers: { "Content-Type": "text/html; charset=utf-8" } });
      }
      const html = file(join(root, `${path.replace(/\/$/, "")}.html`));
      if (html) return new Response(Bun.file(html), { headers: { "Content-Type": "text/html; charset=utf-8" } });
      const missing = file(join(root, "404.html"));
      return new Response(missing ? Bun.file(missing) : "Not found", { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } });
    },
    connect() {
      throw new Error("not supported");
    },
  } as unknown as Fetcher;
}

/** The paths the Worker sees first, the same list as cloudflare.config.ts. */
export const WORKER_FIRST = [/^\/api\//, /^\/[ucs]\//];

if (import.meta.main) {
  const args = process.argv.slice(2);
  const opt = (name: string, fallback: string) => {
    const i = args.indexOf(`--${name}`);
    return i >= 0 ? args[i + 1] : fallback;
  };
  const here = import.meta.dir;
  const site = resolve(opt("site", join(here, "..", "build", "site")));
  const dbFile = opt("db", join(here, "..", "build", "social-dev.sqlite"));
  const port = Number(opt("port", "8788"));
  const env: Env = { DB: d1(dbFile), ASSETS: assets(site), GOOGLE_CLIENT_ID: process.env.GOOGLE_CLIENT_ID ?? "" };
  const ctx = { waitUntil() {}, passThroughOnException() {} } as unknown as ExecutionContext;
  Bun.serve({
    port,
    async fetch(request) {
      const path = new URL(request.url).pathname;
      if (WORKER_FIRST.some((re) => re.test(path))) return worker.fetch(request, env, ctx);
      return env.ASSETS.fetch(request);
    },
  });
  console.log(`Dunder Quest on http://localhost:${port} (site ${site}, database ${dbFile})`);
}
