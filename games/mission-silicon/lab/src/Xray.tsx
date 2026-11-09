// Under the hood: the boxes the app is made of, what each one is holding
// right now, and the last messages that crossed between them. The buttons
// on the boxes are the things that happen to them on a real night.

import { useLayoutEffect, useRef, useState } from "react";
import type { Wire } from "./App";
import type { Level } from "./levels";
import { keyOnPhone, restaurant, type Hop, type Place, type World } from "./model";

type Props = {
  world: World;
  level: Level;
  view: "phone" | "tablet";
  hop: Hop | null;
  hopMs: number;
  wire: Wire | null;
  busy: boolean;
  keyFound: boolean;
  intercept: boolean;
  onIntercept: (on: boolean) => void;
  onReload: () => void;
  onRestart: () => void;
  onPeek: () => void;
};

type Spot = { x: number; y: number; w: number; h: number };

/** Where the wire from box a towards box b leaves a's edge. */
function edge(a: Spot, b: Spot): { x: number; y: number } {
  const dx = b.x - a.x;
  const dy = b.y - a.y;
  const t = Math.min(dx ? a.w / 2 / Math.abs(dx) : Infinity, dy ? a.h / 2 / Math.abs(dy) : Infinity, 1);
  return { x: a.x + dx * t, y: a.y + dy * t };
}
const LABEL: Record<Place, string> = { phone: "phone", tablet: "tablet", server: "server", db: "database", ai: "AI model" };

/** The tablet stands where the phone does: the box is whichever one is in hand. */
function boxOf(place: Place): string {
  return place === "tablet" ? "phone" : place;
}

export function Xray(props: Props) {
  const { world, level, view, hop, wire, busy } = props;
  const b = world.build;
  const has = (tool: string) => level.tools.includes(tool as never);
  const ref = useRef<HTMLDivElement>(null);
  const [spots, setSpots] = useState<Record<string, Spot>>({});

  useLayoutEffect(() => {
    const el = ref.current;
    if (!el) return;
    const measure = () => {
      const base = el.getBoundingClientRect();
      const out: Record<string, Spot> = {};
      el.querySelectorAll<HTMLElement>("[data-place]").forEach((n) => {
        const r = n.getBoundingClientRect();
        out[n.dataset.place!] = { x: r.left - base.left + r.width / 2, y: r.top - base.top + r.height / 2, w: r.width, h: r.height };
      });
      setSpots(out);
    };
    measure();
    if (typeof ResizeObserver === "undefined") return;
    const ro = new ResizeObserver(measure);
    ro.observe(el);
    return () => ro.disconnect();
  }, [world, level, view]);

  const wires: [string, string, string][] = [["phone", "server", ""], ["server", "db", ""]];
  if (level.hasAi) wires.push(keyOnPhone(b) ? ["phone", "ai", "direct"] : ["server", "ai", ""]);
  const live = hop ? [boxOf(hop.from), boxOf(hop.to)] : [];
  const box = (place: string) => (hop && boxOf(hop.to) === place ? "box lit" : "box");

  return (
    <section className="xray" aria-label="Under the hood">
      <h2>Under the hood</h2>
      <div className={level.hasAi ? "boxes four" : "boxes"} ref={ref}>
        <svg className="wires" aria-hidden="true">
          {wires.map(([from, to, kind]) => {
            if (!spots[from] || !spots[to]) return null;
            const a = edge(spots[from], spots[to]);
            const z = edge(spots[to], spots[from]);
            return (
              <line
                key={from + to}
                x1={a.x} y1={a.y} x2={z.x} y2={z.y}
                className={live.includes(from) && live.includes(to) ? `on ${kind}` : kind}
              />
            );
          })}
        </svg>

        <div className={box("phone")} data-place="phone">
          <h3>{view === "tablet" ? "Tablet" : "Phone"}</h3>
          <p className="real">frontend</p>
          {view === "tablet" ? <p className="holds none">shows what the server tells it</p> : (
            <>
              {b.bookings === "memory" && <Held n={world.phone.memory.length} where="in the app's memory" />}
              {b.bookings === "storage" && <Held n={world.phone.storage.length} where="in phone storage" />}
              {(b.bookings === "server" || b.bookings === "db") && <p className="holds none">keeps no bookings</p>}
              {props.keyFound && <p className="holds hot">AI key</p>}
            </>
          )}
          {view === "phone" && <button className="poke" disabled={busy} onClick={props.onReload}>Close and reopen</button>}
          {view === "phone" && has("peek") && <button className="poke" disabled={busy} onClick={props.onPeek}>Peek inside</button>}
        </div>

        <div className={box("server")} data-place="server">
          <h3>Server</h3>
          <p className="real">backend</p>
          {b.bookings === "server" ? <Held n={world.server.memory.length} where="in its memory" /> : (
            <p className="holds none">keeps no bookings</p>
          )}
          {b.check === "server" && <p className="holds rule">checks every booking</p>}
          {b.check !== "server" && level.part === "check" && <p className="holds none">no checks of its own</p>}
          {b.key === "server" && <p className="holds rule">AI key, kept here</p>}
          <button className="poke" disabled={busy} onClick={props.onRestart}>Restart</button>
        </div>

        <div className={box("db")} data-place="db">
          <h3>Database</h3>
          <p className="real">kept for good</p>
          <p className={world.db.bookings.length ? "holds" : "holds none"}>
            bookings: {world.db.bookings.length} {world.db.bookings.length === 1 ? "row" : "rows"}
          </p>
          {world.db.bookings.slice(-2).map((x) => (
            <p key={x.id} className="rowline">#{x.id} {restaurant(x.restaurant).name} · {x.party}</p>
          ))}
          <p className="holds none">restaurants: 3 rows</p>
        </div>

        {level.hasAi && (
          <div className={box("ai")} data-place="ai">
            <h3>AI model</h3>
            <p className="real">rented, paid per question</p>
            <p className={world.ai.questions ? "holds" : "holds none"}>questions: {world.ai.questions}</p>
          </div>
        )}

        {hop && spots[boxOf(hop.from)] && spots[boxOf(hop.to)] && (
          <Packet
            key={`${hop.from}${hop.to}${hop.text}`}
            from={edge(spots[boxOf(hop.from)], spots[boxOf(hop.to)])}
            to={edge(spots[boxOf(hop.to)], spots[boxOf(hop.from)])}
            ms={props.hopMs}
            bad={hop.bad}
          />
        )}
      </div>

      {has("intercept") && (
        <label className={props.intercept ? "intercept on" : "intercept"}>
          <input
            type="checkbox"
            checked={props.intercept}
            disabled={busy}
            onChange={(e) => props.onIntercept(e.target.checked)}
          />
          <span><b>Intercept</b> Pause what the phone sends, so you can read it and change it.</span>
        </label>
      )}

      <div className="wirelog" aria-live="polite">
        <p className="label">On the wire</p>
        {!wire && <p className="none">No messages yet.</p>}
        {wire?.note && <p className="quiet-wire">{wire.note}</p>}
        {wire && wire.hops.length > 0 && (
          <ol>
            {wire.hops.map((h, i) => (
              <li key={i} className={h.bad ? "bad" : undefined}>
                <span className="route">{LABEL[h.from]} → {LABEL[h.to]}</span>
                {h.text}
              </li>
            ))}
          </ol>
        )}
      </div>
    </section>
  );
}

function Held({ n, where }: { n: number; where: string }) {
  return n === 0
    ? <p className="holds none">no bookings yet</p>
    : <p className="holds">{n} {n === 1 ? "booking" : "bookings"}, {where}</p>;
}

type Point = { x: number; y: number };

function Packet({ from, to, ms, bad }: { from: Point; to: Point; ms: number; bad?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useLayoutEffect(() => {
    const el = ref.current;
    if (!el || typeof el.animate !== "function") return;
    el.animate(
      [
        { transform: `translate(${from.x}px, ${from.y}px)` },
        { transform: `translate(${to.x}px, ${to.y}px)` },
      ],
      { duration: ms * 0.9, easing: "ease-in-out", fill: "forwards" },
    );
  }, []);
  return <div ref={ref} className={bad ? "packet-dot bad" : "packet-dot"} style={{ transform: `translate(${from.x}px, ${from.y}px)` }} />;
}
