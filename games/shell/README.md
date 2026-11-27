# Yes, Shell!

A Dunder Quest game that teaches the Unix shell. The Standard Inn has sold beef sandwiches under the train tracks for forty years, and for all forty of them the orders were shouted. Then Ash Bourne came home, out of the finest kitchen in the country, with a roll of green tape, a marker and a system: every station does one thing, does it well, and passes it down the line. Which is also how the shell works.

**Every station is a command, and the pass is a pipe.** Every puzzle is a ticket: the lines that have to reach the pass, in order. The kitchen's files are on the rail beside it. The player writes one line of shell by putting chips down, `grep` `beef` `orders.txt` `|` `head` `-n 2`, and the line runs as they go: the middle of the screen shows what it prints right now, or the shell's own error, word for word. Then they fire. Shell, who runs the pass, says what was wrong with a line that ran and sent the wrong thing: too much, too little, the right plates in the wrong order. The player never types; the chips are the command, and the text on the line is all that runs.

A ticket is scored by fires (fewer is better; that's the leaderboard) and each one sent with the fewest chips possible earns a star.

It's a spoof of the frantic restaurant-kitchen drama: the inherited sandwich shop, the chef home from fine dining, the system nobody asked for, the ticket machine that will not stop, the critic at table one. The names, the restaurant, the lines, the art and the music are invented (see AGENTS.md for the rules).

The game plays at **dunderquest.com/shell/play/**, and its page is at /shell/. It's its own Godot 4.7 project, beside the other games in `games/`.

## The cast

Ash Bourne (the hero, new chef: says little, and most of it is "Yes, Shell"), Michelle "Shell" Tee (who runs the pass and teaches; she'd been typing the orders up behind Uncle Awk's back), Uncle Awk (front of house, thirty years with a pencil and his voice), Dev Null (the dish pit: what you hand him, you never see again) and Regina Root (the critic from the Lakeside Ledger: what Root asks for, Root gets).

## The prologue

A first run opens with a prologue, `ui/intro.gd`, before shift 1; the title's Story button replays it. Eleven pages set up the kitchen and answer "what is the shell?" for someone who has never opened a terminal, each with the word for it underneath: a command is a small program that does one job; a command, then the file to work on; `grep beef` keeps the lines that say beef; the pipe hands one command's output to the next; and that is all the shell is. The lines on screen type themselves chip by chip and are run by the game's own shell, so what they print is real. Any key or a tap turns the page, left goes back one, Skip or Esc goes straight on, and left alone it plays itself.

## The shifts

Act I, built:

| # | Shift | Place | Shell | Tickets |
|---|---|---|---|---|
| 1 | Family Meal | The kitchen | Commands, files and options | `ls` · `cat orders.txt` · `head -n 3 orders.txt` · `wc -l orders.txt` |
| 2 | The Rail | The pass | `grep`, `-v`, `-i`, `-c` | `grep beef orders.txt` · `grep -v melt orders.txt` · `grep -i hot notes.txt` · `grep -c beef orders.txt` |
| 3 | The Pass | The pass | The pipe | `ls \| wc -l` · `grep beef orders.txt \| head -n 2` · `head -n 5 menu.txt \| tail -n 1` · `grep melt orders.txt \| grep -v turkey \| wc -l` |
| 4 | Mise en Place | The walk-in | `sort`, `-n`, `-r`, `uniq`, `-c` | `sort -n tabs.txt` · `sort -n -r tabs.txt` · `sort sold.txt \| uniq` · `sort sold.txt \| uniq -c` |
| 5 | The Critic | The dining room | `cut`, `tr`, `>`, and all of it | `cut -d, -f2 tickets.csv` · `cat specials.txt \| tr a-z A-Z` · `grep 86 notes.txt > board.txt` · `cut -d, -f2 flood.csv \| sort \| uniq -c \| sort -rn \| head -n 1` |

Each new command arrives on a lesson card (Shell's notes: what it means, and a line run in a terminal). The catches are taught as catches: `sort` puts 100 before 12 until it's told they're numbers, `uniq` only notices a repeat that's right behind the one before, `tr` never opens a file. The last ticket is the line people reach for every week to find the most common thing in a file.

Act II, designed and not built: `find` and `xargs` (the walk-in gets deep), `sed` (the menu changes), `awk` (Uncle Awk finally does it his way, in one line nobody can read), `>>` and `2>` (the complaints book), `$variables` and `for` loops (prep lists), exit codes with `&&` and `||`, and a shift on what not to run (`rm -rf`, and why Dev Null is called that).

## It's the real shell

Never teach anything that isn't real shell. The checks hold the game to that:

- `sh/shell.gd` is a shell in GDScript: pipes, `>` and `<`, and `ls`, `cat`, `head`, `tail`, `wc`, `grep`, `sort`, `uniq`, `cut` and `tr` with the options the game uses, answering the way bash and GNU coreutils do in the C locale, down to the width `wc` pads its columns to and the wording of every error. `sh/judge.gd` holds what a line sent against its ticket.
- `tests/replay.gd` runs every ticket's solution (it must win, and send exactly the ticket's `want`), every row of chips shorter than it (none may win, which is what makes par the true minimum: about 38,000 lines), and a set of probes no table can spell, and writes what the game made of them to `tests/out/lines.json`.
- `tests/verify_shell.ts` runs the same lines (about 7,000) through the real bash, in a folder holding the same files, and demands the same output, the same files written, and the same error in the same words. Where two commands on one line both fail, bash only has to complain: they talk over each other.
- Three things are the game's own, and say so on screen rather than pretending to be bash: a first command with no file would wait on the keyboard for ever, so the game refuses it as "standing by" (the verifier checks that bash, handed nothing, runs it without complaint); a real option or pattern the engine doesn't model is refused as "not on the cards", never run wrongly; and so is a line that reads a file it is also writing, which in a real shell depends on which command gets there first.
- Every ticket's `want` in `data/shifts.json`, and what every card's demo prints, was taken from bash, not from the game.
- `tests/bot.tscn` plays the title, every page of the prologue and every shift: on each ticket it fires a line that runs and misses (Shell must say something about it), tries one the shell refuses (it must cost no fire), then writes the solution and fires. Every shift must end with a star for every ticket.
- `tests/layout.tscn` puts up every screen the game has (the title and the rota in every state, each page of the prologue, every line of talk, every lesson card, every ticket's pass blank, full and solved, every line one or two chips can spell and so everything the shell can say about them, everything Shell can say about a miss, every banner and end card, by keys and by touch) and fails if any text reaches past the panel it's in. All text is drawn through `ui/fit.gd` (`Fit.text`, inside `Fit.begin(rect, name)` ... `Fit.end()`), never with a bare `draw_string`. A line of output too long for the pass carries on underneath, as it would in a terminal.

```
bash tests/check.sh        # all four; CI runs it
```

## Making things

Run from this folder; Python comes from mise (`mise exec -- python ...`).

| Tool | Makes |
|---|---|
| `tools/scenery.py` | The six backdrops and the cast's portraits, generated through OpenRouter (the portraits are one set: look at them together) |
| `tools/music.py` | The five music cues, generated; loop them with `../dunder-quest/tools/make_loops.py` |
| `tools/voice.py` | Every spoken line, with ElevenLabs' v4 through OpenRouter. A clip is named for who says it and what they say, so after editing a line, run it again and only that clip is made. A line's `say` spells a command the way it's said ("W C dash L"), and may carry directions in square brackets (`[shouting]`), which are acted, not read |
| `tools/sfx.py` | The sound effects, synthesized with numpy |
| `tools/site_art.py` | The site's screenshots and social card, from `tests/shots/` (`godot --path . res://tests/shots.tscn`, which needs a window) |
| `tools/trailer_audio.py`, `trailer/capture.sh`, `tools/make_trailer.py` | The trailer: its cue, the bot's captures, and the cut (see [trailer/README.md](trailer/README.md)) |

Every line is voiced: the cast, the narrator, Shell reading each lesson card, and the brief for each ticket. The cast are spoofs of the kitchen drama's character types (the worn-out chef in the blue apron, the sharp one on the pass, the shouting relative out front), never drawn or voiced to be the actors.

All the words are in `data/shifts.json` (and the prologue's in `ui/intro.gd`): the cast, the kitchen's files, the shifts, each ticket's brief, chips, solution, hint and `want`, the lesson cards, the glossary, and everything Shell says about a miss or an error.

It has no brand-kit page or launch posts yet.
