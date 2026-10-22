import { createRemoteJWKSet, jwtVerify } from "jose";

/**
 * Cloudflare Access signs in the viewer before a request reaches the Worker
 * and attaches a signed token. Checking it here means the admin area stays shut
 * even if the Access policy is ever removed or the workers.dev URL is used.
 */
const keySets = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function keySet(teamDomain: string) {
  let keys = keySets.get(teamDomain);
  if (!keys) {
    keys = createRemoteJWKSet(new URL(`https://${teamDomain}/cdn-cgi/access/certs`));
    keySets.set(teamDomain, keys);
  }
  return keys;
}

export type Viewer = { email: string };

/** The signed-in viewer, or a Response explaining why they were turned away. */
export async function checkAccess(request: Request, env: Env): Promise<Viewer | Response> {
  const url = new URL(request.url);
  if (env.AUTH_DISABLED === "true" && (url.hostname === "localhost" || url.hostname === "127.0.0.1")) {
    return { email: "local@dev" };
  }
  const teamDomain: string = env.ACCESS_TEAM_DOMAIN;
  const audience: string = env.ACCESS_AUD;
  if (!teamDomain || !audience) {
    return new Response("Stats are locked: set ACCESS_TEAM_DOMAIN and ACCESS_AUD in wrangler.jsonc.", { status: 503 });
  }
  const token = request.headers.get("Cf-Access-Jwt-Assertion");
  if (!token) return new Response("Sign in through Cloudflare Access.", { status: 401 });
  try {
    const { payload } = await jwtVerify(token, keySet(teamDomain), {
      issuer: `https://${teamDomain}`,
      audience,
    });
    const email = typeof payload.email === "string" ? payload.email.toLowerCase() : "";
    const allowed = env.ALLOWED_EMAILS.toLowerCase().split(",").map((e) => e.trim());
    if (!email || !allowed.includes(email)) return new Response("Not on the list.", { status: 403 });
    return { email };
  } catch {
    return new Response("Sign in through Cloudflare Access.", { status: 401 });
  }
}
