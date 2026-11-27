# A Game About Nothing

A Dunder Quest game that teaches HTTP and REST APIs. Four friends on the Upper West Side, one coffee shop, and five counters in New York that run on rules nobody explains: a diner, a broth stand with a line round the block, a restaurant, the post office and a television network. Every one of them is a web server, and every errand is a request.

**Every counter is an API, and every errand is a request.** Each scene has somebody who wants something done, and the status it should come back with (`201 Created`, `204 No Content`, `304 Not Modified`). The player makes a request slip from cards (a method, a path, headers, a body: `POST` `/orders` `Content-Type: application/json` `{"item":"toast","table":4}`) and sends it. The counter answers exactly as a web server would: the status line, the headers that matter and the body, or a 4xx with the reason in the body. The right-hand panel turns between the counter's board (the data on it, each item at its own path, with its ETag where the counter keeps them) and the response. The player never types; the cards are the request, and what's on the slip is all that's sent.

Every take starts from the same counter, so a miss changes nothing. A scene is scored by takes (fewer is better; that's the leaderboard) and each one done with the fewest cards possible earns a star.

It's a spoof of the 1990s New York sitcom: the observational comic, the neurotic friend, the sardonic ex, the neighbour who never knocks, the strict vendor with the line round the block, the smug mail carrier, the network executive who never laughs, the slap-bass sting between scenes, a show about nothing. The names, the counters, the lines, the art and the music are invented (see AGENTS.md for the rules).

The game plays at **dunderquest.com/nothing/play/**, and its page is at /nothing/. It's its own Godot 4.7 project, beside the other games in `games/`.

## The cast

Stu Lerner (a stand-up comedian who notices things, and teaches every card in a set at the Rimshot), Lenny Kaplan (his oldest friend, who books every table twice to be safe), Dana Wexler (his ex, still his friend, mostly out of spite), Zelnick (from across the hall, never knocks, wants to know all his options), Kasimir (runs the broth counter: get one rule wrong and he says "Next!"), Vernon (the post office: every parcel has a version) and Mr. Pratt (runs the network, keeps the pilots behind a login, has never laughed).

## The prologue

A first run opens with a prologue, `ui/intro.gd`, before episode 1; the title's Story button replays it. Ten pages meet the gang and answer "what is HTTP?" for someone who has never looked under a website, each with the word for it underneath: a request is a method and a path, a response is a status code, headers and a body, and POST makes something new. The requests on screen write themselves out and are answered by the game's own counters, so what comes back is real. Any key or a tap turns the page, left goes back one, Skip or Esc goes straight on, and left alone it plays itself.

## The episodes

Act I, built:

| # | Episode | Counter | HTTP | Scenes |
|---|---|---|---|---|
| 1 | The Order | Vic's Diner | Requests: GET and POST | `GET /menu` · `GET /orders/7` · `POST /orders` with a JSON body (201, Location) · `OPTIONS /orders/7` (204, Allow) |
| 2 | The Counter | The broth counter | Headers and JSON bodies | `GET /broths` (and why `Accept: text/html` is 406) · `Content-Type` (415) · missing and extra fields (400) · JSON that isn't (400) |
| 3 | The Duplicate | The Jade Lantern | PUT, PATCH and DELETE | `PUT` the whole booking · `PATCH` one field · `DELETE` the spare (204) · `HEAD` |
| 4 | The Mail | The post office | Versions: ETags and If-Match | `If-None-Match` (304) · `POST` that's `202 Accepted` · `PATCH` with `If-Match` (412, 428) · `DELETE` with `If-Match` |
| 5 | The Table Read | The network | Tokens: 401 and 403 | `Authorization: Bearer` (401) · a token that can read but not write (403) · `PATCH` with a token, a version and a body, twice |

Each new idea arrives in one of Stu's sets (`data/episodes.json`, "cards"): what it means, as a stand-up bit, and a request with what a counter answers it. The catches are taught as catches: POST twice and you've booked two tables, PUT wants every field, a 2xx can still be the wrong thing, 401 and 403 are not the same.

Act II, designed and not built: query strings and pagination (the garage, level by level), `Location` and following a `201` (Zelnick's scheme), redirects (`301`, `302`, `307`: the restaurant moved), CORS (the network's lawyers), `429 Too Many Requests` and `Retry-After` (Lenny calls the radio station), and caching with `Cache-Control` (the coffee shop's day-old muffins).

## It's real HTTP

Never teach anything that isn't real HTTP. The checks hold the game to that:

- `http/http.gd` is the game's counters: each a little REST API of documents and collections, answering the way a well-behaved server does under RFC 9110, from routing (404) and auth (401 with `WWW-Authenticate`, 403) through methods (405 with `Allow`, OPTIONS), content negotiation (406, 415), bodies (400), conditional requests (304, 412, 428) to the answer itself (200, 201 with `Location`, 202, 204, HEAD with no body). `http/wire.gd` writes JSON the way `JSON.stringify` does and reads it as strictly as `JSON.parse` (Godot's own reader lets a trailing comma through). `http/judge.gd` holds a response up against what the scene wants: the status, and where it says so, the method, the path and the data left on the counter.
- `tests/replay.gd` sends every slip every scene's cards can make (none with fewer cards than the solution may win, which is what makes par the true minimum), every lesson card's demo, and a set of probes at every counter, and writes what the game made of them to `tests/out/requests.json`.
- `tests/verify_http.ts` serves the same counters, written again in TypeScript (`http/counter.ts`), from a real HTTP server (`Bun.serve`), sends it every one of those requests (about 450) with real `fetch` over a real socket, and demands the same status and reason phrase (the ones the server's HTTP stack puts on the wire), the same headers, the same body to the character and the same data left behind. It also holds every response to the rules the game teaches: a 201 has a `Location`, a 405 and an OPTIONS an `Allow`, a 401 a `WWW-Authenticate`, a 304 its `ETag`; a 204, a 304 and any answer to HEAD have no body; HEAD gets GET's status and headers.
- The response shows the headers that matter (`Content-Type`, `Location`, `ETag`, `Allow`, `WWW-Authenticate`), not `Date` and `Content-Length`, and the request shows a `Host` line, as every HTTP/1.1 request has. One rule is the game's own and says so: only POST, PUT and PATCH carry a body (`fetch` won't even send a GET or a HEAD with one).
- `tests/bot.tscn` plays the title, every page of the prologue and every episode: on each scene it sends a slip the counter answers but that isn't what the scene wants (Stu must say something about it), tries one with no method (it must cost no take), then makes the solution and sends it. Every episode must end with a star for every scene.
- `tests/layout.tscn` puts up every screen the game has (the title and the TV guide in every state, each page of the prologue, every line of talk, every one of Stu's sets, every slip every scene's cards can make and what comes back, on the response and the board, everything Stu can say, every banner and end card, by keys and by touch) and fails if any text reaches past the panel it's in. All text is drawn through `ui/fit.gd` (`Fit.text`, inside `Fit.begin(rect, name)` ... `Fit.end()`), never with a bare `draw_string`.

```
bash tests/check.sh        # all four; CI runs it
```

## Making things

Run from this folder; Python comes from mise (`mise exec -- python ...`).

| Tool | Makes |
|---|---|
| `tools/scenery.py` | The backdrops and the cast's portraits, generated through OpenRouter (the portraits are one set: look at them together) |
| `tools/music.py` | The music cues, with ElevenLabs Music (`music_v2_5`, through ElevenLabs' own API: it needs `ELEVENLABS_API_KEY` and a paid ElevenLabs plan); smooth the seams with `../dunder-quest/tools/make_loops.py` |
| `tools/voice.py` | Every spoken line, with ElevenLabs' v4 through OpenRouter. A clip is named for who says it and what they say, so after editing a line, run it again and only that clip is made. A line's `say` may carry directions in square brackets (`[panicking]`), which are acted, not read |
| `tools/sfx.py` | The sound effects, synthesized with numpy, the slap-bass sting included |
| `tools/site_art.py` | The site's screenshots and social card, from `tests/shots/` (`godot --path . res://tests/shots.tscn`, which needs a window; in a cloud session, under `xvfb-run`) |
| `tools/trailer_audio.py`, `tools/make_trailer.py` | The trailer's music cue (generated) and the trailer itself, from `trailer/capture.sh`'s captures of `tests/trailer_run.tscn` |

Every line is voiced: the cast, the narrator, Stu reading each of his sets, and the brief for each scene. The cast are sitcom types with invented names, never drawn or voiced to be any actor.

All the words are in `data/episodes.json` (and the prologue's in `ui/intro.gd`): the cast, the counters, the episodes, each scene's brief, data, cards, solution, goal and hint, Stu's sets, the glossary, and everything Stu says about a miss.

Its trailer is cut by `tools/make_trailer.py` from captures of the bot, to a generated cue (`tools/trailer_audio.py`); the steps are in [trailer/README.md](trailer/README.md). It has no brand-kit page or launch posts yet.
