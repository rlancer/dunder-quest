# Game Improvements

Issues spotted while capturing and cutting the trailer (see [trailer/README.md](trailer/README.md)). Each one has the problem, where it lives, a suggested fix and how to check it. Tick items off as they land, and add new ones at the bottom.

## Plan

| # | Item | Area | Size | Priority |
|---|---|---|---|---|
| 1 | Bridge feedback text covers the code sign | Level 5 / FX | S | High |
| 2 | Run bob uses wall-clock time | Player | S | Medium |
| 3 | Duels are hard to read | Duel camera | M | High |
| 4 | "Ward broken!" vanishes too fast | Duel / FX | S | Medium |
| 5 | Possible rough jumps | Level 2, Level 3 | M | Needs playtest |

Suggested order: 1, 2 and 4 are quick one-file fixes and can share a PR. Item 3 needs some design. Item 5 starts with a human playtest.

---

### 1. [x] Bridge feedback text covers the code sign

- **Problem:** On Bellows Bridge, the floating "span(5) returns 14" label draws right over the `def span(n)` sign. Neither is readable at the moment the puzzle pays off (trailer capture frames ~9356–9372).
- **Where:** `levels/level_05.gd:138` calls `Fx.float_text(self, above, ...)`. `common/fx.gd:46` `float_text` places the label at `at + (-8, -20)` and floats it up 14 px.
- **Fix:** In level 5, anchor the text below the blocks or above the sign instead of at `above`. Or add an optional offset parameter to `float_text` so callers can move it clear of signs.
- **Check:** Bump each span block in Bellows Bridge. The result text and the sign's code should both be readable.
- **Done:** `span(n) returns …` and "The bridge holds" now float up from below the blocks (between them and the pebble's head), clear of the sign. `float_text` itself is unchanged for this.

### 2. [x] Run bob uses wall-clock time

- **Problem:** The pebble's run bob ignores `Engine.time_scale`, so it keeps bobbing through hitstop and slow-mo. It also drifts against the frames when recording with Movie Maker.
- **Where:** `entities/player/player.gd:137` uses `int(Time.get_ticks_msec() / 140) % 2`.
- **Fix:** Add a `_bob_time += delta` accumulator in `_process` (it already receives `_delta`) and use `int(_bob_time / 0.14) % 2`. Reset it when the pebble stops or lands, so every run starts on the same phase.
- **Check:** Trigger hitstop while running; the sprite should freeze in place. The run bob should look the same as before at normal speed.
- **Done:** `_bob_time` accumulates game-time `delta` while running on the ground and resets otherwise, so each run starts on the up step. Same 0.14 s step. In a 1 s hitstop mid-run the sprite no longer moves (it flipped 3 times before).

### 3. [ ] Duels are hard to read

- **Problem:** The pebble and the wizard are about 12–16 px tall, at opposite edges of a 480 px arena. While a question is open, the eye has nowhere to land, and in a video (or on a phone) it's hard to tell what's happening.
- **Where:** `entities/wizard/wizard_duel.gd` (engage/asking states) and the player camera.
- **Fix:** While `is_asking()` is true, tween the camera toward the midpoint between the pebble and the wizard, with a slight zoom (×1.25–1.5 at integer-friendly steps). Ease back out when the ward breaks. Keep both figures and the answer blocks in frame.
- **Check:** Play a duel at phone size. You should be able to read the question, the answer blocks and both figures without searching for them.

### 4. [x] "Ward broken!" vanishes too fast

- **Problem:** The confirmation for a right answer is the payoff of each question, but it's fully faded about 0.55 s after it appears. Against the bright skies of Amber Hollow and Crucible Crown it barely registers.
- **Where:** `entities/wizard/wizard_duel.gd:298` calls `Fx.float_text(...)`. The timing comes from `common/fx.gd:58-59` (0.5 s rise, fade starting at 0.3 s).
- **Fix:** Give `float_text` an optional hold time (or add an `Fx.callout` variant) and use about 1.0 s with a thicker, dark outline for "Ward broken!". Leave the other float texts alone.
- **Check:** Win a round in Amber Hollow and Crucible Crown. The text should be easy to read for about a second.
- **Done:** `Fx.float_text` takes optional `hold` (extra seconds at full opacity) and `outline` arguments that default to the old behaviour. "Ward broken!" uses `hold = 0.5` (fully gone at ~1.05 s instead of ~0.55 s) and a 5 px outline.

### 5. [ ] Possible rough jumps

- **Problem:** The trail bot clears almost everything but fell twice in Cinder Span (x ≈ 1930 and x ≈ 2090) and once in Kiln Mouth (x ≈ 1030). That may just be the bot, or those jumps may be tighter than they look.
- **Where:** The level 2 (Cinder Span) and level 3 (Kiln Mouth) layouts. `tests/trail_check.gd` prints the deaths.
- **Fix:** First do a human playtest of those three spots, ideally with someone new to the game. If the jumps are unfair, widen the landing by a tile or lower the gap.
- **Check:** The playtester clears each spot within a couple of tries, and the bot runs `tests/trail_check.tscn` with no falls there.
- **Bot report (2026-10-23, layouts unchanged):** Still the same three falls on main and on the game-improvements branch: Cinder Span `falls=2` (the 1 s trace has the first between x 1549 and 2015 and the second between 2015 and 2228), Kiln Mouth `falls=1` (just past x 763). The run still ends `result=ok fails=0`. Waiting on the human playtest.

### 6. [ ] Bridge verdict text lands off-screen

- **Problem:** On Bellows Bridge, the verdict for a wrong span ("10 < 14: too short!", "16 > 14: won't fit!") is drawn at the far end of the new planks. With the pebble standing under the span blocks, that is at or past the right edge of the screen, so the verdict is cut off or not seen at all.
- **Where:** `levels/level_05.gd`, `_on_call_bumped`, the two `Fx.float_text(self, end + Vector2(-40.0, -20.0), ...)` calls.
- **Fix:** Anchor the verdict near the chasm's near edge (or reuse the spot below the blocks once the `span(...)` text has faded), so it shows from where the player stands.
- **Check:** Bump 3, 4 and 6 from under the blocks. The whole verdict should be on screen.

