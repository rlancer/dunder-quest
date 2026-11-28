// The feedback form: on every play page (the speech bubble in the toolbar,
// as a dialog, so the game stays where it was) and on /feedback/ (in the
// page). It posts to /api/feedback, which needs no player: a guest can send
// it too. Rob reads it on the admin area's Feedback page.

import { api } from "./client.js";
import { FEEDBACK_KINDS, FEEDBACK_MAX, GAMES, ORDER } from "./games.js";
import { dialog, h } from "./ui.js";

const DRAFT = "dq.feedback.draft";

const PROMPTS = {
  bug: "What happened, and what did you expect? Which level were you on?",
  stuck: "Where are you stuck, and what have you tried?",
  idea: "What would make it better?",
  praise: "What did you like?",
  other: "What's on your mind?",
};

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
 * Builds the form into `root`. `game` preselects a game ('' for the site in
 * general); `context` is a line the sender doesn't type (the level they're
 * on), kept with the message. `onDone` runs after "Back to the game".
 */
export function feedbackForm(root, { game = "", context = "", onDone = null } = {}) {
  const draft = loadDraft();
  const about = h("select", { name: "game", "aria-label": "What it's about" },
    h("option", { value: "" }, "The site in general"),
    ORDER.map((k) => h("option", { value: k }, GAMES[k].name)));
  about.value = game && GAMES[game] ? game : "";

  const kinds = h("div.dq-chips", { role: "radiogroup", "aria-label": "What kind of feedback" },
    Object.entries(FEEDBACK_KINDS).map(([key, label], i) => h("label.dq-chip-opt", {},
      h("input", { type: "radio", name: "kind", value: key, checked: (draft.kind || "bug") === key || (!FEEDBACK_KINDS[draft.kind] && i === 0) }),
      h("span", {}, label))));

  let rating = 0;
  const stars = h("div.dq-stars", { role: "radiogroup", "aria-label": "How you're finding it, out of 5" },
    [1, 2, 3, 4, 5].map((n) => h("button.dq-star", {
      type: "button", role: "radio", "aria-checked": "false", "aria-label": `${n} out of 5`, "data-n": n,
      onclick: () => setRating(rating === n ? 0 : n),
    }, "★")));
  function setRating(n) {
    rating = n;
    for (const b of stars.children) {
      const on = Number(b.dataset.n) <= n;
      b.classList.toggle("dq-on", on);
      b.setAttribute("aria-checked", String(Number(b.dataset.n) === n));
    }
  }

  const message = h("textarea", { name: "message", rows: 5, maxlength: FEEDBACK_MAX, required: true, "aria-label": "Your feedback" });
  message.value = draft.message || "";
  const contact = h("input", { name: "contact", type: "text", maxlength: 200, autocomplete: "email", placeholder: "you@example.com", value: draft.contact || "" });
  // A box people never see; bots fill in every box they find.
  const trap = h("input", { name: "website", type: "text", tabindex: "-1", autocomplete: "off", "aria-hidden": "true" });
  const status = h("p.dq-status", { role: "status" });
  const send = h("button.dq-btn.dq-primary", { type: "submit" }, "Send");

  const kind = () => kinds.querySelector("input:checked")?.value || "other";
  const prompt = () => (message.placeholder = PROMPTS[kind()]);
  prompt();
  const keep = () => saveDraft({ kind: kind(), message: message.value, contact: contact.value });
  kinds.addEventListener("change", () => {
    prompt();
    keep();
  });
  message.addEventListener("input", keep);
  contact.addEventListener("input", keep);

  const form = h("form.dq-feedback", {
    onsubmit: async (e) => {
      e.preventDefault();
      if (message.value.trim().length < 3) {
        status.textContent = "Write a few words first.";
        message.focus();
        return;
      }
      send.disabled = true;
      status.textContent = "Sending…";
      try {
        await api("POST", "/api/feedback", {
          game: about.value, kind: kind(), rating: rating || null, message: message.value, contact: contact.value,
          page: location.pathname, context, website: trap.value,
        });
        saveDraft(null);
        thanks();
      } catch (err) {
        status.textContent = err.message;
        send.disabled = false;
      }
    },
  },
    h("div.dq-field", {}, h("span.dq-label", {}, "About"), about),
    h("div.dq-field", {}, h("span.dq-label", {}, "What kind"), kinds),
    h("div.dq-field", {}, h("label", {}, h("span.dq-label", {}, "Tell us"), message)),
    h("div.dq-field", {}, h("span.dq-label", {}, "How are you finding it? (optional)"), stars),
    h("div.dq-field", {}, h("label", {}, h("span.dq-label", {}, "Want a reply? Leave an email (optional)"), contact)),
    h("div.dq-trap", { "aria-hidden": "true" }, h("label", {}, "Leave this empty ", trap)),
    h("p.dq-fine", {}, "We also keep the page you sent it from, your browser's name and, if you have one, your player name. ",
      h("a", { href: "/privacy/", target: "_blank" }, "Privacy")),
    h("div.dq-actions", {}, send, onDone ? h("button.dq-btn", { type: "button", onclick: onDone }, "Cancel") : null),
    status);

  function thanks() {
    root.replaceChildren(
      h("p.dq-thanks", {}, "Thank you! Rob reads every one of these."),
      h("p.dq-fine", {}, contact.value.trim() ? "If it needs an answer, you'll get one by email." : "It's anonymous, so we can't write back, but it's read."),
      h("div.dq-actions", {},
        onDone ? h("button.dq-btn.dq-primary", { type: "button", onclick: onDone }, "Back to the game") : null,
        h("button.dq-btn", { type: "button", onclick: () => feedbackForm(root, { game: about.value, context, onDone }) }, "Send more")));
  }

  root.replaceChildren(form);
  return form;
}

/** The form in a dialog, over a game. */
export function openFeedback({ game = "", context = "", onClose } = {}) {
  const { body, close } = dialog("Send feedback", { onClose, className: "dq-feedback-dialog" });
  feedbackForm(body, { game, context, onDone: close });
  body.querySelector("textarea")?.focus();
}
