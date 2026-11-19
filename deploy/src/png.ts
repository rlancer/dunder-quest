// A small pixel-art canvas and PNG encoder, so the Worker can draw a
// certificate or a profile card as a real image for link previews. Social
// sites won't take SVG for og:image, and the Worker has no <canvas>.
//
// Drawing happens on a low-resolution grid with a palette of at most 256
// colors; `png()` scales it up by a whole number with no smoothing, which is
// both the pixel-art look and cheap to compress.

import { FONT_ASCENT, FONT_HEIGHT, GLYPHS } from "./font";

const glyphBits = new Map<string, Uint8Array>();

function bits(ch: string): Uint8Array {
  let out = glyphBits.get(ch);
  if (!out) {
    const g = GLYPHS[ch];
    out = g && g[3] ? Uint8Array.from(atob(g[3]), (c) => c.charCodeAt(0)) : new Uint8Array(0);
    glyphBits.set(ch, out);
  }
  return out;
}

/** A character the font has: accents it lacks lose their accent, anything else becomes "?". */
function glyphFor(ch: string): string {
  if (GLYPHS[ch]) return ch;
  const bare = ch.normalize("NFD").replace(/\p{M}/gu, "");
  return GLYPHS[bare] ? bare : "?";
}

export class Pixels {
  readonly data: Uint8Array;
  private palette: number[] = [];
  private index = new Map<string, number>();

  constructor(readonly width: number, readonly height: number, background: string) {
    this.data = new Uint8Array(width * height);
    this.data.fill(this.color(background));
  }

  /** The palette slot for a #rrggbb color, added the first time it's used. */
  color(hex: string): number {
    let i = this.index.get(hex);
    if (i === undefined) {
      if (this.palette.length >= 256 * 3) throw new Error("palette full");
      i = this.palette.length / 3;
      const n = Number.parseInt(hex.slice(1), 16);
      this.palette.push((n >> 16) & 255, (n >> 8) & 255, n & 255);
      this.index.set(hex, i);
    }
    return i;
  }

  rect(x: number, y: number, w: number, h: number, hex: string): void {
    const c = this.color(hex);
    const x0 = Math.max(0, Math.round(x));
    const y0 = Math.max(0, Math.round(y));
    const x1 = Math.min(this.width, Math.round(x + w));
    const y1 = Math.min(this.height, Math.round(y + h));
    for (let yy = y0; yy < y1; yy++) this.data.fill(c, yy * this.width + x0, yy * this.width + x1);
  }

  /** A rectangle's outline, `t` pixels thick. */
  frame(x: number, y: number, w: number, h: number, t: number, hex: string): void {
    this.rect(x, y, w, t, hex);
    this.rect(x, y + h - t, w, t, hex);
    this.rect(x, y, t, h, hex);
    this.rect(x + w - t, y, t, h, hex);
  }

  dot(x: number, y: number, hex: string): void {
    if (x >= 0 && y >= 0 && x < this.width && y < this.height) this.data[y * this.width + x] = this.color(hex);
  }

  /** A filled disc, its edge stepped like a sprite's. */
  disc(cx: number, cy: number, r: number, hex: string): void {
    const c = this.color(hex);
    for (let y = -r; y <= r; y++) {
      const half = Math.floor(Math.sqrt(r * r - y * y + r * 0.8));
      const yy = cy + y;
      if (yy < 0 || yy >= this.height) continue;
      const x0 = Math.max(0, cx - half);
      const x1 = Math.min(this.width, cx + half + 1);
      this.data.fill(c, yy * this.width + x0, yy * this.width + x1);
    }
  }

  /** Width of a line of text at a whole-number scale. */
  measure(text: string, scale = 1): number {
    let w = 0;
    for (const ch of text) w += GLYPHS[glyphFor(ch)][0];
    return w * scale;
  }

  /** Text with its top at y. `align` places x at the left, centre or right edge. */
  text(text: string, x: number, y: number, hex: string, scale = 1, align: "left" | "center" | "right" = "left"): number {
    const w = this.measure(text, scale);
    let pen = align === "center" ? Math.round(x - w / 2) : align === "right" ? x - w : x;
    const c = this.color(hex);
    for (const raw of text) {
      const ch = glyphFor(raw);
      const [advance, xoff, gw] = GLYPHS[ch];
      const b = bits(ch);
      for (let gy = 0; gy < FONT_HEIGHT; gy++) {
        for (let gx = 0; gx < gw; gx++) {
          const bit = gy * gw + gx;
          if (!(b[bit >> 3] & (0x80 >> (bit & 7)))) continue;
          const px = pen + (xoff + gx) * scale;
          const py = y + gy * scale;
          for (let sy = 0; sy < scale; sy++) {
            const row = py + sy;
            if (row < 0 || row >= this.height) continue;
            const from = Math.max(0, px);
            const to = Math.min(this.width, px + scale);
            if (to > from) this.data.fill(c, row * this.width + from, row * this.width + to);
          }
        }
      }
      pen += advance * scale;
    }
    return w;
  }

  /** The biggest scale, up to `max`, at which the text fits in `width`. */
  fit(text: string, width: number, max: number): number {
    for (let s = max; s > 1; s--) if (this.measure(text, s) <= width) return s;
    return 1;
  }

  /** Words wrapped into lines no wider than `width`. */
  wrap(text: string, width: number, scale = 1): string[] {
    const lines: string[] = [];
    let line = "";
    for (const word of text.split(/\s+/)) {
      const next = line ? `${line} ${word}` : word;
      if (line && this.measure(next, scale) > width) {
        lines.push(line);
        line = word;
      } else {
        line = next;
      }
    }
    if (line) lines.push(line);
    return lines;
  }

  /** Encodes the canvas as an indexed-color PNG, each pixel blown up to `zoom` x `zoom`. */
  async png(zoom = 2): Promise<Uint8Array> {
    const w = this.width * zoom;
    const h = this.height * zoom;
    const raw = new Uint8Array((w + 1) * h);
    const row = new Uint8Array(w + 1);
    for (let y = 0; y < this.height; y++) {
      row[0] = 0; // filter: none
      const src = y * this.width;
      for (let x = 0; x < this.width; x++) row.fill(this.data[src + x], 1 + x * zoom, 1 + (x + 1) * zoom);
      for (let z = 0; z < zoom; z++) raw.set(row, (y * zoom + z) * (w + 1));
    }
    const idat = new Uint8Array(await new Response(
      new Blob([raw]).stream().pipeThrough(new CompressionStream("deflate")),
    ).arrayBuffer());
    const ihdr = new Uint8Array(13);
    const v = new DataView(ihdr.buffer);
    v.setUint32(0, w);
    v.setUint32(4, h);
    ihdr.set([8, 3, 0, 0, 0], 8); // 8-bit, palette
    const parts = [
      new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
      chunk("IHDR", ihdr),
      chunk("PLTE", new Uint8Array(this.palette)),
      chunk("IDAT", idat),
      chunk("IEND", new Uint8Array(0)),
    ];
    const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
    let at = 0;
    for (const p of parts) {
      out.set(p, at);
      at += p.length;
    }
    return out;
  }
}

export const LINE = FONT_HEIGHT;
export const ASCENT = FONT_ASCENT;

let crcTable: Uint32Array | null = null;

function crc32(bytes: Uint8Array): number {
  if (!crcTable) {
    crcTable = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      crcTable[n] = c >>> 0;
    }
  }
  let c = 0xffffffff;
  for (const b of bytes) c = crcTable[(c ^ b) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + data.length);
  const v = new DataView(out.buffer);
  v.setUint32(0, data.length);
  for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
  out.set(data, 8);
  v.setUint32(8 + data.length, crc32(out.subarray(4, 8 + data.length)));
  return out;
}
