import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { IMG, REPO, SITE, TRAILER_ID, TRAILER_URL } from "../../brand";

export const Route = createFileRoute("/brand/trailer")({
  component: Trailer,
});

const README = `${REPO}/blob/main/trailer/README.md`;
const PLAN = `${REPO}/blob/main/trailer/PLAN.md`;

// The upload checklist from trailer/PLAN.md §8, ready to paste.
const UPLOAD: { label: string; text: string }[] = [
  { label: "Title", text: "Dunder Quest – a pixel platformer that teaches Python (Trailer)" },
  {
    label: "Description",
    text: "Play free in your browser: https://dunderquest.com/\n\nGuide a pebble across six stages to the kiln. Read the lore scrolls, use real Python to build the path, then duel the wizard at the exit by jumping into the block with the right answer.\n\n#python #indiegame #pixelart #learnpython",
  },
  { label: "Tags", text: "python, learn python, indie game, pixel art, platformer, coding game, educational game" },
];

const FACTS: [string, string][] = [
  ["Length", "62 s"],
  ["Music", "cue_b, 125 BPM, every cut on a bar or beat"],
  ["Loudness", "−13.9 LUFS integrated, −0.9 dB peak"],
  ["Native", "480×270, scaled ×4 and ×8 nearest-neighbor"],
];

const DELIVERABLES: { asset: string; spec: string; where: string; file: string }[] = [
  {
    asset: "YouTube master",
    spec: "3840×2160, 60 fps, H.264 + AAC",
    where: "YouTube, embedded on the home page",
    file: "trailer/out/dunder_quest_trailer_4k.mp4",
  },
  {
    asset: "1080p master",
    spec: "1920×1080, 60 fps",
    where: "itch.io, press, Steam later",
    file: "trailer/out/dunder_quest_trailer_1080p.mp4",
  },
  {
    asset: "Thumbnail",
    spec: "1920×1080 PNG, under 2 MB, text is fine",
    where: "YouTube, and the home page as static/img/trailer.png",
    file: "trailer/out/youtube_thumbnail.png",
  },
  { asset: "Vertical Short", spec: "1080×1920, ≤ 60 s, text in the center column", where: "Shorts, TikTok, Reels", file: "Not made yet" },
  { asset: "GIF loops", spec: "3–6 s: the bridge build and a duel", where: "Social posts, README, press kit", file: "Not made yet" },
];

const REBUILD = `# Music + SFX, only when the sound changes
python tools/generate_trailer_audio.py

# Capture, only when the game changes (~35 min)
godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_capture.tscn > trailer/captures/run.log

# Render (~8 min) -> trailer/out/, or just the thumbnail
python tools/make_trailer.py
python tools/make_trailer.py --thumb`;

function Trailer() {
  return (
    <>
      <div className="title-row">
        <h1>Trailer</h1>
      </div>
      <p className="hint">
        A 62 s motion-graphics trailer built entirely from the repo by <code>tools/make_trailer.py</code>. YouTube comes
        first and the home page embeds it; Steam is deferred. How to rebuild it and what's left to do are in{" "}
        <a href={README} target="_blank" rel="noreferrer">
          trailer/README.md
        </a>
        .
      </p>

      <section className="card">
        <h2>
          On YouTube <span className="sub">{TRAILER_ID}</span>
        </h2>
        <p className="sub">
          <a href={TRAILER_URL} target="_blank" rel="noreferrer">
            {TRAILER_URL}
          </a>
        </p>
        <div className="video">
          <iframe
            src={`https://www.youtube-nocookie.com/embed/${TRAILER_ID}?rel=0`}
            title="Dunder Quest trailer"
            allow="encrypted-media; picture-in-picture; fullscreen"
            allowFullScreen
          />
        </div>
        <dl className="facts">
          {FACTS.map(([k, v]) => (
            <div key={k}>
              <dt>{k}</dt>
              <dd>{v}</dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="card">
        <h2>Thumbnails</h2>
        <p className="sub">
          The one YouTube serves and the one the home page shows should match. After a re-render, upload the new one to
          YouTube and copy <code>trailer/out/youtube_thumbnail.png</code> to <code>site/static/img/trailer.png</code>.
        </p>
        <div className="pair">
          <figure>
            <a href={`https://i.ytimg.com/vi/${TRAILER_ID}/maxresdefault.jpg`} target="_blank" rel="noreferrer">
              <img src={`https://i.ytimg.com/vi/${TRAILER_ID}/maxresdefault.jpg`} alt="YouTube's thumbnail" />
            </a>
            <figcaption className="sub">YouTube</figcaption>
          </figure>
          <figure>
            <a href={`${IMG}trailer.png`} target="_blank" rel="noreferrer">
              <img src={`${IMG}trailer.png`} alt="The home page's thumbnail" />
            </a>
            <figcaption className="sub">
              Home page ·{" "}
              <a href={`${SITE}#trailer`} target="_blank" rel="noreferrer">
                dunderquest.com/#trailer
              </a>
            </figcaption>
          </figure>
        </div>
      </section>

      <section className="card">
        <h2>Upload copy</h2>
        <p className="sub">
          Put "Python" in the title, since that's what people search for, and link the site on the description's first
          line. The description is a draft built from the home page's hero. The rest of the checklist is in{" "}
          <a href={`${PLAN}#8-deliverables`} target="_blank" rel="noreferrer">
            trailer/PLAN.md §8
          </a>
          .
        </p>
        {UPLOAD.map((item) => (
          <div className="copy-field" key={item.label}>
            <div className="copy-head">
              <strong>{item.label}</strong>
              <CopyButton text={item.text} />
            </div>
            <pre>{item.text}</pre>
          </div>
        ))}
      </section>

      <section className="card">
        <h2>Deliverables</h2>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Asset</th>
                <th>Spec</th>
                <th>Where it goes</th>
                <th>File</th>
              </tr>
            </thead>
            <tbody>
              {DELIVERABLES.map((d) => (
                <tr key={d.asset}>
                  <td>{d.asset}</td>
                  <td>{d.spec}</td>
                  <td>{d.where}</td>
                  <td>{d.file.startsWith("trailer/") ? <code>{d.file}</code> : <span className="sub">{d.file}</span>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="sub note">
          Video files go on YouTube, never on Cloudflare Pages, which caps file size. For Steam later: ≥ 5 Mbps and a
          text-free thumbnail, and drop "free in your browser".
        </p>
      </section>

      <section className="card">
        <h2>Rebuild</h2>
        <pre>{REBUILD}</pre>
      </section>
    </>
  );
}

function CopyButton({ text }: { text: string }) {
  const [done, setDone] = useState(false);
  return (
    <button
      type="button"
      className="copy"
      onClick={() =>
        navigator.clipboard.writeText(text).then(() => {
          setDone(true);
          setTimeout(() => setDone(false), 1500);
        })
      }
    >
      {done ? "Copied" : "Copy"}
    </button>
  );
}
