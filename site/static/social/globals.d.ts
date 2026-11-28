// What the social layer finds on window: Google's sign-in script, Cloudflare
// Turnstile, and the bridge play.ts puts there for the games.

/** The part of Google Identity Services the sign-in button uses. */
interface GoogleIdentity {
  accounts: {
    id: {
      initialize(options: {
        client_id: string;
        auto_select?: boolean;
        cancel_on_tap_outside?: boolean;
        callback: (response: { credential: string }) => void;
      }): void;
      renderButton(el: HTMLElement, options: Record<string, string>): void;
    };
  };
}

/** The part of Cloudflare Turnstile the feedback form uses. */
interface Turnstile {
  render(el: HTMLElement, options: Record<string, unknown>): string;
  reset(widget: string): void;
}

/** The bridge each game's Social autoload calls through JavaScriptBridge. */
interface DQSocialBridge {
  boot(game: string, local: string): string;
  attach(game: string, local: string): void;
  saved(game: string, text: string): void;
  screenshot(): void;
  version: number;
}

interface Window {
  google?: GoogleIdentity;
  turnstile?: Turnstile;
  DQSocial?: DQSocialBridge;
}
