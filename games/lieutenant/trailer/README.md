# Just One More JOIN trailer

A trailer for **Just One More JOIN**, cut as a fast run of highlights on the beat of one original music cue (walking bass, brushes, vibraphone, a wry bassoon): the title screen, then a card at a time in the game's Caprasimo, black like the game's own title cards, between the moments that sell it. A cold open, the Lieutenant shuffling in with his dog, a record going into the notebook as a table, a query spelled from chips and read to Records, the printout, and then the false exit in one twelve-second take: he says goodnight, makes for the door, stops on the cue's stab, and the bubble comes up on the next one. After it the database's own error, a `JOIN`, a `LEFT JOIN` with its `NULL`, the five freeze frames, and an end card with the URL. It doesn't play the game through, every text card is held for a full bar (2 s), and it runs 60 s. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, and the trailer's own cards are drawn at that size too (1080p is the master, 4K is 2×).

Names and music are the game's own: Lieutenant Colonna, Null, Doris and tonight's suspects, and an original cue whose brief asks for a style and instruments only. Nothing in the trailer names the show it's an homage to.

## Rebuild

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env)
bash trailer/capture.sh                  # the bot's runs at 1920x1080 -> trailer/captures/ (six at once, ~8 GB)
python tools/make_trailer.py             # -> trailer/out/, and the thumbnail to site/static/img/lieutenant/trailer.png
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description (`JJ_CHAPTERS` in `site/build.ts`). Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

The capture is six runs side by side: `intro` (the title screen, the case files and the prologue turning its own pages) and `c1` to `c5` (one case each). Shots look up their frames by name in each run's log (`MARK <frame> say 4 lt point| Doctor? Forgive me...`, `printout 3b error no such column: phones.owner`, `freeze 2`, ...), so a fresh capture usually needs no renumbering. `tests/trailer_run.gd` is the bot (`tests/bot.gd`) at a pace that can be read: lines held by their length, a chip picked every quarter second, the printout left down four seconds. It calls Records with the right answer only, plus three wrong pages chosen to get the database's own errors on camera.

A music model doesn't always keep to the brief, so `python tools/trailer_audio.py --takes 3` makes three takes to pick from. The trailer plays `trailer/audio/cue_join.wav`: copy the chosen take over it, measure its beats, its stop and its last hit, and set `CUE_BAR0`, `STAB_1`, `STAB_2`, `LAST_HIT` and `CUE_END` in `make_trailer.py` to match.

## How it's cut

`cue_join` measured at 120 BPM: beats at 0.09 s + k/2, bars of four from there. It plays from the first frame, and every cut is on a beat or a bar; the game's sound sits under it.

| Cue | Picture |
|---|---|
| bars 0–1.5, three stabs | The title screen |
| bars 1.5–7 | *Every case opens on the murder.* Case 1's cold open: the partner, then "He has thought of everything." *You know who did it. Now prove it.* |
| bars 7–13.5 | The Lieutenant and Null walk in. *The city's records only answer in SQL.* The guest book goes into the notebook as a table; a query spelled chip by chip, the call to Records, the printout; "Are we finished, Lieutenant?" |
| bars 13.5–19.5, the stop at bar 16 | Case 4's false exit in one take: goodnight, the walk to the door, he stops on the stab, "Doctor? Forgive me. It's a silly thing." on the second stab, and her reply as the band comes back |
| bars 19.5–23.5 | *Real SQL. Real errors.* `no such column`, the `JOIN` that names Hugo Brandt, the `LEFT JOIN` with `NULL` beside Augusta Harrow |
| bars 23.5–27 | Five freeze frames, two beats each. *Five cases. From SELECT to LEFT JOIN.* |
| bar 27 → end | The end card on the cue's last hit, with a sting, under the cue's quiet tag |

## Files

```
trailer/
  README.md               tracked
  capture.sh              tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + logs
  out/                    git-ignored; renders
    join_trailer_4k.mp4           upload this one to YouTube
    join_trailer_1080p.mp4        Steam-compatible master (H.264 + AAC, 60 fps)
    join_thumbnail.png            1920×1080
```

## Backlog

- [x] **Listening pass.** The cue's beats, its stop and its last hit were placed by measurement, and the take was chosen by its shape (three were made), not by ear; Rob watched the cut and said the music works (November 2026).
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/), then paste its video ID into `JOIN_TRAILER_ID` in `site/build.ts`.
- [ ] The game's rooms and in-game music are still the stand-ins made in code (see the game's README). If generated ones replace them, capture again.
