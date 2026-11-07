// The pieces every frame of the Pilot is made from: portraits, the spoken
// guide, a conversation that plays line by line, the map, requirement
// tables, notices and stamps.

import { motion } from "motion/react";
import { useEffect, useState, type ReactNode } from "react";
import { voiceKey, type Line } from "./lines";
import { P, type Mark, type Req } from "./model";
import { speak, useAfterSpeech, useVoice } from "./voice";

const faces = import.meta.glob("../../assets/portraits/*.png", { eager: true, query: "?url", import: "default" }) as Record<string, string>;
const face = (who: string) => faces[`../../assets/portraits/${who}.png`];
export const castName = (who: string) => (P.cast as Record<string, { name: string }>)[who]?.name ?? who;

export function Portrait({ who, size = 48 }: { who: string; size?: number }) {
  return <img className="portrait px" src={face(who)} width={size} height={size} alt={castName(who)} />;
}

// One cast member speaking: their face, their name, the words. Speaks the
// line when it first appears (if `voice`), with a button to hear it again.
export function Guide({ line, voice = true, old = false }: { line: Line; voice?: boolean; old?: boolean }) {
  const { playing } = useVoice();
  const key = voiceKey(line);
  useEffect(() => {
    if (voice) speak(line);
  }, [key]);
  const speaking = playing === key;
  return (
    <div className={`guide${old ? " old" : ""}`}>
      <Portrait who={line.who} size={old ? 36 : 48} />
      <div className={`bubble${speaking ? " speaking" : ""}`}>
        <div className="name pixel">
          {castName(line.who)}
          {speaking && <span className="live" aria-hidden />}
          {!old && (
            <button className="replay" onClick={() => speak(line)} aria-label={`Hear ${castName(line.who)} again`}>
              ↻ hear again
            </button>
          )}
        </div>
        <div>{line.say}</div>
      </div>
    </div>
  );
}

// A conversation, one line at a time. The next line comes when the voice
// finishes (or on the button). `onDone` runs once the last line is up.
export function Talk({ lines, onDone }: { lines: Line[]; onDone?: () => void }) {
  const [n, setN] = useState(1);
  useEffect(() => {
    if (n >= lines.length) onDone?.();
  }, [n]);
  useAfterSpeech(voiceKey(lines[n - 1]), () => setN((x) => Math.min(x + 1, lines.length)));
  return (
    <div className="talk">
      {lines.slice(0, n).map((l, i) => (
        <Guide key={i} line={l} old={i < n - 1} />
      ))}
      {n < lines.length && (
        <button className="btn ghost small more" onClick={() => setN(n + 1)}>
          Next line
        </button>
      )}
    </div>
  );
}

export function Next({ onClick, children = "Next", disabled = false, why }: { onClick: () => void; children?: ReactNode; disabled?: boolean; why?: ReactNode }) {
  return (
    <div className="next-row">
      {why && <span className="why">{why}</span>}
      <button className="btn" onClick={onClick} disabled={disabled}>
        {children} →
      </button>
    </div>
  );
}

export function Notice({ kind = "", head, children }: { kind?: "" | "good" | "bad"; head?: ReactNode; children: ReactNode }) {
  return (
    <motion.div className={`notice ${kind}`} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
      {head && <h4>{head}</h4>}
      <div>{children}</div>
    </motion.div>
  );
}

export function Stamp({ s }: { s: { label: string; term: string; plain: string; eg?: string } }) {
  return (
    <motion.div className="stamp" initial={{ opacity: 0, scale: 0.97 }} animate={{ opacity: 1, scale: 1 }}>
      <div className="label">{s.label}</div>
      <div className="t">{s.term}</div>
      <div>{s.plain}</div>
      {s.eg && <div className="eg">{s.eg}</div>}
    </motion.div>
  );
}

const MARK: Record<string, string> = { y: "Yes", p: "Partly", n: "No" };

// The requirements beside an option: yes, partly or no, with the reason.
export function ReqTable({ reqs, r, head, laterNote, fill = (s) => s }: {
  reqs: Req[];
  r: Record<string, string[]> | null;
  head: string;
  laterNote?: string;
  fill?: (s: string) => string;
}) {
  return (
    <table className="reqs">
      <thead>
        <tr>
          <th>{head}</th>
          <th>This option</th>
        </tr>
      </thead>
      <tbody>
        {reqs.map((q) => {
          const v = r?.[q.id];
          return (
            <tr key={q.id} className={q.later ? "dim" : ""}>
              <td className="need">
                {fill(q.t)}
                {q.must && <span className="must">MUST</span>}
                {q.later && laterNote && <span className="later">{laterNote}</span>}
              </td>
              <td>
                {v ? (
                  <motion.span key={v[1]} initial={{ opacity: 0 }} animate={{ opacity: 1 }}>
                    <span className={`mk ${v[0]}`}>{MARK[v[0] as Mark]}</span>
                    {fill(v[1])}
                  </motion.span>
                ) : (
                  <span className="mk q">?</span>
                )}
              </td>
            </tr>
          );
        })}
      </tbody>
    </table>
  );
}

export type BoxId = "device" | "server" | "db" | "model";
const BOXES: BoxId[] = ["device", "server", "db", "model"];

// The map: the diner's device, the internet, our server, and the database
// and the AI model behind it. `at` puts the request's envelope on a box (or
// the wire); `skipServer` draws Aleister's plan, the phone calling the model.
export function MapView({ hot, seen = {}, onTap, at, skipServer = false, label }: {
  hot?: string;
  seen?: Record<string, boolean>;
  onTap?: (k: BoxId) => void;
  at?: string;
  skipServer?: boolean;
  label?: string;
}) {
  const env = <motion.span layoutId="envelope" className="envelope" transition={{ type: "spring", stiffness: 260, damping: 26 }}>✉ {label}</motion.span>;
  const box = (k: BoxId) => {
    const b = P.map.boxes[k];
    const gone = skipServer && k === "server";
    const cls = `box ${k}${hot === k ? " hot" : ""}${seen[k] ? " seen" : ""}${gone ? " gone" : ""}`;
    const inner = (
      <>
        <span className="n">{b.n}</span>
        <span className="s">{gone ? "skipped" : b.s}</span>
        {at === k && env}
      </>
    );
    return onTap ? (
      <button key={k} className={cls} onClick={() => onTap(k)} aria-pressed={hot === k}>
        {inner}
      </button>
    ) : (
      <div key={k} className={cls}>
        {inner}
      </div>
    );
  };
  return (
    <div className="map" role="group" aria-label="The map of a web app">
      {box("device")}
      <div className="wire">{at === "wire" ? env : <span>{P.map.wire}</span>}</div>
      {box("server")}
      <div className="fork" />
      {box("db")}
      {box("model")}
      {skipServer && <div className="direct">Aleister's plan: the phone calls the AI model directly</div>}
    </div>
  );
}

export { BOXES };
