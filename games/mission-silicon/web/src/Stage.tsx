// The stage: a pixel-art set, and the cast on its floor as full-body sprites
// that walk, turn and talk. Each sprite is a strip of four frames from
// tools/sprites.py: standing, two steps of a walk, talking.

import { useEffect, useState } from "react";
import { castName } from "./ui";
import { walkMs, type Actor, type StageState } from "./show";
import movein from "../../assets/backgrounds/movein.png";
import den from "../../assets/backgrounds/den.png";
import pitch from "../../assets/backgrounds/pitch.png";

const SETS: Record<string, string> = { movein, den, pitch };
export const hasSet = (s: string) => s in SETS;

const strips = import.meta.glob("../../assets/sprites/*.png", { eager: true, query: "?url", import: "default" }) as Record<string, string>;
const strip = (who: string) => strips[`../../assets/sprites/${who}.png`];
export const hasSprite = (who: string) => !!strip(who);

const PROPS: Record<string, string> = { envelope: "✉️", key: "🔑" };

function Sprite({ who, a, talking, sign, props }: { who: string; a: Actor; talking: boolean; sign?: string; props: string[] }) {
  // Where it's drawn, and how long the move there takes. A newcomer is drawn
  // off stage first, then sent to its mark on the next frame, so it walks on.
  const [x, setX] = useState(a.enter ?? a.x);
  const [ms, setMs] = useState(0);
  const [moving, setMoving] = useState(false);
  const [frame, setFrame] = useState(0);

  useEffect(() => {
    if (x === a.x) return;
    const d = walkMs(a.x - x);
    const r = requestAnimationFrame(() => {
      setMs(d);
      setX(a.x);
      setMoving(true);
    });
    const t = setTimeout(() => setMoving(false), d + 30);
    return () => {
      cancelAnimationFrame(r);
      clearTimeout(t);
    };
  }, [a.x]);

  useEffect(() => {
    if (moving) {
      setFrame(1);
      const t = setInterval(() => setFrame((f) => (f === 1 ? 2 : 1)), 150);
      return () => clearInterval(t);
    }
    if (talking) {
      setFrame(3);
      const t = setInterval(() => setFrame((f) => (f === 3 ? 0 : 3)), 380);
      return () => clearInterval(t);
    }
    setFrame(0);
  }, [moving, talking]);

  return (
    <div className={`actor${talking ? " talking" : ""}`} style={{ left: `${x}%`, transition: `left ${ms}ms linear`, zIndex: talking ? 3 : 2 }}>
      <div className="over">
        {talking && <span className="nametag pixel">{castName(who)}</span>}
        {sign && !moving && <span className="sign">{sign}</span>}
      </div>
      <div className="spr" style={{ backgroundImage: `url(${strip(who)})`, backgroundPositionX: `${(frame / 3) * 100}%`, transform: `scaleX(${a.face ?? 1})` }} role="img" aria-label={castName(who)} />
      {props.map((p) => (
        <span key={p} className={`prop ${p}`} style={{ [a.face === -1 ? "left" : "right"]: "-6%" }} aria-label={p}>
          {PROPS[p]}
        </span>
      ))}
    </div>
  );
}

export default function Stage({ s, speaker, onTap }: { s: StageState; speaker: string | null; onTap?: () => void }) {
  return (
    <div className="stage" onClick={onTap}>
      <img className="px set" src={SETS[s.set]} alt="" />
      {s.place && (
        <span key={`${s.cut}-${s.place}`} className="place pixel">
          {s.place}
        </span>
      )}
      {Object.entries(s.actors).map(([who, a]) => (
        <Sprite key={`${who}-${s.cut}`} who={who} a={a} talking={speaker === who} sign={s.signs[who]} props={Object.keys(s.props).filter((p) => s.props[p] === who)} />
      ))}
    </div>
  );
}
