// Share links for each network, built the same way on the server (the
// certificate, profile and screenshot pages) and in the browser (the
// screenshot composer). Every one of them opens the network's own compose
// window with the text and link filled in; nothing is posted for the player.

/** [key, label, url builder] for each network, in the order the buttons show. */
export const NETWORKS = [
  ["x", "X", (text, url) => `https://x.com/intent/post?text=${encodeURIComponent(text)}&url=${encodeURIComponent(url)}`],
  ["linkedin", "LinkedIn", (_text, url) => `https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(url)}`],
  ["bluesky", "Bluesky", (text, url) => `https://bsky.app/intent/compose?text=${encodeURIComponent(`${text} ${url}`)}`],
  ["facebook", "Facebook", (_text, url) => `https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(url)}`],
  ["threads", "Threads", (text, url) => `https://www.threads.net/intent/post?text=${encodeURIComponent(`${text} ${url}`)}`],
  ["reddit", "Reddit", (text, url) => `https://www.reddit.com/submit?url=${encodeURIComponent(url)}&title=${encodeURIComponent(text)}`],
  ["whatsapp", "WhatsApp", (text, url) => `https://wa.me/?text=${encodeURIComponent(`${text} ${url}`)}`],
  ["email", "Email", (text, url) => `mailto:?subject=${encodeURIComponent(text)}&body=${encodeURIComponent(`${text}\n\n${url}`)}`],
];

/** Small single-color icons (24x24 paths) so the buttons need no image requests. */
export const ICONS = {
  x: "M17.8 3h3.1l-6.8 7.8L22 21h-6.2l-4.9-6.4L5.3 21H2.2l7.3-8.3L1.8 3h6.4l4.4 5.8L17.8 3zm-1.1 16.2h1.7L7.4 4.7H5.6l11.1 14.5z",
  linkedin: "M4.98 3.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5zM3 9h4v12H3zM9 9h3.8v1.7h.1c.5-1 1.8-2 3.8-2 4 0 4.8 2.6 4.8 6V21h-4v-5.5c0-1.3 0-3-1.9-3s-2.2 1.4-2.2 2.9V21H9z",
  bluesky: "M5.2 3.6C7.6 5.4 10.2 9 11.2 11c1-2 3.6-5.6 6-7.4 1.7-1.3 4.5-2.3 4.5.9 0 .6-.4 5.3-.6 6-.8 2.6-3.4 3.3-5.8 2.9 4.2.7 5.2 3.1 2.9 5.4-4.4 4.5-6.3-1.1-6.8-2.5l-.2-.5-.2.5c-.5 1.4-2.4 7-6.8 2.5-2.3-2.3-1.3-4.7 2.9-5.4-2.4.4-5-.3-5.8-2.9-.2-.7-.6-5.4-.6-6 0-3.2 2.8-2.2 4.5-.9z",
  facebook: "M14 8.5V6.8c0-.8.2-1.3 1.4-1.3H17V2.3c-.3 0-1.3-.1-2.5-.1-2.5 0-4.2 1.5-4.2 4.3v2H7.5V12h2.8v9.8H14V12h2.8l.4-3.5z",
  threads: "M16.7 11.2c-.1 0-.2-.1-.3-.1-.2-3-1.8-4.7-4.6-4.7-1.7 0-3.1.7-3.9 2l1.5 1c.6-.9 1.6-1.1 2.4-1.1 1 0 1.7.3 2.1.8.3.4.5.9.6 1.5-.8-.1-1.6-.2-2.5-.1-2.5.1-4.1 1.6-4 3.6.1 1 .6 1.9 1.4 2.4.7.5 1.6.7 2.6.6 1.3-.1 2.3-.6 3-1.4.5-.7.9-1.5 1-2.6.6.4 1.1.8 1.3 1.4.5 1 .5 2.7-.9 4.1-1.2 1.2-2.7 1.8-4.9 1.8-2.5 0-4.3-.8-5.5-2.3-1.1-1.4-1.7-3.4-1.7-6s.6-4.6 1.7-6c1.2-1.5 3-2.3 5.5-2.3s4.4.8 5.6 2.3c.6.7 1 1.7 1.3 2.7l1.8-.5c-.3-1.3-.9-2.5-1.7-3.4C17.1 2.9 14.7 2 11.8 2 8.8 2 6.6 3 5.1 4.9 3.8 6.6 3.1 8.9 3.1 12s.7 5.4 2 7.1C6.6 21 8.8 22 11.8 22c2.7 0 4.5-.7 6.1-2.2 2-2 2-4.5 1.3-6.1-.4-1-1.3-1.9-2.5-2.5zm-4.4 4.2c-1.1.1-2.2-.4-2.2-1.4 0-.8.5-1.6 2.3-1.7h.6c.6 0 1.2.1 1.8.2-.2 2.4-1.4 2.8-2.5 2.9z",
  reddit: "M22 12.1a2.2 2.2 0 0 0-3.7-1.6 10.8 10.8 0 0 0-5.8-1.8l1-4.6 3.2.7a1.6 1.6 0 1 0 .2-1l-3.6-.8a.5.5 0 0 0-.6.4l-1.1 5.3c-2.2 0-4.3.7-5.9 1.8a2.2 2.2 0 1 0-2.4 3.6v.6c0 3.4 3.9 6.1 8.7 6.1s8.7-2.7 8.7-6.1v-.6a2.2 2.2 0 0 0 1.3-2zM7.2 13.6a1.6 1.6 0 1 1 3.2 0 1.6 1.6 0 0 1-3.2 0zm8.8 4.2c-1.1.8-2.5 1.2-4 1.2s-2.9-.4-4-1.2a.4.4 0 0 1 .5-.6c.9.6 2.2 1 3.5 1s2.6-.4 3.5-1a.4.4 0 0 1 .5.6zm-.3-2.6a1.6 1.6 0 1 1 0-3.2 1.6 1.6 0 0 1 0 3.2z",
  whatsapp: "M12 2a10 10 0 0 0-8.6 15l-1.4 5 5.2-1.4A10 10 0 1 0 12 2zm5.8 14.1c-.2.7-1.4 1.3-2 1.4-.5.1-1.2.1-1.9-.1l-1.8-.7c-3.1-1.3-5.1-4.5-5.3-4.7-.2-.2-1.3-1.7-1.3-3.2s.8-2.3 1.1-2.6c.3-.3.6-.4.8-.4h.6c.2 0 .4 0 .6.5l.9 2.1c.1.2.1.3 0 .5l-.3.5-.4.5c-.1.1-.3.3-.1.6.2.3.8 1.3 1.7 2.1 1.2 1 2.1 1.4 2.4 1.5.3.1.5.1.7-.1l1-1.2c.2-.3.4-.2.7-.1l2 1c.3.1.5.2.5.3.1.2.1.7-.1 1.4z",
  email: "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1V6a1 1 0 0 1 1-1zm9 7.1L4.4 7H4v.6l8 5.4 8-5.4V7h-.4L12 12.1z",
  link: "M10.6 13.4a1 1 0 0 1 0-1.4l3.5-3.5a3 3 0 0 1 4.2 4.2l-2.1 2.1a1 1 0 1 1-1.4-1.4l2.1-2.1a1 1 0 0 0-1.4-1.4L12 13.4a1 1 0 0 1-1.4 0zm2.8-2.8a1 1 0 0 1 0 1.4l-3.5 3.5a3 3 0 0 1-4.2-4.2l2.1-2.1a1 1 0 1 1 1.4 1.4l-2.1 2.1a1 1 0 0 0 1.4 1.4l3.5-3.5a1 1 0 0 1 1.4 0z",
  share: "M18 16a3 3 0 0 0-2.4 1.2l-6.7-3.4a3 3 0 0 0 0-1.6l6.7-3.4A3 3 0 1 0 15 7l-6.7 3.4a3 3 0 1 0 0 3.2L15 17a3 3 0 1 0 3-1z",
  download: "M11 3h2v9.6l3.3-3.3 1.4 1.4L12 16.4l-5.7-5.7 1.4-1.4 3.3 3.3V3zM4 18h16v2H4z",
  camera: "M9 4h6l1.5 2H20a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h3.5L9 4zm3 4.5a4.5 4.5 0 1 0 0 9 4.5 4.5 0 0 0 0-9zm0 2a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z",
  trophy: "M7 3h10v2h3v3a4 4 0 0 1-4.1 4A5 5 0 0 1 13 14.9V18h3v2H8v-2h3v-3.1A5 5 0 0 1 8.1 12 4 4 0 0 1 4 8V5h3V3zm0 4H6v1a2 2 0 0 0 1.2 1.8A5 5 0 0 1 7 8.5V7zm10 0v1.5c0 .5 0 .9-.2 1.3A2 2 0 0 0 18 8V7h-1z",
  user: "M12 12a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9zm0 2c-4.4 0-8 2.2-8 5v2h16v-2c0-2.8-3.6-5-8-5z",
};

export function icon(name, size = 18) {
  return `<svg class="dq-icon" viewBox="0 0 24 24" width="${size}" height="${size}" aria-hidden="true" focusable="false"><path fill="currentColor" d="${ICONS[name]}"/></svg>`;
}

const escAttr = (s) => String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

/**
 * A row of share buttons as HTML. The page's script adds the native share
 * sheet (on phones) and copy-link behaviour to the buttons marked data-share.
 */
export function shareButtons(text, url, { networks = NETWORKS.map((n) => n[0]) } = {}) {
  const links = NETWORKS.filter(([key]) => networks.includes(key)).map(([key, label, build]) =>
    `<a class="dq-share-btn dq-share-${key}" href="${escAttr(build(text, url))}" target="_blank" rel="noopener" title="Share on ${label}">${icon(key)}<span>${label}</span></a>`);
  return `<div class="dq-share" data-share-text="${escAttr(text)}" data-share-url="${escAttr(url)}">`
    + `<button type="button" class="dq-share-btn dq-share-native" data-share="native" hidden>${icon("share")}<span>Share…</span></button>`
    + links.join("")
    + `<button type="button" class="dq-share-btn" data-share="copy">${icon("link")}<span>Copy link</span></button>`
    + "</div>";
}

/** LinkedIn's "Add licence or certification" form, filled in. */
export function linkedInCertUrl({ name, issued, url, id }) {
  const d = new Date(issued * 1000);
  const q = new URLSearchParams({
    startTask: "CERTIFICATION_NAME",
    name,
    organizationName: "Dunder Quest",
    issueYear: String(d.getUTCFullYear()),
    issueMonth: String(d.getUTCMonth() + 1),
    certUrl: url,
    certId: id,
  });
  return `https://www.linkedin.com/profile/add?${q}`;
}
