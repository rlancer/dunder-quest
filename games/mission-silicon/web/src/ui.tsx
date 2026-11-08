// Small pieces the Pilot's dock is made from: portraits, a spoken guide
// line, the Next button, notices and stamps.

import { motion } from "motion/react";
import { useEffect, type ReactNode } from "react";
import { voiceKey, type Line } from "./lines";
import { P } from "./model";
import { speak, useVoice } from "./voice";

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
