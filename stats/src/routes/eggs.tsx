import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/eggs")({
  component: Eggs,
});

type Egg = {
  line: string;
  where: string;
  trigger: string;
  sketch: string;
  code: string;
};

const GROUPS: [string, Egg[]][] = [
  [
    "Menus",
    [
      {
        line: "Spam, spam, spam, spam... lovely spam!",
        where: "Title screen",
        trigger: "Type S P A M on a keyboard. The footer shows the line for 4 seconds, with the pickup sound.",
        sketch: "Spam (Flying Circus, series 2). It's also why Python's docs use spam and eggs as example names.",
        code: "ui/title_screen.gd: _input, _show_egg",
      },
      {
        line: "And now for something completely different.",
        where: "Title screen",
        trigger: "Leave the title screen alone for 60 seconds. Any press puts the footer back.",
        sketch: "The show's link line between sketches.",
        code: "ui/title_screen.gd: _process",
      },
      {
        line: "Ni! Bring us... a shrubbery!",
        where: "World map",
        trigger: "Type N I. The prompt under the stage card turns green for 2.5 seconds and the pebble hops.",
        sketch: "The Knights Who Say Ni (Holy Grail).",
        code: "levels/world_map.gd: _unhandled_input, _knights_say_ni",
      },
      {
        line: "It's not paused, it's resting!",
        where: "Pause menu, any stage",
        trigger: 'Leave the pause menu open for 30 seconds. The "Paused" title changes until you close and reopen it.',
        sketch: "The Dead Parrot (Flying Circus, series 1): it's not dead, it's resting.",
        code: "ui/stage_hud.gd: _process, open_pause",
      },
    ],
  ],
  [
    "On the trail",
    [
      {
        line: "A very silly walk!",
        where: "Any stage",
        trigger:
          "On the ground, turn left and right six times quickly, each turn within 0.6 seconds of the last. Once per stage visit.",
        sketch: "The Ministry of Silly Walks (Flying Circus, series 2).",
        code: "entities/player/player.gd: _watch_silly_walk",
      },
      {
        line: "Run away! Run away!",
        where: "Any stage with copperlings",
        trigger: "Get caught by a copperling (touch it without stomping). Shows the first time each visit.",
        sketch: "King Arthur's knights fleeing the Rabbit of Caerbannog (Holy Grail).",
        code: "entities/player/player.gd: _handle_contacts",
      },
      {
        line: "I got better.",
        where: "Any stage",
        trigger: "Fall for the third time in one attempt. The line floats over the lantern you respawn at.",
        sketch: '"She turned me into a newt!" ... "I got better." (Holy Grail).',
        code: "levels/stage_level.gd: _respawn_player",
      },
      {
        line: "Auuuuuugh!",
        where: "Bellows Bridge (stage 5)",
        trigger: "Fall into the wide chasm the span(n) bridge crosses (tiles 85 to 98).",
        sketch: "Knights and the Bridgekeeper thrown into the Gorge of Eternal Peril (Holy Grail).",
        code: "levels/level_05.gd: _on_fall_zone_body_entered",
      },
      {
        line: "Always look on the bright side of life!",
        where: "Crucible Crown (stage 6), the final card",
        trigger: 'Clear the last stage after 5 or more falls in that attempt. Replaces "… cleared. Thanks for playing!"',
        sketch: "The closing song of Life of Brian.",
        code: "ui/stage_hud.gd: show_clear",
      },
    ],
  ],
  [
    "Wizard duels",
    [
      {
        line: "Three! Not four. And five is right out!",
        where: "Amber Hollow (stage 1), the Ash Hexer",
        trigger: "Break his last ward (his trial is three questions). It's his final line before he's banished.",
        sketch: "The Holy Hand Grenade of Antioch (Holy Grail). It fits the counting lesson.",
        code: "entities/wizard/wizard_duel.gd: _on_block_bumped",
      },
      {
        line: "There are some who call me... Tim.",
        where: "Kiln Mouth (stage 3), the Kiln Archmage",
        trigger: 'His opening line when you first walk into the arena (in place of "Bump your answer, if you dare!").',
        sketch: "Tim the Enchanter (Holy Grail), the wizard who loves fire.",
        code: "entities/wizard/wizard_duel.gd: _engage",
      },
      {
        line: "Nobody expects the hex strike!",
        where: "Kiln Mouth (stage 3), the Kiln Archmage",
        trigger: "The first hex strike of each fight. Kiln Mouth is where hex strikes first appear.",
        sketch: "Nobody expects the Spanish Inquisition! (Flying Circus, series 2).",
        code: "entities/wizard/wizard_duel.gd: _cast_hex",
      },
      {
        line: "Stop! Answer me these questions... four!",
        where: "Bellows Bridge (stage 5), the Bellows Sage",
        trigger: "His opening line when you first walk into the arena. His trial is four questions, so he loses count.",
        sketch: "The Bridgekeeper at the Bridge of Death (Holy Grail).",
        code: "entities/wizard/wizard_duel.gd: _engage",
      },
      {
        line: "African or European?! Auuugh!",
        where: "Bellows Bridge (stage 5), the Bellows Sage",
        trigger: "Break his last ward. It's his final line before he's banished.",
        sketch: "The airspeed velocity of an unladen swallow, which the Bridgekeeper can't answer (Holy Grail).",
        code: "entities/wizard/wizard_duel.gd: _on_block_bumped",
      },
      {
        line: "None shall pass!",
        where: "Any duel",
        trigger: "Walk into the wizard mid-fight (while not blinking from a recent hit).",
        sketch: "The Black Knight (Holy Grail).",
        code: "entities/wizard/wizard_duel.gd: _on_wizard_touched",
      },
      {
        line: "'Tis but a scratch!",
        where: "Any duel",
        trigger: "Drop to your last spark. Floats over the pebble once per fight.",
        sketch: "The Black Knight again, after losing an arm (Holy Grail).",
        code: "entities/wizard/wizard_duel.gd: _hurt",
      },
    ],
  ],
];

const COUNT = GROUPS.reduce((total, [, eggs]) => total + eggs.length, 0);

function Eggs() {
  return (
    <>
      <div className="title-row">
        <h1>Easter eggs</h1>
      </div>
      <p className="hint">
        Python is named after Monty Python, so the game hides {COUNT} of their lines. All of them work in release
        builds. Every line lives in <code>common/eggs.gd</code>, so changing one is a one-file edit. Each egg's code
        reads its line from there as <code>Eggs.SOMETHING</code>.
      </p>

      {GROUPS.map(([group, eggs]) => (
        <section className="card" key={group}>
          <h2>{group}</h2>
          {eggs.map((egg) => (
            <div className="egg" key={egg.line}>
              <p className="egg-line">"{egg.line}"</p>
              <dl>
                <dt>Where</dt>
                <dd>{egg.where}</dd>
                <dt>How to find it</dt>
                <dd>{egg.trigger}</dd>
                <dt>The sketch</dt>
                <dd>{egg.sketch}</dd>
                <dt>Code</dt>
                <dd>
                  <code>{egg.code}</code>
                </dd>
              </dl>
            </div>
          ))}
        </section>
      ))}

      <section className="card">
        <h2>Testing them quickly</h2>
        <ul>
          <li>
            In a debug build, press a stage's number on the world map to jump straight to it (see Dev notes). Stage 3
            has the Tim and hex strike lines, stage 5 the bridge ones.
          </li>
          <li>
            For the duel endings, answer three (stage 1) or four (stage 5) questions right. For "'Tis but a scratch",
            get hit twice.
          </li>
          <li>
            Typed eggs need a keyboard. Gamepad and touch players can still find the rest.
          </li>
        </ul>
      </section>
    </>
  );
}
