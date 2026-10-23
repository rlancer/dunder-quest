# Dunder Quest — Trailer Plan

> The original research and plan. v1 is built; see [README.md](README.md) for how to rebuild it and what's next.

Everything needed to cut a motion-graphics trailer for **__dunder_quest__**, a pixel-art platformer where a pebble heads for the kiln and learns Python by bumping blocks and dueling wizards.

---

## 1. The pitch the trailer has to land

One line: **"A pixel platformer where Python is the magic."**

The hook is that **code changes the world**. `span(n)` returns the gap and the bridge builds. A `range()` raises the kiln lift. You answer a wizard by head-bumping the block marked with the right output. No other platformer does this, so it should be on screen within the first 10 seconds.

Supporting beats, in rising order of interest:
1. Run, jump, stomp copperlings, collect emberseeds (sets the genre).
2. Lore scrolls teach a concept (`row[0]`, `row[-1]`, slices).
3. Bump-block puzzles where the code drives the level (gates, lift, bridge).
4. Wizard duels: read the code, bump A/B/C/D, dodge hex strikes and ward waves.
5. Six biomes, from Amber Hollow up to Crucible Crown.

**Platform priority:** YouTube first (plus Shorts), with dunderquest.com embedding the YouTube video. Steam can come later. Section 8 covers what changes if you add it, and the main cut already follows Steam's rules, so nothing needs re-editing.

## 2. Trailer craft rules (research summary)

- **Gameplay first.** Show play within the first few seconds. People browsing decide in under 10 seconds, and on YouTube the first 15 s decide audience retention. ([Steamworks][steam], [Derek Lieu via GameDiscoverCo][gdco])
- **Genre → Hook → Content.** Establish "it's a platformer" fast, then show the hook, then show variety. Put the hook in the first 10–15 s and no later than the halfway point. ([GameDiscoverCo][gdco], [PC Gamer][pcg])
- **"Tell, Show, Repeat."** A short title card states an idea, then gameplay proves it right away. This is where the motion graphics go. ([presskit.gg][presskit])
- **Escalate.** Order shots from simple to complex: plain jump, then a bump puzzle, then the bridge building, then a wizard duel. Save the wildest shot for last. ([PC Gamer][pcg])
- **Audio first.** Pick or make the music before editing, then cut to it. The music sets the structure. ([GDC / Derek Lieu][gdc])
- **Works muted.** YouTube home-feed previews and embeds often autoplay with the sound off, and so do Shorts scrolled past quickly. Text cards and visuals have to carry the message. ([Steamworks][steam])
- **Logo at the end.** Skip a long logo intro. A 1-second wordmark flash up front is fine; the full lockup belongs on the end card.
- **Front-load the first 6 seconds.** The YouTube feed preview plays the opening, and Steam later builds its uneditable 6-second microtrailer from 1-second clips of your first trailer. Pack those first seconds with readable gameplay. ([Steamworks][steam])
- **Keep the HUD.** Real gameplay from the player's view with the HUD on reads as honest, and Steam requires it for the first trailer. ([Steamworks][steam])

## 3. Beat sheet (≈ 60–75 s, cut at ~120 BPM so 1 bar = 2 s)

| Time | Bars | Picture | Motion graphics |
|---|---|---|---|
| 0:00–0:04 | 2 | Cold open: pebble sprints and jumps through Amber Hollow, stomps a copperling, grabs an emberseed | none, pure gameplay (feeds the microtrailer) |
| 0:04–0:06 | 1 | Hard cut to black | `>>> import adventure` types out in VT323, cursor blinks |
| 0:06–0:12 | 3 | Fast montage of jumps across Cinder Span, Kiln Mouth and Smelter's Fork | Stage names slam in per cut, pixel-snapped |
| 0:12–0:16 | 2 | **Hook:** `span(?)` on screen, block bumped, bridge builds (`tour_bridge_short` → `tour_bridge_built`) | Card: **"Your code builds the world."** |
| 0:16–0:24 | 4 | Kiln lift rises on a `range()`, fork gates open on booleans | Code snippet animates in beside the action, the changing value highlighted |
| 0:24–0:28 | 2 | Lore scroll opens: `row[0]  # ash` | Card: **"Learn real Python."** |
| 0:28–0:40 | 6 | **Wizard duel** escalation: question panel, bump B, ward wave, hex strike, wrong answer, banish | Duel question types itself out; "✓" / "✗" stamps on the beat |
| 0:40–0:48 | 4 | Rapid cuts, one per beat: all six biomes, world map path drawing | Topic chips per cut: `lists` `dicts` `loops` `bools` `functions` `comprehensions` |
| 0:48–0:54 | 3 | Crucible Crown climb and final duel, music peaks | none, let it breathe |
| 0:54–0:58 | 2 | Pebble at the waygate, spark burst, cut to black on the downbeat | — |
| 0:58–1:05 | 3–4 | End card: title art + `__dunder_quest__` wordmark | "Play free in your browser · dunderquest.com" + platforms. Leave empty space for YouTube end-screen elements (a subscribe button and a video/link tile), which can only appear in the last 5–20 s |

The duel is the strongest shot, so it lands two-thirds of the way through.

## 4. Visual style for the motion graphics

Reuse the game's identity so cards and gameplay feel like one thing.

- **Fonts** (already in the repo, both OFL, so fine for a trailer):
  - `assets/fonts/PixelifySans.ttf`: headlines and the wordmark
  - `assets/fonts/VT323.ttf`: code, terminal prompts, labels
- **Palette** (from `tools/make_og.py`):
  - Gold `#F2B544`, the headline color
  - Parchment `#F4E4C4`, body text
  - Ember `#FF8A3D`, accents and highlights
  - Ash `#B0A9D0`, secondary text
  - Night `#15122A`, backgrounds and card fills
  - Line `#4A4F86`, panel borders
- **Code syntax colors:** keywords in ember, strings in gold, numbers in parchment, comments in ash. Use these on every code card.
- **Pixel-perfect rule:** every graphic is either built at the game's native **480×270** or scaled by a whole number. Text sizes and moves land on whole native pixels (4-px steps at 1080p). Avoid sub-pixel easing on pixel art; step positions (hold-frames / "on twos") look more authentic.
- **Motion vocabulary:** typewriter code with a blinking block cursor, hard cuts, 1–2-frame white flashes on hits, small screen shakes timed to stomps and ward waves, CRT-free (the game is clean, so keep it clean), parallax pushes using the three background layers.
- **Existing art to animate:** `assets/backgrounds/*_far|mid|near.png` are separate parallax layers, so you can build 2.5D camera moves for cards and the end card. `title_art.png` and `world_map.png` are good for the end card and the montage.

## 5. Capturing footage

### Native resolution is the key fact
The game renders at **480×270** (`project.godot`, viewport stretch, integer scale). Scale exactly **×4 → 1920×1080** or **×8 → 3840×2160** with nearest-neighbor filtering. Never scale by a fractional factor.

### Option A — Godot Movie Maker (recommended for clean, smooth shots)
Movie Maker renders frame by frame at a fixed FPS, so you never drop a frame no matter how heavy the scene is. ([Godot docs][godot-movie])

```sh
# PNG sequence + WAV: lossless, best for editing
godot --path . --write-movie captures/amber/frame.png --fixed-fps 60 res://levels/level_01.tscn

# Quick preview as AVI (MJPEG)
godot --path . --write-movie captures/amber.avi --fixed-fps 60 --quit-after 600 res://levels/level_01.tscn
```

- With `viewport` stretch, the output is the **viewport** size, so you get the true 480×270 frames. Upscale those yourself, which gives the cleanest result.
- Audio is written to the file and **you can't hear it while recording**. Mix rate must divide evenly by the FPS (44100 or 48000 both work with 30 and 60).
- Movie Maker can't be toggled at runtime, and real-time play is awkward while it runs. That's why scripted shots fit it best.

**Scripted shots:** `tests/look_tour.gd` already drives the game into exact states: holding the player at a spot, bumping blocks by label, starting duels, choosing right/wrong answers, casting `wave`/`hex`. Clone it as `tests/trailer_tour.gd` and run it under `--write-movie`. You get repeatable takes of the bridge build, the lift, the gates and every duel beat.

**For real platforming runs**, add a small input recorder: log `Input.is_action_pressed` for each action every physics frame while you play normally, save it to JSON, and replay it under Movie Maker. You play it once at your own pace and get a perfect 60 fps render you can re-render whenever you like.

**Recording hygiene:**
- Hide the touch-control overlay (`TouchControls` autoload) and any debug UI.
- Set `GameProgression.persist = false` like the tour does, so captures don't touch save data.
- Use the `movie` feature tag (`OS.has_feature("movie")`) for capture-only tweaks, like a longer camera look-ahead or turning off telemetry.
- Mute music during gameplay capture and record SFX separately so the trailer music isn't fighting the stage loops.

### Option B — OBS (for quick, real-time play)
- Run the game windowed at **1920×1080** (`--resolution 1920x1080`, integer ×4) and capture it 1:1 so there's no extra scaling.
- Record at 60 fps with a near-lossless setting (CQP/CRF ≈ 15, or a lossless codec) and remux to MP4.
- In OBS, set the source's scale filter to **Point**, not bilinear. ([OBS forum][obs])

## 6. Tools

| Job | Recommended | Alternatives |
|---|---|---|
| Edit + color + audio | **DaVinci Resolve** (free) | Premiere Pro, Shotcut |
| Motion graphics / code cards | **Motion Canvas** (TypeScript, free) | Resolve Fusion page, After Effects, Remotion |
| Pixel-art touch-ups / title frames | Aseprite | Photoshop, Krita |
| Upscaling + final encode | **ffmpeg** | Handbrake |

**Why Motion Canvas:** it's code-driven (it fits a dev's workflow and lives in git), and its built-in **Code** component animates syntax-highlighted code, typing it out and morphing between versions. That's exactly the "code changes the world" hook. Turn off image smoothing and work on a 480×270 or 1920×1080 canvas with 4-px snapping. ([Remotion vs Motion Canvas][mc-vs-remotion])

**Pixel-art gotchas in editors:**
- **Resolve:** in the Fusion page, use a Resize/Transform node set to Nearest and **untick "Only Use Filter in HiQ"**, or the preview and render won't match. ([Resolve manual][resolve-manual]) The simplest route is to pre-scale every clip to 1080p/4K with ffmpeg before importing, then do all the editing at 1:1 scale.
- **Premiere:** there's no nearest-neighbor scaling for motion, so pre-scale with ffmpeg or use the PixelPerfect plugin. ([Adobe community][adobe])

### ffmpeg recipes

```sh
# PNG sequence (480x270) → 1080p ProRes intermediate for editing
ffmpeg -framerate 60 -i captures/amber/frame%08d.png -i captures/amber/frame.wav \
  -vf "scale=iw*4:ih*4:flags=neighbor" -c:v prores_ks -profile:v 3 -c:a pcm_s16le amber_1080.mov

# 1080p master (itch.io, press, Steam later): 1080p60 H.264 + AAC, high bitrate
ffmpeg -i trailer_master.mov -c:v libx264 -preset slow -crf 14 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -ar 48000 -movflags +faststart dunder_quest_trailer_1080p.mp4

# YouTube master: upload at 4K so YouTube gives pixel art far more bitrate
ffmpeg -i trailer_master_1080.mov -vf "scale=3840:2160:flags=neighbor" \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 320k dunder_quest_trailer_4k.mp4
```

Uploading pixel art to YouTube at 4K (×8) is a well-known trick: YouTube serves 4K uploads with a better codec and much more bitrate, so the hard pixel edges survive even when people watch at 1080p.

## 7. Music and sound

- **Make the music first** and cut to it. ([GDC][gdc])
- **Generated so far** with `python tools/generate_trailer_audio.py` (Lyria 3 Pro for music, Seed Audio for SFX, through the same OpenRouter setup as the game). Output goes to `trailer/audio/` as 48 kHz WAV:

  | File | What | Notes |
  |---|---|---|
  | `cue_a.wav` | Ocarina/taiko trailer cue with a timed section map | Came out **94 s**, not the 64 s asked for. Use it as a long cut, or trim it to the beat sheet |
  | `cue_b.wav` | Chiptune + orchestra hybrid | **64 s**, the length the beat sheet expects |
  | `typing`, `cursor_blip` | Under code cards | |
  | `whoosh`, `impact`, `riser` | Title slams, the hook reveal, the final hit | |
  | `correct`, `wrong` | Duel answer stamps | |

  The prompts asked for 120 BPM and section changes at set times, but the model only follows them roughly. **Listen first**, find the real tempo and where the drops land, then shift the beat-sheet timings to the music, not the other way round. Re-run the script (e.g., `... cue_b`) for new takes; each run differs.
- Other options if neither cue works: a **licensed track** (Epidemic Sound, Artlist; check that the license covers YouTube monetization, or Content ID may claim the video), or **commission** a rework of the Amber theme.
- Before publishing, check that the generator service's terms allow promotional use. YouTube Content ID shouldn't flag original generated music, but if it does, dispute it.
- **SFX layer:** the game's own `jump`, `stomp`, `bump`, `break`, `pickup` and `goal` wavs, synced to picture and pushed a little louder than in-game, plus the trailer SFX above.
- **Mix:** the raw cues measure about −11.5 LUFS, so turn them down. Master the final mix to about **−14 LUFS** integrated with a −1 dBTP ceiling (YouTube's playback level). Keep SFX on transients and duck the music under them.

## 8. Deliverables

| Asset | Spec | Where it goes |
|---|---|---|
| **YouTube master** (primary) | 3840×2160 (×8 nearest), 60 fps, H.264 CRF ~16 + AAC 48 kHz, 60–75 s | YouTube, embedded on dunderquest.com |
| **YouTube thumbnail** | 1280×720 (or larger, 16:9) JPG/PNG under 2 MB. Unlike Steam, text is fine: a duel frame with a big `print(xs[1])` and the wordmark. Use `tools/make_og.py`'s look as a starting point | YouTube |
| **Vertical cut** | 1080×1920, 9:16, 15–30 s, key text kept in the center column away from the top/bottom UI | YouTube Shorts, TikTok, Reels ([specs][shorts]) |
| **1080p master** | 1920×1080, 60 fps, ~20 Mbps | itch.io, Steam later, press |
| **GIF / short loops** | 3–6 s, the bridge build and a duel answer | Social posts, README, press kit |
| **Press-kit stills** | Clean 1080p/4K frames from the captures | Press kit |

**YouTube upload checklist:**
- Title: `Dunder Quest – a pixel platformer that teaches Python (Trailer)`. Put "Python" in the title, since that's what people search for.
- The description's first line links to `https://dunderquest.com/`. Add tags/hashtags like `#python #indiegame #pixelart #learnpython`.
- End screen: a subscribe element plus a link (linking to your own site needs YouTube Partner Program; otherwise use a pinned comment and the description).
- Upload the 4K file even though it's the same footage as 1080p (see §6).
- Post the vertical cut as a Short that links to the main video ("related video").
- Embed it on the site's home page. The site's social card (`og/home.png`) already exists, so the share preview stays consistent.

**Steam, if you add it later:** Steam wants 1920×1080 H.264 at ≥ 5 Mbps and a thumbnail that's a **text-free frame from the video**. The first 6 s of your first trailer become the uneditable microtrailer. The 1080p master above works as is. Whether Steam is worth it: a Steam page mostly pays off through wishlists for a paid launch. For a free browser game that teaches Python, YouTube, Shorts, r/learnpython, and itch.io reach the audience more directly. Steam is worth revisiting if you add a paid desktop version.

**Vertical cut layouts** (both keep whole-number scaling):
- **Crop:** game at ×4 (1920×1080), cropped to a 1080-wide window that follows the pebble (270×270 native pixels). That fills the middle of the 1920-tall frame, with cards above and below.
- **Stack:** the full game frame at ×4 cropped to 1080×1080 above a large code card, or the whole frame at ×2 (960×540) with room to spare. "Code on top, game below" reads well on phones and plays to the hook.

Don't host the video files on Cloudflare Pages: `scripts/fit_pages_limit.py` exists because Pages caps file size. Host on YouTube and embed it.

## 9. Production checklist

The plan first called for Motion Canvas and Resolve. v1 replaced both with a Python compositor (`tools/make_trailer.py`), so every frame stays on the game's pixel grid and the whole cut rebuilds from one command.

1. [x] Pick a music cue and map its tempo and drop points (`cue_b`, 125 BPM).
2. [x] Write the shot list from the beat sheet (it lives in `edit()` in `tools/make_trailer.py`).
3. [x] Capture with Movie Maker at 60 fps as PNG + WAV at native 480×270 (`tests/trailer_capture.gd`).
4. [x] Build the motion graphics with the game's fonts and palette, then scale ×4 and ×8 nearest-neighbor.
5. [x] SFX pass and mix to −14 LUFS.
6. [x] Export the YouTube 4K master, the 1080p master and the thumbnail.
7. [ ] Listen to the mix on real speakers and headphones.
8. [ ] Watch it **muted**. If the hook doesn't come across, strengthen the cards.
9. [ ] Export the vertical Short.
10. [ ] Show it to 3–5 people who've never seen the game and ask them "what is this game?" If they don't say "platformer that teaches Python," recut the open.

## Sources

- [Steamworks — Trailers][steam]
- [Godot docs — Creating movies (Movie Maker)][godot-movie]
- [GameDiscoverCo — How to get to your game's hook quick (Derek Lieu)][gdco]
- [PC Gamer — The art of making effective game trailers][pcg]
- [GDC Vault — Trailer talk][gdc]
- [presskit.gg — Game trailers & screenshots guide][presskit]
- [Remotion — Motion Canvas comparison][mc-vs-remotion]
- [DaVinci Resolve manual — Resize node][resolve-manual]
- [Adobe community — nearest-neighbor scaling request][adobe]
- [OBS forum — nearest-neighbor source scaling][obs]
- [Streamlabs — YouTube Shorts dimensions][shorts]

[steam]: https://partner.steamgames.com/doc/store/trailer
[godot-movie]: https://docs.godotengine.org/en/latest/tutorials/animation/creating_movies.html
[gdco]: https://newsletter.gamediscover.co/p/how-to-get-to-your-games-hook-quick
[pcg]: https://www.pcgamer.com/the-art-of-making-effective-game-trailers
[gdc]: https://www.gdcvault.com/play/1025729
[presskit]: https://presskit.gg/field-guides/game-trailers-screenshots-guide
[mc-vs-remotion]: https://www.remotion.dev/docs/compare/motion-canvas
[resolve-manual]: https://www.steakunderwater.com/VFXPedia/__man/Resolve18-6/DaVinciResolve18_Manual_files/part2520.htm
[adobe]: https://community.adobe.com/t5/premiere-pro-ideas/nearest-neighbor-scaling-sampling-simple-and-vital/idi-p/13515843/page/2
[obs]: https://obsproject.com/forum/threads/nearest-neighbor-source-scaling.49675/
[shorts]: https://streamlabs.com/content-hub/post/youtube-shorts-dimensions
