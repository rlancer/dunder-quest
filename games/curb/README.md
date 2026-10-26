# Curb Your Oxidation

A Dunder Quest game that teaches Rust. Barry Danvers, a semi-retired TV writer on the Westside of LA, lives by rules nobody else has heard of and keeps getting into petty disputes about them. Each dispute is settled by a plan, and every plan is a short Rust program on Barry's yellow legal pad.

**The borrow checker is the unwritten social contract.** Run a plan and Barry first plays it through in his head (in sepia), line by line, the way rustc reads the whole program before anything runs. If it breaks the rules, Sharon Greene bursts in at the offending line with the real rustc error (`error[E0382]: borrow of moved value: wine`) and an opinion about it. If it compiles, the scene plays it out for real: every `println!` is somebody saying that line, and the scene only moves on when the program prints exactly what should happen. Each scene opens on a black serif title card and ends on a freeze frame and a bouncy tuba sting.

It's a homage to a certain LA cringe-comedy series: the format, the tone and the tropes, with invented names and original lines and music (see AGENTS.md for the rules).

The game plays at **dunderquest.com/curb/play/**. Its own page will be at /curb/. It's its own Godot 4.7 project, beside `../dunder-quest/` and `../flatmates/`.

## The cast

Barry Danvers (the hero), Gil Greene (his manager and best friend), Sharon Greene (Gil's wife, and the voice of the borrow checker), Carol (Barry's ex-wife), Lamont (the houseguest who came for one night), Ted Pruitt (the neighbor with the lawnmower), Sol (the deli), Whit Thornbury (the country club), Philippe (the maitre d'), Dana (returns) and Rain (the barista).

## The scenes

| # | Episode | Place | Rust | The dispute |
|---|---|---|---|---|
| 1 | The Second Latte | Barry's Kitchen | `let` and `mut` | Barry said one latte, then wants two (E0384); minutes as an `i32` (E0308) |
| 2 | The Sample Abuser | Sol's Deli | Functions | the tail expression a semicolon swallows (E0308); arguments in order (E0061) |
| 3 | The Regift | The Greenes' Dinner Party | Ownership and moves | the host gift moved (E0382); the regifted candle, `clone()` to buy your own |
| 4 | The Lawnmower | Ted's Driveway | Borrowing with `&` | admire it with `&String`, don't take it; `&mut` to sharpen it (E0596) |
| 5 | The Last Shrimp | Club Brunch | `&mut`: one at a time | two hands on one tray (E0499); clearing it while he's looking (E0502) |
| 6 | The Mulligan | The Ninth Hole | Structs and methods | `&mut self` to add a stroke (E0594, E0596); every field of a `Cart` (E0063) |
| 7 | The Maybe | Le Petit Bistro | Enums, `match`, `Option` | "maybe" not covered (E0004); `Some(2)`, not `2` |
| 8 | The Receipt | The Returns Desk | `Result` and `?` | a bool, not "yes"; passing the blame up with `?` (E0277), and `unwrap()` panics |
| 9 | Stop and Chat | The Coffee Line | `Vec` and `for` | the loop that takes your friends (E0382); holding a place in a growing line (E0502, E0507) |
| 10 | The Houseguest | Barry's Guest Room | Lifetimes | `longest<'a>` (E0106); the spare key that outlives its block (E0597) |

## How it's built

- `rust/`: a small rustc and a runner, in GDScript. `RustParser` parses the slice of Rust the plans use; `RustChecker` checks it in rustc's order (names and types, then match exhaustiveness, then a non-lexical borrow check that knows where each reference is last used) and reports rustc's error codes; `RustRunner` runs what passes. `Plan` is a plan's code with «blanks» and their options.
- `data/scenes.json`: the whole season. The cast, each scene's opening, plans (code, blanks, start and solution, the error the start must hit, what it must print), success lines and freeze-frame ending, Sharon's rant for each error code, and the lesson cards.
- `scenes/curb_scene.gd`: one script builds every scene from that data: walking, talking, the rehearsal, the interruption, the performance and the ending. `ui/hud.gd` draws the bubbles, close-ups, code strip, rants, cards and title cards; `ui/pad.gd` is the legal pad.
- Art: `tools/paint.py` paints the cast (a 6-frame sheet and a 4-frame close-up each) by hand. `tools/scenery.py` and `tools/music.py` generate the backdrops, title art, map, music, sting and SFX through the Dunder Quest generators (`../dunder-quest/tools/`). The title cards use Libre Baskerville (OFL).

## Checks

```sh
godot --headless --path . --import
godot --headless --path . res://tests/smoke.tscn            # every scene loads
godot --headless --path . --script res://tests/cases.gd     # CASES result=ok: every plan, every combination of blanks
godot --headless --path . res://tests/bot.tscn              # BOT result=ok: plays all ten, wrong answer first at every plan
python tests/verify_rust.py                                 # RUST result=ok: rustc agrees with the checker (needs rustc)
godot --path . res://tests/shots.tscn -- scene=5            # screenshots into tests/shots/ (needs a window)
bash tests/check.sh                                         # cases, bot and rustc, as CI runs them
```

`verify_rust.py` compiles every plan in every combination of its blanks with the real rustc and runs what builds. The starting picks must fail with the scene's error code, the solution must print exactly the scene's lines, every lesson card must print what it says (or fail with its code), and the in-game checker must agree with rustc on every combination: the same pass or fail, an error code rustc also reports, and the same output and panics. CI runs it with the runner's rustc.

## Trailer capture

`tests/trailer_run.tscn` is the bot's full run paced for a trailer (lines stay up to be read, the pad is held open with its picks showing, music muted, one panic and one wrong answer added on camera). It prints `MARK <frame> <what>` lines for every moment worth cutting to: `scene`, `say`, `card`, `pad`, `rehearsal`, `rant`, `panic`, `run`, `squint`, `freeze`, `end`.

```sh
godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn > trailer/captures/run.log
godot --path . --write-movie trailer/captures/s5/f.png --fixed-fps 60 res://tests/trailer_run.tscn -- scene=5 > trailer/captures/s5.log
```

Trailer working files go in `trailer/`, which the web build ignores.

## Export

`scripts/export_web.sh` (CI) exports the Web preset to `build/site/curb/play/` and gzips the engine to fit Cloudflare's file limit.
