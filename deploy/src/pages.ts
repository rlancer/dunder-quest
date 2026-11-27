// Pages the Worker writes on request, because each one is about one player
// and needs its own link preview: a certificate (/c/<id>), a profile
// (/u/<id>) and a shared screenshot (/s/<id>), with their images. They
// borrow the site's stylesheet and bar, so they look like the rest of it.

import { GAMES, ORDER, bestLine, formatTime, summarize } from "../../site/static/social/games.js";
import { avatarSvg } from "../../site/static/social/avatar.js";
import { icon, linkedInCertUrl, shareButtons } from "../../site/static/social/share.js";
import { certJson, certsOf, leaderboard, publicPlayer, savesOf } from "./api";
import { CERT_DESIGN, type CardGame, certificatePng, longDate, profilePng } from "./cards";
import type { CertRow, Env, PlayerRow, ShotRow } from "./db";

type Game = keyof typeof GAMES;

export function esc(text: unknown): string {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#x27;");
}

type Meta = { title: string; description: string; url: string; image: string; imageAlt: string; width?: number; height?: number; type?: string };

function shell(origin: string, meta: Meta, body: string, data: Record<string, string> = {}): string {
  const attrs = Object.entries(data).map(([k, v]) => ` data-${k}="${esc(v)}"`).join("");
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(meta.title)}</title>
<meta name="description" content="${esc(meta.description)}">
<link rel="canonical" href="${esc(meta.url)}">
<meta property="og:type" content="${meta.type ?? "website"}">
<meta property="og:site_name" content="Dunder Quest">
<meta property="og:locale" content="en_US">
<meta property="og:title" content="${esc(meta.title)}">
<meta property="og:description" content="${esc(meta.description)}">
<meta property="og:url" content="${esc(meta.url)}">
<meta property="og:image" content="${esc(meta.image)}">
<meta property="og:image:secure_url" content="${esc(meta.image)}">
<meta property="og:image:type" content="${meta.image.includes(".jpg") ? "image/jpeg" : "image/png"}">
<meta property="og:image:width" content="${meta.width ?? 1200}">
<meta property="og:image:height" content="${meta.height ?? 630}">
<meta property="og:image:alt" content="${esc(meta.imageAlt)}">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${esc(meta.title)}">
<meta name="twitter:description" content="${esc(meta.description)}">
<meta name="twitter:image" content="${esc(meta.image)}">
<meta name="twitter:image:alt" content="${esc(meta.imageAlt)}">
<meta name="theme-color" content="#15122a">
<link rel="icon" href="/static/img/icon.svg" type="image/svg+xml">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible+Mono:wght@400;600&family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/static/style.css">
<link rel="stylesheet" href="/static/social/social.css">
</head>
<body${attrs}>
<a class="skip" href="#main">Skip to content</a>
<header class="bar">
  <a class="brand" href="/"><img src="/static/img/squire.png" alt="" width="16" height="24"><span class="wordmark"><span class="sr">Dunder Quest</span><span aria-hidden="true"><i>__</i>dunder_<wbr>quest<i>__</i></span></span></a>
  <nav aria-label="Site"><a href="/curb/">Curb Your Oxidation</a><a href="/dunder-quest/">Dunder Quest</a><a href="/flatmates/">Flatmates.js</a><a href="/prince/">Prince of Versions</a><a href="/lieutenant/">Just One More JOIN</a><a href="/greedy/">The Good, the Bad and the Greedy</a><a href="/shell/">Yes, Shell!</a><a href="/nothing/">A Game About Nothing</a><a href="/leaderboards/">Leaderboards</a></nav>
  <a class="btn btn-small" href="/curb/play/">Play</a>
</header>
<main id="main">
${body}
</main>
<footer class="foot">
  <p>Dunder Quest: free pixel-art games that teach real programming, in your browser.</p>
  <p><a href="/">All games</a> · <a href="/curb/">Curb Your Oxidation</a> · <a href="/dunder-quest/">Dunder Quest</a> · <a href="/flatmates/">Flatmates.js</a> · <a href="/prince/">Prince of Versions</a> · <a href="/lieutenant/">Just One More JOIN</a> · <a href="/greedy/">The Good, the Bad and the Greedy</a> · <a href="/shell/">Yes, Shell!</a> · <a href="/nothing/">A Game About Nothing</a> · <a href="/leaderboards/">Leaderboards</a> · <a href="/me/">Your progress</a> · <a href="/privacy/">Privacy</a></p>
</footer>
<script type="module" src="/static/social/site.js"></script>
</body>
</html>
`;
}

function html(text: string, status = 200, cache = "public, max-age=60"): Response {
  return new Response(text, { status, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": cache } });
}

function png(bytes: Uint8Array, cache = "public, max-age=86400"): Response {
  return new Response(bytes, { headers: { "Content-Type": "image/png", "Cache-Control": cache } });
}

async function notFound(env: Env, origin: string): Promise<Response> {
  const page = await env.ASSETS.fetch(new Request(`${origin}/404.html`));
  return new Response(page.body, { status: 404, headers: { "Content-Type": "text/html; charset=utf-8" } });
}

/** A short hash for cache-busting image addresses when what they show changes. */
async function version(text: string): Promise<string> {
  const d = await crypto.subtle.digest("SHA-1", new TextEncoder().encode(text));
  return [...new Uint8Array(d).slice(0, 4)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function playButton(game: Game, label = "Play it free"): string {
  return `<a class="btn" href="${GAMES[game].play}">${label}</a><a class="btn btn-ghost" href="${GAMES[game].page}">About ${esc(GAMES[game].name)}</a>`;
}

// ---- Certificates ----

async function certificate(env: Env, id: string): Promise<CertRow | null> {
  return env.DB.prepare("SELECT c.id, c.player_id, c.game, c.name, c.issued_at, c.stats FROM certificates c JOIN players p ON p.id = c.player_id WHERE c.id = ? AND p.hidden = 0")
    .bind(id).first<CertRow>();
}

async function certImage(env: Env, row: CertRow, host: string): Promise<Uint8Array> {
  const cached = await env.DB.prepare("SELECT png, png_design FROM certificates WHERE id = ?").bind(row.id)
    .first<{ png: ArrayBuffer | number[] | null; png_design: number | null }>();
  if (cached?.png && cached.png_design === CERT_DESIGN) return new Uint8Array(cached.png);
  const bytes = await certificatePng(certJson(row) as never, host);
  await env.DB.prepare("UPDATE certificates SET png = ?, png_design = ? WHERE id = ?").bind(bytes, CERT_DESIGN, row.id).run();
  return bytes;
}

export async function certPage(env: Env, url: URL, id: string): Promise<Response> {
  const row = await certificate(env, id);
  if (!row) return notFound(env, url.origin);
  const c = certJson(row);
  const game = c.game as Game;
  const def = GAMES[game];
  const v = await version(`${c.name}|${row.stats}|${CERT_DESIGN}`);
  const pageUrl = `${url.origin}/c/${c.id}`;
  const image = `${url.origin}/c/${c.id}.png?v=${v}`;
  const lessons = def.levels.map((l) => l.lesson);
  const title = `${c.name} finished ${def.name}`;
  const description = `Certificate of completion: ${c.name} finished all ${def.levels.length} ${def.unit[1]} of ${def.name} and learned ${def.lang}, from ${lessons[0]} to ${lessons[lessons.length - 1]}. A free game you can play in your browser.`;
  const s = c.stats;
  const facts = [`Issued ${longDate(c.issued)}`, `${def.levels.length} ${def.unit[1]}`];
  if (def.best === "tries" && s.tries) facts.push(`${s.tries} tries`);
  if (def.best === "time" && s.time) facts.push(`total time ${formatTime(s.time)}`);
  if (def.collectible && s.collectMax) facts.push(`${s.collected} of ${s.collectMax} ${def.collectible[1]}`);
  const shareText = `I finished ${def.name} and learned ${def.lang}! ${def.tag}`;
  const body = `
<section class="section dq-cert-page">
  <p class="kicker">Certificate of completion</p>
  <h1>${esc(title)}</h1>
  <figure class="dq-cert"><img src="/c/${c.id}.png?v=${v}" alt="${esc(`Certificate of completion for ${c.name}: ${def.name}, ${def.lang}`)}" width="1200" height="630"></figure>
  <p class="dq-facts">${facts.map(esc).join(" · ")}</p>
  <div class="cta">
    <a class="btn dq-linkedin-add" href="${esc(linkedInCertUrl({ name: `${def.name}: ${def.lang}`, issued: c.issued, url: pageUrl, id: c.id }))}" target="_blank" rel="noopener">${icon("linkedin")} Add to LinkedIn profile</a>
    <a class="btn btn-ghost" href="/c/${c.id}.png?v=${v}" download="${esc(`${def.name} certificate.png`)}">${icon("download")} Download</a>
    <button type="button" class="btn btn-ghost" data-dq-print>Print</button>
  </div>
  ${shareButtons(shareText, pageUrl)}
  <form class="dq-owner dq-rename" data-cert="${esc(c.id)}" hidden>
    <label>Name on the certificate <input name="name" value="${esc(c.name)}" maxlength="32" minlength="2" required></label>
    <button class="btn btn-small" type="submit">Save</button>
    <span class="dq-status" role="status"></span>
  </form>
  <h2>What this covers</h2>
  <ol class="dq-lessons">${def.levels.map((l) => `<li><b>${esc(l.name)}</b> <span>${esc(l.lesson)}</span></li>`).join("")}</ol>
  <p class="dq-fine">Issued by <a href="/">dunderquest.com</a> when the game's own save showed every ${esc(def.unit[0])} cleared. <a class="dq-by" href="/u/${esc(row.player_id)}">${avatarSvg(row.player_id, 18)}See their profile</a>.</p>
  <div class="cta">${playButton(game, `Play ${esc(def.name)}`)}</div>
</section>`;
  return html(shell(url.origin, { title, description, url: pageUrl, image, imageAlt: `A pixel-art certificate: ${c.name} finished ${def.name}` }, body, { owner: row.player_id, page: "certificate" }));
}

export async function certPng(env: Env, url: URL, id: string): Promise<Response> {
  const row = await certificate(env, id);
  if (!row) return new Response("Not found", { status: 404 });
  return png(await certImage(env, row, url.host), url.searchParams.has("v") ? "public, max-age=31536000, immutable" : "public, max-age=300");
}

// ---- Profiles ----

async function player(env: Env, id: string): Promise<PlayerRow | null> {
  return env.DB.prepare("SELECT * FROM players WHERE id = ? AND hidden = 0").bind(id).first<PlayerRow>();
}

export async function profilePage(env: Env, url: URL, id: string): Promise<Response> {
  const p = await player(env, id);
  if (!p) return notFound(env, url.origin);
  const saves = await savesOf(env, p.id);
  const certs = (await certsOf(env, p.id)).map(certJson);
  const board = await leaderboard(env, "all", 1, p);
  const pub = publicPlayer(p);
  const total = ORDER.reduce((n, g) => n + GAMES[g as Game].levels.length, 0);
  const v = await version(`${p.name}|${p.xp}|${p.levels}`);
  const pageUrl = `${url.origin}/u/${p.id}`;
  const games = ORDER.map((key) => {
    const g = key as Game;
    const def = GAMES[g];
    const row = saves.find((r) => r.game === g);
    const s = summarize(g, row?.data ?? null);
    const cert = certs.find((c) => c.game === g);
    const levels = def.levels.map((l) => `<li class="${s.cleared.includes(l.id) ? "done" : ""}" title="${esc(l.lesson)}">${esc(l.name)}</li>`).join("");
    const best = bestLine(g, s);
    return `<article class="dq-game-card" style="--accent:${def.accent}">
      <header><h3><a href="${def.page}">${esc(def.name)}</a></h3><span class="dq-lang">${esc(def.lang)}</span></header>
      <div class="dq-bar" role="img" aria-label="${s.count} of ${s.total} ${def.unit[1]}"><span style="width:${Math.round((100 * s.count) / s.total)}%"></span></div>
      <p class="dq-count">${s.count} of ${s.total} ${def.unit[1]}${best ? ` · ${esc(best)}` : ""}${s.collectMax ? ` · ${s.collected}/${s.collectMax} ${def.collectible[1]}` : ""}</p>
      <ul class="dq-levels">${levels}</ul>
      ${cert ? `<a class="dq-cert-link" href="/c/${cert.id}">${icon("trophy")} Certificate</a>` : `<a class="dq-play-link" href="${def.play}">${s.count ? "Keep playing" : "Play"}</a>`}
    </article>`;
  }).join("");
  const rank = board?.me?.rank;
  const title = `${p.name} on Dunder Quest`;
  const description = `${p.name} has ${p.xp.toLocaleString("en-US")} XP: ${p.levels} of ${total} levels cleared${p.completed ? ` and ${p.completed} ${p.completed === 1 ? "game" : "games"} finished` : ""} in free games that teach Rust, Python, JavaScript, Git and SQL.`;
  const body = `
<section class="section dq-profile">
  <p class="kicker">Player${rank ? ` · #${rank} overall` : ""}</p>
  <div class="dq-me-head">${avatarSvg(p.id, 64)}<h1>${esc(p.name)}</h1></div>
  <p class="dq-stats"><b>${p.xp.toLocaleString("en-US")}</b> XP · <b>${p.levels}</b> of ${total} levels · <b>${p.completed}</b> ${p.completed === 1 ? "game" : "games"} finished</p>
  ${shareButtons(`My progress learning to code on Dunder Quest: ${p.xp.toLocaleString("en-US")} XP so far.`, pageUrl)}
  <p class="dq-owner" hidden>This is you, as everyone else sees you. <a class="btn btn-small" href="/me/">Your progress and settings</a></p>
  <div class="dq-games">${games}</div>
  ${certs.length ? `<h2>Certificates</h2><div class="dq-cert-grid">${certs.map((c) => `<a href="/c/${c.id}"><img src="/c/${c.id}.png" alt="${esc(`${GAMES[c.game as Game].name} certificate`)}" width="600" height="315" loading="lazy"></a>`).join("")}</div>` : ""}
  <p class="dq-fine">Playing since ${longDate(pub.since)}. <a href="/leaderboards/">See the leaderboards</a>.</p>
</section>`;
  return html(shell(url.origin, { title, description, url: pageUrl, image: `${url.origin}/u/${p.id}.png?v=${v}`, imageAlt: `${p.name}'s progress in every Dunder Quest game` }, body, { owner: p.id, page: "profile" }), 200, "public, max-age=30");
}

export async function profileImage(env: Env, url: URL, id: string, ctx: ExecutionContext): Promise<Response> {
  const cache = (globalThis as { caches?: { default: Cache } }).caches?.default;
  const hit = await cache?.match(url.toString());
  if (hit) return hit;
  const p = await player(env, id);
  if (!p) return new Response("Not found", { status: 404 });
  const games: CardGame[] = (await savesOf(env, p.id)).map((r) => {
    const s = summarize(r.game as Game, r.data);
    return { game: r.game, count: s.count, total: s.total, complete: s.complete };
  });
  const res = png(await profilePng(p, games, url.host), url.searchParams.has("v") ? "public, max-age=31536000, immutable" : "public, max-age=300");
  if (cache) ctx.waitUntil(cache.put(url.toString(), res.clone()));
  return res;
}

// ---- Screenshots ----

async function shot(env: Env, id: string): Promise<(ShotRow & { name: string }) | null> {
  return env.DB.prepare(
    "SELECT s.id, s.player_id, s.game, s.caption, s.type, s.width, s.height, s.created_at, p.name FROM shots s JOIN players p ON p.id = s.player_id WHERE s.id = ? AND s.hidden = 0 AND p.hidden = 0",
  ).bind(id).first<ShotRow & { name: string }>();
}

export async function shotPage(env: Env, url: URL, id: string): Promise<Response> {
  const s = await shot(env, id);
  if (!s) return notFound(env, url.origin);
  const game = s.game as Game;
  const def = GAMES[game];
  const ext = s.type === "image/png" ? "png" : "jpg";
  const pageUrl = `${url.origin}/s/${s.id}`;
  const caption = s.caption || `A moment from ${def.name}`;
  const title = caption.length > 90 ? `${caption.slice(0, 87)}…` : caption;
  const description = `Shared by ${s.name} from ${def.name}, a free pixel-art game that teaches ${def.lang}. Play it in your browser.`;
  const body = `
<section class="section dq-shot-page">
  <p class="kicker"><a href="${def.page}">${esc(def.name)}</a> · ${esc(def.lang)}</p>
  <figure class="dq-shot"><img src="/s/${s.id}.${ext}" alt="${esc(caption)}" width="${s.width}" height="${s.height}">
    <figcaption>${esc(caption)}<span>Shared by <a class="dq-by" href="/u/${esc(s.player_id)}">${avatarSvg(s.player_id, 18)}${esc(s.name)}</a> · ${longDate(s.created_at)}</span></figcaption></figure>
  ${shareButtons(caption, pageUrl)}
  <p class="dq-owner" hidden><button type="button" class="btn btn-small btn-ghost" data-dq-delete-shot="${esc(s.id)}">Delete this screenshot</button></p>
  <div class="cta">${playButton(game)}</div>
</section>`;
  return html(shell(url.origin, {
    title: `${title} · ${def.name}`, description, url: pageUrl, image: `${url.origin}/s/${s.id}.${ext}`,
    imageAlt: caption, width: s.width, height: s.height,
  }, body, { owner: s.player_id, page: "shot" }), 200, "public, max-age=300");
}

export async function shotImage(env: Env, id: string): Promise<Response> {
  const row = await env.DB.prepare("SELECT s.type, s.image FROM shots s JOIN players p ON p.id = s.player_id WHERE s.id = ? AND s.hidden = 0 AND p.hidden = 0").bind(id).first<{ type: string; image: ArrayBuffer | number[] }>();
  if (!row) return new Response("Not found", { status: 404 });
  // D1 has handed blobs back both as ArrayBuffers and as arrays of numbers.
  return new Response(new Uint8Array(row.image), { headers: { "Content-Type": row.type, "Cache-Control": "public, max-age=31536000, immutable" } });
}
