# A Game About Nothing trailer

A 70-second trailer for **A Game About Nothing**: a fast run of highlights on the beat of one original music cue (a slapped bass, finger snaps, a light funk band), with the game's own voices. Stu on stage at the Rimshot noticing that the whole internet is people asking for things, while a request writes itself out and a 200 comes back; the name as the band comes in; the 404, and Lenny, who wanted the soup; then a card at a time in the game's Righteous between the moments that teach: a request slip made card by card and a `201 Created`, the broth counter answering a wrong Content-Type with `{"error":"Next!"}`, four status lines a beat each, and then the music drops to almost nothing for Stu's bit on DELETE and `204 No Content`. The band comes back for the post office's `412`, the network's PATCH with a token, a version and a body, Mr. Pratt's one laugh, and an end card with the URL and one last joke about whose fault a 4 is. It doesn't play the game through. Like the other games' trailers it's built entirely from the repo with no video editor in the loop, and its text is sharp: the game draws text at window resolution and is captured at 1920×1080, the trailer's own cards are drawn at that size too, and the pixel art is only ever scaled by whole numbers (1080p is the master, 4K is 2×).

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

The cue is generated, so running `trailer_audio.py` again gives different music (`cue_nothing:3` makes three takes to choose from; the trailer uses the second of the first three, saved as `cue_nothing.wav`). **Keep `audio/` (and `out/`) safe outside the worktree**, as AGENTS.md says, and copy it back rather than regenerating. This trailer was rendered in a cloud session, whose files are gone when it ends, so the masters, the thumbnail and the cue were sent to Rob to save into `games/nothing/trailer/` in his main checkout. A new cue has to be measured again: its tempo, its first note (`LEAD`), and where the band comes in, stops, comes back and lands its last hit (`BAND`, `SLAM`, `STOP`, `LONE`, `BACK`, `TAG`, `LAST_HIT`).

## How it's cut

`cue_nothing` measured at exactly 120 BPM, with its first note 0.18 s in. The trailer starts 0.32 s before the cue, so that note falls on 0.5 s and every beat after it on a half second; every cut is on one. The bass plays alone, with finger snaps, until a drum fill brings the band in at 8.5 s. The band takes a breath at 22.6 s and slams back on 24. Its last hit is at 38.5 s, and then there are eight seconds of almost nothing (a snap a second, and one lone hit on 40) before it comes back at 47. A bass tag follows the last downbeat at 60.5 s, and the last hit is at 63. The opening's solo bass comes back, quietly, under the end card.

| Time | Picture |
|---|---|
| 0–8.5 s | Stu at the Rimshot: *You ever notice the whole internet is just people asking for things?* while `GET /menu` writes itself out and `200 OK` comes back |
| 8.5–10.5 s | The name, as the band comes in |
| 10.5–17 s | *And it always answers with a number.* `GET /orders/9`, `404 Not Found` |
| 17–20.5 s | Lenny: *A number? I don't want a number! I want the soup!* |
| 20.5–24 s | *Every counter in New York is a web server. Every errand is an HTTP request.* |
| 24–29.5 s | `POST /orders` with its Content-Type and its body, a card at a time, sent: `201 Created`, and scene |
| 29.5–34 s | Dana: *Get one thing wrong and he says one word.* Kasimir: *Next!* |
| 34–36.5 s | The same order sent as `text/plain`: `415 Unsupported Media Type`, `{"error":"Next!"}` |
| 36.5–38.5 s | Four status lines, a beat each: `200 OK`, `201 Created`, `304 Not Modified`, `202 Accepted` |
| the nothing, 38.5–47 s | `DELETE /tables/4` goes over on the lone hit and `204 No Content` comes back, then Stu's set: *It worked, and there's nothing to say about it. My favourite status. It's a show about nothing.* |
| 47–50.5 s | Vernon: *Every parcel has a version, Lerner.* A PATCH with last week's `If-Match`: `412 Precondition Failed` |
| 50.5–56 s | Mr. Pratt: *Show me who you are, or don't come in.* The PATCH with a token, a version and a body, at a little over one and a half times speed: `200 OK` |
| 56–60.5 s | Mr. Pratt: *Ha.* Lenny: *Six episodes! Of nothing! We're geniuses!* |
| 60.5–63 s | *Real HTTP. Every request is checked against a real HTTP server.* |
| 63 s → end | The end card on the cue's last hit; *And anything starting with a 4?* *Means it's your fault.* and a rimshot |

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

- [ ] **Listening pass.** The cue's beats, its stop and its last hit were placed by measurement, the voice lines were cut at pauses found by measurement, and the frames were checked by eye, but nobody has listened to the mix: it was made in a cloud session by an agent that can't hear. Rob to watch it. Things worth an ear: whether Mr. Pratt's *Ha.* reads as a laugh, whether Lenny's *We're geniuses!* sits well over the last card, and the generated rimshot at the very end.
- [ ] **Upload** to [@dunderquest](https://www.youtube.com/@dunderquest) using the upload form on [dunderquest.com/brand/youtube/](https://dunderquest.com/brand/youtube/) (the steps are in AGENTS.md; it needs Rob's own Chrome), then paste its video ID into `NOTHING_TRAILER_ID` in `site/build.ts`.
