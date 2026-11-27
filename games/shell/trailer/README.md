# Yes, Shell! trailer

A 70-second trailer for **Yes, Shell!**: a fast run of highlights on the beat of one original music cue (a scrappy rock band, nervy guitar, driving bass and drums, and a kitchen's pots, pans and service bell), with the game's own voices. Uncle Awk's kitchen, where the orders were shouted, the name as the band crashes in, Ash Bourne home with a system, then a card at a time in the game's Bebas Neue between the moments that teach: `grep beef orders.txt` written chip by chip with the pass printing as it goes, the fire, the ticks and the ORDER UP; the words the wrong way round and bash's own `grep: beef: No such file or directory`; a line that sends too much food and Shell saying so; the pipe; the to-go machine in the cue's dead stop; the critic's question through the build; and the five-command line on the band's return, ending on `5 fries` and an end card with the URL and Uncle Awk's last word. It doesn't play the game through. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

Names, lines and music are the game's own: Ash Bourne, Michelle "Shell" Tee, Uncle Awk and Regina Root, and an original cue whose brief asks for a style and instruments only. Nothing in the trailer names a show, a character or an actor.

## Rebuild

Run from `games/shell/`; Python comes from mise (`mise exec -- python ...`).

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env); a new cue is new music, see below
bash trailer/capture.sh                  # the bot's six runs at 1920x1080 -> trailer/captures/ (~15 min, ~2 GB)
python tools/make_trailer.py             # -> trailer/out/, and the thumbnail to site/static/img/shell/trailer.png
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description (`YS_CHAPTERS` in `site/build.ts`). Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list and where each voice line sits), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

**The captures run one at a time**, as AGENTS.md asks: several copies of a game recording at 1920×1080 at once brought Rob's machine down. Godot needs a window, so on a machine with no display (a cloud session) `capture.sh` runs it under `xvfb-run`; set `GODOT` to the editor binary if it isn't `godot` on the PATH. `tests/trailer_run.gd`, the bot (`tests/bot.gd`) paced for the camera, only takes its time over what the trailer cuts to: its `PAGES` (the prologue's pages) and `WANT` (each shift's lines of talk, tickets and lesson cards, and the wrong lines to write first, `miss`). Everything else it hurries through. To cut to something new, add it there and capture that run again (`bash trailer/capture.sh s3 shift=3`).

Shots look up their capture frames by name in the logs (`MARK <frame> write 2a 0`, `refused 2a 0`, `sent 5d`, `say 5 awk 3.610| The machine!...`), so a fresh capture needs no renumbering. The voices aren't taken from the captures: `voices()` in `make_trailer.py` lays the game's clips (`assets/voice/`, named the way `core/voice.gd` names them, with each line's `say` looked up in `data/shifts.json`) straight into the mix, so a line can be cut to the words that land (`cut`) or have its pauses closed up (`tight`). The captures' own sound is used only on the pass, for the chips, the fire, the plates and the order-up.

The cue is generated, so running `trailer_audio.py` again gives different music (`cue_shell:3` makes three takes to choose from; the trailer uses the third, saved as `cue_shell.wav`, chosen because it kept the brief's shape: a sparse open, the band, a dead stop, a build and one last hit). Keep `audio/` (and `out/`) safe outside the worktree, as AGENTS.md says, and copy it back rather than regenerating. A new cue has to be measured again: its tempo and beat phase, where the sparse opening and the band start (`CUE_SPARSE`, `CUE_BAND`), the stop, the build, the band's return and the last hit.

## How it's cut

`cue_shell` measured at 120 BPM, beats at 0.49 s + k/2 in cue time. It opens on two seconds of nothing and eight sparse seconds (a ticking knife, a muted riff), then the band at 9.99 s; the trailer drops the nothing and plays the sparse bars one and a half times, because the cold open needs twelve seconds. From the band's entry at 12 s every beat is half a second and every bar two, and every cut is on one. The band stops dead at 44.5 s, builds quietly from 52.5 s, slams back at 56.5 s and lands its last hit at 61.5 s, with a soft guitar tag under the end card.

| Time | Picture |
|---|---|
| 0–12 s | Uncle Awk's kitchen: *It was Uncle Awk's kitchen. Orders were shouted. Tickets were lost.* *Two beef! No, three! Who's got table six? WHO HAS TABLE SIX?* |
| 12–14 s | The name, as the band crashes in |
| 14–23 s | *Then Ash Bourne came home... and a system.* *Every station does one thing. It does it well. Then it passes it down the line.* |
| 23–25 s | *Every station is a command. The pass is a pipe.* |
| 25–29 s | `grep beef orders.txt`, a chip at a time, the pass printing as it goes, the fire, three ticks and the ORDER UP |
| 29–31 s | *Real shell. Real errors.* |
| 31–37 s | `grep orders.txt beef` and bash's own `grep: beef: No such file or directory`, while Shell says why |
| 37–40 s | `cat orders.txt` fired: too much food, and the Chef's *Yes, Shell.* |
| 40–43.5 s | The pipe: `grep beef orders.txt \| head -n 2`, written and sent |
| 43.5–44.5 s | Two ORDER UP banners, a beat each |
| the stop, 44.5–52.5 s | *The machine! The to-go machine! It won't stop printing!* *Twelve tickets and climbing. Don't read them, Chef. Build a line.* |
| 52.5–56.5 s | Regina Root: *One question, Chef, and I'll have the answer on one line.* Then her ticket |
| 56.5–61.5 s | `cut -d, -f2 flood.csv \| sort \| uniq -c \| sort -rn \| head -n 1`, a chip at a time, fired: `5 fries` |
| 61.5 s → end | The end card on the cue's last hit; *Fries. Five stations, not one raised voice, and the answer is fries.* and Uncle Awk's *...Yes, Shell.* |

## Files

```
trailer/
  README.md               tracked
  capture.sh              tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + logs (open, s1..s5)
  out/                    git-ignored; renders
    shell_trailer_4k.mp4          upload this one to YouTube
    shell_trailer_1080p.mp4       Steam-compatible master (H.264 + AAC, 60 fps)
    shell_thumbnail.png           1920×1080
```

## Backlog

- [ ] **Keep the cue and the masters.** They were made in a cloud session (November 2026), so they're not in any checkout: copy `audio/` and `out/` from the files handed over into `D:\src\dunder-quest\games\shell\trailer\`.
- [ ] **Listening pass.** The cue's beats, its stop and its last hit were placed by measurement, and the frames were checked by eye, but nobody has listened to the mix: Rob to watch it.
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/) (the steps are in AGENTS.md), then paste its video ID into `SHELL_TRAILER_ID` in `site/build.ts`.
