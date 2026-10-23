# Trailer

A 62 s motion-graphics trailer for **__dunder_quest__**, cut to the beat of a generated music cue and built entirely from the repo. There's no video editor in the loop. YouTube comes first; Steam is deferred (see [PLAN.md](PLAN.md) §8).

- [PLAN.md](PLAN.md) has the research: the pitch, trailer craft rules, beat sheet, visual style, deliverable specs and sources.
- [../GAME_IMPROVEMENTS.md](../GAME_IMPROVEMENTS.md) lists the game issues spotted while making it.

## Rebuild

```sh
python tools/generate_trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in .env)
godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_capture.tscn > trailer/captures/run.log   # ~35 min
python tools/make_trailer.py                      # ~8 min -> trailer/out/
```

Quicker checks while editing the cut:

```sh
python tools/make_trailer.py --stills             # contact sheet of the whole cut -> trailer/out/stills.png
python tools/make_trailer.py --at 12.5 30         # frames at those times -> trailer/out/at.png
python tools/make_trailer.py --thumb              # YouTube thumbnail only
python tools/make_trailer.py --audio-only         # re-mix and re-encode, reusing the rendered native.mkv
python tools/make_trailer.py --no-4k              # skip the 4K encode
```

Regenerate a single cue or SFX with `python tools/generate_trailer_audio.py cue_b whoosh`. Re-run the capture only when the game changes. The shot source frames in `make_trailer.py` point into that capture, so re-check them against the new `run.log` afterwards.

## How it works

| Stage | File | What it does |
|---|---|---|
| Audio | `tools/generate_trailer_audio.py` | Prompts Lyria for the music cues and Seed Audio for the SFX, writing 48 kHz stereo WAVs to `trailer/audio/`. |
| Capture | `tests/trailer_capture.gd` | Reuses the `trail_check` bot to play all six stages under Movie Maker: 13,442 lossless PNG frames + WAV, stage music muted. Prints `MARK <frame> <event> on/off x=<pos>` for cards, builds, duel questions, answers, misses and banishes. |
| Edit | `tools/make_trailer.py` → `edit()` | The cut as a list of `Shot`s (source frame, speed, zoom, focus, overlay FX). Every cut lands on a bar or a beat of `cue_b` (125 BPM, first beat 0.06 s, drop 38.46 s, slam 53.82 s). |
| Compose | `tools/make_trailer.py` | Draws each frame at native 480×270 with the game's fonts and palette: punch-ins, flashes, shakes, typed syntax-colored code, stage slams, code chips, parallax cards, end card. |
| Mix | `tools/make_trailer.py` → `mix_audio()` | Music (ducked under hits) + in-game SFX (boosted, soft-limited) + trailer SFX, then two-pass loudnorm to −14 LUFS / −1 dBTP. |
| Encode | `tools/make_trailer.py` → `encode()` | Nearest-neighbor ×4 (1080p) and ×8 (4K), x264 `tune=animation`, AAC 320k. |

## Files

```
trailer/
  README.md, PLAN.md      tracked
  audio/*.wav             git-ignored; regenerate with generate_trailer_audio.py
  captures/               git-ignored; ~640 MB of capture frames + run.log
  out/                    git-ignored; renders
    dunder_quest_trailer_4k.mp4     upload this one to YouTube
    dunder_quest_trailer_1080p.mp4
    youtube_thumbnail.png           1920×1080
```

`trailer/.gdignore` keeps Godot from importing any of it.

## v1 status (2026-10-23)

Done: the full cut, the 1080p and 4K masters and the thumbnail. Measured −13.9 LUFS integrated and −0.9 dB peak, 62.000 s, pixel grid checked on 4K crops.

## Backlog

In rough priority order. Tick items off here as they land.

- [ ] **Listening pass.** The mix was balanced by measurement only, so nobody has heard it yet. Check the music/SFX balance, the ducking, and whether `cue_b` actually fits. `cue_a` (94 s) is the alternative.
- [ ] **Muted watch.** The hook ("YOUR CODE / BUILDS THE WORLD") and the code chips have to land with the sound off.
- [ ] **Show the wizard's spells.** The bot answers almost instantly, so ward waves and hexes barely appear. Add a scripted duel shot that uses the `spell` step from `tests/look_tour.gd`.
- [ ] **Vertical Short** (1080×1920, ≤ 60 s). The compositor can do it with new `W`/`H` and per-shot crops; see PLAN.md §8 for the two layouts.
- [ ] **GIF loops** (3–6 s) of the bridge build and a duel, for the site and social posts.
- [ ] **Re-capture after game fixes.** Several items in GAME_IMPROVEMENTS.md (bridge text, duel framing, "Ward broken!") change how shots read, so re-capture once they land.
  - Landed in #23 and #25 (items 1–4). Shots in `tools/make_trailer.py` that change:
    - `BRIDGE = 9290`: the `span(5) returns 14` text now floats up from under the span blocks, not over the `def span(n)` sign. Check the shake still lines up with the bump at 9356.
    - The six finale `duels` (1000, 3322, 5683, 7770, 9876, 12075), `ARENA = 5560` and the thumbnail at 5732: while a question is open, the camera now eases in (up to about ×1.2) on the blocks and both figures, and "Ward broken!" holds about 1 s with a thicker outline.
    - Every running shot: the run bob now follows game time, so it no longer drifts against Movie Maker frames.
  - The changes are visual only and gameplay timing is the same, so the source frame numbers above should still match a fresh capture. Spot-check them against the new contact sheets before re-rendering.
  - After re-rendering, update the home page embed from #26. Set `TRAILER_ID` in `site/build.py` and in `stats/src/brand.ts` (the admin's Brand pages) to the new YouTube video ID, and replace `site/static/img/trailer.png` with the new thumbnail (`tools/make_trailer.py` renders it from capture frame 5732 to `trailer/out/youtube_thumbnail.png`). Then run `python site/build.py` to check the site still builds.
- [ ] **Upload.** Use the YouTube checklist in PLAN.md §8, then embed the video on dunderquest.com. Don't host video files on Cloudflare Pages.
- [ ] **Steam (later).** Raise the bitrate to at least 5 Mbps (the current 1080p is ~2.3 Mbps) and remove any text that says "free in your browser".
