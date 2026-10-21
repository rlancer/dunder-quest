declare namespace Cloudflare {
  interface Env {
    /** Set in .dev.vars only. Skips the Access check for localhost requests. */
    AUTH_DISABLED?: string;
  }
}
