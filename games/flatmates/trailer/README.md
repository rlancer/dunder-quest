# Flatmates.js trailer

A 66 s trailer for **Flatmates.js**, played as a flat-share sitcom. The inner voices do the talking, the camera sits in one flatmate's head and stares at the other, and the jokes land in the awkward silences. Like the Dunder Quest trailer (`../../dunder-quest/trailer/`), it's built entirely from the repo with no video editor in the loop, and every frame is composed at the game's native 480×270 and scaled by whole numbers.

Names and lines are winks, not the show's: Clive and Jazz only, and every line is original.

## Rebuild

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env)
godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn > trailer/captures/run.log   # ~12 min
python tools/make_trailer.py             # -> trailer/out/
```

Quicker checks: `--stills` (contact sheet, one frame per shot), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`, the same flags as the Dunder Quest trailer.

Shots look up their capture frames by name in `run.log` (`mark("run jazz.js", stage, nth)`), so a fresh capture usually needs no renumbering. The punch-in spots (`CLOSE_CLIVE`, `POV_STARE` and so on) are screen positions, so check them on `--stills` after re-capturing.

The `typing` and `impact` SFX come from the Dunder Quest trailer's `../../dunder-quest/trailer/audio/`, so run `python ../dunder-quest/tools/generate_trailer_audio.py typing impact` first on a fresh clone.

## How it's cut

`cue_flat` measured at 123.45 BPM, first beat 0.148 s in. Its soft first two bars are skipped (`CUE_SKIP`), so it comes in on the full band right on the title. Its sections set the structure:

| Trailer | Cue | Picture |
|---|---|---|
| 0:00–0:06.5 | (none, game SFX) | Cold open in the middle of things: Jazz strums once too often, the speakers come down, record scratch, freeze frame. *Clive:* "Yep. That's me. You're probably wondering how we got here." Tape rewind to EARLIER THAT SATURDAY. |
| bars 2–8 | verse | Title on the band's first hit, Clive / Jazz in half a bar each, the editor running into Jazz doing it, Clive's POV on Jazz, then the hook: **YOU WRITE THE SCRIPT. HE LIVES IT.** |
| bars 8–16 | chorus | The six stops, a bar each, with name and code chip, then a bar of quick cuts |
| bars 16–22 | piano breakdown | The awkward bit: the 500 ms barrier, a lesson card, and a held stare ("Say something. Anything." … "Do you like semicolons?") |
| bars 22–28 | full band | Finale: the bell, the tannoy, the wedding, the car, then cuts on every beat |
| bar 28 → end | last chord + piano tag | End card. Over the tag: "Did we just learn JavaScript?" / "Don't tell anyone." |

## Files

```
trailer/
  README.md               tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + run.log
  out/                    git-ignored; renders
    flatmates_trailer_4k.mp4      upload this one to YouTube
    flatmates_trailer_1080p.mp4
    youtube_thumbnail.png         1920×1080
```

## Backlog

- [ ] **Listening pass.** The mix was balanced by measurement only, not by ear.
- [ ] **Muted watch.** The freeze frame and the stare rely on the inner-voice text, which should hold up with the sound off.
- [ ] **Upload** to YouTube and embed it on dunderquest.com/flatmates/. Don't host video on Cloudflare Pages.
- [ ] **Vertical Short.** The stare and the cold open would crop well to 9:16.
