// Episode 1, the Pilot, played as an interactive sitcom. The cast act out
// the four boxes of a web app on stage, argue each of four decisions (where
// it runs, what goes where, build or rent the backend, reading the plan),
// and turn to the player to pick. A pick that fails Thursday plays a
// flash-forward of Thursday going wrong, then its champion says when it
// would be the right choice, and the player picks again. Then Thursday by
// device, Gerard's decision record, and the cliffhanger.
//
// Every word is in ../data/pilot.json (`show` is the script) and the rules
// are in model.ts; show.ts says what each beat does to the stage, and
// Stage.tsx draws it. Below the stage, the dock holds whatever the beat
// needs: the line being spoken, the whiteboard, the TV, a choice, a widget.

import { AnimatePresence, motion } from "motion/react";
import { useEffect, useMemo, useReducer } from "react";
import type { Line } from "./lines";
import { voiceKey } from "./lines";
import { P, clock, feed, fill, hoursLeft, marks, outcome, passes, platform, testers, thursday, type Option, type Req } from "./model";
import { EMPTY, SCENES, apply, expandGive, holds, type Beat, type Opt, type StageState } from "./show";
import Stage from "./Stage";
import { Guide, Next, Notice, Portrait, Stamp, castName } from "./ui";
import { useTheme, type Theme } from "./theme";
import { setVoice, speak, stop, unlock, useAfterSpeech, useVoice } from "./voice";

export type Picks = { platform: string; tried: string[]; backend: string; triedBackend: string[]; misplaced: number; fixed: boolean };
const NO_PICKS: Picks = { platform: "", tried: [], backend: "", triedBackend: [], misplaced: 0, fixed: false };
const SAVE = "ms-pilot";

type Saved = { scene: number; picks: Picks };
function loadSave(): Saved | null {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE) || "null");
    return s && typeof s.scene === "number" && s.scene < SCENES.length ? s : null;
  } catch {
    return null;
  }
}

// ---- The run: where we are in the script, and the stage it has built ----

type Run = {
  mode: "title" | "show" | "end";
  scene: number;
  queue: Beat[];
  stage: StageState;
  picks: Picks;
  // Options already tried at each choice, so a retry shows them crossed out.
  tried: Record<string, string[]>;
  // The last line spoken, kept in the dock while people walk.
  line: Beat | null;
  // Bumped on every beat, so a line repeated word for word still restarts.
  n: number;
};

const START: Run = { mode: "title", scene: 0, queue: [], stage: EMPTY, picks: NO_PICKS, tried: {}, line: null, n: 0 };

const choiceKey = (b: Beat) => `${b.choice}${b.piece ? ":" + b.piece : ""}`;

// The options a choice offers, which one is right, and what each one plays.
export function optionsFor(b: Beat, picks: Picks): (Opt & { then: Beat[] })[] {
  const own = (id: string, dflt: Beat[] = []) => b.then?.[id] ?? dflt;
  switch (b.from) {
    case "platforms":
      return P.platforms.map((p) => ({ id: p.id, label: p.n, ok: passes(p, P.pick.reqs as Req[], P.budget.time), then: own(p.id) }));
    case "backend": {
      const left = hoursLeft(picks.platform || "web");
      return P.backend.options.map((o) => ({ id: o.id, label: o.n, ok: passes(o as Option, P.backend.reqs as Req[], left), then: own(o.id) }));
    }
    case "code":
      return P.code.flatMap((l, i) => ("key" in l ? [{ id: "key", label: l.c, ok: true, then: own("key") }] : "note" in l ? [{ id: String(i), label: l.c, then: own(String(i), [l.note as Beat]) }] : []));
    case "plan":
      return P.plan.lines.map((l, i) => ("bad" in l ? { id: "bad", label: String(l.c), ok: true, then: own("bad") } : { id: String(i), label: String(l.c), then: own(String(i), [l.claim as Beat]) }));
    case "zones": {
      const piece = P.sort.pieces.find((p) => p.id === b.piece)!;
      return P.sort.zones.map((z) => ({ id: z.id, label: `${castName(z.who)} · ${z.h}`, ok: piece.z === z.id, then: [(piece.why as Record<string, Line>)[z.id] as Beat] }));
    }
    default:
      return (b.options ?? []).map((o) => ({ ...o, then: own(o.id) }));
  }
}

// Plays instant beats until one holds the show (or the script runs out).
function settle(r: Run): Run {
  let { queue, stage, scene, line } = r;
  queue = [...queue];
  for (let guard = 0; guard < 500; guard++) {
    const head = queue[0];
    if (!head) {
      if (scene + 1 >= SCENES.length) return { ...r, mode: "end", queue, stage, scene, line };
      scene++;
      queue = [...SCENES[scene].beats];
      continue;
    }
    if (head.give) {
      queue.splice(0, 1, ...expandGive(stage, head));
      continue;
    }
    stage = apply(stage, head);
    if (holds(head)) {
      if (head.say !== undefined) line = head;
      if (head.card) line = null;
      return { ...r, queue, stage, scene, line, n: r.n + 1 };
    }
    queue.shift();
  }
  throw new Error("the script never stops for a line");
}

// The stage as it stands at the start of a scene, for Continue: every
// earlier scene's beats (not the branches), with nobody mid-walk.
function stageAt(scene: number): StageState {
  let s = EMPTY;
  for (const sc of SCENES.slice(0, scene)) {
    for (const b of sc.beats) {
      if (b.give) for (const g of expandGive(s, b)) s = apply(s, g);
      else s = apply(s, b);
    }
  }
  const actors = Object.fromEntries(Object.entries(s.actors).map(([k, a]) => [k, { ...a, enter: undefined }]));
  return { ...s, actors, cut: s.cut + 1 };
}

type Act = { t: "start"; from?: Saved } | { t: "next" } | { t: "choose"; id: string } | { t: "title" };

function reduce(r: Run, a: Act): Run {
  switch (a.t) {
    case "title":
      return START;
    case "start": {
      const scene = a.from?.scene ?? 0;
      return settle({ ...START, mode: "show", scene, queue: [...SCENES[scene].beats], stage: a.from ? stageAt(scene) : EMPTY, picks: a.from?.picks ?? NO_PICKS });
    }
    case "next": {
      const head = r.queue[0];
      if (!head || head.choice) return r;
      return settle({ ...r, queue: r.queue.slice(1) });
    }
    case "choose": {
      const head = r.queue[0];
      if (!head?.choice) return r;
      const opt = optionsFor(head, r.picks).find((o) => o.id === a.id);
      if (!opt) return r;
      const key = choiceKey(head);
      const tried = { ...r.tried, [key]: [...new Set([...(r.tried[key] ?? []), a.id])] };
      const p = { ...r.picks };
      if (head.from === "platforms") {
        p.tried = [...new Set([...p.tried, a.id])];
        if (opt.ok) p.platform = a.id;
      }
      if (head.from === "backend") {
        p.triedBackend = [...new Set([...p.triedBackend, a.id])];
        if (opt.ok) p.backend = a.id;
      }
      if (head.from === "zones" && !opt.ok) p.misplaced++;
      if (head.from === "plan" && opt.ok) p.fixed = true;
      // A wrong pick plays its scene, then the same choice comes back.
      const rest = r.queue.slice(1);
      const queue = opt.ok ? [...opt.then, ...rest] : [...opt.then, head, ...rest];
      return settle({ ...r, queue, tried, picks: p });
    }
  }
}

// ---- The episode ----

export default function Pilot({ speed = 10 }: { speed?: number }) {
  const saved = useMemo(loadSave, []);
  const [r, dispatch] = useReducer(reduce, START);
  const head = r.queue[0];
  const next = () => dispatch({ t: "next" });

  useEffect(() => {
    try {
      if (r.mode === "show") localStorage.setItem(SAVE, JSON.stringify({ scene: r.scene, picks: r.picks }));
      if (r.mode === "end") localStorage.removeItem(SAVE);
    } catch {}
  }, [r.scene, r.mode]);

  // A wait holds the show for its time, then moves on. The bot, running
  // Thursday at infinite speed, doesn't wait for walks either.
  useEffect(() => {
    if (!head?.wait) return;
    const t = setTimeout(next, speed === Infinity ? 0 : head.wait);
    return () => clearTimeout(t);
  }, [r.n]);

  // Lines are spoken as they come up.
  useEffect(() => {
    if (head?.say !== undefined) speak(head as Line);
    else if (!head?.wait) stop();
  }, [r.n]);

  useEffect(() => {
    window.scrollTo?.({ top: 0 });
  }, [r.scene, r.mode]);

  if (r.mode === "title")
    return (
      <Title
        saved={saved}
        onStart={(from) => {
          unlock();
          dispatch({ t: "start", from });
        }}
      />
    );
  if (r.mode === "end") return <EndCard onAgain={() => dispatch({ t: "start" })} />;

  const scene = SCENES[r.scene];
  if (head?.card) return <Card key={r.n} beat={speed === Infinity ? { ...head, auto: undefined } : head} onNext={next} />;

  const speaking = head?.say !== undefined ? head : null;
  return (
    <>
      <Bar scene={r.scene} picks={r.picks} />
      <main className={`show${r.stage.board || r.stage.screen || head?.widget ? " compact" : ""}`}>
        <Stage s={r.stage} speaker={speaking?.who ?? null} onTap={speaking ? next : undefined} />
        <div className="dock">
          {head?.choice ? (
            <ChoicePanel beat={head} r={r} onPick={(id) => dispatch({ t: "choose", id })} />
          ) : head?.stamp ? (
            <>
              <Stamp s={P.stamps[head.stamp]} />
              <Next onClick={next}>Go on</Next>
            </>
          ) : head?.widget === "thursday" ? (
            <ThursdayWidget picks={r.picks} speed={speed} onDone={next} />
          ) : head?.widget === "record" ? (
            <RecordWidget picks={r.picks} onDone={next} />
          ) : (
            <Caption key={r.n} line={r.line} live={!!speaking} onNext={next} />
          )}
          {!head?.choice && <Screens s={r.stage} picks={r.picks} claimed={r.tried.plan ?? []} />}
        </div>
      </main>
      <span hidden data-scene={scene.id} />
    </>
  );
}

// ---- The dock ----

// The line being spoken: face, name, words, and the real term when there is
// one. It moves on when the voice finishes, or on a tap.
function Caption({ line, live, onNext }: { line: Beat | null; live: boolean; onNext: () => void }) {
  const l = line as (Line & Beat) | null;
  const { playing } = useVoice();
  useAfterSpeech(l ? voiceKey(l) : "", () => live && onNext());
  if (!l) return <div className="caption empty" />;
  const speaking = playing === voiceKey(l);
  return (
    <div className={`caption${live ? "" : " old"}`} onClick={live ? onNext : undefined}>
      <Portrait who={l.who} size={56} />
      <div className="words">
        <div className="name pixel">
          {castName(l.who)}
          {speaking && <span className="live" aria-hidden />}
          {live && (
            <button className="replay" onClick={(e) => (e.stopPropagation(), speak(l))} aria-label={`Hear ${castName(l.who)} again`}>
              ↻
            </button>
          )}
        </div>
        <div className="text">{l.say}</div>
        {l.term && (
          <div className="term">
            <span>Real term</span> {l.term}
          </div>
        )}
      </div>
      {live && (
        <button className="btn small go" onClick={(e) => (e.stopPropagation(), onNext())} aria-label="Next line">
          ›
        </button>
      )}
    </div>
  );
}

// The whiteboard and the TV, when they're on.
function Screens({ s, picks, claimed, choose }: { s: StageState; picks: Picks; claimed: string[]; choose?: { tried: string[]; onPick: (id: string) => void } }) {
  return (
    <>
      {s.board && <Board kind={s.board} marked={s.marked} picks={picks} choose={choose} />}
      {s.screen === "code" && <CodeScreen found={s.marked.includes("key")} choose={choose} />}
      {s.screen === "plan" && <PlanScreen fixed={s.fixed} picks={picks} claimed={claimed} choose={choose} />}
    </>
  );
}

function ChoicePanel({ beat, r, onPick }: { beat: Beat; r: Run; onPick: (id: string) => void }) {
  const tried = r.tried[choiceKey(beat)] ?? [];
  const opts = optionsFor(beat, r.picks);
  const onScreen = beat.from === "platforms" || beat.from === "backend" || beat.from === "code" || beat.from === "plan";
  const last = tried.length ? opts.find((o) => o.id === tried[tried.length - 1]) : undefined;
  return (
    <motion.div className="choice" initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
      <div className="kicker">Your call</div>
      <h2>{beat.prompt}</h2>
      {last && !last.ok && (beat.from === "platforms" || beat.from === "backend") && <Misses kind={beat.from} id={last.id} picks={r.picks} />}
      {onScreen ? (
        <Screens s={r.stage} picks={r.picks} claimed={r.tried.plan ?? []} choose={{ tried, onPick }} />
      ) : (
        <div className="options">
          {opts.map((o) => (
            <button key={o.id} className={`option${tried.includes(o.id) ? " fail" : ""}`} disabled={tried.includes(o.id)} onClick={() => onPick(o.id)}>
              <span className="n">{o.label}</span>
            </button>
          ))}
        </div>
      )}
    </motion.div>
  );
}

const MARK: Record<string, string> = { y: "✓", p: "~", n: "✗" };
const MARK_WORD: Record<string, string> = { y: "Yes", p: "Partly", n: "No" };

// The whiteboard: each option against the requirements. A row fills in when
// someone argues for it; the reasons for the row being argued are spelled
// out beneath. When it's the player's call, each row is a button.
function Board({ kind, marked, picks, choose }: { kind: "platforms" | "backend"; marked: string[]; picks: Picks; choose?: { tried: string[]; onPick: (id: string) => void } }) {
  const left = hoursLeft(picks.platform || "web");
  const f = (s: string) => (kind === "backend" ? fill(s, left) : s);
  const reqs = (kind === "platforms" ? P.pick.reqs : P.backend.reqs) as (Req & { s: string })[];
  const rows = (kind === "platforms" ? P.platforms : P.backend.options) as (Option & { rn: string; champ: string })[];
  const hours = kind === "platforms" ? P.budget.time : left;
  const shown = (id: string) => !!choose || marked.includes(id);
  const focus = rows.find((o) => o.id === (choose ? choose.tried[choose.tried.length - 1] : marked[marked.length - 1]));
  return (
    <div className="board">
      <div className="board-head">
        <span>{kind === "platforms" ? P.pick.needs : P.backend.needs}</span>
        <span className="hrs">{hours} hours to spend</span>
      </div>
      <table>
        <thead>
          <tr>
            <th />
            {reqs.map((q) => (
              <th key={q.id} className={q.must ? "must" : "dim"} title={f(q.t)}>
                {f(q.s)}
                <small>{q.must ? "must" : q.later ? "later" : "nice"}</small>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((o) => {
            const ok = passes(o, reqs, hours);
            const tried = choose?.tried.includes(o.id);
            const head = (
              <>
                <Portrait who={o.champ} size={28} />
                <span>
                  <b>{o.n}</b>
                  <small>
                    {o.rn} · {o.h}h
                  </small>
                </span>
              </>
            );
            return (
              <tr key={o.id} className={`${tried ? (ok ? "ok" : "no") : ""}${focus?.id === o.id ? " focus" : ""}`}>
                <th>
                  {choose ? (
                    <button className="rowpick" disabled={tried} onClick={() => choose.onPick(o.id)} aria-label={o.n}>
                      {head}
                    </button>
                  ) : (
                    <span className="rowpick">{head}</span>
                  )}
                </th>
                {reqs.map((q) => {
                  const v = o.r[q.id];
                  return (
                    <td key={q.id} className={q.must ? "" : "dim"}>
                      {shown(o.id) && v ? (
                        <motion.span className={`mk ${v[0]}`} initial={{ scale: 0.4, opacity: 0 }} animate={{ scale: 1, opacity: 1 }} title={f(v[1])} aria-label={`${MARK_WORD[v[0]]}: ${f(v[1])}`}>
                          {MARK[v[0]]}
                        </motion.span>
                      ) : (
                        <span className="mk q">?</span>
                      )}
                    </td>
                  );
                })}
              </tr>
            );
          })}
        </tbody>
      </table>
      {focus && shown(focus.id) && (
        <motion.ul key={focus.id} className="reasons" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <li className="who">{focus.n}</li>
          {reqs.map((q) => {
            const v = focus.r[q.id];
            return (
              v && (
                <li key={q.id}>
                  <span className={`mk ${v[0]}`}>{MARK[v[0]]}</span> <b>{f(q.s)}:</b> {f(v[1])}
                </li>
              )
            );
          })}
        </motion.ul>
      )}
      {choose && <p className="hint">Every must needs a ✓. Tap the one you'd go with.</p>}
    </div>
  );
}

// Which musts a failed pick misses, so it says exactly why.
function Misses({ kind, id, picks }: { kind: "platforms" | "backend"; id: string; picks: Picks }) {
  const left = hoursLeft(picks.platform || "web");
  const hours = kind === "platforms" ? P.budget.time : left;
  const reqs = (kind === "platforms" ? P.pick.reqs : P.backend.reqs) as Req[];
  const o = (kind === "platforms" ? P.platforms : P.backend.options).find((x) => x.id === id) as Option;
  const f = (s: string) => fill(s, left);
  const miss = reqs.filter((q) => !q.later && q.must && o.r[q.id]?.[0] !== "y").map((q) => f(q.t));
  if (o.h > hours && !miss.length) miss.push(`Fits the ${hours} hours`);
  return (
    <Notice kind="bad" head={`${o.n}: not this time`}>
      Misses {miss.length} must{miss.length === 1 ? "" : "s"}: {miss.join("; ")}.
    </Notice>
  );
}

// The TV: the app's code, as any browser can read it.
function CodeScreen({ found, choose }: { found: boolean; choose?: { tried: string[]; onPick: (id: string) => void } }) {
  return (
    <pre className="code tv" aria-label="The app's code">
      {P.code.map((l, k) => {
        const id = "key" in l ? "key" : String(k);
        const tappable = choose && ("key" in l || "note" in l);
        const cls = `${"key" in l && found ? "hot" : l.c.startsWith("//") ? "dim" : ""}${choose?.tried.includes(id) ? " tried" : ""}`;
        return tappable ? (
          <button key={k} className={`codeline ${cls}`} disabled={choose.tried.includes(id)} onClick={() => choose.onPick(id)}>
            {l.c}
          </button>
        ) : (
          <div key={k} className={cls}>
            {l.c || " "}
          </div>
        );
      })}
    </pre>
  );
}

// The TV: Aleister's tech stack, each line tagged with its box once claimed.
function PlanScreen({ fixed, picks, claimed, choose }: { fixed: boolean; picks: Picks; claimed: string[]; choose?: { tried: string[]; onPick: (id: string) => void } }) {
  const plat = picks.platform || "web";
  const text = (v: string | Record<string, string>) => (typeof v === "string" ? v : (v[plat] ?? v.web));
  return (
    <div className="plan tv">
      <div className="head">{P.plan.head}</div>
      {P.plan.lines.map((l, k) => {
        const bad = "bad" in l;
        const id = bad ? "bad" : String(k);
        const c = bad && fixed ? l.fixed! : text(l.c);
        const box = bad && fixed ? l.fixed_box! : l.box;
        const known = fixed || claimed.includes(id);
        const inner = (
          <>
            <span>{c}</span>
            <span className={`boxtag${known ? (box === "?" ? " q" : " placed") : ""}`}>{known ? box : "?"}</span>
          </>
        );
        return choose ? (
          <button key={k} className={`stackline${choose.tried.includes(id) ? " open" : ""}`} disabled={choose.tried.includes(id)} onClick={() => choose.onPick(id)}>
            {inner}
          </button>
        ) : (
          <div key={k} className={`stackline${bad && !fixed ? " bad" : ""}`}>
            {inner}
          </div>
        );
      })}
    </div>
  );
}

// ---- Cards, bar, title, end ----

function Card({ beat, onNext }: { beat: Beat; onNext: () => void }) {
  useEffect(() => {
    if (!beat.auto) return;
    const t = setTimeout(onNext, beat.auto);
    return () => clearTimeout(t);
  }, []);
  if (beat.card === "goal") {
    const g = P.goal_card;
    return (
      <div className="card-screen" onClick={onNext}>
        <div>
          <div className="kicker">{g.head}</div>
          <ul>
            {g.items.map((t) => (
              <li key={t}>{t}</li>
            ))}
          </ul>
          <div className="kicker" style={{ color: "#fff" }}>
            {g.sub}
          </div>
          <button className="btn">Show me →</button>
        </div>
      </div>
    );
  }
  const flash = beat.card === "FLASH-FORWARD";
  return (
    <motion.div className={`card-screen${flash ? " flash" : ""}`} onClick={onNext} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
      <div>
        <h1>{beat.card}</h1>
        {beat.sub && <p className="sub big">{beat.sub}</p>}
        <button className="btn ghost small" aria-label="Go on">
          Tap to go on
        </button>
      </div>
    </motion.div>
  );
}

const THEME: Record<Theme, [string, string]> = { auto: ["◐", "Auto"], light: ["☀", "Light"], dark: ["☾", "Dark"] };

function Bar({ scene, picks }: { scene: number; picks: Picks }) {
  const { on } = useVoice();
  const [theme, nextTheme] = useTheme();
  const cur = SCENES[scene].decision ?? 0;
  const doneBy = (k: number) => SCENES.findIndex((s) => s.decision === k) < scene && cur !== k;
  const used = (picks.platform ? platform(picks.platform)!.h : 0) + (picks.backend ? P.backend.options.find((b) => b.id === picks.backend)!.h : 0);
  const left = P.budget.time - used;
  return (
    <header className="bar">
      <span className="brand">
        MISSION <b>SILICON</b>
      </span>
      <span className="ep">Episode 1 · Pilot</span>
      <span className="decisions" aria-label="The four decisions">
        {P.decisions.map((d, k) => (
          <span key={d} title={d} className={`dec${doneBy(k + 1) ? " done" : cur === k + 1 ? " on" : ""}`}>
            {k + 1}
          </span>
        ))}
      </span>
      <span className="hours" title="Aleister's hours of building before Thursday">
        {left}h left
        <span className="track">
          <span className="fill" style={{ width: `${(left / P.budget.time) * 100}%` }} />
        </span>
      </span>
      <button className="sound" onClick={() => (on ? setVoice(false) : (unlock(), setVoice(true)))} aria-pressed={on} aria-label={on ? "Turn voices off" : "Turn voices on"}>
        {on ? "🔊" : "🔇"}
        <span className="lbl"> {on ? "Voices" : "Muted"}</span>
      </button>
      <button className="sound" onClick={nextTheme} aria-label={`Theme: ${THEME[theme][1]}. Tap to change.`} title="Light, dark, or your device's setting">
        {THEME[theme][0]}
        <span className="lbl"> {THEME[theme][1]}</span>
      </button>
    </header>
  );
}

function Title({ saved, onStart }: { saved: Saved | null; onStart: (from?: Saved) => void }) {
  return (
    <div className="card-screen">
      <div>
        <div className="kicker">EPISODE 1 · PILOT</div>
        <h1>
          MISSION <b>SILICON</b>
        </h1>
        <p className="sub">You're a non-technical founder with an AI startup, a house full of opinions and a very confident AI coding assistant. Watch them argue; you make the calls.</p>
        <div className="row">
          {saved ? (
            <>
              <button className="btn" onClick={() => onStart(saved)}>
                Continue
              </button>
              <button className="btn ghost" onClick={() => onStart()}>
                Start over
              </button>
            </>
          ) : (
            <button className="btn" onClick={() => onStart()}>
              Start
            </button>
          )}
        </div>
        <p className="sub" style={{ fontSize: 14 }}>
          The cast talk it through. Turn your sound on, or read along and tap.
        </p>
      </div>
    </div>
  );
}

function EndCard({ onAgain }: { onAgain: () => void }) {
  const n = P.next;
  return (
    <div className="card-screen">
      <div>
        <div className="kicker">{n.top}</div>
        <h1>{n.title}</h1>
        <p className="sub">{n.sub}</p>
        <p className="sub">Episode 2 is being rebuilt. The Pilot is all there is for now.</p>
        <div className="row">
          <button className="btn" onClick={onAgain}>
            Play the Pilot again
          </button>
          <a className="btn ghost" href="../" style={{ textDecoration: "none", display: "inline-grid", placeItems: "center" }}>
            About the game
          </a>
        </div>
      </div>
    </div>
  );
}

// ---- Widgets ----

// Thursday: 200 testers on three kinds of device, each square one diner,
// the 4:40 iPhone bug, and the same evening on native apps for comparison.
function ThursdayWidget({ picks, speed, onDone }: { picks: Picks; speed: number; onDone: () => void }) {
  const T = P.thursday;
  const mine = picks.platform || "web";
  const [st, set] = useReducer((s: { build: string; m: number; running: boolean; ranMine: boolean }, p: Partial<typeof s>) => ({ ...s, ...p }), { build: mine, m: 0, running: true, ranMine: false });
  const { build, m, running, ranMine } = st;
  const all = testers();
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    let last = performance.now();
    let cur = m;
    const tick = (now: number) => {
      const dt = Math.max(0, now - last) / 1000;
      last = now;
      cur = speed === Infinity ? T.minutes : Math.min(T.minutes, cur + dt * speed);
      if (cur >= T.minutes) set({ m: T.minutes, running: false, ranMine: ranMine || build === mine });
      else {
        set({ m: cur });
        raf = requestAnimationFrame(tick);
      }
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [running, build]);
  const restart = (b: string) => set({ build: b, m: 0, running: true });
  const c = thursday(build, m);
  const share = c.n ? c.fit / c.n : 0;
  const finished = m >= T.minutes;
  const goal = P.goal_share;
  return (
    <div className="widget">
      <Guide line={T.intro} />
      <h2>Thursday · {T.title}</h2>
      <div className="next-row" style={{ justifyContent: "flex-start", marginTop: 4 }}>
        <span className="toggle" role="group" aria-label="Which build">
          <button aria-pressed={build === mine} onClick={() => restart(mine)}>
            {T.mine}: {platform(mine)!.n}
          </button>
          <button aria-pressed={build === "native"} onClick={() => restart("native")}>
            {T.native}
          </button>
        </span>
        {!finished && (
          <button className="btn ghost small" onClick={() => set({ running: !running })}>
            {running ? "Pause" : "Resume"}
          </button>
        )}
        {finished && (
          <button className="btn ghost small" onClick={() => restart(build)}>
            {T.again}
          </button>
        )}
      </div>
      <div className="thursday" style={{ marginTop: 12 }}>
        <div className="panel devices">
          {T.devices.map((dev) => (
            <div key={dev.id} className="device-row">
              <div className="lbl">
                {dev.n} · {dev.count}
              </div>
              <div className="tiles">
                {all[dev.id].map((w, k) => (
                  <span key={k} className={`tile${w.at < m ? " " + outcome(build, dev.id, w) : ""}`} />
                ))}
              </div>
            </div>
          ))}
          <div className="legend">
            {(["fit", "near", "wrong", "none"] as const).map((k) => (
              <span key={k}>
                <i className={`tile ${k}`} />
                {T.legend[k]}
              </span>
            ))}
          </div>
        </div>
        <div className="panel">
          <div className="clock" aria-live="off">
            {clock(m)}pm
          </div>
          <div>{T.meter}</div>
          <div className="meter" aria-label={`${Math.round(share * 100)}% found a place`}>
            <span className={`fill${share < goal ? " low" : ""}`} style={{ width: `${share * 100}%` }} />
            <span className="goal" style={{ left: `${goal * 100}%` }} />
          </div>
          <div style={{ display: "flex", justifyContent: "space-between", fontSize: 15 }}>
            <strong>{Math.round(share * 100)}%</strong>
            <span>{T.goal}</span>
          </div>
          <div style={{ fontSize: 14, color: "var(--slate-mid)" }}>{T.so_far.replace("%d", String(c.n))}</div>
          <ul className="feed">
            {feed(build, m).map((f) => (
              <motion.li key={f.t} className={f.kind} initial={{ opacity: 0, x: 8 }} animate={{ opacity: 1, x: 0 }}>
                {f.t}
              </motion.li>
            ))}
          </ul>
        </div>
      </div>
      <AnimatePresence>
        {finished && (
          <Notice kind={share >= goal ? "good" : "bad"} head={`${platform(build)!.n}: ${Math.round(share * 100)}% found a place that fits`}>
            {build === "native"
              ? `On native apps the laptops can't open it at all, and the iPhone fix waits for store review. That's why the platform decision mattered.`
              : `${c.wrong} iPhone diners booked the wrong night before the fix went live three minutes later. On the web, a fix reaches everyone on their next tap. Try "${T.native}" to see the other road.`}
          </Notice>
        )}
      </AnimatePresence>
      <Next onClick={onDone} disabled={!ranMine} why={ranMine ? "" : "Watch your build's evening to the end."}>
        Back to the house
      </Next>
    </div>
  );
}

// Gerard's decision record, the marks and the runway.
function RecordWidget({ picks, onDone }: { picks: Picks; onDone: () => void }) {
  const d = P.postmortem;
  const plat = picks.platform || "web";
  const rows = [(d.platform_rows as Record<string, string[]>)[plat], ...d.rows];
  const m = marks(plat, picks.tried.includes("native"));
  return (
    <div className="widget">
      <h2>{d.prompt}</h2>
      <p className="lede">{d.when}</p>
      <table className="adr">
        <thead>
          <tr>
            {d.heads.map((h) => (
              <th key={h}>{h}</th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row[0]}>
              {row.map((cell, k) => (
                <td key={k} data-h={k ? d.heads[k] : undefined}>
                  {cell || "—"}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <Notice head="New word">{d.word}</Notice>
      <div className="marks">
        {(["live", "lean", "ulrich"] as const).map((k) => (
          <span key={k} className={`markchip${m[k] ? "" : " miss"}`}>
            {m[k] ? "✓ " : ""}
            {d.marks[k][m[k] ? 0 : 1]}
          </span>
        ))}
      </div>
      <Notice kind="good" head="Runway">
        {d.runway}
      </Notice>
      <Next onClick={onDone}>Go on</Next>
    </div>
  );
}
