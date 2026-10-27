# Curb Your Oxidation trailer

A trailer for **Curb Your Oxidation**, cut like the promos for the kind of LA cringe comedy the game is a homage to, as a fast run of highlights on the beat of one music cue: the name in the show's yellow on black, Barry's punchlines, white cards on black, all in heavy Franklin Gothic like the show's titles (Libre Franklin, OFL, in `trailer/fonts/`; the show's ITC Franklin Gothic Heavy is commercial), the sepia rehearsal stopping on a red line and Sharon bursting in with the rustc error, the `unwrap()` panic, Barry's squint held through an awkward silence, a run of freeze frames, and a bouncy tuba sting. It doesn't play the whole game: a bar (2 s) or so per moment, every text card held for a full bar, 71 s in all. Like the Dunder Quest and Flatmates.js trailers, it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

Names, lines and music are the game's own: Barry, Gil, Sharon and the rest of the homage cast, original lines, and an original Italian-library-style cue (tuba, mandolin, pizzicato). The music briefs ask for the style and instruments only and never describe any TV theme. The trailer doesn't name the show.

## Rebuild

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env)
bash trailer/capture.sh                  # the bot's run at 1920x1080 -> trailer/captures/ (~1.5 h, ~8 GB)
python tools/make_trailer.py             # -> trailer/out/
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description. Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

Shots look up their capture frames by name in `run.log` (`mark("rant E0382", scene)`), so a fresh capture usually needs no renumbering. The squint punch-in (`SQUINT_FOCUS`) is a screen position, so check it on `--stills` after re-capturing.

## How it's cut

`cue_curb` measured at 120 BPM, beats at 0.05 s + k/2, bars from 1.05 s. It plays from the start, and every cut is on a beat or a bar; the game's sound sits under it.

| Cue | Picture |
|---|---|
| pickup to bar 1 | *Curb Your Oxidation* in yellow on black |
| bars 1–5.5 | Scene 1's punchlines: "One. One latte.", the rehearsal stopping on line 4, Sharon with E0384, Barry's squint ("Is that a rule?") |
| bars 5.5–12 | A bar for each card, then footage: *Barry Danvers has rules.* (the deli) *So does Rust.* (the legal pad) *And somebody is always checking.* (Sharon on the regifted Barolo, E0382) |
| bars 12–15 | Three plans, a bar each, with the key line of Rust on a legal-pad chip |
| the stop at 32.2 s | The `unwrap()` panic, then the rehearsal and Sharon on the shrimp tray (E0499) |
| the silence at 38.5 s | Barry's squint, held |
| bars 20–22 | Sharon on `match` (E0004) and the spare key (E0597) |
| bars 22–28 | Three endings (the Barolo, the shrimp, the returns desk): their last awkward lines, then the freeze frame |
| bar 28 → last chord | The houseguest, his freeze frame on the cue's last chord, the tuba sting, then the end card over the game's title tune |

## Files

```
trailer/
  README.md               tracked
  fonts/                  tracked; Libre Franklin and its OFL licence
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + run.log
  out/                    git-ignored; renders
    curb_trailer_4k.mp4           upload this one to YouTube
    curb_trailer_1080p.mp4        Steam-compatible master (H.264 + AAC, 60 fps)
    curb_thumbnail.png         1920×1080
```

## Backlog

- [ ] **Listening pass.** The mix and the cue's sections were placed by measurement only, not by ear.
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest), using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/), then embed it on dunderquest.com/curb/.
