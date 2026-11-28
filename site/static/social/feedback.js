// The feedback form: on every play page (the speech bubble in the toolbar,
// as a dialog, so the game stays where it was) and on /feedback/ (in the
// page). It posts to /api/feedback, which needs no player: a guest can send
// it too. Only Rob reads it, on the admin area's Feedback page; players never
// see each other's.
//
// Spam defence: a hidden box bots fill in (`website`), the Worker's per-IP
// rate limit, and Cloudflare Turnstile once the site has a widget (its site
// key comes from /api/config; without one the form works without it).

import { api, getConfig } from "./client.js";
import { FEEDBACK_KINDS, FEEDBACK_MAX, GAMES, ORDER } from "./games.js";
import { dialog, h } from "./ui.js";

const DRAFT = "dq.feedback.draft";

const PROMPTS = {
  bug: "What happened, and what did you expect?",
  stuck: "Where are you stuck, and what have you tried?",
  idea: "What would make it better?",
  praise: "What did you like?",
  other: "What's on your mind?",
};

const CHECK = '<svg class="dq-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><path d="M4 12l5 5L20 6"/></svg>';
const TICK = '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" aria-hidden="true"><path d="M5 12l5 5L19 7"/></svg>';

function loadDraft() {
  try {
    return JSON.parse(localStorage.getItem(DRAFT) || "null") || {};
  } catch {
    return {};
  }
}

function saveDraft(draft) {
  try {
    if (draft) localStorage.setItem(DRAFT, JSON.stringify(draft));
    else localStorage.removeItem(DRAFT);
  } catch {}
}

/**
 * Where a player has got to in a game, as a line kept with their feedback:
 * the level they're up to and how many they've cleared, e.g. "Scene 3, The
 * Regift (2 of 10 cleared)". `summary` is games.js's summarize().
 */
export function progressLine(game, summary) {
  const def = GAMES[game];
  if (!def || !summary) return "";
  const { count, total, complete, cleared } = summary;
  if (complete) return `Finished (${total} of ${total})`;
  const index = def.levels.findIndex((l) => !cleared.includes(l.id));
  const level = def.levels[index];
  if (!level) return `${count} of ${total} cleared`;
  const unit = def.unit[0][0].toUpperCase() + def.unit[0].slice(1);
  return `${unit} ${index + 1}, ${level.name} (${count} of ${total} cleared)`;
}

let turnstileScript = null;

function loadTurnstile() {
  if (!turnstileScript) {
    turnstileScript = new Promise((resolve, reject) => {
      const s = document.createElement("script");
      s.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
      s.async = true;
      s.onload = () => resolve(window.turnstile);
      s.onerror = () => {
        turnstileScript = null;
        reject(new Error("Couldn't load the bot check."));
      };
      document.head.append(s);
    });
  }
  return turnstileScript;
}

/**
 * Builds the form into `root`.
 * - `game` preselects a game ('' for the site in general).
 * - `context` is a line the sender doesn't type (where they are in the game),
 *   kept with the message. With a context the game is shown as "Sent with: …"
 *   and the picker hides behind a Change link, as in a game's dialog.
 * - `rating` shows the "How's the game so far?" stars.
 * - `onDone` closes the dialog: the "Back to the game" buttons.
 */
export function feedbackForm(root, { game = "", context = "", kind: firstKind = "bug", rating: withRating = false, onDone = null } = {}) {
  const draft = loadDraft();
  const startGame = game && GAMES[game] ? game : "";
  const inGame = Boolean(onDone && startGame);

  const about = h("select", { name: "game" },
    h("option", { value: "" }, "The site in general"),
    ORDER.map((k) => h("option", { value: k }, GAMES[k].name)));
  about.value = startGame;
  const aboutField = h("label.dq-fb-field", {}, h("span.dq-label", {}, "About"), about);

  // In a game: the game and where they are, with the picker behind Change.
  let sentWith = null;
  if (inGame) {
    aboutField.hidden = true;
    sentWith = h("div.dq-fb-context", {},
      h("span", { html: CHECK }),
      h("span", {}, "Sent with: ", h("b", {}, GAMES[startGame].name), context ? `, ${context[0].toLowerCase()}${context.slice(1)}` : ""),
      h("a", {
        href: "#", onclick: (e) => {
          e.preventDefault();
          sentWith.hidden = true;
          aboutField.hidden = false;
          about.focus();
        },
      }, "Change"));
  }

  let kind = FEEDBACK_KINDS[draft.kind] ? draft.kind : firstKind;
  const kinds = h("div.dq-fb-kinds", { role: "radiogroup", "aria-label": "What it's about" },
    Object.entries(FEEDBACK_KINDS).map(([key, label]) => h("button.dq-fb-kind", {
      type: "button", role: "radio", "data-kind": key, onclick: () => setKind(key),
    }, label)));
  function setKind(key) {
    kind = key;
    for (const b of kinds.children) b.setAttribute("aria-checked", String(b.dataset.kind === key));
    message.placeholder = PROMPTS[key];
    keep();
  }

  let rating = 0;
  const stars = h("div.dq-fb-stars", { role: "radiogroup", "aria-label": "Rating out of 5" },
    [1, 2, 3, 4, 5].map((n) => h("button.dq-fb-star", {
      type: "button", role: "radio", "aria-checked": "false", "aria-label": `${n} out of 5`, "data-n": n,
      onclick: () => setRating(rating === n ? 0 : n),
    }, "★")));
  function setRating(n) {
    rating = n;
    for (const b of stars.children) {
      b.classList.toggle("dq-on", Number(b.dataset.n) <= n);
      b.setAttribute("aria-checked", String(Number(b.dataset.n) === n));
    }
  }

  const message = h("textarea", { name: "message", rows: inGame ? 4 : 6, maxlength: FEEDBACK_MAX });
  message.value = draft.message || "";
  const contact = h("input", { name: "contact", type: "email", maxlength: 200, autocomplete: "email", placeholder: "you@example.com" });
  contact.value = draft.contact || "";
  // A box people never see; bots fill in every box they find.
  const trap = h("input", { name: "website", type: "text", tabindex: "-1", autocomplete: "off" });
  const status = h("p.dq-status.dq-fb-status", { role: "status" });
  const send = h("button.dq-btn.dq-primary.dq-fb-send", { type: "submit" }, "Send");

  // Turnstile, if the site has a widget: drawn when the config says so.
  const bot = h("div.dq-fb-turnstile");
  let botToken = "";
  let botWidget = null;
  getConfig().then(async ({ turnstile: siteKey }) => {
    if (!siteKey) return bot.remove();
    const ts = await loadTurnstile();
    botWidget = ts.render(bot, {
      sitekey: siteKey,
      theme: "dark",
      size: "flexible",
      action: "feedback",
      callback: (t) => (botToken = t),
      "expired-callback": () => (botToken = ""),
      "error-callback": () => {
        botToken = "";
      },
    });
  }).catch((err) => {
    status.textContent = err.message;
  });
  const resetBot = () => {
    botToken = "";
    if (botWidget !== null) window.turnstile?.reset(botWidget);
  };

  function keep() {
    saveDraft({ kind, message: message.value, contact: contact.value });
  }
  message.addEventListener("input", keep);
  contact.addEventListener("input", keep);

  const back = onDone ? h("button.dq-btn", { type: "button", onclick: onDone }, "Back to the game") : null;

  const form = h("form.dq-fb", {
    noValidate: true,
    onsubmit: async (e) => {
      e.preventDefault();
      if (message.value.trim().length < 3) {
        status.textContent = "Write a few words first.";
        message.focus();
        return;
      }
      if (contact.value.trim() && !contact.checkValidity()) {
        status.textContent = "That email doesn't look right. Leave it empty to stay anonymous.";
        contact.focus();
        return;
      }
      send.disabled = true;
      status.textContent = "Sending…";
      try {
        await api("POST", "/api/feedback", {
          game: about.value,
          kind,
          rating: withRating && about.value && rating ? rating : null,
          message: message.value,
          contact: contact.value.trim(),
          page: location.pathname,
          // Where they are only means something in the game it was measured in.
          context: about.value === startGame ? context : "",
          website: trap.value,
          turnstile: botToken,
        });
        saveDraft(null);
        thanks(Boolean(contact.value.trim()));
      } catch (err) {
        status.textContent = err.message;
        send.disabled = false;
        resetBot();
      }
    },
  },
    sentWith,
    aboutField,
    h("fieldset.dq-fb-field", {}, h("legend.dq-label", {}, "What's it about?"), kinds),
    h("label.dq-fb-field", {}, h("span.dq-label", {}, "Tell us"), message),
    h("div.dq-fb-row", {},
      withRating ? h("div.dq-fb-field.dq-fb-rating", {}, h("span.dq-label", {}, "How's the game so far? (optional)"), stars) : null,
      h("label.dq-fb-field.dq-fb-email", {}, h("span.dq-label", {}, "Want a reply? Email (optional)"), contact)),
    h("div.dq-fb-trap", { "aria-hidden": "true" }, h("label", {}, "Leave this empty ", trap)),
    h("p.dq-fine.dq-fb-fine", {},
      inGame
        ? "We also keep the page you sent it from and your browser's name. No sign-up, and your email is only used to answer you. "
        : "We also keep the page you sent it from and your browser's name. Your email is only used to answer you. ",
      h("a", { href: "/privacy/", target: inGame ? "_blank" : null }, "Privacy")),
    bot,
    h("div.dq-actions.dq-fb-actions", {}, send, back),
    status);

  function thanks(withEmail) {
    root.replaceChildren(h("div.dq-fb-thanks", { tabindex: "-1" },
      h("div.dq-fb-thanks-head", {},
        h("span.dq-fb-tick", { html: TICK, "aria-hidden": "true" }),
        h("h3", {}, "Thank you!")),
      h("p", {}, withEmail
        ? "Rob reads every one of these. You left an email, so if it needs an answer, you'll get one there."
        : "Rob reads every one of these. It's anonymous, so we can't write back unless you left an email."),
      h("div.dq-actions", {},
        onDone ? h("button.dq-btn.dq-primary", { type: "button", onclick: onDone }, "Back to the game") : null,
        h("button.dq-btn", {
          type: "button",
          onclick: () => feedbackForm(root, { game: about.value, context: about.value === startGame ? context : "", kind: firstKind, rating: withRating, onDone }),
        }, "Send more"))));
    root.firstChild.focus();
  }

  setKind(kind);
  root.replaceChildren(form);
  return form;
}

/** The form in a dialog, over a game. */
export function openFeedback({ game = "", context = "", onClose } = {}) {
  const { body, close } = dialog("Send feedback", { onClose, className: "dq-fb-dialog" });
  feedbackForm(body, { game, context, rating: Boolean(game), onDone: close });
  body.querySelector("textarea")?.focus();
}
