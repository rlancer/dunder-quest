# Prince of Versions

A Dunder Quest game that teaches Git. The Vizier has locked Princess Shirin in the tower and turned the hourglass, and all the Prince has is a dagger full of sand. It turns back time, but only to a moment he sealed. **A seal is a `git commit`.**

Every torch, gate, bridge and spike field in a room is a one-line file in a real Git repository, and the room is drawn from the working tree. Pull a lever and `gate` changes from `shut` to `open`, unstaged, until you commit it. Fall on the spikes and time stops in sepia: the only way on is `git reset --hard`, and the only places it can take you are commits, so whatever you hadn't committed is gone. The exit opens only on `main` with a clean tree. The Prince never types: the dagger's console is buttons, and each one shows the exact command it runs and Git's own output. The commit ids on screen are the ones Git computes.

It's a spoof of a certain palace-run platformer and its time-rewinding sequel, with homage names and its own rooms, sprites and music (see AGENTS.md for the rules). The full design, curriculum and level list are in [GAME.md](GAME.md).

The game plays at **dunderquest.com/prince/play/**, and its page is at /prince/. It's its own Godot 4.7 project, beside `../dunder-quest/`, `../flatmates/` and `../curb/`.

## The cast

The Prince (the hero, in a white tunic and red sash), Grand Vizier Rebasir (the villain, who commits sabotage into your log and means to rewrite history), Princess Shirin (locked in the tower, keeping the palace ledger; her commits are already in `main`), the Sultan of Main (offstage: `main` is his line, the only history the palace honours) and the palace guard (a real `pre-commit` hook that refuses commits straight to `main`).

## The rooms

Act I, built:

| # | Room | Git | What it teaches |
|---|---|---|---|
| 1 | The Hall of Seals | `git commit` · `git status` · `git reset --hard HEAD` | A commit is a save point; a hard reset loses what wasn't committed |
| 2 | The Vizier's Seal | `git log` · `git reset --hard <commit>` | The Vizier commits sabotage on top of you; `HEAD` is his commit, so go back further |
| 3 | The Princess's Bridge | `git revert` · `ORIG_HEAD` | Undo one commit and keep the ones after it; a reset would drop the Princess's bridge |
| 4 | Two Doors | `git switch -c` · `git switch` · `git merge` | Branches are parallel timelines; the guard refuses `main`; merge the one that worked |
| 5 | The Vizier's Gate (boss) | three-way `git merge` · conflicts | Git merges what it can; when both sides changed `gate`, you choose in its markers |

Act II (stash, cherry-pick, bisect, reflog, rebase and push) is designed in GAME.md and not built.

## How it's built

- `git/repo.gd`: a Git repository in GDScript. It hashes blobs, trees and commits the way Git does, with a fixed author date, so its ids match the real git; it does commits, resets, reverts, branches, fast-forward and three-way merges with Git's own conflict markers, `ORIG_HEAD`, and Git's output lines. `git/steps.gd` turns a level's steps (and the dagger's buttons) into commands on it.
- `data/levels.json`: the whole act. Each room's map, its files and which tiles show them, its starting history, the Vizier's triggers, the commands it unlocks, its solution, its lesson card, and the probes (wrong turns) the tests replay.
- `world/room.gd`: one script builds every room from that data: the tiles drawn from the working tree, death, the rewind, the Vizier's cutscenes and the exit. `world/prince.gd` is the Prince. `ui/console.gd` is the dagger's console, `ui/trail.gd` the sand trail along the top (the commit graph: one grain per commit, branch banners, `HEAD` as the glint of the dagger), and `ui/hud.gd` the cards, speech, hourglass and toasts.
- Sharp text: the window stretches in `canvas_items` mode, so the game is laid out at 480×270 and the pixel art scales up nearest-neighbor, while text is drawn at the window's own resolution.
- Art and sound: `tools/paint.py` paints the sprites and tiles by hand, at two texels to a room pixel (see GAME.md, "How the Prince reads"); `tools/scenery.py` and `tools/music.py` generate the backdrops and music; `tools/sfx.py` synthesizes the sound effects; `tools/site_art.py` makes the page's screenshots, the brand kit's cut-out sprites and the social card. Fonts are Pixelify Sans and VT323 (both OFL).

## Checks

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/replay.gd    # REPLAY result=ok: every solution and probe through the in-game Git
bun tests/verify_git.ts                                     # the same commands against the real git: same ids, files, conflicts, output
godot --headless --path . res://tests/bot.tscn              # BOT result=ok: plays every room, making its mistake first
godot --path . res://tests/shots.tscn -- room=3             # screenshots into tests/shots/ (needs a window)
bash tests/check.sh                                         # all three, as CI runs them
```

## Trailer

`tests/trailer_run.tscn` is the bot's run paced for a trailer (real timings for cards, speeches and the rewind, the console held open to be read, music muted), printing `MARK <frame> <what>` lines for every moment worth cutting to. `trailer/capture.sh` records it at 1920×1080, `tools/trailer_audio.py` generates the cue and effects, and `tools/make_trailer.py` cuts it. See [trailer/README.md](trailer/README.md). Trailer working files stay in `trailer/`, out of `assets/`, so the web build stays small.

## Export

`scripts/export_web.sh` (CI) exports the Web preset to `build/site/prince/play/` and fits it under Cloudflare's file limit.
