// The Lab: Aleister says a feature is finished and the player finds out
// whether it is, by using the app, poking the machinery under it and reading
// what crosses the wire. App holds the level, the world and the notes; the
// screens below draw them.

import { useEffect, useRef, useState } from "react";
import aleisterPng from "../../assets/portraits/aleister.png";
import gerardPng from "../../assets/portraits/gerard.png";
import ulrichPng from "../../assets/portraits/ulrich.png";
import { Device } from "./Device";
import { LEVELS, flawOf, type Flaw, type Level, type Text } from "./levels";
import {
  appContents, ask, askMessage, book, findKey, newWorld, peek, QUESTIONS, reload, restart, restaurant,
  viewTablet, type Build, type Hop, type Obs, type Step, type World,
} from "./model";
import { Xray } from "./Xray";

/** How long a message takes to cross one wire. Tests don't wait. */
const HOP_MS = import.meta.env.MODE === "test" ? 0 : 560;

type Phase = "intro" | "tool" | "test" | "report" | "incident" | "win" | "end";
type Caught = { kind: "book"; id: string; party: number } | { kind: "ask"; qid: string };
export type Wire = { hops: Hop[]; note?: string };
type Result = { incidents: number; rebuilds: number };

const FACES: Record<Text["who"], string | null> = { ulrich: ulrichPng, gerard: gerardPng, nonna: null };
const NAMES: Record<Text["who"], string> = { ulrich: "Ulrich", gerard: "Gerard", nonna: "Nonna" };

export default function App() {
  const [li, setLi] = useState(0);
  const level = LEVELS[li];
  const [phase, setPhase] = useState<Phase>("intro");
  const [world, setWorld] = useState<World>(() => newWorld(level.start));
  const [notes, setNotes] = useState<Obs[]>([]);
  const [view, setView] = useState<"phone" | "tablet">("phone");
  const [intercept, setIntercept] = useState(false);
  const [caught, setCaught] = useState<Caught | null>(null);
  const [anim, setAnim] = useState<{ step: Step; i: number } | null>(null);
  const [wire, setWire] = useState<Wire | null>(null);
  const [peeking, setPeeking] = useState(false);
  const [flash, setFlash] = useState<Obs | null>(null);
  const [hints, setHints] = useState(0);
  const [said, setSaid] = useState(level.brief);
  const [tried, setTried] = useState<string[]>([]);
  const [score, setScore] = useState<Result>({ incidents: 0, rebuilds: 0 });
  const [results, setResults] = useState<(Result | null)[]>(() => LEVELS.map(() => null));

  const flaw = flawOf(level, world.build);
  const problem = notes.find((n) => n.ok === false);
  const busy = anim !== null;

  function commit(step: Step, note?: string) {
    setWorld(step.world);
    if (step.obs.length > 0) {
      setNotes((old) => [...old.filter((n) => !step.obs.some((o) => o.id === n.id)), ...step.obs]);
    }
    if (step.trace.length > 0) setWire({ hops: step.trace });
    else if (note) setWire({ hops: [], note });
    const news = step.obs.find((o) => o.ok === false) ?? step.obs[step.obs.length - 1];
    if (news) setFlash(news);
    else if (step.trace.length === 0 && note) setFlash({ id: "wire", ok: null, text: note });
  }

  /** Play a step's messages across the wire, then show what they did. */
  function run(step: Step, note?: string) {
    if (step.trace.length === 0 || HOP_MS === 0) commit(step, note);
    else setAnim({ step, i: 0 });
  }

  useEffect(() => {
    if (!anim) return;
    const timer = setTimeout(() => {
      if (anim.i + 1 < anim.step.trace.length) setAnim({ step: anim.step, i: anim.i + 1 });
      else {
        commit(anim.step);
        setAnim(null);
      }
    }, HOP_MS);
    return () => clearTimeout(timer);
  }, [anim]);

  useEffect(() => {
    if (!flash) return;
    const timer = setTimeout(() => setFlash(null), 4500);
    return () => clearTimeout(timer);
  }, [flash]);

  function fresh(build: Build) {
    setFlash(null);
    setWorld(newWorld(build));
    setNotes([]);
    setView("phone");
    setIntercept(false);
    setCaught(null);
    setAnim(null);
    setWire(null);
    setPeeking(false);
    setHints(0);
  }

  function start(i: number) {
    const next = LEVELS[i];
    setLi(i);
    fresh(next.start);
    setSaid(next.brief);
    setTried([]);
    setScore({ incidents: 0, rebuilds: 0 });
    setPhase(next.newTool ? "tool" : "test");
  }

  function rebuild(value: string) {
    const build = { ...world.build, [level.part]: value } as Build;
    fresh(build);
    setTried((t) => (t.includes(value) ? t : [...t, value]));
    setScore((s) => ({ ...s, rebuilds: s.rebuilds + 1 }));
    setSaid(flawOf(level, build)?.rebuilt ?? level.fixed);
    setPhase("test");
  }

  function ship() {
    if (flaw) {
      setScore((s) => ({ ...s, incidents: s.incidents + 1 }));
      setPhase("incident");
    } else {
      setResults((r) => r.map((x, i) => (i === li ? score : x)));
      setPhase("win");
    }
  }

  function onBook(id: string, party: number) {
    const leaves = world.build.bookings === "server" || world.build.bookings === "db";
    if (intercept && leaves) setCaught({ kind: "book", id, party });
    else run(book(world, id, party), "You booked, and no message left the phone.");
  }

  function onAsk(qid: string) {
    if (intercept) setCaught({ kind: "ask", qid });
    else run(ask(world, qid));
  }

  function show(next: "phone" | "tablet") {
    setView(next);
    if (next === "tablet") run(viewTablet(world));
  }

  if (phase === "intro") return <Intro onStart={() => start(0)} />;
  if (phase === "end") return <End results={results} onAgain={() => start(0)} />;

  const hintList = flaw?.hints ?? [];
  return (
    <div className="app">
      <header className="bar">
        <span className="brand">Mission Silicon</span>
        <nav className="dots" aria-label="Levels">
          {LEVELS.map((l, i) => (
            <button
              key={l.id}
              className={i === li ? "dot here" : results[i] ? "dot done" : "dot"}
              aria-label={l.kicker}
              aria-current={i === li ? "step" : undefined}
              onClick={() => start(i)}
            >
              {i + 1}
            </button>
          ))}
        </nav>
      </header>

      <main className="play">
        <section className="aleister" aria-live="polite">
          <img src={aleisterPng} alt="" className="face" />
          <div className="bubble">
            <p className="kicker">{level.kicker}</p>
            <p className="who">Aleister Jr., your AI</p>
            <p className="line">{said}</p>
          </div>
        </section>

        <div className="bench">
          <Device
            world={world}
            view={view}
            busy={busy}
            hasAi={level.hasAi === true}
            onView={show}
            onBook={onBook}
            onAsk={onAsk}
          />
          <div className="side">
            <Xray
              world={world}
              level={level}
              view={view}
              hop={anim ? anim.step.trace[anim.i] : null}
              hopMs={HOP_MS}
              wire={anim ? { hops: anim.step.trace.slice(0, anim.i + 1) } : wire}
              busy={busy}
              keyFound={notes.some((n) => n.id === "peek" && n.ok === false)}
              intercept={intercept}
              onIntercept={setIntercept}
              onReload={() => run(reload(world))}
              onRestart={() => run(restart(world))}
              onPeek={() => {
                setPeeking(true);
                run(peek(world));
              }}
            />
            <section className="notes" aria-label="Your notes">
              <h2>Your notes</h2>
              {notes.length === 0 && hints === 0 && (
                <p className="empty">Nothing yet. Use the app, poke what's under it, and the notes write themselves.</p>
              )}
              <ul>
                {notes.map((n) => (
                  <li key={n.id} className={n.ok === false ? "note bad" : n.ok ? "note good" : "note"}>
                    <span className="mark" aria-hidden="true">{n.ok === false ? "✗" : n.ok ? "✓" : "·"}</span>
                    {n.text}
                  </li>
                ))}
                {hintList.slice(0, hints).map((h) => (
                  <li key={h} className="note hint"><span className="mark" aria-hidden="true">?</span>{h}</li>
                ))}
              </ul>
            </section>
          </div>
        </div>
      </main>

      {/* On a phone the machinery is a scroll away from the app, so what just
          crossed the wire, and what it showed, follows the player down here. */}
      {(anim || flash) && (
        <div className={anim ? "ticker" : flash!.ok === false ? "ticker bad" : "ticker"} aria-hidden="true">
          {anim ? (
            <>
              <span className="route">{anim.step.trace[anim.i].from} → {anim.step.trace[anim.i].to}</span>
              {anim.step.trace[anim.i].text}
            </>
          ) : (
            <>{flash!.ok === false ? "✗ " : flash!.ok ? "✓ " : ""}{flash!.text}</>
          )}
        </div>
      )}

      <footer className="actions">
        <button className="btn quiet" disabled={hints >= hintList.length} onClick={() => setHints((h) => h + 1)}>
          Hint
        </button>
        {problem ? (
          <>
            <button className="btn quiet" disabled={busy} onClick={ship}>Ship anyway</button>
            <button className="btn alarm" disabled={busy} onClick={() => setPhase("report")}>Tell Aleister</button>
          </>
        ) : (
          <button className="btn go" disabled={busy} onClick={ship}>Ship it</button>
        )}
      </footer>

      {phase === "tool" && level.newTool && (
        <Sheet label="New tool">
          <p className="kicker">New tool</p>
          <h2>{level.newTool.name}</h2>
          <p>{level.newTool.text}</p>
          <button className="btn go wide" onClick={() => setPhase("test")}>Got it</button>
        </Sheet>
      )}

      {caught && (
        <CaughtSheet
          caught={caught}
          world={world}
          sealed={world.build.check === "sealed"}
          onCancel={() => setCaught(null)}
          onSend={(party) => {
            const c = caught;
            setCaught(null);
            run(c.kind === "book" ? book(world, c.id, party, true) : ask(world, c.qid, true));
          }}
        />
      )}

      {peeking && (
        <PeekSheet
          build={world.build}
          found={notes.some((n) => n.id === "peek" && n.ok === false)}
          onFind={() => run(findKey(world))}
          onClose={() => setPeeking(false)}
        />
      )}

      {phase === "report" && flaw && problem && (
        <Sheet label="What you found" onClose={() => setPhase("test")}>
          <p className="kicker good">Caught before launch</p>
          <h2>You found it.</h2>
          <p className="saw"><span className="mark" aria-hidden="true">✗</span>{problem.text}</p>
          <Diagnosis level={level} flaw={flaw} tried={tried} current={world.build[level.part]} onFix={rebuild} />
        </Sheet>
      )}

      {phase === "incident" && flaw && (
        <Sheet label="Launch night">
          <p className="kicker bad">Launch night</p>
          <h2>You shipped it.</h2>
          <Texts texts={flaw.incident} />
          <Diagnosis level={level} flaw={flaw} tried={tried} current={world.build[level.part]} onFix={rebuild} />
        </Sheet>
      )}

      {phase === "win" && (
        <Sheet label="Shipped">
          <p className="kicker good">Launch night</p>
          <h2>Shipped. Quiet night.</h2>
          <Texts texts={level.quiet} />
          <p className="tally">
            {score.incidents === 0 ? "Caught before launch." : `Launched broken ${times(score.incidents)} first.`}{" "}
            {score.rebuilds === 1 ? "Fixed in one go." : `${score.rebuilds} rebuilds.`}
          </p>
          <Takeaway level={level} />
          <button className="btn go wide" onClick={() => (li + 1 < LEVELS.length ? start(li + 1) : setPhase("end"))}>
            {li + 1 < LEVELS.length ? "Next level" : "Finish"}
          </button>
        </Sheet>
      )}
    </div>
  );
}

function times(n: number) {
  return n === 1 ? "once" : n === 2 ? "twice" : `${n} times`;
}

function Intro({ onStart }: { onStart: () => void }) {
  return (
    <div className="intro">
      <p className="brand">Mission Silicon</p>
      <h1>Your AI says it's done.<br /><em>Is it?</em></h1>
      <p className="lede">
        You're launching Forkcast, an app that books dinner tables. Aleister Jr., your AI, writes all the code.
        That leaves you the other job: finding out whether it works, before your diners do.
      </p>
      <ol className="how">
        <li><span><b>Use the app</b> the way a real person would.</span></li>
        <li><span><b>Poke what's under it:</b> the phone, the server, the database.</span></li>
        <li><span><b>Ship it</b> when you'd bet a launch on it.</span></li>
      </ol>
      <div className="aleister small">
        <img src={aleisterPng} alt="" className="face" />
        <div className="bubble"><p className="line">I've never shipped a bug. I've shipped surprises.</p></div>
      </div>
      <button className="btn go wide" onClick={onStart}>Start</button>
      <p className="fine">Three levels, about ten minutes. You won't write any code.</p>
    </div>
  );
}

function End({ results, onAgain }: { results: (Result | null)[]; onAgain: () => void }) {
  const caught = results.filter((r) => r && r.incidents === 0).length;
  return (
    <div className="intro end">
      <p className="brand">Mission Silicon</p>
      <h1>Forkcast is live.</h1>
      <p className="lede">
        You caught {caught} of {LEVELS.length} before launch. Here's what you take with you: three checks to run on
        anything an AI builds for you, and what to say to it.
      </p>
      {LEVELS.map((l) => (
        <section className="card" key={l.id}>
          <p className="kicker">{l.kicker}</p>
          <Takeaway level={l} />
        </section>
      ))}
      <button className="btn go wide" onClick={onAgain}>Play again</button>
    </div>
  );
}

function Takeaway({ level }: { level: Level }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="takeaway">
      <h3>The check</h3>
      <p>{level.win.habit}</p>
      <h3>Say this to your AI</h3>
      <blockquote>{level.win.prompt}</blockquote>
      <button
        className="btn quiet smallbtn"
        onClick={() => {
          navigator.clipboard?.writeText(level.win.prompt).then(() => setCopied(true), () => {});
        }}
      >
        {copied ? "Copied" : "Copy"}
      </button>
      <h3>The real terms</h3>
      <dl className="terms">
        {level.win.terms.map(([term, means]) => (
          <div key={term}><dt>{term}</dt><dd>{means}</dd></div>
        ))}
      </dl>
    </div>
  );
}

function Diagnosis(props: { level: Level; flaw: Flaw; tried: string[]; current: string; onFix: (value: string) => void }) {
  const { level, flaw, tried, current } = props;
  return (
    <>
      <h3>Why</h3>
      <p>{flaw.why}</p>
      <p className="right-when"><b>When it's the right call:</b> {flaw.rightWhen}</p>
      <h3>Tell Aleister: {level.ask.toLowerCase()}</h3>
      <div className="fixes">
        {level.fixes.map((f) => (
          <button key={f.value} className="fix" disabled={f.value === current} onClick={() => props.onFix(f.value)}>
            <span>"{f.say}"</span>
            {f.value === current ? <small>That's this build</small> : tried.includes(f.value) && <small>Tried</small>}
          </button>
        ))}
      </div>
      <p className="fine">He'll build whichever you say. You'll have to test it again to know.</p>
    </>
  );
}

function Texts({ texts }: { texts: Text[] }) {
  return (
    <ul className="texts">
      {texts.map((t, i) => {
        const face = FACES[t.who];
        return (
          <li key={i} style={{ animationDelay: `${i * 0.5}s` }}>
            {face ? <img src={face} alt="" className="face" /> : <span className="face initial">N</span>}
            <p><b>{NAMES[t.who]}</b>{t.text}</p>
          </li>
        );
      })}
    </ul>
  );
}

function Sheet(props: { label: string; onClose?: () => void; children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    ref.current?.focus();
  }, []);
  return (
    <div className="scrim" onClick={(e) => e.target === e.currentTarget && props.onClose?.()}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label={props.label} tabIndex={-1} ref={ref}>
        {props.onClose && <button className="close" aria-label="Close" onClick={props.onClose}>×</button>}
        {props.children}
      </div>
    </div>
  );
}

function CaughtSheet(props: {
  caught: Caught;
  world: World;
  sealed: boolean;
  onCancel: () => void;
  onSend: (party: number) => void;
}) {
  const { caught, world } = props;
  const [party, setParty] = useState(caught.kind === "book" ? caught.party : 0);
  const message = caught.kind === "ask"
    ? askMessage(world, QUESTIONS.find((q) => q.id === caught.qid)!.ask)
    : null;
  return (
    <Sheet label="Message caught" onClose={props.onCancel}>
      <p className="kicker">Intercepted</p>
      <h2>Caught, mid-air.</h2>
      {caught.kind === "book" ? (
        <>
          <p>
            This is what the phone was about to send. The app has finished with it, so nothing in the app sees what
            you change now.{props.sealed && " It gets sealed after you've edited it."}
          </p>
          <div className="packet">
            <div>POST /bookings</div>
            <div>restaurant: "{restaurant(caught.id).name}"</div>
            <div className="edit">
              <label htmlFor="party">party:</label>
              <input
                id="party"
                type="number"
                inputMode="numeric"
                value={party}
                onChange={(e) => setParty(Math.round(Number(e.target.value)))}
              />
              <button className="chip" onClick={() => setParty(200)}>200</button>
              <button className="chip" onClick={() => setParty(-4)}>-4</button>
            </div>
          </div>
        </>
      ) : (
        <>
          <p>This is what the phone was about to send, and where it's going. Read it.</p>
          <div className="packet">
            <div>to: {message!.to === "ai" ? "the AI model, directly" : "our own server"}</div>
            <div className={message!.to === "ai" ? "hot" : undefined}>{message!.text}</div>
          </div>
        </>
      )}
      <button className="btn go wide" onClick={() => props.onSend(party)}>Let it go</button>
    </Sheet>
  );
}

function PeekSheet(props: { build: Build; found: boolean; onFind: () => void; onClose: () => void }) {
  const [shrug, setShrug] = useState<string | null>(null);
  const lines = appContents(props.build);
  const secret = lines.some((l) => l.secret);
  return (
    <Sheet label="Inside the app" onClose={props.onClose}>
      <p className="kicker">Peek inside</p>
      <h2>What ships to every phone</h2>
      <p>{secret || props.found ? "Tap anything a stranger shouldn't have." : "Everything in the app, as anyone holding it can read it."}</p>
      <div className="packet code">
        {lines.map((l) => (
          <button
            key={l.text}
            className={l.secret && props.found ? "hot" : shrug === l.text ? "meh" : undefined}
            onClick={() => (l.secret ? props.onFind() : setShrug(l.text))}
          >
            {l.text}
          </button>
        ))}
      </div>
      {props.found ? (
        <p className="saw"><span className="mark" aria-hidden="true">✗</span>That's the AI key, in every copy of the app.</p>
      ) : shrug ? (
        <p className="fine">Nothing secret about that one.</p>
      ) : !secret ? (
        <p className="saw ok"><span className="mark" aria-hidden="true">✓</span>No key in here. The app only knows our server's address.</p>
      ) : null}
      <button className="btn quiet wide" onClick={props.onClose}>Done</button>
    </Sheet>
  );
}
