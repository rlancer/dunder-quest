// Episode 1, the Pilot, on the web: the cold open and Walter's test; the map
// of a web app and one search followed through it; four decisions, each
// checked against Thursday's requirements as the player picks (where it
// runs, what goes where, build or rent the backend, reading the plan);
// Thursday by device; Gerard's decision record; the cliffhanger.
//
// Every word is in ../data/pilot.json and the rules are in model.ts. The
// story is pixel art (Scene); the lessons are plain, readable cards, with a
// cast member speaking each step aloud (Guide, Talk).

import { AnimatePresence, motion } from "motion/react";
import { useEffect, useMemo, useState } from "react";
import type { Line } from "./lines";
import { voiceKey } from "./lines";
import { P, clock, feed, fill, hoursLeft, marks, outcome, passes, platform, testers, thursday, type Option, type Req } from "./model";
import { Guide, MapView, Next, Notice, ReqTable, Stamp, Talk, castName, Portrait, type BoxId } from "./ui";
import { useTheme, type Theme } from "./theme";
import { setVoice, speak, stop, unlock, useAfterSpeech, useVoice } from "./voice";
import movein from "../../assets/backgrounds/movein.png";
import house from "../../assets/backgrounds/house.png";

const BACKDROPS: Record<string, string> = { movein, house };

const FRAMES = ["title", "cold", "goal", "map", "steps", "ways", "pick", "noserver", "sort", "backend", "plan", "thursday", "postmortem", "cliff", "end"] as const;
type Frame = (typeof FRAMES)[number];
// Which of the four decisions each frame is part of.
const DECISION: Partial<Record<Frame, number>> = { ways: 1, pick: 1, noserver: 2, sort: 2, backend: 3, plan: 4 };

export type Picks = { platform: string; tried: string[]; backend: string; triedBackend: string[]; misplaced: number; fixed: boolean };
const NO_PICKS: Picks = { platform: "", tried: [], backend: "", triedBackend: [], misplaced: 0, fixed: false };
const SAVE = "ms-pilot";

function loadSave(): { frame: number; picks: Picks } | null {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE) || "null");
    return s && typeof s.frame === "number" ? s : null;
  } catch {
    return null;
  }
}

const ricky = (say: string): Line => ({ who: "ricky", say });

export default function Pilot({ speed = 10 }: { speed?: number }) {
  const saved = useMemo(loadSave, []);
  const [i, setI] = useState(0);
  const [picks, setPicks] = useState<Picks>(NO_PICKS);
  const frame = FRAMES[i];
  const go = (n: number) => {
    stop();
    setI(n);
    window.scrollTo?.({ top: 0 });
  };
  const next = () => go(i + 1);
  const pick = (p: Partial<Picks>) => setPicks((x) => ({ ...x, ...p }));

  useEffect(() => {
    try {
      if (i > 0 && frame !== "end") localStorage.setItem(SAVE, JSON.stringify({ frame: i, picks }));
      if (frame === "end") localStorage.removeItem(SAVE);
    } catch {}
  }, [i, picks]);

  const start = (from?: { frame: number; picks: Picks }) => {
    unlock();
    setPicks(from?.picks ?? NO_PICKS);
    go(from?.frame ?? 1);
  };

  return (
    <>
      {frame !== "title" && <Bar frame={frame} picks={picks} />}
      <AnimatePresence mode="wait">
        <motion.div key={frame} style={{ flex: 1, display: "flex", flexDirection: "column" }} initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: 0.18 }}>
          {frame === "title" && <Title saved={saved} onStart={start} />}
          {frame === "cold" && <Scene {...P.cold_open} onDone={next} />}
          {frame === "goal" && <GoalCard onNext={next} />}
          {frame === "map" && <MapFrame onNext={next} />}
          {frame === "steps" && <StepsFrame onNext={next} />}
          {frame === "ways" && <WaysFrame onNext={next} />}
          {frame === "pick" && <PickFrame picks={picks} pick={pick} onNext={next} />}
          {frame === "noserver" && <NoServerFrame onNext={next} />}
          {frame === "sort" && <SortFrame picks={picks} pick={pick} onNext={next} />}
          {frame === "backend" && <BackendFrame picks={picks} pick={pick} onNext={next} />}
          {frame === "plan" && <PlanFrame picks={picks} pick={pick} onNext={next} />}
          {frame === "thursday" && <ThursdayFrame picks={picks} speed={speed} onNext={next} />}
          {frame === "postmortem" && <PostmortemFrame picks={picks} onNext={next} />}
          {frame === "cliff" && <Scene {...P.cliffhanger} onDone={next} />}
          {frame === "end" && <EndCard onAgain={() => start()} />}
        </motion.div>
      </AnimatePresence>
    </>
  );
}

// The bar: the episode, the four decisions, Aleister's hours, the sound.
const THEME: Record<Theme, [string, string]> = { auto: ["◐", "Auto"], light: ["☀", "Light"], dark: ["☾", "Dark"] };

function Bar({ frame, picks }: { frame: Frame; picks: Picks }) {
  const { on } = useVoice();
  const [theme, nextTheme] = useTheme();
  const at = FRAMES.indexOf(frame);
  const cur = DECISION[frame] ?? 0;
  const used = (picks.platform ? platform(picks.platform)!.h : 0) + (picks.backend ? P.backend.options.find((b) => b.id === picks.backend)!.h : 0);
  const left = P.budget.time - used;
  const doneBy = [FRAMES.indexOf("noserver"), FRAMES.indexOf("backend"), FRAMES.indexOf("plan"), FRAMES.indexOf("thursday")];
  return (
    <header className="bar">
      <span className="brand">
        MISSION <b>SILICON</b>
      </span>
      <span className="ep">Episode 1 · Pilot</span>
      <span className="decisions" aria-label="The four decisions">
        {P.decisions.map((d, k) => (
          <span key={d} title={d} className={`dec${at >= doneBy[k] ? " done" : cur === k + 1 ? " on" : ""}`}>
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
        {on ? "🔊" : "🔇"}<span className="lbl"> {on ? "Voices" : "Muted"}</span>
      </button>
      <button className="sound" onClick={nextTheme} aria-label={`Theme: ${THEME[theme][1]}. Tap to change.`} title="Light, dark, or your device's setting">
        {THEME[theme][0]}<span className="lbl"> {THEME[theme][1]}</span>
      </button>
    </header>
  );
}

function Title({ saved, onStart }: { saved: { frame: number; picks: Picks } | null; onStart: (from?: { frame: number; picks: Picks }) => void }) {
  return (
    <div className="card-screen">
      <div>
        <div className="kicker">EPISODE 1 · PILOT</div>
        <h1>
          MISSION <b>SILICON</b>
        </h1>
        <p className="sub">You're a non-technical founder with an AI startup and a very confident AI coding assistant. Learn the decisions behind every app you'll build with AI.</p>
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
          The cast talk you through it. Turn your sound on, or read along.
        </p>
      </div>
    </div>
  );
}

// A story scene: a pixel-art backdrop and one line at a time beneath it. The
// next line comes when the voice finishes, or on a tap.
function Scene({ place, backdrop, lines, onDone }: { place: string; backdrop: string; lines: Line[]; onDone: () => void }) {
  const [n, setN] = useState(0);
  const line = lines[n];
  const advance = () => (n + 1 < lines.length ? setN(n + 1) : onDone());
  useEffect(() => speak(line), [n]);
  useAfterSpeech(voiceKey(line), () => n + 1 < lines.length && setN((x) => Math.min(x + 1, lines.length - 1)));
  return (
    <div className="scene" onClick={advance} role="button" tabIndex={0} aria-label="Next line" onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && advance()}>
      <div className="backdrop">
        <img className="px" src={BACKDROPS[backdrop]} alt="" />
        <span className="place pixel">{place}</span>
      </div>
      <AnimatePresence mode="wait">
        <motion.div key={n} className="say" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0 }} transition={{ duration: 0.15 }}>
          <Portrait who={line.who} size={64} />
          <div>
            <div className="name pixel">{castName(line.who)}</div>
            <div className="text">{line.say}</div>
          </div>
        </motion.div>
      </AnimatePresence>
      <div className="tap">{n + 1 < lines.length ? "Tap for the next line" : "Tap to go on"} · {n + 1} of {lines.length}</div>
    </div>
  );
}

function GoalCard({ onNext }: { onNext: () => void }) {
  const g = P.goal_card;
  return (
    <div className="card-screen">
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
        <button className="btn" onClick={onNext}>
          Show me →
        </button>
      </div>
    </div>
  );
}

// Act 1: the map. Four boxes; each says what it is.
function MapFrame({ onNext }: { onNext: () => void }) {
  const m = P.map;
  const [sel, setSel] = useState<BoxId | null>(null);
  const [seen, setSeen] = useState<Record<string, boolean>>({});
  const n = Object.keys(seen).length;
  const tap = (k: BoxId) => {
    setSel(k);
    setSeen((s) => ({ ...s, [k]: true }));
  };
  const info = sel ? m.info[sel] : null;
  const line = info ? ricky(info.say) : n === 4 ? m.done_say : m.hint;
  return (
    <div className="lesson">
      {n === 4 && info ? <Talk key={sel} lines={[line, m.done_say]} /> : <Guide line={line} />}
      <h2>Every app is four boxes</h2>
      <p className="lede">{m.prompt}</p>
      <MapView hot={sel ?? undefined} seen={seen} onTap={tap} />
      {info && (
        <motion.div key={sel} className="panel" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
          <strong>{info.h}</strong>
          <dl className="facts">
            {(["pic", "real", "fk", "note"] as const).map((k) => (
              <div key={k} style={{ display: "contents" }}>
                <dt>{m.keys[k]}</dt>
                <dd>{info[k]}</dd>
              </div>
            ))}
          </dl>
        </motion.div>
      )}
      <Next onClick={onNext} disabled={n < 4} why={n < 4 ? `Tap all four boxes · ${n} of 4` : m.done}>
        Follow a search
      </Next>
    </div>
  );
}

// Act 1: one search, step by step, the envelope moving box to box.
function StepsFrame({ onNext }: { onNext: () => void }) {
  const list = P.steps.list;
  const [k, setK] = useState(0);
  const s = list[k];
  return (
    <div className="lesson">
      <Guide line={ricky(s.t)} />
      <h2>{P.steps.prompt}</h2>
      <MapView at={s.at} hot={s.at === "wire" ? undefined : s.at} label={k === list.length - 1 ? "response" : "request"} />
      <motion.div key={k} className="panel" initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
        <span className="term">
          Step {k + 1} · {s.term}
        </span>
        <div className="eg">{s.eg.includes("{") ? <code>{s.eg}</code> : s.eg}</div>
      </motion.div>
      <div className="steps-nav">
        <span className="dots" aria-label={`Step ${k + 1} of ${list.length}`}>
          {list.map((_, j) => (
            <span key={j} className={`dot${j <= k ? " on" : ""}`} />
          ))}
        </span>
        <button className="btn ghost small" onClick={() => setK(k - 1)} disabled={k === 0}>
          ← Back
        </button>
        {k < list.length - 1 ? (
          <button className="btn small" onClick={() => setK(k + 1)}>
            Next step →
          </button>
        ) : (
          <button className="btn small" onClick={onNext}>
            On to the decisions →
          </button>
        )}
      </div>
    </div>
  );
}

// Decision 1: four ways to put an app in front of people.
function WaysFrame({ onNext }: { onNext: () => void }) {
  const [ready, setReady] = useState(false);
  const [sel, setSel] = useState<string | null>(null);
  const [seen, setSeen] = useState<Record<string, boolean>>({});
  const n = Object.keys(seen).length;
  const p = sel ? platform(sel)! : null;
  return (
    <div className="lesson">
      <Talk lines={P.ways.lines} onDone={() => setReady(true)} />
      {ready && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <h2>{P.ways.prompt}</h2>
          <p className="lede">{P.ways.status}. Tap each to see what it's good at and what it costs.</p>
          <div className="options">
            {P.platforms.map((o) => (
              <button key={o.id} className={`option${seen[o.id] ? " seen" : ""}${sel === o.id ? " sel" : ""}`} onClick={() => (setSel(o.id), setSeen((s) => ({ ...s, [o.id]: true })))} aria-pressed={sel === o.id}>
                <span className="n">{o.n}</span>
                <span className="realname">{o.rn}</span>
              </button>
            ))}
          </div>
          {p && (
            <motion.div key={p.id} className="panel" initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }}>
              <strong>{p.n}</strong> · {p.how}
              <div className="goodcost">
                <div className="good">
                  <b>Good at</b>
                  {p.good}
                </div>
                <div className="cost">
                  <b>Costs</b>
                  {p.cost}
                </div>
              </div>
            </motion.div>
          )}
          <Next onClick={onNext} disabled={n < 4} why={n < 4 ? `Look at all four · ${n} of 4` : "Now pick one for Thursday."}>
            Pick one
          </Next>
        </motion.div>
      )}
    </div>
  );
}

// Decision 1: pick one, against Thursday's requirements. Only the web app
// and the installable web app go on; the others say when they'd be right.
function PickFrame({ picks, pick, onNext }: { picks: Picks; pick: (p: Partial<Picks>) => void; onNext: () => void }) {
  const q = P.pick;
  const [sel, setSel] = useState<string | null>(picks.platform || null);
  const p = sel ? platform(sel)! : null;
  const reqs = q.reqs as Req[];
  const ok = p ? passes(p, reqs, P.budget.time) : false;
  const choose = (id: string) => {
    setSel(id);
    const fits = passes(platform(id)!, reqs, P.budget.time);
    pick({ tried: [...new Set([...picks.tried, id])], platform: fits ? id : "" });
  };
  const quip = sel ? (q.quips as Record<string, Line>)[sel] : null;
  return (
    <div className="lesson">
      <Guide line={q.guide} voice={!sel} />
      <h2>{q.prompt}</h2>
      <div className="options">
        {P.platforms.map((o) => {
          const fits = passes(o, reqs, P.budget.time);
          const tried = picks.tried.includes(o.id);
          return (
            <button key={o.id} className={`option${sel === o.id ? " sel" : ""}${tried && !fits ? " fail" : ""}`} onClick={() => choose(o.id)} aria-pressed={sel === o.id}>
              <span className="n">{o.n}</span>
              <span className="h">About {o.h} hours of Aleister's 8</span>
              {tried && <span className={`tag ${fits ? "ok" : "no"}`}>{fits ? "Fits Thursday" : "Doesn't fit Thursday"}</span>}
            </button>
          );
        })}
      </div>
      <div className="panel">
        <ReqTable reqs={reqs} r={p?.r ?? null} head={q.needs} laterNote={q.later} />
      </div>
      {p && quip && (
        <div style={{ marginTop: 14 }} key={p.id}>
          <Talk lines={[quip, ricky(ok ? q.right : q.wrong)]} />
          {ok ? <Notice kind="good" head="Fits Thursday">{q.right_head}</Notice> : <Misses name={p.n} what="not for Thursday" reqs={reqs} r={p.r} hours={P.budget.time} h={p.h} />}
        </div>
      )}
      <Next onClick={onNext} disabled={!ok} why={!sel ? "Pick one to check it." : ok ? "" : "Every MUST needs a yes. Try another."}>
        Lock it in
      </Next>
    </div>
  );
}

// Decision 2: Aleister's no-server plan, and the key anyone can read.
function NoServerFrame({ onNext }: { onNext: () => void }) {
  const d = P.noserver;
  const [stage, setStage] = useState(0);
  return (
    <div className="lesson">
      <Talk lines={d.lines} onDone={() => setStage((s) => Math.max(s, 1))} />
      <h2>{d.prompt}</h2>
      <MapView skipServer at={undefined} />
      {stage >= 1 && stage < 2 && (
        <div className="next-row" style={{ justifyContent: "flex-start" }}>
          <button className="btn" onClick={() => setStage(2)}>
            {d.button}
          </button>
        </div>
      )}
      {stage >= 2 && (
        <>
          <pre className="code" aria-label="The app's code">
            {d.code.map((c, k) => (
              <div key={k} className={k === d.key_line ? "hot" : c.startsWith("//") ? "dim" : ""}>
                {c || " "}
              </div>
            ))}
          </pre>
          <div style={{ marginTop: 14 }}>
            <Talk lines={d.after} onDone={() => setStage(3)} />
          </div>
        </>
      )}
      {stage >= 3 && (
        <>
          <Stamp s={d.stamp} />
          <Next onClick={onNext}>So what goes where?</Next>
        </>
      )}
    </div>
  );
}

// Decision 2: the sort. Tap a piece, then where it lives. A piece in the
// wrong place shows why and must be taken back before the next.
function SortFrame({ picks, pick, onNext }: { picks: Picks; pick: (p: Partial<Picks>) => void; onNext: () => void }) {
  const s = P.sort;
  const [placed, setPlaced] = useState<Record<string, string>>({});
  const [armed, setArmed] = useState<string | null>(null);
  const [last, setLast] = useState<{ id: string; z: string } | null>(null);
  const wrong = Object.entries(placed).find(([id, z]) => s.pieces.find((p) => p.id === id)!.z !== z)?.[0];
  const allRight = s.pieces.every((p) => placed[p.id] === p.z);
  const put = (z: string) => {
    if (!armed) return;
    const piece = s.pieces.find((p) => p.id === armed)!;
    setPlaced({ ...placed, [armed]: z });
    setLast({ id: armed, z });
    if (piece.z !== z) pick({ misplaced: picks.misplaced + 1 });
    setArmed(null);
  };
  const takeBack = (id: string) => {
    const { [id]: _, ...rest } = placed;
    setPlaced(rest);
    setLast(null);
    setArmed(id);
  };
  const lp = last ? s.pieces.find((p) => p.id === last.id)! : null;
  return (
    <div className="lesson">
      <Guide line={allRight ? ricky(s.done) : s.guide} />
      <h2>{s.prompt}</h2>
      <div className="pieces" aria-label="Pieces to place">
        {s.pieces
          .filter((p) => !placed[p.id])
          .map((p) => (
            <button key={p.id} className={`piece${armed === p.id ? " armed" : ""}`} disabled={!!wrong} onClick={() => setArmed(armed === p.id ? null : p.id)} aria-pressed={armed === p.id}>
              {p.t}
            </button>
          ))}
        {allRight && <span className="why">All seven placed.</span>}
      </div>
      <div className="zones">
        {s.zones.map((z) => (
          <div key={z.id} className={`zone${armed ? " target" : ""}`} onClick={() => put(z.id)} role={armed ? "button" : undefined} aria-label={armed ? `Put it on: ${z.h}` : undefined}>
            <span className="h">{z.h}</span>
            <span className="s">{z.s}</span>
            {s.pieces
              .filter((p) => placed[p.id] === z.id)
              .map((p) =>
                p.z === z.id ? (
                  <div key={p.id} className="placed">
                    <b>{p.t}</b>
                  </div>
                ) : (
                  <button key={p.id} className="placed wrong" onClick={(e) => (e.stopPropagation(), takeBack(p.id))}>
                    <b>{p.t}</b>
                    {s.take_back}
                  </button>
                ),
              )}
          </div>
        ))}
      </div>
      {lp && last && (
        <Notice key={`${last.id}-${last.z}`} kind={lp.z === last.z ? "good" : "bad"} head={lp.t}>
          {(lp.why as Record<string, string>)[last.z]}
        </Notice>
      )}
      <Next onClick={onNext} disabled={!allRight} why={allRight ? s.done : `${Object.keys(placed).length - (wrong ? 1 : 0)} of ${s.pieces.length} ${s.placed}`}>
        Next decision
      </Next>
    </div>
  );
}

// Decision 3: build or rent the backend, in the hours the platform left.
function BackendFrame({ picks, pick, onNext }: { picks: Picks; pick: (p: Partial<Picks>) => void; onNext: () => void }) {
  const b = P.backend;
  const left = hoursLeft(picks.platform);
  const [sel, setSel] = useState<string | null>(picks.backend || null);
  const reqs = b.reqs as Req[];
  const o = sel ? (b.options.find((x) => x.id === sel)! as Option & (typeof b.options)[number]) : null;
  const ok = o ? passes(o, reqs, left) : false;
  const choose = (id: string) => {
    setSel(id);
    const opt = b.options.find((x) => x.id === id)! as Option;
    pick({ triedBackend: [...new Set([...picks.triedBackend, id])], backend: passes(opt, reqs, left) ? id : "" });
  };
  const f = (s: string) => fill(s, left);
  return (
    <div className="lesson">
      <Guide line={b.guide} voice={!sel} />
      <h2>{b.prompt}</h2>
      <p className="lede">
        {platform(picks.platform)?.n} took {platform(picks.platform)?.h} of Aleister's {P.budget.time} hours. {left} left.
      </p>
      <div className="options">
        {b.options.map((x) => {
          const fits = passes(x as Option, reqs, left);
          const tried = picks.triedBackend.includes(x.id);
          return (
            <button key={x.id} className={`option${sel === x.id ? " sel" : ""}${tried && !fits ? " fail" : ""}`} onClick={() => choose(x.id)} aria-pressed={sel === x.id}>
              <span className="n">{x.n}</span>
              <span className="realname">{x.rn}</span>
              <span className="h">About {x.h} hour{x.h === 1 ? "" : "s"}</span>
              {tried && <span className={`tag ${fits ? "ok" : "no"}`}>{fits ? "Fits" : "Doesn't fit"}</span>}
            </button>
          );
        })}
      </div>
      {o && (
        <motion.div key={o.id} className="goodcost" style={{ marginBottom: 12 }} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <div className="good">
            <b>Good at</b>
            {o.good}
          </div>
          <div className="cost">
            <b>Costs</b>
            {o.cost}
          </div>
        </motion.div>
      )}
      <div className="panel">
        <ReqTable reqs={reqs} r={o?.r ?? null} head={b.needs} laterNote="(later)" fill={f} />
      </div>
      {o && (
        <div style={{ marginTop: 14 }} key={o.id}>
          <Talk lines={ok ? [b.quip, ricky(b.right)] : [ricky(b.wrong)]} />
          {ok ? <Notice kind="good" head="Fits">{b.right_head}</Notice> : <Misses name={o.n} what="not this time" reqs={reqs} r={o.r} hours={left} h={o.h} fill={f} />}
        </div>
      )}
      <Next onClick={onNext} disabled={!ok} why={!sel ? "Pick one to check it." : ok ? "" : "Every MUST needs a yes. Try another."}>
        Lock it in
      </Next>
    </div>
  );
}

// Which musts an option misses, so a wrong pick says exactly why.
function Misses({ name, what, reqs, r, hours, h, fill: f = (s) => s }: { name: string; what: string; reqs: Req[]; r: Record<string, string[]>; hours: number; h: number; fill?: (s: string) => string }) {
  const miss = reqs.filter((q) => !q.later && q.must && r[q.id]?.[0] !== "y").map((q) => f(q.t));
  if (h > hours && !miss.length) miss.push(`Fits the ${hours} hours`);
  return (
    <Notice kind="bad" head={`${name}: ${what}`}>
      Misses {miss.length} must{miss.length === 1 ? "" : "s"}: {miss.join("; ")}.
    </Notice>
  );
}

const BOX_OF: Record<string, BoxId> = { Frontend: "device", Backend: "server", Database: "db", "AI model": "model" };

// Decision 4: Aleister's tech stack. Each line goes on the map; the one that
// can't is the NEXT_PUBLIC_ key, headed for the phone again.
function PlanFrame({ picks, pick, onNext }: { picks: Picks; pick: (p: Partial<Picks>) => void; onNext: () => void }) {
  const d = P.plan;
  const [ready, setReady] = useState(false);
  const [open, setOpen] = useState<Record<number, boolean>>({});
  const [cur, setCur] = useState<number | null>(null);
  const [fixed, setFixed] = useState(picks.fixed);
  const plat = picks.platform || "web";
  const text = (v: string | Record<string, string>) => (typeof v === "string" ? v : v[plat] ?? v.web);
  const n = Object.keys(open).length;
  const done = n === d.lines.length && fixed;
  const line = cur !== null ? d.lines[cur] : null;
  const isBad = (l: (typeof d.lines)[number]) => "bad" in l && !!l.bad;
  const boxOf = (l: (typeof d.lines)[number]) => (isBad(l) && fixed && "fixed_box" in l ? l.fixed_box! : l.box);
  return (
    <div className="lesson">
      <Talk lines={[d.guide, d.intro]} onDone={() => setReady(true)} />
      {ready && (
        <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
          <h2>{d.prompt}</h2>
          <div className="cols">
            <div className="stack">
              <div className="head">{d.head}</div>
              {d.lines.map((l, k) => {
                const bad = isBad(l);
                const c = bad && fixed && "fixed" in l ? l.fixed! : text(l.c);
                const box = boxOf(l);
                return (
                  <button key={k} className={`stackline${open[k] ? " open" : ""}${bad && !fixed ? " bad" : ""}`} onClick={() => (setCur(k), setOpen((o) => ({ ...o, [k]: true })))} aria-pressed={cur === k}>
                    <span>{c}</span>
                    <span className={`boxtag${open[k] ? (box === "?" ? " q" : " placed") : ""}`}>{open[k] ? box : d.read}</span>
                  </button>
                );
              })}
            </div>
            <div>
              <MapView hot={line ? BOX_OF[boxOf(line)] : undefined} seen={Object.fromEntries(Object.keys(open).map((k) => [BOX_OF[boxOf(d.lines[+k])], true]))} />
              {line && (
                <motion.div key={`${cur}-${fixed}`} className={`notice${isBad(line) && !fixed ? " bad" : ""}`} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                  {isBad(line) && !fixed && "look" in line && <h4>{line.look}</h4>}
                  {text(line.plain)}
                  {isBad(line) && !fixed && (
                    <div className="next-row" style={{ justifyContent: "flex-start" }}>
                      <button className="btn small" onClick={() => (setFixed(true), pick({ fixed: true }))}>
                        {d.fix_button}
                      </button>
                    </div>
                  )}
                </motion.div>
              )}
            </div>
          </div>
          {fixed && (
            <div style={{ marginTop: 14 }}>
              <Guide line={d.fixed} />
            </div>
          )}
          {done && <Stamp s={d.stamp} />}
          <Next onClick={onNext} disabled={!done} why={done ? "" : n < d.lines.length ? `Place every line on the map · ${n} of ${d.lines.length}` : "One line can't be placed. Look closer."}>
            {d.merge}
          </Next>
        </motion.div>
      )}
    </div>
  );
}

// Thursday: 200 testers on three kinds of device, each square one diner,
// the 4:40 iPhone bug, and the same evening on native apps for comparison.
function ThursdayFrame({ picks, speed, onNext }: { picks: Picks; speed: number; onNext: () => void }) {
  const T = P.thursday;
  const mine = picks.platform || "web";
  const [build, setBuild] = useState(mine);
  const [m, setM] = useState(0);
  const [running, setRunning] = useState(true);
  const [ranMine, setRanMine] = useState(false);
  const all = testers();
  useEffect(() => {
    if (!running) return;
    let raf = 0;
    let last = performance.now();
    const tick = (now: number) => {
      const dt = Math.max(0, now - last) / 1000;
      last = now;
      setM((x) => (speed === Infinity ? T.minutes : Math.min(T.minutes, x + dt * speed)));
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [running, build]);
  useEffect(() => {
    if (m >= T.minutes) {
      setRunning(false);
      if (build === mine) setRanMine(true);
    }
  }, [m]);
  const restart = (b: string) => {
    setBuild(b);
    setM(0);
    setRunning(true);
  };
  const c = thursday(build, m);
  const share = c.n ? c.fit / c.n : 0;
  const finished = m >= T.minutes;
  const goal = P.goal_share;
  return (
    <div className="lesson">
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
          <button className="btn ghost small" onClick={() => setRunning(!running)}>
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
      {finished && (
        <Notice kind={share >= goal ? "good" : "bad"} head={`${platform(build)!.n}: ${Math.round(share * 100)}% found a place that fits`}>
          {build === "native"
            ? `On native apps the laptops can't open it at all, and the iPhone fix waits for store review. That's why the platform decision mattered.`
            : `${c.wrong} iPhone diners booked the wrong night before the fix went live three minutes later. On the web, a fix reaches everyone on their next tap. Try "${T.native}" to see the other road.`}
        </Notice>
      )}
      <Next onClick={onNext} disabled={!ranMine} why={ranMine ? "" : "Watch your build's evening to the end."}>
        Gerard's postmortem
      </Next>
    </div>
  );
}

// Gerard's decision record, the marks, Walter's cheque and the runway.
function PostmortemFrame({ picks, onNext }: { picks: Picks; onNext: () => void }) {
  const d = P.postmortem;
  const plat = picks.platform || "web";
  const rows = [(d.platform_rows as Record<string, string[]>)[plat], ...d.rows];
  const m = marks(plat, picks.tried.includes("native"));
  return (
    <div className="lesson">
      <Talk lines={[d.guide, d.cheque]} />
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
          {rows.map((r) => (
            <tr key={r[0]}>
              {r.map((cell, k) => (
                <td key={k} data-h={k ? d.heads[k] : undefined}>
                  {cell || "—"}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
      <Notice head="New word">{d.word.replace(/^New word · /, "")}</Notice>
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
      <Next onClick={onNext}>Thursday night</Next>
    </div>
  );
}

function EndCard({ onAgain }: { onAgain: () => void }) {
  const n = P.cliffhanger.next;
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

