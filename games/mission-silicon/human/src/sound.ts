// Every sound effect is made here from oscillators and noise, so the game
// downloads none. The music is the season's existing track, fetched after
// the first tap. Nothing plays until the player has touched the page.

import musicUrl from "../../assets/audio/music_live.ogg?url";

type Tone = { f: number; to?: number; d: number; at?: number; type?: OscillatorType; v?: number };

let ctx: AudioContext | null = null;
let master: GainNode | null = null;
let music: HTMLAudioElement | null = null;
let muted = false;
const last: Record<string, number> = {};

try {
  muted = localStorage.getItem("ms-human-mute") === "1";
} catch {
  /* private window */
}

export function isMuted() {
  return muted;
}

export function setMuted(m: boolean) {
  muted = m;
  try {
    localStorage.setItem("ms-human-mute", m ? "1" : "0");
  } catch {
    /* private window */
  }
  if (master) master.gain.value = m ? 0 : 0.5;
  if (music) music.muted = m;
}

/** Call from a tap: browsers only start audio from one. */
export function unlock() {
  if (ctx || typeof AudioContext === "undefined") return;
  ctx = new AudioContext();
  master = ctx.createGain();
  master.gain.value = muted ? 0 : 0.5;
  master.connect(ctx.destination);
  music = new Audio(musicUrl);
  music.loop = true;
  music.volume = 0.16;
  music.muted = muted;
  music.play().catch(() => {});
}

export function duck(on: boolean) {
  if (music) music.volume = on ? 0.03 : 0.16;
}

function tones(list: Tone[]) {
  if (!ctx || !master || muted) return;
  const now = ctx.currentTime;
  for (const t of list) {
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    const start = now + (t.at ?? 0);
    o.type = t.type ?? "square";
    o.frequency.setValueAtTime(t.f, start);
    if (t.to) o.frequency.exponentialRampToValueAtTime(t.to, start + t.d);
    g.gain.setValueAtTime(0, start);
    g.gain.linearRampToValueAtTime(t.v ?? 0.12, start + 0.005);
    g.gain.exponentialRampToValueAtTime(0.0001, start + t.d);
    o.connect(g).connect(master);
    o.start(start);
    o.stop(start + t.d + 0.02);
  }
}

function noise(d: number, v = 0.15, at = 0, low = 1800) {
  if (!ctx || !master || muted) return;
  const buf = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * d), ctx.sampleRate);
  const data = buf.getChannelData(0);
  for (let i = 0; i < data.length; i++) data[i] = (Math.random() * 2 - 1) * (1 - i / data.length);
  const src = ctx.createBufferSource();
  src.buffer = buf;
  const f = ctx.createBiquadFilter();
  f.type = "lowpass";
  f.frequency.value = low;
  const g = ctx.createGain();
  g.gain.value = v;
  src.connect(f).connect(g).connect(master);
  src.start(ctx.currentTime + at);
}

const SFX = {
  pick: () => tones([{ f: 520, to: 700, d: 0.05, v: 0.07 }]),
  drop: () => {
    noise(0.06, 0.2);
    tones([{ f: 180, to: 120, d: 0.07, type: "triangle", v: 0.2 }]);
  },
  robot: () => tones([{ f: 1300, to: 900, d: 0.03, v: 0.025 }]),
  ok: () => tones([{ f: 880, d: 0.06, v: 0.06 }, { f: 1320, d: 0.1, at: 0.05, v: 0.06 }]),
  bad: () => tones([{ f: 200, to: 110, d: 0.22, type: "sawtooth", v: 0.1 }]),
  meh: () => tones([{ f: 400, to: 330, d: 0.12, type: "triangle", v: 0.1 }]),
  sly: () => tones([{ f: 300, to: 600, d: 0.08, v: 0.07 }, { f: 300, to: 600, d: 0.08, at: 0.1, v: 0.07 }]),
  bounce: () => tones([{ f: 240, d: 0.05, v: 0.09 }, { f: 190, d: 0.07, at: 0.06, v: 0.09 }]),
  coin: () => tones([{ f: 1568, d: 0.05, v: 0.05 }, { f: 2093, d: 0.12, at: 0.04, v: 0.05 }]),
  drain: () => tones([{ f: 700, to: 300, d: 0.1, type: "triangle", v: 0.07 }]),
  learn: () => tones([523, 659, 784, 1047].map((f, i) => ({ f, d: 0.11, at: i * 0.07, v: 0.1 }))),
  unlearn: () => tones([784, 523, 392].map((f, i) => ({ f, d: 0.1, at: i * 0.07, type: "triangle" as const, v: 0.14 }))),
  tick: () => tones([{ f: 990, d: 0.04, v: 0.09 }]),
  down: () => {
    tones([{ f: 440, to: 30, d: 1.1, type: "sawtooth", v: 0.22 }]);
    noise(0.5, 0.3, 0, 600);
  },
  up: () => tones([{ f: 60, to: 520, d: 0.5, type: "sawtooth", v: 0.12 }, { f: 1047, d: 0.12, at: 0.5, v: 0.08 }]),
  tear: () => noise(0.12, 0.25, 0, 5000),
  note: () => tones([{ f: 1100, d: 0.03, type: "triangle", v: 0.05 }]),
  arriveOk: () => tones([{ f: 660, d: 0.05, v: 0.06 }, { f: 990, d: 0.08, at: 0.05, v: 0.06 }]),
  arriveBad: () => tones([{ f: 160, to: 90, d: 0.25, type: "square", v: 0.12 }]),
  station: () => tones([392, 523, 784].map((f, i) => ({ f, d: 0.16, at: i * 0.09, type: "triangle" as const, v: 0.16 }))),
  key: () => {
    noise(0.05, 0.2, 0, 6000);
    tones([{ f: 2400, d: 0.2, type: "sine", v: 0.08 }, { f: 3100, d: 0.25, at: 0.07, type: "sine", v: 0.06 }]);
  },
  seat: () => tones([{ f: 330, d: 0.07, v: 0.1 }, { f: 494, d: 0.12, at: 0.07, v: 0.1 }]),
  star: () => tones([{ f: 1319, d: 0.09, v: 0.1 }, { f: 1760, d: 0.25, at: 0.08, v: 0.1 }]),
  end: () => tones([392, 494, 587, 784].map((f, i) => ({ f, d: 0.3, at: i * 0.12, type: "triangle" as const, v: 0.16 }))),
};

export type Sfx = keyof typeof SFX;

/** Play a sound, at most once per `gap` seconds, so a busy robot is a purr and not a wall. */
export function sfx(name: Sfx, gap = 0.04) {
  const now = performance.now() / 1000;
  if (now - (last[name] ?? -9) < gap) return;
  last[name] = now;
  SFX[name]();
}

/** A voice for each of the cast: a run of blips at their own pitch. */
const VOICE: Record<string, number> = { ulrich: 150, gerard: 330, gilroy: 110, danesh: 260, ricky: 300, aleister: 520, nonna: 400 };

export function blips(who: string, chars: number) {
  const f = VOICE[who] ?? 280;
  const n = Math.min(14, Math.ceil(chars / 7));
  tones(Array.from({ length: n }, (_, i) => ({
    f: f * (1 + ((i * 7) % 5) * 0.06), d: 0.045, at: i * 0.07, type: who === "aleister" ? "square" as const : "triangle" as const, v: 0.07,
  })));
}
