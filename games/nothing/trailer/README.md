# A Game About Nothing trailer

An 80-second trailer for **A Game About Nothing**: a fast run of highlights on the beat of one original music cue (a slapped bass, finger snaps, a light funk band), with the game's own voices. Stu on stage at the Rimshot noticing that the whole internet is people asking for things, and that nobody goes on to offer, while a request writes itself out and a 200 comes back; the name as the band comes in; the 404 ("Like my refrigerator."), and Lenny, who wanted the soup; then a card at a time in the game's Righteous between the moments that teach: a request slip made card by card and a `201 Created` (six years of tuna, and now Lenny's a toast guy), the broth counter answering a wrong Content-Type with `{"error":"Next!"}`, four status lines a beat each, and then the music drops to almost nothing for Stu's bit on DELETE and `204 No Content`, and Lenny's *Finally, a status code about us.* The band comes back for the post office's `412`, the network's PATCH with a token, a version and a body under Mr. Pratt's *If I laugh, I'll sign it. I won't laugh.*, his one laugh, and an end card with the URL and one last joke about whose fault a 4 is. It doesn't play the game through. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

This is the second cut. The first (PR #110) was made from the script as it was before #111 rewrote it to be funnier and re-voiced it, so several of its clips no longer exist; this one is cut from the new lines, to a new cue.

Names, lines and music are the game's own: Stu Lerner, Lenny Kaplan, Dana Wexler, Kasimir, Vernon and Mr. Pratt, and an original cue whose brief asks for a style and instruments only. Nothing in the trailer names a show, a character or an actor, quotes one, or recreates a theme tune.

## Rebuild

Run from `games/nothing/`; Python comes from mise (`mise exec -- python ...`; in a cloud session, plain `python3`).

```sh
python tools/trailer_audio.py            # music cue + SFX -> trailer/audio/ (OpenRouter, key in the repo's .env); a new cue is new music, see below
bash trailer/capture.sh                  # the bot's six runs at 1920x1080 -> trailer/captures/ (~20 min, ~1.6 GB)
python tools/make_trailer.py             # -> trailer/out/, and the thumbnail to site/static/img/nothing/trailer.png
```

`make_trailer.py` prints the YouTube chapter times (`CHAPTER m:ss ...`) for the description (`AN_CHAPTERS` in `site/build.ts`). Quicker checks: `--stills` (contact sheet, one frame per shot, plus the shot list and where each voice line sits), `--at 12.5 30` (frames at those times), `--thumb`, `--audio-only`, `--no-4k`.

**The captures run one at a time**, as AGENTS.md asks. Recording at 1920×1080 is slow (about eight frames a second), so `tests/trailer_run.gd`, the bot (`tests/bot.gd`) paced for the camera, only takes its time over what the trailer cuts to: its `PAGES` (the prologue's pages) and `WANT` (each episode's lines of talk, scenes and sets, and any slip sent wrong on purpose first). Everything else it hurries through. To cut to something new, add it there and capture that run again (`bash trailer/capture.sh e3 episode=3`).

Recording needs a window. Where there's no display (a cloud session), `capture.sh` runs Godot under `xvfb-run` with the OpenGL renderer; set `GODOT` to the binary (`source scripts/godot_setup.sh` fetches it) and run `--import` on the project first. That is how this trailer was captured.

Shots look up their capture frames by name in the logs (`MARK <frame> write 1c 0`, `won 3c 204`, `say 2 kasimir 0.751| Next!`), so a fresh capture needs no renumbering. The voices aren't in the captures at all (the bot runs muted): `voices()` in `make_trailer.py` lays the game's clips (`assets/voice/`, named the way `core/voice.gd` names them) straight into the mix, so a line can be cut to the sentence that lands (`cut`) or have its pauses closed up (`tight`). The captures' own sound is used only at the counter, for the cards, the send and the verdict.

The cue is generated, so running `trailer_audio.py` again gives different music. For this cut it made six takes from OpenRouter (`cue_nothing:3`, twice) and two from ElevenLabs Music with a timed section plan (`cue_nothing_el:2`; both ignored the plan's stop, so neither was used); the trailer uses take 5, the only one with the long near-silence the DELETE bit needs, saved as `cue_nothing.wav`. **Keep `audio/` (and `out/`) safe outside the worktree**, as AGENTS.md says, and copy it back rather than regenerating. This trailer was rendered in a cloud session, whose files are gone when it ends, so the masters, the thumbnail and the cue were sent to Rob to save into `games/nothing/trailer/` in his main checkout, replacing the first cut's. A new cue has to be measured again: its tempo, its first note, where the band comes in, stops, comes back and lands its last hit (`BAND`, `STOP`, `BACK`, `LAST_HIT`, `TAG`), and where bars can be cut out so its ending lands where the cut wants it (`SPLICE`, `CUE_END`).

## How it's cut

`cue_nothing` (take 5) measured at 122 BPM, a beat every 0.4915 s, with its first note 0.6 s in; the trailer and the cue start together. The bass plays alone, with finger snaps, until the band comes in on 7.0 s, and every cut before the splice is on one of the cue's eighth notes counted from there (`on(k)` in `make_trailer.py`). The band's last hit before the break is on 40.17 s, and then there are almost fourteen seconds of nearly nothing (a snap every two beats) before it comes back on 54. The cue runs a long way after that, so nine bars of it (cue 64.46–82.17 s, picked where the band sounds most alike either side) are cut out with a short crossfade, which puts its last hit on 69.79 s. A solo slap-bass tag follows to 72.7 s, and the cue is stopped there, before a stray full-band burst it adds after a silence. The opening's solo bass comes back, quietly, under the end card.

| Time | Picture |
|---|---|
| 0–7 s | Stu at the Rimshot: *You ever notice the whole internet is just people asking for things? Give me the menu. Nobody goes on to offer.* while `GET /menu` writes itself out and `200 OK` comes back |
| 7–9 s | The name, as the band comes in |
| 9–16.3 s | *And it always answers with a number. 200, it's OK. 404, there's nothing there. Like my refrigerator.* `GET /orders/9`, `404 Not Found` |
| 16.3–20.3 s | Lenny: *A number? I don't want a number! I want the soup!* |
| 20.3–24.2 s | *Every counter in New York is a web server. Every errand is an HTTP request.* |
| 24.2–30.1 s | Stu: *Lenny wants a toast at table 4. Put the order in, as JSON, before he loses his nerve.* `POST /orders` with its Content-Type and its body, a card at a time, sent: `201 Created` |
| 30.1–33 s | Lenny: *Six years of tuna, and now I'm a toast guy!* |
| 33–36.5 s | Dana: *Get one thing wrong and he says one word.* Kasimir: *Next!* |
| 36.5–38.2 s | The same order sent as `text/plain`: `415 Unsupported Media Type`, `{"error":"Next!"}`, and *Next!* again |
| 38.2–40.2 s | Four status lines, a beat each: `200 OK`, `201 Created`, `304 Not Modified`, `202 Accepted` |
| the nothing, 40.2–54 s | `DELETE /tables/4` goes over under *And what does it send back?* and `204 No Content` comes back, then Stu's set: *It worked, and there's nothing to say about it. My favourite status. It's a show about nothing.* Then Lenny: *Finally, a status code about us.* |
| 54–57.5 s | Vernon: *Every parcel has a version, Lerner.* A PATCH with last week's `If-Match`: `412 Precondition Failed` |
| 57.5–64.2 s | Mr. Pratt: *Show me who you are, or don't come in.* Then the PATCH with a token, a version and a body, made card by card at about one and a half times speed under his *If I laugh, I'll sign it. I won't laugh.*: `200 OK` |
| 64.2–69.8 s | Mr. Pratt: *Ha.* (once). Lenny: *Six episodes! Of nothing! We're geniuses!* |
| 69.8–72.7 s | On the band's last hit, over the bass tag: *Real HTTP. Every request is checked against a real HTTP server.* |
| 72.7 s → end | The end card; *And anything starting with a 4?* *Means it's your fault.* and a rimshot |

## Files

```
trailer/
  README.md               tracked
  capture.sh              tracked
  audio/*.wav             git-ignored; regenerate with tools/trailer_audio.py (new music each time)
  captures/               git-ignored; capture frames + logs (open, e1..e5)
  out/                    git-ignored; renders
    nothing_trailer_4k.mp4        upload this one to YouTube
    nothing_trailer_1080p.mp4     Steam-compatible master (H.264 + AAC, 60 fps)
    nothing_thumbnail.png         1920×1080
```

## Backlog

- [ ] **Listening pass.** The cue's beats, its stop, its splice and its last hit were placed by measurement, the voice lines were cut at pauses found by measurement, and the frames were checked by eye, but nobody has listened to the mix: it was made in a cloud session by an agent that can't hear. Rob to watch it. Things worth an ear: the splice at 64.5 s (under Mr. Pratt's laugh; if it jumps, try another pair of bars), whether the cue's tempo sits with the cuts (it's 122 BPM, and its hits fall on the off-beat in places), Stu's opening line with *Give me the weather.* taken out (the caption still shows it), and the generated rimshot at the very end.
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/) (the steps are in AGENTS.md; it needs Rob's own Chrome), then paste its video ID into `NOTHING_TRAILER_ID` in `site/build.ts`.
