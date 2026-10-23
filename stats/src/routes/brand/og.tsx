import { createFileRoute } from "@tanstack/react-router";
import { IMG, SITE } from "../../brand";
import { STAGE_NAMES } from "../../server/stages";

export const Route = createFileRoute("/brand/og")({
  component: Og,
});

// The cards tools/make_og.py paints, served by the live site.
const OG_BASE = `${IMG}og/`;

const SLUGS: Record<number, string> = {
  1: "amber-hollow",
  2: "cinder-span",
  3: "kiln-mouth",
  4: "smelters-fork",
  5: "bellows-bridge",
  6: "crucible-crown",
};

type Card = { file: string; name: string; usedBy: string; page: string };

const CARDS: Card[] = [
  { file: "home.png", name: "Home", usedBy: "Home, How to play, and any page without its own card", page: "" },
  { file: "lessons.png", name: "Lessons", usedBy: "The lessons index", page: "lessons/" },
  ...Object.entries(SLUGS).map(([id, slug]) => ({
    file: `${slug}.png`,
    name: `Stage ${id} · ${STAGE_NAMES[Number(id)]}`,
    usedBy: "That stage's lesson page",
    page: `lessons/${slug}/`,
  })),
];

function Og() {
  return (
    <>
      <div className="title-row">
        <h1>Social cards</h1>
      </div>
      <p className="hint">
        The 1200×630 <code>og:image</code> each page shares with. Chat apps show either the large card or a small
        thumbnail cropped from the middle, so anything that has to be readable belongs in the centered square. Repaint
        them with <code>python tools/make_og.py</code>; this page shows what's deployed.
      </p>

      {CARDS.map((card) => (
        <section className="card og" key={card.file}>
          <h2>
            {card.name} <span className="sub">{card.file}</span>
          </h2>
          <p className="sub">
            {card.usedBy} ·{" "}
            <a href={SITE + card.page} target="_blank" rel="noreferrer">
              dunderquest.com/{card.page}
            </a>
          </p>
          <div className="og-row">
            <a className="og-full" href={OG_BASE + card.file} target="_blank" rel="noreferrer">
              <img src={OG_BASE + card.file} alt={`${card.name} social card`} width={1200} height={630} />
            </a>
            <figure>
              <div className="og-thumb">
                <img src={OG_BASE + card.file} alt="" />
              </div>
              <figcaption className="sub">Thumbnail</figcaption>
            </figure>
          </div>
        </section>
      ))}

      <section className="card og">
        <h2>
          Logo <span className="sub">logo.png</span>
        </h2>
        <p className="sub">
          <code>og:logo</code> on every page
        </p>
        <img className="og-logo" src={`${OG_BASE}logo.png`} alt="Dunder Quest logo" width={128} height={128} />
      </section>
    </>
  );
}
