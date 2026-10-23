import { createFileRoute } from "@tanstack/react-router";
import { IMG, PALETTE, REPO } from "../../brand";

export const Route = createFileRoute("/brand/")({
  component: Identity,
});

// Every line the game is pitched with, and where each one ships.
const COPY: { text: string; where: string; source: string }[] = [
  { text: "A pixel platformer where Python is the magic.", where: "The pitch", source: "trailer/PLAN.md §1" },
  {
    text: "A platformer where every stage teaches you a piece of Python.",
    where: "Home page hero",
    source: "site/build.py",
  },
  { text: "A pixel-art platformer that teaches Python", where: "Home social card", source: "tools/make_og.py" },
  {
    text: "Dunder Quest is a pixel-art platformer that teaches Python. Play it in your browser or download it.",
    where: "Default meta description",
    source: "site/build.py",
  },
  { text: "LEARN PYTHON BY PLAYING", where: "YouTube thumbnail", source: "tools/make_trailer.py" },
  { text: "YOUR CODE / BUILDS THE WORLD", where: "Trailer hook card", source: "tools/make_trailer.py" },
  {
    text: "A pebble's journey to the kiln · Play free in your browser · dunderquest.com",
    where: "Trailer end card",
    source: "tools/make_trailer.py",
  },
];

const FONTS: { name: string; family: string; use: string; sample: string }[] = [
  {
    name: "Pixelify Sans",
    family: "brand-pixel, monospace",
    use: "Headlines and the wordmark, in the game, the site, the cards and the trailer",
    sample: "Six stages to the kiln",
  },
  {
    name: "VT323",
    family: "brand-label, monospace",
    use: "Code, terminal prompts and labels",
    sample: ">>> import adventure",
  },
  {
    name: "Atkinson Hyperlegible",
    family: '"Atkinson Hyperlegible", system-ui, sans-serif',
    use: "Body text on the site only (falls back to the system font)",
    sample: "Guide a pebble across six stages to the kiln.",
  },
];

// Deployed by site/build.py, so these are safe to hand out as a press kit.
// Sprites carry their size so they can be drawn at a whole-number scale.
const ART: { file: string; name: string; note: string; size?: [number, number, number] }[] = [
  { file: "title_art.png", name: "Title art", note: "Behind every social card and the end card" },
  { file: "trail_map.png", name: "World map", note: "The home page's trail" },
  { file: "wizard.png", name: "Wizard", note: "The duel opponent", size: [18, 28, 2] },
  { file: "pebble.png", name: "Pebble", note: "The hero", size: [16, 24, 2] },
  { file: "copperling.png", name: "Copperling", note: "Stomped in the cold open", size: [20, 12, 3] },
  { file: "emberseed.png", name: "Emberseed", note: "The collectible", size: [12, 12, 4] },
  { file: "waygate.png", name: "Waygate", note: "A stage's exit", size: [24, 40, 1] },
  { file: "shots/tour_bridge_built.png", name: "Bridge built", note: "The hook: span(5) lays the planks" },
  { file: "shots/tour_amber_duel.png", name: "Wizard duel", note: "The strongest shot" },
  { file: "shots/tour_amber_scroll.png", name: "Lore scroll", note: "A lesson card" },
];

function Identity() {
  return (
    <>
      <div className="title-row">
        <h1>Identity</h1>
      </div>
      <p className="hint">
        One look across the game, the site, the social cards and the trailer: the game's two pixel fonts, its palette,
        and art at whole-number scales only. The full style rules are in{" "}
        <a href={`${REPO}/blob/main/trailer/PLAN.md#4-visual-style-for-the-motion-graphics`} target="_blank" rel="noreferrer">
          trailer/PLAN.md §4
        </a>
        .
      </p>

      <section className="card">
        <h2>Wordmark</h2>
        <p className="sub">
          <code>__dunder_quest__</code>: gold letters between ember underscores, the way Python's dunder names sit
          between theirs. Written lowercase, as one word with underscores. In running text the game is Dunder Quest.
        </p>
        <div className="brand-stage">
          <p className="wordmark">
            <span>__</span>dunder_quest<span>__</span>
          </p>
          <figure>
            <img className="pixel" src={`${IMG}og/logo.png`} alt="Dunder Quest logo" width={64} height={64} />
            <figcaption>logo.png · icon.svg</figcaption>
          </figure>
        </div>
      </section>

      <section className="card">
        <h2>Copy</h2>
        <p className="sub">
          The hook is that code changes the world, so every line says "platformer" and "Python". Change a line at its
          source.
        </p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Line</th>
                <th>Where</th>
                <th>Source</th>
              </tr>
            </thead>
            <tbody>
              {COPY.map((row) => (
                <tr key={row.text}>
                  <td>{row.text}</td>
                  <td>{row.where}</td>
                  <td>
                    <code>{row.source}</code>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="card">
        <h2>Palette</h2>
        <p className="sub">
          Code on every card uses the same syntax colors: keywords in ember, strings in gold, numbers in parchment,
          comments in ash.
        </p>
        <div className="swatches">
          {PALETTE.map((color) => (
            <div className="swatch" key={color.hex}>
              <div className="chip" style={{ background: color.hex }} />
              <strong>{color.name}</strong> <code>{color.hex}</code>
              <p className="sub">{color.use}</p>
            </div>
          ))}
        </div>
        <pre className="code-sample">
          <span className="kw">for</span> i <span className="kw">in</span> range(<span className="nm">4</span>):{"\n"}
          {"    "}lift.rise()  <span className="cm"># one notch</span>
          {"\n"}name = <span className="st">"ember"</span>
        </pre>
      </section>

      <section className="card">
        <h2>Type</h2>
        <p className="sub">
          Both pixel fonts are in <code>assets/fonts/</code> under the OFL, so they're fine for the trailer and press.
        </p>
        {FONTS.map((f) => (
          <div className="specimen" key={f.name}>
            <p style={{ fontFamily: f.family }}>{f.sample}</p>
            <p className="sub">
              <strong>{f.name}</strong> · {f.use}
            </p>
          </div>
        ))}
      </section>

      <section className="card">
        <h2>Art</h2>
        <p className="sub">
          The game renders at 480×270. Scale art by whole numbers with nearest-neighbor, never by fractions, or the
          pixels come out uneven. Click one for the full file.
        </p>
        <div className="art-grid">
          {ART.map((art) => (
            <figure key={art.file}>
              <a href={IMG + art.file} target="_blank" rel="noreferrer">
                <img
                  className="pixel"
                  src={IMG + art.file}
                  alt={art.name}
                  loading="lazy"
                  width={art.size && art.size[0] * art.size[2]}
                  height={art.size && art.size[1] * art.size[2]}
                />
              </a>
              <figcaption>
                <strong>{art.name}</strong> · {art.note}
              </figcaption>
            </figure>
          ))}
        </div>
      </section>
    </>
  );
}
