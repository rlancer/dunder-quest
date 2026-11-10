// The screen: the street at the top (phones, Nonna's door), the pile of
// slips in the middle, the robot and its rules, and the desk at the bottom.
// The rules of the night are all in engine.ts; this file draws what the
// engine says happened and passes on what the player's thumb did.

import { type Carry, DINERS, Engine, type Ev, type Kind, NIGHTS, type Note, ROUTES, type Slip, type StationId, TIME, TOPICS, TTL, tally } from "./engine";
import { KIND_NAME, REAL_NAME, RULE_NAME, STATION_NAME, TERMS, brief } from "./lines";
import * as snd from "./sound";

const cast = import.meta.glob("../../assets/portraits/*.png", { eager: true, query: "?url", import: "default" }) as Record<string, string>;

export function face(name: string): string {
  return cast[`../../assets/portraits/${name}.png`] ?? `./art/${name}.png`;
}

const NAMES: Record<string, string> = {
  ulrich: "Ulrich", gerard: "Gerard", gilroy: "Gilroy", danesh: "Danesh", ricky: "Ricky", aleister: "Aleister Jr.", nonna: "Nonna",
};
const STATIONS: StationId[] = ["notes", "ledger", "stamp", "adder", "model", "key"];
const ART: Record<StationId, string> = { notes: "notes", ledger: "ledger", stamp: "stamp", adder: "ratecard", model: "model", key: "key" };
const KIND_TAG: Record<Kind, string> = { book: "BOOK", pay: "DEPOSIT", cancel: "CANCEL", ask: "ASK", free: "BROWSE" };
const TOPIC_TAG = { cosy: "C", family: "F", vegan: "V", party: "B" } as const;
const HOUSEMATES = ["danesh", "gilroy", "ricky"];
const KINDS: Kind[] = ["book", "pay", "cancel", "ask", "free"];
/** Which nights have to be behind you before a thing wears its real name. */
const NAMED_AFTER: Record<StationId, number> = { notes: 1, ledger: 1, stamp: 2, adder: 2, model: 3, key: 3 };
const SAVE_KEY = "ms-human";

type Save = { next: number; carry: Carry; stars: number[]; servers: number };
const freshSave = (): Save => ({ next: 1, carry: { rules: {}, ttl: false }, stars: [], servers: 1 });

function h<K extends keyof HTMLElementTagNameMap>(tag: K, cls = "", text = ""): HTMLElementTagNameMap[K] {
  const el = document.createElement(tag);
  if (cls) el.className = cls;
  if (text) el.textContent = text;
  return el;
}

function img(src: string, cls = ""): HTMLImageElement {
  const el = h("img", cls);
  el.src = src;
  el.alt = "";
  el.draggable = false;
  return el;
}

function slipText(s: Slip): string {
  if (s.kind === "book") return `Table for ${s.party}`;
  if (s.kind === "pay") return `Party of ${s.party}`;
  if (s.kind === "cancel") return `Free table #${s.no}`;
  if (s.kind === "ask") return TOPICS[s.topic!];
  return "What's free tonight?";
}

export class Game {
  engine: Engine | null = null;
  save: Save = freshSave();
  private stage = h("div", "stage");
  private hudNight = h("div", "hud-night");
  private hudOk = h("span", "hud-n ok", "0");
  private hudBad = h("span", "hud-n bad", "0");
  private hudTill = h("span", "hud-n till", "$0");
  private muteBtn = h("button", "mute");
  private street = h("section", "street");
  private sign = h("div", "sign");
  private doorFaces = h("div", "door-faces");
  private doorCount = h("div", "door-count");
  private phones: HTMLElement[] = [];
  private talk = h("div", "talk");
  private inbox = h("section", "inbox");
  private warn = h("div", "warn");
  private robotBar = h("section", "robot");
  private chips = h("div", "chips");
  private desks = h("section", "desks");
  private desk = h("section", "desk");
  private tiles = {} as Record<StationId, HTMLElement>;
  private stickies = h("div", "stickies");
  private ttlBtn = h("button", "ttl");
  private lockBtn = h("button", "lock", "Change the lock");
  private fx = h("div", "fx");
  private darkEl = h("div", "dark");
  private overlay = h("div", "overlay");
  private hint = h("div", "hint");
  private slipEls = new Map<number, HTMLElement>();
  private offs = new WeakMap<HTMLElement, { x: number; y: number }>();
  private selected: number | null = null;
  private drag: { id: number; el: HTMLElement; x: number; y: number; moved: boolean } | null = null;
  private pulses = new Set<string>();
  private talkQ: { who: string; name: string; text: string; msg: boolean }[] = [];
  private talkLeft = 0;
  private timers: { at: number; fn: () => void }[] = [];
  private clock = 0;
  private paused = true;
  private scale = 1;
  private warnLeft = 0;
  private warnTotal = 1;
  private lastPop: Record<string, number> = {};
  private lastHand = 0;
  private seated = 0;
  private turned = 0;
  private chipsWere = "";
  private freshChip: Kind | null = null;
  private handDone = false;
  private shownTill = 0;

  constructor(private root: HTMLElement, private manual = false) {
    this.load();
    this.build();
    this.layout();
    window.addEventListener("resize", () => this.layout());
    this.title();
    if (!manual) {
      let prev = performance.now();
      const loop = (now: number) => {
        const dt = Math.min(0.1, (now - prev) / 1000);
        prev = now;
        this.frame(dt);
        requestAnimationFrame(loop);
      };
      requestAnimationFrame(loop);
    }
  }

  // ------------------------------------------------------------------ set up

  private load() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw) this.save = { ...freshSave(), ...JSON.parse(raw) };
    } catch {
      /* private window: play without saving */
    }
  }

  private store() {
    try {
      localStorage.setItem(SAVE_KEY, JSON.stringify(this.save));
    } catch {
      /* private window */
    }
  }

  private build() {
    const hud = h("header", "hud");
    const stat = (label: string, n: HTMLElement) => {
      const el = h("div", "hud-stat");
      el.append(h("span", "hud-l", label), n);
      return el;
    };
    this.muteBtn.setAttribute("aria-label", "Sound");
    this.muteBtn.onclick = () => {
      snd.unlock();
      snd.setMuted(!snd.isMuted());
      this.muteBtn.classList.toggle("off", snd.isMuted());
    };
    this.muteBtn.classList.toggle("off", snd.isMuted());
    hud.append(this.hudNight, stat("happy", this.hudOk), stat("angry", this.hudBad), stat("till", this.hudTill), this.muteBtn);

    const door = h("div", "door");
    door.append(img("./art/door.png", "door-art"), this.sign, this.doorFaces, this.doorCount);
    const row = h("div", "phones");
    for (let i = 0; i < 5; i++) {
      const p = h("div", "phone");
      p.append(img(face(DINERS[i].face), "phone-face"), h("span", "react"));
      this.phones.push(p);
      row.append(p);
    }
    this.street.append(door, row);

    this.robotBar.append(img("./art/robot.png", "robot-art"), this.chips);

    for (const id of STATIONS) {
      const tile = h("div", `station s-${id}`);
      tile.dataset.id = id;
      tile.setAttribute("role", "button");
      tile.tabIndex = 0;
      tile.append(img(`./art/${ART[id]}.png`, "station-art"), h("span", "station-name", STATION_NAME[id]), h("span", "station-real", REAL_NAME[id]));
      const q = h("span", "station-q");
      for (let i = 0; i < TIME[id].cap; i++) q.append(h("i"));
      tile.append(q, h("span", "station-bar"));
      tile.onclick = () => this.tapStation(id);
      tile.onkeydown = (e) => {
        if (e.key === "Enter" || e.key === " ") this.tapStation(id);
      };
      this.tiles[id] = tile;
      this.desk.append(tile);
    }
    this.ttlBtn.onclick = (e) => {
      e.stopPropagation();
      this.engine?.setTtl(!this.engine.ttl);
      snd.sfx("tick");
      this.pump();
    };
    this.tiles.notes.append(this.stickies, this.ttlBtn);
    this.lockBtn.onclick = (e) => {
      e.stopPropagation();
      this.engine?.rotateKey();
      snd.sfx("key");
    };
    this.tiles.key.append(this.lockBtn);

    this.inbox.append(this.warn);
    this.inbox.addEventListener("pointerdown", (e) => this.down(e));
    window.addEventListener("pointermove", (e) => this.move(e));
    window.addEventListener("pointerup", (e) => this.up(e));
    window.addEventListener("pointercancel", () => this.cancelDrag());

    this.stage.append(hud, this.street, this.talk, this.inbox, this.robotBar, this.desks, this.desk, this.fx, this.hint, this.darkEl, this.overlay);
    this.root.append(this.stage);
  }

  private layout() {
    const w = window.innerWidth || 360;
    const hgt = window.innerHeight || 640;
    this.scale = Math.min(w / 360, hgt / 600);
    this.stage.style.height = `${hgt / this.scale}px`;
    this.stage.classList.toggle("short", hgt / this.scale < 700);
    this.stage.style.transform = `scale(${this.scale})`;
    this.stage.style.left = `${(w - 360 * this.scale) / 2}px`;
  }

  /** Something to do later, on the game's own clock, so the tests can run it. */
  private after(secs: number, fn: () => void) {
    this.timers.push({ at: this.clock + secs, fn });
  }

  // ------------------------------------------------------------------ screens

  private card(...children: (HTMLElement | string)[]): HTMLElement {
    this.overlay.replaceChildren();
    const card = h("div", "card");
    card.append(...children);
    this.overlay.append(card);
    this.overlay.classList.add("on");
    return card;
  }

  private button(text: string, cls: string, fn: () => void): HTMLButtonElement {
    const b = h("button", `btn ${cls}`, text);
    b.onclick = () => {
      snd.unlock();
      snd.sfx("pick");
      fn();
    };
    return b;
  }

  private title() {
    this.paused = true;
    this.stage.classList.add("idle");
    const logo = h("h1", "logo");
    logo.append(h("span", "", "MISSION "), h("span", "green", "SILICON"));
    const kicker = h("p", "kicker", "The Human Backend");
    const pitch = h("p", "pitch", "Your AI built the app. It forgot the part that does anything. It launches tonight.");
    const buttons = h("div", "buttons");
    const resume = this.save.next > 1 && this.save.next <= 4;
    if (resume) buttons.append(this.button(`Night ${this.save.next}`, "go", () => this.start(this.save.next)));
    if (this.save.next > 4) buttons.append(this.button("Your brief", "go", () => this.brief()));
    buttons.append(this.button(resume || this.save.next > 4 ? "Start over" : "Start your shift", resume || this.save.next > 4 ? "" : "go", () => {
      this.save = freshSave();
      this.start(1);
    }));
    const fine = h("p", "fine", "Four nights, about ten minutes. Sound helps.");
    const card = this.card(img("./art/robot.png", "title-robot"), logo, kicker, pitch, buttons, fine);
    card.classList.add("title");
  }

  start(night: number) {
    const carry = night === 1 ? freshSave().carry : this.save.carry;
    this.engine = new Engine(night, structuredClone(carry));
    this.stage.classList.remove("idle");
    this.stage.dataset.night = String(night);
    for (const el of this.slipEls.values()) el.remove();
    this.slipEls.clear();
    this.selected = null;
    this.pulses.clear();
    this.talkQ = [];
    this.talkLeft = 0;
    this.talk.replaceChildren();
    this.timers = [];
    this.seated = this.turned = 0;
    this.doorFaces.replaceChildren();
    this.doorCount.replaceChildren();
    this.sign.textContent = "";
    this.sign.classList.remove("on");
    this.warnLeft = 0;
    this.shownTill = 0;
    this.handDone = night !== 1;
    this.hint.classList.remove("on");
    this.darkEl.classList.remove("on");
    this.fx.replaceChildren();
    this.hudNight.textContent = `${NIGHTS[night - 1].sub} · ${NIGHTS[night - 1].title}`;
    this.stage.classList.toggle("has-till", night > 1);
    this.renderDesk();
    this.renderChips();
    this.renderNotes();
    this.renderDesks();
    // The night's name, for a moment, then straight in.
    this.overlay.replaceChildren();
    const slate = h("div", "slate");
    slate.append(h("span", "slate-sub", NIGHTS[night - 1].sub), h("span", "slate-title", NIGHTS[night - 1].title));
    this.overlay.append(slate);
    this.overlay.classList.add("on");
    this.paused = true;
    this.after(this.manual ? 0 : 1.3, () => {
      this.overlay.classList.remove("on");
      this.paused = false;
    });
  }

  private endNight() {
    const e = this.engine!;
    const t = tally(e);
    const n = e.night;
    this.save.carry = e.carry();
    this.save.stars[n - 1] = Math.max(this.save.stars[n - 1] ?? 0, t.stars);
    this.save.next = Math.max(this.save.next, n + 1);
    if (n === 4) this.save.servers = e.servers;
    this.store();
    this.paused = true;
    snd.sfx("end");
    const stars = h("div", "stars");
    for (let i = 0; i < 3; i++) stars.append(h("i", i < t.stars ? "star on" : "star"));
    const rows = h("div", "rows");
    for (const r of t.rows) {
      const row = h("div", `row ${r.good ? "good" : "poor"}`);
      row.append(h("span", "", r.label), h("b", "", r.value));
      rows.append(row);
    }
    const terms = h("div", "terms");
    terms.append(h("h3", "", "What you had your hands on"));
    for (const term of TERMS[n - 1]) {
      const p = h("p", "term");
      p.append(h("b", "", term.term), ` ${term.means}`);
      terms.append(p);
    }
    const buttons = h("div", "buttons");
    buttons.append(
      this.button(n < 4 ? `Night ${n + 1}` : "Your brief", "go", () => (n < 4 ? this.start(n + 1) : this.brief())),
      this.button("Again", "", () => {
        // Replaying a night starts the robot as it was when the night began.
        this.start(n);
      }),
    );
    const card = this.card(h("p", "kicker", `${NIGHTS[n - 1].sub} · ${NIGHTS[n - 1].title}`), stars, rows, terms, buttons);
    card.classList.add("end");
    this.renderDesk();
  }

  /** The last screen: the robot's rules, as sentences for a real AI. */
  private brief() {
    this.paused = true;
    this.stage.classList.add("idle");
    const lines = brief(this.save.carry.rules, this.save.carry.ttl, this.save.servers);
    const list = h("ol", "brief");
    for (const line of lines) {
      const li = h("li", line.ok ? "ok" : "no");
      li.append(h("span", "", line.text));
      if (!line.ok) li.append(h("em", "", line.instead ?? ""));
      list.append(li);
    }
    const earned = lines.filter((l) => l.ok);
    const text = ["When you build this, hold to these rules:", ...earned.map((l) => `- ${l.text}`)].join("\n");
    const copy = this.button("Copy the brief", "go", () => {
      navigator.clipboard?.writeText(text).then(() => (copy.textContent = "Copied"), () => (copy.textContent = "Select it and copy"));
    });
    const buttons = h("div", "buttons");
    buttons.append(copy, this.button("Play again", "", () => {
      this.save = freshSave();
      this.store();
      this.start(1);
    }));
    const total = this.save.stars.reduce((a, b) => a + b, 0);
    const card = this.card(
      h("p", "kicker", `${total} of 12 stars`),
      h("h2", "", "Your brief"),
      h("p", "pitch", earned.length === lines.length
        ? "Everything your robot does, you taught it by hand. Paste this above your next request to a real AI. It's the same list."
        : "Every line here is something you did with your own hands. The crossed-out ones, your robot still gets wrong: play those nights again."),
      list, buttons,
    );
    card.classList.add("end", "final");
  }

  // ---------------------------------------------------------------- the frame

  frame(dt: number) {
    this.clock += dt;
    const due = this.timers.filter((t) => t.at <= this.clock);
    this.timers = this.timers.filter((t) => t.at > this.clock);
    for (const t of due) t.fn();
    this.sayNext(dt);
    const e = this.engine;
    if (!e || this.paused) return;
    for (let left = dt; left > 0.0001; left -= 0.05) e.step(Math.min(0.05, left));
    this.pump();
    this.render(dt);
  }

  /** Draw whatever the engine says has happened since last time. */
  private pump() {
    const e = this.engine;
    if (!e) return;
    for (const ev of e.drain()) this.handle(ev, e);
  }

  private handle(ev: Ev, e: Engine) {
    switch (ev.t) {
      case "spawn":
        this.phone(ev.slip, "wait");
        if (e.inbox.includes(ev.slip)) this.addSlip(ev.slip);
        break;
      case "gone": {
        const el = this.slipEls.get(ev.slip.id);
        if (el) {
          this.slipEls.delete(ev.slip.id);
          el.classList.add("lost");
          this.after(0.35, () => el.remove());
        }
        if (ev.why !== "power") {
          this.phone(ev.slip, "bad", ev.why === "full" ? "busy!" : "hello?");
          snd.sfx("bad", 0.15);
          if (ev.why === "full") this.inbox.classList.add("full");
          this.after(0.3, () => this.inbox.classList.remove("full"));
        }
        break;
      }
      case "sent": {
        const el = this.slipEls.get(ev.slip.id);
        if (el) {
          this.slipEls.delete(ev.slip.id);
          this.fly(el, this.tiles[ev.station], ev.by === "robot" ? 0.16 : 0.2);
          if (ev.by === "robot") el.classList.add("by-robot");
        }
        snd.sfx(ev.by === "robot" ? "robot" : "drop", ev.by === "robot" ? 0.07 : 0.02);
        if (this.selected === ev.slip.id) this.selected = null;
        if (ev.by === "hand") {
          this.handDone = true;
          this.hint.classList.remove("on");
        }
        this.bump(this.tiles[ev.station]);
        break;
      }
      case "bounce": {
        const el = this.slipEls.get(ev.slip.id);
        if (el) {
          el.classList.remove("shake");
          void el.offsetWidth;
          el.classList.add("shake");
        }
        snd.sfx("bounce");
        this.pop(this.tiles[ev.station], ev.why === "busy" ? "Full!" : ev.why === "miss" ? "No note for that" : "Not here", "warn", 0);
        break;
      }
      case "reply": {
        this.phone(ev.slip, ev.mood, ev.text);
        const gap = ev.by === "robot" ? 0.25 : 0;
        const tone = ev.mood === "sly" ? "bad" : ev.mood === "meh" && ev.slip.cheat ? "good" : ev.mood === "bad" ? "bad" : ev.mood === "meh" ? "warn" : "";
        const quiet = ev.by === "robot" && ev.mood === "ok";
        if (ev.slip.kind !== "pay" && !quiet) this.pop(this.tiles[ev.station], ev.text, tone, gap);
        snd.sfx(ev.mood === "ok" ? "ok" : ev.mood, ev.by === "robot" ? 0.12 : 0.03);
        break;
      }
      case "money":
        if (ev.station === "strangers") {
          this.pop(this.tiles.model, `-$${-ev.amount}`, "bad", 0.2);
          snd.sfx("drain", 0.2);
        } else if (ev.station !== "desks") {
          const zero = ev.amount === 0;
          this.pop(this.tiles[ev.station], zero ? "$0" : ev.amount > 0 ? `+$${ev.amount}` : `-$${-ev.amount}`, zero || ev.amount < 0 ? "bad" : "good", 0.22);
          if (ev.amount > 0) snd.sfx("coin", 0.12);
        }
        break;
      case "note+":
        snd.sfx("note", 0.06);
        this.renderNotes();
        break;
      case "note-":
        if (ev.why === "wipe") this.flutter();
        else if (ev.why === "tear" || ev.why === "ttl") snd.sfx("tear", 0.1);
        this.renderNotes();
        break;
      case "learned":
        snd.sfx("learn");
        this.freshChip = ev.kind;
        this.bump(this.robotBar);
        break;
      case "watching":
        snd.sfx("unlearn", 1);
        break;
      case "bark":
        this.say(ev.who, NAMES[ev.who] ?? ev.who, ev.text, false);
        break;
      case "text":
        this.say(ev.who, ev.name, ev.text, true);
        break;
      case "station":
        snd.sfx("station");
        this.renderDesk(ev.id);
        break;
      case "warn":
        this.warnLeft = this.warnTotal = ev.secs;
        this.warn.replaceChildren(img("./art/scooter.png"), h("span", "", "Ulrich wants the plug"), h("i"));
        break;
      case "unplug":
        this.warnLeft = 0;
        snd.sfx("down");
        this.stage.classList.add("shock");
        this.after(0.5, () => this.stage.classList.remove("shock"));
        if (ev.total) {
          this.darkEl.replaceChildren(h("span", "", "unplugged"), h("small", "", "Everything that was only in memory is gone."));
          this.darkEl.classList.add("on");
          snd.duck(true);
          this.cancelDrag();
        } else this.renderDesks();
        break;
      case "power":
        this.darkEl.classList.remove("on");
        snd.duck(false);
        snd.sfx("up");
        break;
      case "arrive":
        this.arrive(ev);
        break;
      case "door":
        this.seated += ev.seated;
        this.turned += ev.turned;
        this.doorCount.replaceChildren(h("b", this.turned ? "bad" : "", this.turned ? `${this.turned} turned away` : "nobody turned away"), h("span", "", `${this.seated} seated`));
        break;
      case "pulse":
        if (ev.on) this.pulses.add(ev.what);
        else this.pulses.delete(ev.what);
        this.renderChips();
        this.renderNotes();
        this.renderDesks();
        break;
      case "sign":
        this.sign.textContent = ev.text;
        this.sign.classList.remove("on");
        void this.sign.offsetWidth;
        this.sign.classList.add("on");
        snd.sfx("meh");
        break;
      case "stranger": {
        const p = this.phones[Math.floor(Math.random() * 5)];
        (p.firstChild as HTMLImageElement).src = face("stranger");
        this.react(p, "sly", "heh");
        break;
      }
      case "keycut":
        this.pop(this.tiles.key, "New lock", "good", 0);
        snd.sfx("key");
        break;
      case "servers":
        snd.sfx("seat");
        this.renderDesks();
        break;
      case "phase":
        break;
      case "end":
        this.after(1.2, () => this.endNight());
        break;
    }
  }

  private render(dt: number) {
    const e = this.engine!;
    // The pile: oldest at the top, squeezing together when it grows.
    const room = this.inbox.clientHeight || 200;
    const n = e.inbox.length;
    const step = n > 1 ? Math.min(48, (room - 50) / (n - 1)) : 48;
    e.inbox.forEach((slip, i) => {
      const el = this.slipEls.get(slip.id);
      if (!el) return;
      el.style.top = `${4 + i * step}px`;
      el.style.zIndex = String(10 + i);
      const left = (slip.due - e.t) / (slip.due - slip.born);
      (el.lastChild as HTMLElement).style.transform = `scaleX(${Math.max(0, left)})`;
      el.classList.toggle("late", slip.due - e.t < 4);
      el.classList.toggle("sel", this.selected === slip.id);
      el.classList.toggle("auto", !!e.rules[slip.kind]);
    });
    this.inbox.classList.toggle("brim", n >= e.inboxCap - 1);

    for (const id of ["ledger", "adder", "model"] as const) {
      const q = e.queues[id];
      const tile = this.tiles[id];
      const pips = tile.querySelector(".station-q")!.children;
      for (let i = 0; i < pips.length; i++) pips[i].classList.toggle("on", i < q.length);
      const bar = tile.querySelector<HTMLElement>(".station-bar")!;
      const job = q[0];
      bar.style.transform = `scaleX(${job ? 1 - job.left / TIME[id][job.by] : 0})`;
      tile.classList.toggle("busy", q.length > 0);
      tile.classList.toggle("jam", q.length >= TIME[id].cap);
    }

    const chips = this.chipState(e);
    if (chips !== this.chipsWere) {
      this.chipsWere = chips;
      this.renderChips(this.freshChip ?? undefined);
      this.freshChip = null;
    }

    this.hudOk.textContent = String(e.stats.ok);
    this.hudBad.textContent = String(e.stats.angry);
    this.shownTill += (e.till - this.shownTill) * Math.min(1, dt * 8);
    const till = Math.round(this.shownTill);
    this.hudTill.textContent = till < 0 ? `-$${-till}` : `$${till}`;
    this.hudTill.classList.toggle("neg", till < 0);

    if (this.warnLeft > 0) {
      const before = Math.ceil(this.warnLeft);
      this.warnLeft -= dt;
      if (Math.ceil(this.warnLeft) < before) snd.sfx("tick");
      (this.warn.lastChild as HTMLElement).style.transform = `scaleX(${Math.max(0, this.warnLeft / this.warnTotal)})`;
    }
    this.warn.classList.toggle("on", this.warnLeft > 0);

    this.lockBtn.classList.toggle("on", e.key.everLeaked || this.pulses.has("key"));
    this.lockBtn.classList.toggle("pulse", this.pulses.has("key") && e.key.cutting <= 0);
    this.lockBtn.textContent = e.key.cutting > 0 ? "Cutting..." : "Change the lock";
    this.tiles.key.classList.toggle("leaking", e.key.leaked);
    this.ttlBtn.classList.toggle("on", e.ttlOffered);
    this.ttlBtn.classList.toggle("pulse", this.pulses.has("ttl"));
    this.ttlBtn.textContent = e.ttl ? `Notes last ${TTL}s` : "Notes last forever";
    this.tiles.notes.classList.toggle("pulse", this.pulses.has("notes"));
    if (e.ttl) {
      for (const el of this.stickies.children) {
        const at = Number((el as HTMLElement).dataset.at ?? -1);
        if (at >= 0) (el as HTMLElement).style.opacity = String(Math.max(0.35, 1 - (e.t - at) / TTL * 0.65));
      }
    }

    // A slip nobody has touched for a while: show where it could go.
    const waiting = e.inbox.find((s) => !e.rules[s.kind]);
    if (!this.drag && this.selected === null) {
      const idle = waiting && this.clock - this.lastHand > 4 && e.t - waiting.born > 3;
      this.mark(idle ? waiting.kind : null);
      if (waiting && !this.handDone && e.t - waiting.born > 0.6) this.showHint(waiting);
    }
  }

  // -------------------------------------------------------------------- slips

  private addSlip(slip: Slip) {
    const el = h("button", `slip k-${slip.kind}`);
    el.dataset.id = String(slip.id);
    el.append(img(face(slip.who.face), "slip-face"), h("span", "slip-kind", KIND_TAG[slip.kind]), h("span", "slip-what", slipText(slip)));
    if (slip.kind === "pay") {
      const amt = h("span", `slip-amt${slip.cheat ? " odd" : ""}`);
      amt.append(h("small", "", "app says"), `$${slip.claimed}`);
      el.append(amt);
    }
    if (slip.kind === "ask") el.append(h("span", `slip-topic t-${slip.topic}`, TOPIC_TAG[slip.topic!]));
    el.append(h("i", "slip-timer"));
    el.style.top = `${4 + (this.engine!.inbox.length - 1) * 48}px`;
    this.inbox.append(el);
    this.slipEls.set(slip.id, el);
  }

  private stationAt(x: number, y: number): StationId | null {
    for (const id of STATIONS) {
      const tile = this.tiles[id];
      if (!tile.classList.contains("on")) continue;
      const r = tile.getBoundingClientRect();
      if (x >= r.left - 4 && x <= r.right + 4 && y >= r.top - 4 && y <= r.bottom + 4) return id;
    }
    return null;
  }

  private down(e: PointerEvent) {
    const el = (e.target as HTMLElement).closest<HTMLElement>(".slip");
    if (!el || !this.engine || this.paused) return;
    snd.unlock();
    this.drag = { id: Number(el.dataset.id), el, x: e.clientX, y: e.clientY, moved: false };
  }

  private move(e: PointerEvent) {
    const d = this.drag;
    if (!d) return;
    const dx = e.clientX - d.x;
    const dy = e.clientY - d.y;
    if (!d.moved && Math.hypot(dx, dy) > 8) {
      d.moved = true;
      d.el.classList.add("drag");
      this.selected = null;
      snd.sfx("pick");
      const slip = this.engine?.inbox.find((s) => s.id === d.id);
      this.mark(slip?.kind ?? null);
    }
    if (!d.moved) return;
    const off = { x: dx / this.scale, y: dy / this.scale };
    this.offs.set(d.el, off);
    d.el.style.transform = `translate(${off.x}px, ${off.y}px) rotate(-3deg)`;
    const over = this.stationAt(e.clientX, e.clientY);
    for (const id of STATIONS) this.tiles[id].classList.toggle("over", id === over);
  }

  private up(e: PointerEvent) {
    const d = this.drag;
    if (!d) return;
    this.drag = null;
    for (const id of STATIONS) this.tiles[id].classList.remove("over");
    if (!d.moved) {
      // A tap picks a slip up; the next tap on the desk puts it down.
      this.selected = this.selected === d.id ? null : d.id;
      const slip = this.engine?.inbox.find((s) => s.id === d.id);
      this.mark(this.selected === null ? null : slip?.kind ?? null);
      snd.sfx("pick");
      this.lastHand = this.clock;
      return;
    }
    const station = this.stationAt(e.clientX, e.clientY);
    if (station) this.sendByHand(d.id, station);
    this.settle(d.el);
    this.mark(null);
  }

  private cancelDrag() {
    if (!this.drag) return;
    this.settle(this.drag.el);
    this.drag = null;
    this.mark(null);
  }

  /** Put a dragged slip back in the pile, if it's still in it. */
  private settle(el: HTMLElement) {
    el.classList.remove("drag");
    if (this.slipEls.get(Number(el.dataset.id)) === el) {
      el.style.transform = "";
      this.offs.delete(el);
    }
  }

  private tapStation(id: StationId) {
    const e = this.engine;
    if (!e || this.paused || this.selected === null) return;
    const slip = e.inbox.find((s) => s.id === this.selected);
    if (!slip) return;
    const sent = this.sendByHand(slip.id, id);
    // Keep a hand going: pick up the next slip of the same kind.
    const next = sent ? e.inbox.find((s) => s.kind === slip.kind && !e.rules[s.kind]) : slip;
    this.selected = next?.id ?? null;
    this.mark(next ? next.kind : null);
  }

  private sendByHand(id: number, station: StationId): boolean {
    this.lastHand = this.clock;
    const ok = this.engine!.send(id, station, "hand");
    this.pump();
    return ok;
  }

  /** Light up what a kind of slip can be dropped on. */
  private mark(kind: Kind | null) {
    const e = this.engine;
    for (const id of STATIONS) {
      const can = !!kind && !!e && e.on[id] && ROUTES[kind].includes(id) && !(id === "notes" && kind !== "book" && !e.cache);
      this.tiles[id].classList.toggle("can", can);
      this.tiles[id].classList.toggle("cant", !!kind && !can);
    }
  }

  private fly(el: HTMLElement, to: HTMLElement, secs: number) {
    const a = el.getBoundingClientRect();
    const b = to.getBoundingClientRect();
    const off = this.offs.get(el) ?? { x: 0, y: 0 };
    const dx = off.x + (b.left + b.width / 2 - (a.left + a.width / 2)) / this.scale;
    const dy = off.y + (b.top + b.height / 2 - (a.top + a.height / 2)) / this.scale;
    el.classList.add("flying");
    el.classList.remove("drag", "sel");
    el.style.transition = `transform ${secs}s cubic-bezier(.5,0,.8,.4), opacity ${secs}s ease-in`;
    void el.offsetWidth;
    el.style.transform = `translate(${dx}px, ${dy}px) scale(.2)`;
    el.style.opacity = "0.2";
    this.after(secs, () => el.remove());
  }

  // ------------------------------------------------------------- small effects

  private bump(el: HTMLElement) {
    el.classList.remove("bump");
    void el.offsetWidth;
    el.classList.add("bump");
  }

  /** A word floating up off something. `gap` keeps a busy robot from papering the screen. */
  private pop(at: HTMLElement, text: string, tone: string, gap: number) {
    const key = at.className;
    if (gap && this.clock - (this.lastPop[key] ?? -9) < gap) return;
    this.lastPop[key] = this.clock;
    const a = at.getBoundingClientRect();
    const s = this.stage.getBoundingClientRect();
    const el = h("div", `pop ${tone}`, text);
    el.style.left = `${(a.left + a.width / 2 - s.left) / this.scale}px`;
    el.style.top = `${(a.top + a.height * 0.35 - s.top) / this.scale}px`;
    this.fx.append(el);
    this.after(0.9, () => el.remove());
  }

  private phone(slip: Slip, mood: "wait" | "ok" | "bad" | "meh" | "sly", text = "") {
    const p = this.phones[slip.id % 5];
    if (mood === "wait") {
      (p.firstChild as HTMLImageElement).src = face(slip.who.face);
      p.classList.add("waiting");
      return;
    }
    p.classList.remove("waiting");
    this.react(p, mood, text);
  }

  private react(p: HTMLElement, mood: string, text: string) {
    const r = p.lastChild as HTMLElement;
    r.textContent = mood === "ok" ? "\u2713" : mood === "sly" ? "heh" : mood === "meh" ? "hm" : text.length <= 6 ? text : "\u2717";
    r.className = "react";
    void r.offsetWidth;
    r.className = `react show ${mood}`;
  }

  private arrive(ev: Extract<Ev, { t: "arrive" }>) {
    const el = h("div", `guest ${ev.ok ? "ok" : "no"}`);
    el.append(img(face(ev.face)), h("span", "", ev.text));
    this.doorFaces.append(el);
    while (this.doorFaces.children.length > 2) this.doorFaces.firstChild!.remove();
    this.after(2.2, () => el.remove());
    snd.sfx(ev.ok ? "arriveOk" : "arriveBad", 0.1);
  }

  /** Every sticky note comes off the board at once. */
  private flutter() {
    const board = this.tiles.notes.getBoundingClientRect();
    const s = this.stage.getBoundingClientRect();
    if (this.fx.querySelectorAll(".leaf").length > 30) return;
    const el = h("i", "leaf");
    el.style.left = `${(board.left - s.left + Math.random() * board.width) / this.scale}px`;
    el.style.top = `${(board.top - s.top + Math.random() * board.height * 0.6) / this.scale}px`;
    el.style.setProperty("--dx", `${Math.round(Math.random() * 120 - 60)}px`);
    el.style.setProperty("--rot", `${Math.round(Math.random() * 500 - 250)}deg`);
    this.fx.append(el);
    this.after(1.6, () => el.remove());
  }

  private showHint(slip: Slip) {
    const el = this.slipEls.get(slip.id);
    if (!el) return;
    const a = el.getBoundingClientRect();
    const b = this.tiles.notes.getBoundingClientRect();
    const s = this.stage.getBoundingClientRect();
    this.hint.style.left = `${(a.left + a.width * 0.6 - s.left) / this.scale}px`;
    this.hint.style.top = `${(a.top + a.height / 2 - s.top) / this.scale}px`;
    this.hint.style.setProperty("--dx", `${(b.left + b.width / 2 - a.left - a.width * 0.6) / this.scale}px`);
    this.hint.style.setProperty("--dy", `${(b.top + b.height / 2 - a.top - a.height / 2) / this.scale}px`);
    this.hint.classList.add("on");
  }

  // --------------------------------------------------------------------- talk

  private say(who: string, name: string, text: string, msg: boolean) {
    this.talkQ.push({ who, name, text, msg });
    if (this.talkLeft <= 0) this.sayNext(0);
  }

  private sayNext(dt: number) {
    this.talkLeft -= dt * (this.talkQ.length > 1 ? 1.6 : 1);
    if (this.talkLeft > 0) return;
    const line = this.talkQ.shift();
    if (!line) {
      if (this.talkLeft < -1.5) this.talk.classList.remove("on");
      return;
    }
    const bubble = h("div", `bubble${line.msg ? " msg" : ""}`);
    bubble.append(h("b", "", line.msg ? `${line.name} · text message` : line.name), h("span", "", line.text));
    this.talk.replaceChildren(img(face(line.who), "talk-face"), bubble);
    this.talk.className = `talk on${line.msg ? " msg" : ""}`;
    this.bump(this.talk);
    this.talkLeft = Math.max(2.4, line.text.length * 0.05);
    if (line.msg) snd.sfx("meh");
    else snd.blips(line.who, line.text.length);
  }

  // ------------------------------------------------------- the desk, the robot

  private renderDesk(fresh?: StationId) {
    const e = this.engine;
    if (!e) return;
    let shown = 0;
    const known = this.save.next - 1;
    for (const id of STATIONS) {
      const tile = this.tiles[id];
      tile.classList.toggle("on", e.on[id]);
      tile.classList.toggle("named", known >= NAMED_AFTER[id]);
      if (e.on[id]) shown++;
      if (id === fresh) this.bump(tile);
    }
    this.desk.dataset.n = String(shown);
  }

  /** The robot's rules. Tap one and he stops to watch how you do it. */
  private renderChips(fresh?: Kind) {
    const e = this.engine;
    if (!e) return;
    this.chips.replaceChildren();
    const dots = (n: number) => {
      const el = h("span", "dots");
      for (let i = 0; i < 3; i++) el.append(h("i", i < n ? "on" : ""));
      return el;
    };
    for (const kind of KINDS) {
      const rule = e.rules[kind];
      if (rule) {
        const held = e.held(kind);
        const streak = e.streak[kind] ?? 0;
        const chip = h("button", `chip k-${kind}`);
        chip.append(h("b", "", KIND_NAME[kind]), h("span", "", held ? "watching you" : RULE_NAME[`${kind}:${rule[0]}`]));
        if (held || streak) {
          chip.classList.add("watching");
          chip.append(dots(streak));
        }
        chip.classList.toggle("pulse", this.pulses.has(`chip:${kind}`) && !held);
        if (kind === fresh) chip.classList.add("fresh");
        chip.onclick = () => {
          if (this.paused) return;
          e.hold(kind);
          this.pump();
        };
        this.chips.append(chip);
      } else if (e.inbox.some((s) => s.kind === kind) || e.seen[kind]?.length) {
        const chip = h("div", `chip watching k-${kind}`);
        chip.append(h("b", "", KIND_NAME[kind]), h("span", "", "watching you"), dots(e.seen[kind]?.length ?? 0));
        this.chips.append(chip);
      }
    }
    if (!this.chips.children.length) this.chips.append(h("div", "chip idle", "Aleister Jr. is watching."));
  }

  /** Everything a chip shows, so it's only redrawn when one of those changes. */
  private chipState(e: Engine): string {
    return KINDS.map((k) => `${e.rules[k]?.[0]}${e.held(k)}${e.streak[k]}${e.seen[k]?.length}${e.inbox.some((s) => s.kind === k)}${this.pulses.has(`chip:${k}`)}`).join();
  }

  private renderNotes() {
    const e = this.engine;
    if (!e) return;
    this.stickies.replaceChildren();
    const max = 8;
    const notes = e.notes;
    // Answers first: they're the ones worth tapping.
    const order = [...notes.filter((n) => n.type !== "booking"), ...notes.filter((n) => n.type === "booking")];
    for (const note of order.slice(0, max)) this.stickies.append(this.sticky(note, e));
    if (order.length > max) this.stickies.append(h("span", "more", `+${order.length - max}`));
  }

  private sticky(note: Note, e: Engine): HTMLElement {
    const el = h("button", `sticky n-${note.type}`);
    if (note.type === "booking") {
      el.append(img(face(note.face)));
      el.title = "Write it in the book";
    } else {
      el.dataset.at = String(note.at);
      if (note.type === "answer") {
        el.classList.add(`t-${note.topic}`);
        el.append(h("b", "", TOPIC_TAG[note.topic]), h("span", "", note.value));
        if (this.pulses.has("stale") && note.value !== e.truth[note.topic]) el.classList.add("pulse");
      } else el.append(h("b", "", "3"), h("span", "", "free"));
      el.title = "Tear it off";
    }
    el.onclick = (ev) => {
      ev.stopPropagation();
      if (this.paused) return;
      if (this.selected !== null) return this.tapStation("notes");
      if (note.type === "booking") {
        if (e.flush(note.id)) {
          snd.sfx("drop");
          this.pop(this.tiles.ledger, "Written down", "good", 0);
        } else if (e.on.ledger) this.pop(this.tiles.ledger, "Full!", "warn", 0);
      } else e.tear(note.id);
      this.pump();
      this.renderNotes();
    };
    return el;
  }

  private renderDesks() {
    const e = this.engine;
    this.desks.replaceChildren();
    const show = !!e && e.night === 4 && (this.pulses.has("couch") || e.servers > 1 || e.phase !== "free-teach");
    this.desks.classList.toggle("on", show);
    if (!e || !show) return;
    const lb = h("div", "lb");
    lb.append(img(face("ulrich")), h("span", "", "deals"));
    this.desks.append(lb);
    const first = h("div", `seat taken${e.deskOff > 0 ? " off" : ""}`);
    first.append(img("./art/robot.png"), h("span", "", "Desk 1"));
    this.desks.append(first);
    HOUSEMATES.forEach((who, i) => {
      const taken = e.servers > i + 1;
      const seat = h("button", `seat${taken ? " taken" : ""}`);
      seat.append(img(face(who)), h("span", "", taken ? `Desk ${i + 2}` : "+ desk"));
      seat.classList.toggle("pulse", !taken && this.pulses.has("couch"));
      seat.onclick = () => {
        if (taken || this.paused || e.servers !== i + 1) return;
        e.addServer();
        this.pump();
      };
      if (!taken && e.servers !== i + 1) seat.classList.add("later");
      this.desks.append(seat);
    });
    if (e.deskOff > 0) this.after(e.deskOff + 0.1, () => this.renderDesks());
  }
}
