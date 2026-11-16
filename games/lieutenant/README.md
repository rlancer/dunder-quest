# Just One More JOIN

A Dunder Quest game that teaches SQL. Lieutenant Colonna, Homicide, looks like he slept in his raincoat and usually knows who did it inside five minutes. Knowing isn't proof. The department has a new machine in Records, Doris has typed every guest book, gate log and telephone bill in the city into it, and it only takes questions in SQL.

**Every case shows you the crime first.** A cold open, letterboxed, shows who did it and how they covered it, before the Lieutenant has arrived. So the puzzle is never who. It's which record gives them away, and how to ask for it. The player walks the Lieutenant round the room; each record he finds goes into his notebook as a table. Talking to the suspect opens the notebook on one question for Records, and the player spells the query from chips, a clause to a line: `SELECT`, `FROM`, `JOIN`, `WHERE`, `GROUP BY`, `HAVING`, `ORDER BY`, `LIMIT`. Under the chips is the SQL exactly as it will be read to Doris, and that text is all that runs. The answer comes back on green-bar paper: the rows, or the database's own error, and what the Lieutenant makes of it. Before the last question he says goodnight, heads for the door, and turns round.

A question is settled when the query returns what it asked for: the same columns and rows as the solution on file (and the same order, from an `ORDER BY`, where the question asks for one). Any SQL that gets there counts.

It's an homage to a certain rumpled television detective and the mysteries that showed you the murder first: the format, the tone and the tropes, with invented names, cases, lines, art and music (see AGENTS.md for the rules).

The game plays at **dunderquest.com/lieutenant/play/**, and its page is at /lieutenant/. It's its own Godot 4.7 project, beside `../dunder-quest/`, `../flatmates/`, `../curb/` and `../prince/`.

## The cast

Lieutenant Colonna (the hero: a raincoat, a cigar he never lights, a wife he quotes and nobody sees), Null (his basset hound, who never got a name), Doris (Records Division, on the telephone: she reads back exactly what the machine says), and tonight's suspects: Sterling Voss (developer), Dinah Bannister (tennis champion), Hugo Brandt (astrologer), Dr. Miriam Sloane (psychiatrist) and Augusta Harrow (hotelier). Opal Fenwick, 81, is in every case's records and has done nothing.

## The prologue

A first run (Start with no save, or New game) opens with a short prologue, `ui/intro.gd`, before case 1; the title's Story button replays it. It tells the story and answers "what is SQL?" for someone who has never seen any. Nine pages, each a line of story with the database word for it underneath:

1. Los Angeles, 1974: every night somebody thinks of everything.
2. The five suspects come out of the dark, one at a time: the alibi, the witnesses, the one detail nobody would check.
3. But the town writes everything down (a database is where records are kept so they can be asked about).
4. Doris has typed it into tables; a marker walks down the guest book a row at a time, then across it a column at a time (each row is one record, each column one fact).
5. The machine only understands one language. A query is typed, `SELECT name, arrived FROM guests WHERE arrived > '21:00'`, and the three rows it returns light up (that language is SQL; a question in it is a query).
6. Lieutenant Colonna walks in with his dog.
7. Knowing isn't proof (`SELECT` what to read back, `FROM` which table, `WHERE` which rows).
8. He's almost out of the door, and turns round (`JOIN` puts two tables side by side).
9. The five case files land on the desk.

The table on screen is case 1's real guest book and the query is run by the game's own engine, so the lit rows are the ones SQLite returns. The right arrow (or any key, or a tap) turns the page, the left arrow (or a tap on the left quarter of the screen) turns back one to watch it again, Skip or Esc goes straight on, and left alone it plays itself. Keep the lines short: one or two sentences a page. The bot turns every page, goes back to the first and forward again, and checks the query. It has no voice-over yet (Prince of Versions' prologue is read aloud; this one was built in a session with no key for the voice generator).

## The cases

Act I, built:

| # | Case | Place | SQL | What gives them away |
|---|---|---|---|---|
| 1 | Select Company | The Hartwell Gala, Bel Air | `SELECT` · `FROM` · `WHERE` | The guest book says he arrived at 8:05. The coat check says his coat arrived at 9:50 |
| 2 | Out of Order | The Palisades Racquet Club | `LIKE` · `AND` · `OR` · `ORDER BY` · `LIMIT` | A black sedan, plate beginning 4K. Only one was out of the lot at twenty to ten |
| 3 | Inner Circle | The House of Brandt, Malibu | `JOIN ... ON` | He rang his answering service "from home". The call came from his car telephone |
| 4 | Group Therapy | Dr. Sloane's Office, Beverly Hills | `COUNT` · `GROUP BY` · `HAVING` | Six prescriptions at six drugstores, and five of them picked up by the doctor |
| 5 | Left for Dead | The Harrow Grand Hotel | `LEFT JOIN` · `IS NULL` | Ten chairs, nine dinners. The one with no ticket is hers, and her key rode to the penthouse |

Each case is three or four questions. Each new clause arrives on a lesson card (a query, what it returns, and what that means); a wrong query gets the Lieutenant's reading of what came back (too many rows, a column missing, no `ORDER BY`), and the chips that are classic mistakes (`= NULL`, `AND` where `OR` was meant, a `COUNT(*)` in `WHERE`, `LEFT JOIN` the wrong way round, the wrong `ON`) have a note of their own.

Act II, designed and not built: subqueries (everyone who paid more than the average), `WITH` (name a query, then ask it something), window functions (who used the key card just before the victim), `UPDATE` and `DELETE` (what a ledger looks like after somebody forgets the `WHERE`), and transactions (the transfer that was started and never committed).

## It's real SQL

Never teach anything that isn't real SQL. The checks hold the game to that:

- `sql/sql.gd` is a SQL engine in GDScript: a lexer, a parser and an executor for the slice of `SELECT` the cases use, with SQLite's semantics (NULL and three-valued logic, its comparison affinity, its `LIKE`, its column names, its order of name resolution, so the first error is the one SQLite reports, in SQLite's words).
- `tests/replay.gd` runs every question's solution, every lesson card and every query the chips on each page can spell (up to three `SELECT` chips and two `WHERE` chips: 15,769 queries) through that engine, and checks the script against it: each solution is accepted and returns rows, and each note is tied to a chip that exists and is wrong.
- `tests/verify_sql.ts` loads the same tables into the real SQLite (bun's built-in one) and runs the same SQL text. It demands the same columns, the same rows (in order where there's an `ORDER BY`, give or take ties) and the same error text.
- One rule is stricter than SQLite on purpose: a bare column beside an aggregate has to be in `GROUP BY`. SQLite would answer with a value from some row; PostgreSQL and most others refuse, and the game refuses in PostgreSQL's words and says so. `verify_sql.ts` checks that SQLite really does accept each of those.
- `tests/bot.tscn` turns every page of the prologue, then plays every case with the real input actions: looks at the records, talks to the suspect, calls Records with a blank page and with the solution spoiled by one wrong chip (the case must not move on), then writes the solution the way a player does, by clicking the chips and the Call Records button on one question and with the arrow keys, Space and Enter on the next (it must move on).

- `tests/layout.tscn` puts up every screen the game has (every line of dialogue with the speaker at either wall, every notebook page blank, solved and with every chip picked at once, every printout those give, every card, caption and slip, the case files in every state, each page of the prologue, by keys and by touch) and fails if any text reaches past the panel it's in, runs over other text, or doesn't fit. All text is drawn through `ui/fit.gd`, inside the panel it belongs to (`Fit.begin(rect, name)` ... `Fit.end()`), which is what lets the test see it; the bot runs the same check on the screens it passes through. A new line that's too long for its box fails here, with the words and by how many pixels.

```sh
godot --headless --path . --import
godot --headless --path . --script res://tests/replay.gd    # REPLAY result=ok: every solution and every spellable query
bun tests/verify_sql.ts                                     # SQL result=ok: SQLite agrees on all of them
godot --headless --path . res://tests/bot.tscn              # BOT result=ok: the prologue and all five cases
godot --headless --path . res://tests/layout.tscn           # LAYOUT result=ok: no text outside its panel on any screen
godot --path . res://tests/shots.tscn -- case=3             # screenshots into tests/shots/ (needs a window; xvfb-run works)
bash tests/check.sh                                         # all four, as CI runs them
```

## How it's built

- `data/cases.json`: everything. The cast, each case's cold open, its tables, the props that put a table in the notebook, its questions (the suspect's claim, the question, the chips on the page, the solution, the notes for particular wrong chips, what's said when it's right), its ending, the lesson cards and the stock lines.
- `sql/`: `sql.gd` is the engine; `query.gd` turns the chips picked on a page into SQL text; `judge.gd` compares what came back with what the solution returns and picks the Lieutenant's remark.
- `world/case_scene.gd`: one script builds every case from that data: the cold open, the title card, the arrival, walking and looking, the questions, the false exit, the freeze frame. `world/person.gd` is anyone standing in a room, `world/dog.gd` is Null.
- `ui/fit.gd` draws every piece of text and knows which panel it's meant to stay inside. `ui/notebook.gd` is the notebook and the printout, `ui/hud.gd` the bubbles, captions and cards, `ui/intro.gd` the prologue, `ui/files.gd` the case files, `ui/title.gd` the title.
- Sharp text: the window stretches in `canvas_items` mode, so the game is laid out at 480×270 and text is drawn at the window's own resolution. The cast and the rooms are painted at two texels to a room pixel and drawn through `world/sharp_pixels.gdshader` (the same shader as Prince of Versions), so they stay even at any window scale.

## Art and sound

All of it is made by scripts in `tools/`, with no key and no network:

- `tools/paint.py` paints the cast from shapes, four times larger and averaged down, lit in three tones (the way Prince of Versions paints its cast).
- `tools/scenery.py` paints the five rooms, the night street, the title's street and the desk, from shapes, lit by their lamps.
- `tools/audio.py` synthesizes the effects and the three music loops (an original minor blues for bass, vibraphone, electric piano and brushes) with numpy.
- `tools/site_art.py` copies the page's screenshots out of `tests/shots/` and paints the social card.

The other games' rooms and music are generated (`tools/scenery.py` and `tools/music.py` there go through OpenRouter). This game was built in a session without that key, so its rooms and music are stand-ins made in code; generated ones can replace them file for file. Fonts are Caprasimo (the titles), Pixelify Sans and VT323, all OFL.

## Export

`scripts/export_web.sh` (CI) exports the Web preset to `build/site/lieutenant/play/` and fits it under Cloudflare's file limit.
