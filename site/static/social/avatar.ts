// A player's avatar: a little pixel sprite drawn from their id, so every
// player has one without uploading anything (we keep nothing from Google,
// picture included). The same id always gives the same sprite, here and in
// the Worker's pages (deploy/src/pages.ts imports this file).

const COLORS: string[] = ["#f2b544", "#7be08a", "#6cc6ff", "#ff8fa3", "#c49bff", "#ffa25c", "#5fe0c8", "#e9e46b"];

function hash(text: string): number {
  // FNV-1a, 32-bit.
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/**
 * The avatar as an SVG string: a 5×5 sprite, mirrored left to right like a
 * face, in one of eight colours on the site's dark panel. `size` is in CSS
 * pixels; `label` makes it an image for screen readers, else it's hidden.
 */
export function avatarSvg(id: string | null | undefined, size = 24, label = ""): string {
  const h = hash(String(id || "?"));
  const color = COLORS[h % COLORS.length];
  let bits = h >>> 3;
  let cells = "";
  for (let y = 0; y < 5; y++) {
    for (let x = 0; x < 3; x++) {
      const on = bits & 1;
      bits >>>= 1;
      if (!on) continue;
      cells += `M${x + 1} ${y + 1}h1v1h-1z`;
      if (x < 2) cells += `M${5 - x} ${y + 1}h1v1h-1z`;
    }
  }
  // An empty or nearly empty sprite would look like a missing image; give it eyes.
  if (cells.length < 40) cells += "M2 2h1v1h-1zM4 2h1v1h-1zM2 4h3v1h-3z";
  const a11y = label ? `role="img" aria-label="${label.replace(/[&<>"]/g, "")}"` : `aria-hidden="true"`;
  return `<svg class="dq-avatar" viewBox="0 0 7 7" width="${size}" height="${size}" ${a11y} shape-rendering="crispEdges">`
    + `<rect width="7" height="7" rx="1.2" fill="#2c3263"/><path fill="${color}" d="${cells}"/></svg>`;
}
