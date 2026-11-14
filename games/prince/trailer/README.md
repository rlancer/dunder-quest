# Prince of Versions trailer

A trailer for **Prince of Versions**, cut as a fast run of highlights on the beat of one original music cue (oud, santur, ney, frame drums): the title screen, then a card at a time in the game's Pixelify Sans between the moments that teach. A commit and Git's reply, a death with a torch uncommitted and the sands running back, the Vizier's sabotage commit, a reset past `HEAD`, a revert, the palace guard refusing `main`, branches on the sand trail, the merge conflict held through the cue's dead stop, a montage of rewinds, and an end card with the URL. It doesn't play the game through: a bar (2 s) or so per moment, every text card held for a full bar, 66 s in all. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

Names and music are the game's own: the Prince, Grand Vizier Rebasir and Princess Shirin, and an original cue whose brief asks for a style and instruments only. Nothing in the trailer names the game it spoofs.

## Rebuild

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env)
bash trailer/capture.sh                  # the bot's run at 1920x1080 -> trailer/captures/ (~30 min, ~10 GB)
python tools/make_trailer.py             # -> trailer/out/, and the thumbnail to site/static/img/prince/trailer.png
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description (`PV_CHAPTERS` in `site/build.ts`). Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

Shots look up their capture frames by name in `run.log` (`MARK <frame> git 1 0 commit -am "Light the first torch"`, `state 1 dead`, `conflict 5 gate`, ...), so a fresh capture usually needs no renumbering. `tests/trailer_run.gd` is the bot (`tests/bot.gd`) with real timings and the console held open long enough to read (`press_frames`, `hold_frames`).

## How it's cut

`cue_prince` measured at 120 BPM: beats at 0.055 s + k/2, bars of four from there. It plays from the first frame, and every cut is on a beat or a bar; the game's sound sits under it.

| Cue | Picture |
|---|---|
| bars 0–1.5 | The title screen |
| bars 1.5–8.5 | *A dagger that turns back time.* A torch and its commit. *But only to a moment you sealed.* The spikes with a torch uncommitted, `git reset --hard HEAD` and the rewind. *A seal is a git commit.* |
| bars 8.5–16 | *The Vizier commits too.* His speech and sabotage commit, the reset past `HEAD`, room 3's revert, the guard refusing `main`, two branches and a merge on the sand trail, a beat each |
| the stop at bar 16 | `git merge winch`: the conflict lands on the cue's hit and is held, with Git's markers, through the reversed swell |
| bars 18–25 | *Real Git. Real commit ids.* The merge committed, the Vizier fleeing, the door, the room's lesson card |
| bars 25–27 | Eight rewinds, a beat each |
| bars 27–30 | *Five rooms. Your first commit to your first merge conflict.* The title screen again |
| bar 30 → end | The end card on the cue's last hit, with the sting |

## Files

```
trailer/
  README.md               tracked
  capture.sh              tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py
  captures/               git-ignored; capture frames + run.log
  out/                    git-ignored; renders
    prince_trailer_4k.mp4         upload this one to YouTube
    prince_trailer_1080p.mp4      Steam-compatible master (H.264 + AAC, 60 fps)
    prince_thumbnail.png          1920×1080
```

## Backlog

- [ ] **Listening pass.** The cue's beats and its stop were placed by measurement only, not by ear.
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/), then paste its video ID into `PRINCE_TRAILER_ID` in `site/build.ts`.
