// The voice player with a stand-in for the browser's audio: a line started
// while the last is still loading makes the browser reject the last one's
// play(), and that must not end the new line (it used to, and the
// conversation moved on, cutting the new speaker off).

import { beforeAll, expect, test, vi } from "vitest";
import { allLines, voiceKey } from "./lines";

const plays: { reject: (e: Error) => void; resolve: () => void }[] = [];
let ended: () => void = () => {};

class FakeAudio {
  src = "";
  muted = false;
  preload = "";
  play() {
    return new Promise<void>((resolve, reject) => plays.push({ resolve, reject }));
  }
  pause() {}
  addEventListener(name: string, f: () => void) {
    if (name === "ended") ended = f;
  }
}

let voice: typeof import("./voice");
beforeAll(async () => {
  vi.stubGlobal("Audio", FakeAudio);
  voice = await import("./voice");
  voice.unlock();
});

const voiced = () => allLines().filter((l) => voice.hasVoice(l));
const snapshot = () => {
  let now = "";
  const Probe = () => ((now = voice.useVoice().playing), null);
  return { Probe, get: () => now };
};

test("every spoken line has a recording", () => {
  expect(voiced().length).toBe(allLines().length);
});

test("a line cut off while loading doesn't end the next one", async () => {
  const { render } = await import("@testing-library/react");
  const { createElement } = await import("react");
  const p = snapshot();
  render(createElement(p.Probe));
  const [a, b] = voiced();
  voice.speak(a);
  voice.speak(b);
  plays.at(-2)!.reject(new DOMException("interrupted by a new load request", "AbortError"));
  await new Promise((r) => setTimeout(r, 0));
  expect(p.get()).toBe(voiceKey(b));
  ended();
  await new Promise((r) => setTimeout(r, 0));
  expect(p.get()).toBe("");
});
