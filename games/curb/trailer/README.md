# Curb Your Oxidation trailer

A trailer for **Curb Your Oxidation**, cut like the promos for the kind of LA cringe comedy the game is a homage to: it opens like an episode, on the title tune with the name in the show's yellow serif on black and then the episode's title card, before dropping into the situation; then plain white serif on black cards, the squabbling left to play, the sepia rehearsal stopping on a red line and Sharon bursting in with the rustc error, Barry's squint held through an awkward silence, the `unwrap()` panic, and a freeze frame with a bouncy tuba sting. Like the Dunder Quest and Flatmates.js trailers, it's built entirely from the repo with no video editor in the loop, and every frame is composed at the game's native 480×270 and scaled by whole numbers.

Names, lines and music are the game's own: Barry, Gil, Sharon and the rest of the homage cast, original lines, and an original Italian-library-style cue (tuba, mandolin, pizzicato). The music briefs ask for the style and instruments only and never describe any TV theme. The trailer doesn't name the show.

## Rebuild

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env)
godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn > trailer/captures/run.log   # ~25 min
python tools/make_trailer.py             # -> trailer/out/
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description. Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

Shots look up their capture frames by name in `run.log` (`mark("rant E0382", scene)`), so a fresh capture usually needs no renumbering. The squint punch-in (`SQUINT_FOCUS`) is a screen position, so check it on `--stills` after re-capturing.

## How it's cut

The opening titles sit on the game's title tune (`assets/audio/music_title.ogg`), whose beats fall at 0.5 s + k. `cue_curb` measured at 120 BPM, beats at 0.05 s + k/2, bars from 1.05 s. It comes in on its pickup after the situation, and every cut after that is on a beat or a bar.

| Trailer | Cue | Picture |
|---|---|---|
| 0:00–0:07.5 | the game's title tune | Like the top of an episode: *Curb Your Oxidation* in yellow serif on black, then the game's own title card for scene 1, *The Second Latte*. The tune drops out on the cut. |
| 0:07.5–0:21 | (none: game sound and kitchen room tone) | The situation, scene 1: "One. One latte." / "Write it down." / "That was a Tuesday." The pad, the sepia rehearsal stopping on line 4, Sharon with E0384, Barry's squint: "Is that a rule? Is that a real rule?" |
| bars 0–8 | main section | From the cue's first hit, card / footage / card / footage: *Barry Danvers has rules.* (the deli) *So does Rust.* (the legal pad) *And somebody is always checking.* (the rehearsal and Sharon on the regifted Barolo, E0382) |
| bars 8–15 | busier section | Scenes 4 to 10, a bar each: the game's own black serif title card for a beat and a half, then the plan playing out, with its key line of Rust on a legal-pad chip |
| the stop at 32.2 s | silence, breakdown | The `unwrap()` panic, then the rehearsal and Sharon on the shrimp tray (E0499) |
| the silence at 38.5 s | nothing | Barry's squint, held |
| bars 20–28 | full band | Sharon on `match` (E0004) and the spare key (E0597), then three endings (the Barolo, the shrimp, the returns desk): their last awkward lines, then the freeze frame |
| bar 28 → last chord | sting | The houseguest ("You OWN it."), his freeze frame on the cue's last chord, the tuba sting, then the end card over the game's title tune |

## Files

```
trailer/
  README.md               tracked
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
