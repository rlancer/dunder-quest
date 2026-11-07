// Plays the spoken lines recorded by tools/voice.ts. One line at a time: a
// new one stops the last. Phones only allow sound after a tap, so nothing
// plays until the player's first tap (the title's Start button). The words
// are always on screen too; the sound button turns the voices off.

import { useEffect, useRef, useSyncExternalStore } from "react";
import { voiceKey, type Line } from "./lines";

const files = import.meta.glob("../voice/*.mp3", { eager: true, query: "?url", import: "default" }) as Record<string, string>;
const urls = new Map(Object.entries(files).map(([path, url]) => [path.replace(/^.*\/|\.mp3$/g, ""), url]));

function load(): boolean {
  try {
    return localStorage.getItem("ms-voice") !== "off";
  } catch {
    return true;
  }
}

let on = load();
let unlocked = false;
let playing = "";
// Which call to speak() is current. Starting a line while the last one is
// still loading makes the browser reject the last one's play(); that
// rejection must not mark the new line as finished, or the conversation
// moves on and cuts the new speaker off.
let turn = 0;
const audio = typeof Audio === "undefined" ? null : new Audio();
const subs = new Set<() => void>();
const emit = () => subs.forEach((f) => f());

if (audio) {
  audio.preload = "auto";
  audio.addEventListener("ended", () => ((playing = ""), emit()));
}

export function hasVoice(l: Line): boolean {
  return urls.has(voiceKey(l));
}

// Called from the first tap, so later lines may play on their own.
export function unlock(): void {
  if (unlocked || !audio) return;
  unlocked = true;
  audio.muted = true;
  audio.play().catch(() => {});
  audio.pause();
  audio.muted = false;
}

export function speak(l: Line | null | undefined): void {
  if (!audio || !l) return;
  const mine = ++turn;
  audio.pause();
  const url = urls.get(voiceKey(l));
  playing = on && unlocked && url ? voiceKey(l) : "";
  if (!playing) return emit();
  audio.src = url!;
  audio.play().catch(() => {
    if (mine !== turn) return;
    playing = "";
    emit();
  });
  emit();
}

export function stop(): void {
  if (!audio) return;
  turn++;
  audio.pause();
  playing = "";
  emit();
}

export function setVoice(v: boolean): void {
  on = v;
  try {
    localStorage.setItem("ms-voice", v ? "on" : "off");
  } catch {}
  if (!v) stop();
  emit();
}

const subscribe = (f: () => void) => (subs.add(f), () => subs.delete(f));

// Runs `then` a moment after the line `key` finishes playing (not when
// it is cut off by another line), so a conversation can move on by itself.
export function useAfterSpeech(key: string, then: () => void): void {
  const { playing } = useVoice();
  const heard = useRef(false);
  useEffect(() => {
    heard.current = false;
  }, [key]);
  useEffect(() => {
    if (playing === key) heard.current = true;
    else if (heard.current && playing === "") {
      heard.current = false;
      const t = setTimeout(then, 450);
      return () => clearTimeout(t);
    }
  }, [playing, key]);
}

export function useVoice(): { on: boolean; playing: string } {
  const isOn = useSyncExternalStore(subscribe, () => on, () => on);
  const now = useSyncExternalStore(subscribe, () => playing, () => playing);
  return { on: isOn, playing: now };
}
