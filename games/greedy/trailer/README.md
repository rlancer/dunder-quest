# The Good, the Bad and the Greedy trailer

A 68-second trailer for **The Good, the Bad and the Greedy**: a fast run of highlights on the beat of one original music cue (twangy guitar, a whistle, trumpet, jaw harp), with the game's own voices. The band standing in the desert while the old-timer says who they are, the name as the band gallops in, the town where everybody is a Hobson, Dot Starr riding in, then a card at a time in the game's Rye between the moments that teach: `H.nk` written chip by chip with the line-up lighting up, the draw and the CAUGHT banner, the Mayor on the subject of the church organists, a run of banners a beat each, Big Backtrack in the cue's dead stop and his count doubling through the build, greedy against lazy, Dot Starr caught by her own `.*`, and an end card with the URL and one last joke about the beans. It doesn't play the game through. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

Names, lines and music are the game's own: Sheriff Reg Exley, the Lazy Kid, Dot Starr, Mayor Hobson and Big Backtrack, and an original cue whose brief asks for a style and instruments only. Nothing in the trailer names a film, a character or an actor.

## Rebuild

Run from `games/greedy/`; Python comes from mise (`mise exec -- python ...`).

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env); a new cue is new music, see below
bash trailer/capture.sh                  # the bot's six runs at 1920x1080 -> trailer/captures/ (~20 min, ~1.6 GB)
python tools/make_trailer.py             # -> trailer/out/, and the thumbnail to site/static/img/greedy/trailer.png
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description (`GR_CHAPTERS` in `site/build.ts`). Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list and where each voice line sits), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

**The captures run one at a time.** Recording at 1920×1080 is slow here (about seven frames a second), and six copies of the game recording at once brought Rob's machine down (November 2026). So `tests/trailer_run.gd`, the bot (`tests/bot.gd`) paced for the camera, only takes its time over what the trailer cuts to: its `PAGES` (the prologue's pages) and `WANT` (each job's lines of talk, posters and lesson cards). Everything else it hurries through. To cut to something new, add it there and capture that run again (`bash trailer/capture.sh j3 job=3`).

Shots look up their capture frames by name in the logs (`MARK <frame> write 1b 0`, `caught 5c`, `say 1 sheriff 2.478| Everybody in this town...`), so a fresh capture needs no renumbering. The voices aren't taken from the captures: `voices()` in `make_trailer.py` lays the game's clips (`assets/voice/`, named the way `core/voice.gd` names them) straight into the mix, so a line can be cut to the sentence that lands (`cut`) or have its pauses closed up (`tight`). The captures' own sound is used only on the desk, for the chips, the draw and the verdicts.

The cue is generated, so running `trailer_audio.py` again gives different music (`cue_greedy:3` makes three takes to choose from; the trailer uses the third of the first three, saved as `cue_greedy.wav`). Keep `audio/` (and `out/`) safe outside the worktree, as AGENTS.md says, and copy it back rather than regenerating. A new cue has to be measured again: its tempo, where the sparse opening and the band start (`CUE_SPARSE`, `CUE_BAND`), the stop, the build, and the last hit.

## How it's cut

`cue_greedy` measured at 120 BPM. It opens on four seconds of nothing, then four sparse seconds of whistle, then the band; the trailer drops the nothing and plays the sparse four seconds twice, because the old-timer needs eight. From the band's entry at 8 s every beat is half a second and every bar two, and every cut is on one. The cue stops dead at 40.5 s, builds quietly from 44 s, comes back at 48 s and lands its last hit at 61.5 s; the sparse bars come back, twice over, as a tag under the end card, after two whip cracks count the last hit in.

| Time | Picture |
|---|---|
| 0–8 s | The band in the desert: *That's the band. They go wherever the story goes, and nobody is sure who's paying them.* |
| 8–10 s | The name, as the band gallops in |
| 10–15 s | *Everybody in this town is named Hobson?* *It keeps the stationery simple.* |
| 15–22 s | *Then Dot Starr rode in.* *I'll take the bank. And the feed store. And everything else on the line.* |
| 22–26 s | *Nobody shoots anybody. The law is a wanted poster.* *A wanted poster is a pattern.* |
| 26–31 s | `H.nk`, a chip at a time, the draw, the verdicts and the CAUGHT banner |
| 31–36 s | The Mayor: *You've arrested Hunk and Hink. They're the church organists!* and `H[ao]nk` |
| 36–38 s | *`H[ao]nk`: that's a regular expression.* |
| 38–40.5 s | Five CAUGHT banners, a beat each: `^DOT`, `\bKid\b`, `pf+t`, `\$\d{3}$`, `WANTED: (DEAD\|ALIVE)` |
| the stop, 40.5–46 s | Big Backtrack: *Backtrack try every way. Then Backtrack go back. Try every other way.* |
| 46–50 s | His count of ways to split a row of a's, doubling through the build and the band's return |
| 50–57 s | Dot: *They call it greedy. I call it thorough.* Then `".*"` and `".*?"` on the same line-up |
| 57–61.5 s | `^D.* Starr$` written and drawn at double speed while Dot objects; *Five jobs. Every line voiced. Real regex.* |
| 61.5 s → end | The end card on the cue's last hit, and the Kid's last word on the beans |

## Files

```
trailer/
  README.md               tracked
  capture.sh              tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + logs (open, j1..j5)
  out/                    git-ignored; renders
    greedy_trailer_4k.mp4         upload this one to YouTube
    greedy_trailer_1080p.mp4      Steam-compatible master (H.264 + AAC, 60 fps)
    greedy_thumbnail.png          1920×1080
```

## Backlog

- [ ] **Listening pass.** The cue's beats, its stop and its last hit were placed by measurement, and the frames were checked by eye, but nobody has listened to the mix: Rob to watch it.
- [x] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/) (the steps are in AGENTS.md), then paste its video ID into `GREEDY_TRAILER_ID` in `site/build.ts`.
