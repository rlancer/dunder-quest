import { createFileRoute } from "@tanstack/react-router";
import { STAGE_NAMES } from "../server/stages";

export const Route = createFileRoute("/dev")({
  component: Dev,
});

const RELEASE_PAGE = "https://github.com/rlancer/dunder-quest/releases/tag/builds";

const TESTS: [string, string][] = [
  [
    "tests/flow_check.tscn",
    "Drives the menus through real scene changes: title, map, Amber Hollow, pause, a fall and respawn, a full wizard duel, and back. Prints FLOW result=ok.",
  ],
  [
    "tests/lesson_check.tscn",
    "Drives each stage's lesson pieces with real input: scroll cards, the index row, the duel (seal, clock, hints, sparks and a knockout), the vault, the kiln lift and the Spellbook.",
  ],
  [
    "tests/trail_check.tscn",
    "A bot plays all six stages start to finish with real input, then checks that the wrong answers really fail and that each stage's seeds match the map. Add -- --from=4 to start later, or -- --checks for just the checks.",
  ],
  [
    "tests/look_tour.tscn",
    "Opens each screen in a real window and saves a screenshot to tests/shots/tour_*.png. Add -- --only=fork to capture only matching steps.",
  ],
];

const SAVE_DIRS: [string, string][] = [
  ["Windows", "%APPDATA%\\Godot\\app_userdata\\Dunder Quest\\"],
  ["macOS", "~/Library/Application Support/Godot/app_userdata/Dunder Quest/"],
  ["Linux", "~/.local/share/godot/app_userdata/Dunder Quest/"],
  ["Browser", "The browser's IndexedDB for the site. Clear the site data to reset it."],
];

function Dev() {
  return (
    <>
      <div className="title-row">
        <h1>Dev notes</h1>
      </div>
      <p className="hint">
        Shortcuts for testing the game without playing through it. They work only in debug builds (a run from the Godot
        editor or the <code>godot</code> command). The site's game and the downloads are release builds, so players
        can't use them.
      </p>

      <section className="card">
        <h2>Skip to any stage</h2>
        <p>
          On the world map, press a number key to go straight into that stage, even if it's locked. The save doesn't
          change, so locked stages stay locked on the map. Clearing a stage this way records the clear and unlocks the
          next stage.
        </p>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Key</th>
                <th>Stage</th>
                <th>Scene</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(STAGE_NAMES).map(([id, name]) => (
                <tr key={id}>
                  <td>{id}</td>
                  <td>{name}</td>
                  <td>
                    <code>res://levels/level_0{id}.tscn</code>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p className="hint">
          This is <code>_debug_stage_skip</code> in <code>levels/world_map.gd</code>, gated on{" "}
          <code>OS.is_debug_build()</code>.
        </p>
      </section>

      <section className="card">
        <h2>Launch a scene directly</h2>
        <p>Pass a scene path to skip the title and map. Each stage scene runs on its own.</p>
        <pre>
          {`godot --path . res://levels/level_04.tscn      # straight into Smelter's Fork
godot --path . res://levels/world_map.tscn     # straight to the map
godot --path .                                 # normal start, title screen`}
        </pre>
        <p>In the editor, open a stage scene and press F6 (Run Current Scene) to do the same thing.</p>
      </section>

      <section className="card">
        <h2>Progress and the save file</h2>
        <p>
          Progress lives in <code>user://cinder_progression.json</code>: unlocked and cleared stages, best seeds and
          times, total falls, and the scrolls read.
        </p>
        <div className="table-wrap">
          <table>
            <tbody>
              {SAVE_DIRS.map(([where, path]) => (
                <tr key={where}>
                  <th>{where}</th>
                  <td>{where === "Browser" ? path : <code>{path}</code>}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          <b>Reset:</b> on the title screen, choose New game and press it again to confirm. That deletes the file.
        </p>
        <p>
          <b>Unlock everything:</b> with the game closed, edit the file and set every stage under{" "}
          <code>"unlocked"</code> to <code>true</code>.
        </p>
        <pre>{`"unlocked": {"1": true, "2": true, "3": true, "4": true, "5": true, "6": true}`}</pre>
        <p className="hint">
          Tests set <code>GameProgression.persist = false</code> so a bot run never overwrites a real save, and never
          sends stats.
        </p>
      </section>

      <section className="card">
        <h2>Test scenes</h2>
        <p>
          Run any of these headless from the repo root with <code>godot --headless --path . res://&lt;scene&gt;</code>.{" "}
          <code>look_tour</code> needs a real window, so leave out <code>--headless</code>.
        </p>
        <div className="table-wrap">
          <table>
            <tbody>
              {TESTS.map(([scene, what]) => (
                <tr key={scene}>
                  <th>
                    <code>{scene}</code>
                  </th>
                  <td>{what}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <p>
          <code>python tools/verify_quiz.py</code> runs every scroll and question snippet in{" "}
          <code>data/lessons.json</code> in a fresh Python process. It checks that each marked answer matches what
          Python prints, and that every card fits on the game's screen. Run it after any change to the lessons.
        </p>
      </section>

      <section className="card">
        <h2>Builds and deploys</h2>
        <ul>
          <li>
            <b>Push to main:</b> deploys the site and the browser game to production, replaces the desktop downloads on
            the <a href={RELEASE_PAGE}>builds release</a>, then deploys this admin area.
          </li>
          <li>
            <b>Push to dev:</b> deploys to the dev site.
          </li>
          <li>
            <b>Pull request:</b> builds everything, including the desktop exports, and runs a deploy dry run. Nothing is
            published.
          </li>
        </ul>
        <pre>
          {`bash scripts/export_web.sh       # site + browser game into build/site
bash scripts/export_desktop.sh   # desktop zips into build/downloads`}
        </pre>
        <p className="hint">
          Building locally needs Linux with bash, curl, zip and unzip; it fetches Godot 4.7.2. To preview only the
          site, run <code>python site/build.py build/site</code>, then <code>python -m http.server -d build/site</code>.
        </p>
      </section>
    </>
  );
}
