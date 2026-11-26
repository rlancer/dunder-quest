# The Good, the Bad and the Greedy

A Dunder Quest game that teaches regular expressions. Backslash Ridge is a peaceable little town where every last soul is named Hobson, which kept the stationery simple until Dot Starr rode in and took the bank. The Governor sent the only sheriff he had left, Reg Exley, and a deputy, the Lazy Kid, who never does more than he has to. Nobody in Backslash Ridge shoots anybody. The law is a wanted poster, and a poster catches exactly what's written on it.

**A wanted poster is a pattern.** Every puzzle is a line-up of names (or telegrams, ledgers, witness statements) marked CATCH or FREE. The player writes the poster by putting chips down, `H` `.` `nk`, and the lines light up as they go, showing what the pattern matches so far. Then they draw. Each line gets its verdict, and the Kid says what went wrong with the first one that did: who walked free, who got arrested for nothing, or which piece of the line the judge wanted instead. The player never types; the chips are the regex, and the text on the poster is all that runs.

A poster is scored by draws (fewer is better; that's the leaderboard) and each one written in the fewest chips possible earns a star.

It's a comic western: a spoof of the spaghetti western and of the western comedies that send the whole genre up, with invented names, town, lines, art and music (see AGENTS.md for the rules). The band that plays the score is standing in the desert in the first shot, and nobody is sure who's paying them.

The game plays at **dunderquest.com/greedy/play/**, and its page is at /greedy/. It's its own Godot 4.7 project, beside the other games in `games/`.

## The cast

Sheriff Reg Exley (the hero: the calmest man in the territory), the Lazy Kid (his deputy, who teaches: fastest pattern in the West, when he can be bothered), Dot Starr (the villain: dot, as in anything at all; star, as in as much of it as she pleases), Mayor Hobson (flustered, hopeful), Gibber Hobson (a prospector who talks in authentic frontier regex; his lines are real patterns, and the last one matches what he means) and Big Backtrack (Dot's muscle, who tries every way, then goes back and tries every other way).

Every line is voiced: the cast, the narrator, the Kid reading each lesson card, and the brief for each poster.

## The prologue

A first run opens with a prologue, `ui/intro.gd`, before job 1; the title's Story button replays it. It's read aloud. Twelve pages set up the town and answer "what is a regular expression?" for someone who has never seen one, each with the word for it underneath: a line of text is a string; a poster catches exactly what's written on it; `Slim` hauls in every Slim in the county, Slimy Pete the preacher included (a pattern matches anywhere it fits); a dot is any one character and a star is as many as you like; and that is all a regular expression is, a wanted poster for text. The posters on screen are written chip by chip and run by the game's own engine, so the lit lines are the real matches. Any key or a tap turns the page, left goes back one, Skip or Esc goes straight on, and left alone it plays itself.

## The jobs

Act I, built:

| # | Job | Place | Regex | Posters |
|---|---|---|---|---|
| 1 | A Town Called Hobson | Main street | Plain letters · `.` · `[ao]` · `\d` | `Slim` · `H.nk` · `H[ao]nk` · `\d` |
| 2 | The Toll Gate | A toll gate in open desert | `^` · `$` · `\b` | `^DOT` · `NOON$` · `^....$` · `\bKid\b` |
| 3 | Beans | The gang's campfire | `+` · `*` · `?` · `{3}` | `pf+t` · `pf*t` · `salo?on` · `\$\d{3}$` |
| 4 | The Greedy and the Lazy | The saloon | `.*` and `.*?` · `( )` · `\|` | `".*"` · `".*?"` · `\$(\d+)` · `WANTED: (DEAD\|ALIVE)` |
| 5 | Showdown at Backslash Ridge | The decoy town | All of it, and `\1` | `\d{2}` · `(\w+) \1` · `^D.* Starr$` |

Each new piece arrives on a lesson card (the Kid's notes: what it means, and a small poster lighting up what it catches). Job 4's posters are judged on what they take, not just whether they match: the same line, greedy and lazy, gives two different answers. Job 5 ends on Big Backtrack and `(a+)+$`, with the number of ways he has to try doubling for every `a` on the line: catastrophic backtracking, the thing that has taken real websites down.

Act II, designed and not built: lookahead and lookbehind (the man standing next to the man you want), named groups, flags (`i`, `g`, `m`), replacing with `$1`, Unicode classes, and a job on the regex you shouldn't write (an email address; HTML).

## It's real regex

Never teach anything that isn't real regex. The checks hold the game to that:

- `regex/rx.gd` turns the chips into a pattern and runs it with Godot's `RegEx` (PCRE2). Before that it checks the chips against a grammar as strict as JavaScript's (with the `u` flag), so nothing PCRE2 would let slide gets through: a counter with nothing to count, a `)` with no `(`. `regex/judge.gd` reads each line of the line-up against the pattern: matched or not, and what was taken.
- `tests/replay.gd` runs every poster's solution (it must win), every pattern shorter than it that the chips can spell (none may win, which is what makes par the true minimum: about 88,000 patterns), and a set of probes, and writes them all to `tests/out/patterns.json`.
- `tests/verify_regex.ts` runs the same patterns over the same lines in JavaScript's `RegExp` (bun's) and demands the same answer: the same match, at the same place, with the same groups, and a refusal wherever the game refuses.
- One rule is the game's alone: `\1` before group 1 has been closed is refused. JavaScript accepts it (it matches nothing), which teaches nobody anything; the refusal says why, and the verifier checks that JavaScript really does accept each of those.
- `tests/bot.tscn` plays the title, every page of the prologue and every job: on each poster it draws on a pattern that misses (the Kid must say something about it), tries one the engine refuses (it must cost no draw), then writes the solution and draws. Every job must end with a star for every poster.
- `tests/layout.tscn` puts up every screen the game has (the title and the job board in every state, each page of the prologue, every line of talk, every lesson card, every poster's desk blank, full, missed and solved, with everything the Kid can say about every line, every caught banner and end card, by keys and by touch) and fails if any text reaches past the panel it's in. All text is drawn through `ui/fit.gd` (`Fit.text`, inside `Fit.begin(rect, name)` ... `Fit.end()`), never with a bare `draw_string`.

```
bash tests/check.sh        # all four; CI runs it
```

## Making things

Run from this folder; Python comes from mise (`mise exec -- python ...`).

| Tool | Makes |
|---|---|
| `tools/scenery.py` | The backdrops and the cast's portraits, generated through OpenRouter (the portraits are one set: look at them together) |
| `tools/music.py` | The four music cues, generated; loop them with `../dunder-quest/tools/make_loops.py` |
| `tools/sfx.py` | The sound effects, synthesized with numpy |
| `tools/voice.py` | Every spoken line, with ElevenLabs' v4 through OpenRouter. A clip is named for who says it and what they say, so after editing a line, run it again and only that clip is made. A line's `say` gives the words to read where the text is regex, and may carry directions in square brackets (`[whispering]`), which are acted, not read |
| `tools/site_art.py` | The site's screenshots and social card, from `tests/shots/` (`godot --path . res://tests/shots.tscn`, which needs a window) |

All the words are in `data/jobs.json`: the cast, the jobs, each poster's brief, chips, solution, hint and line-up, the lesson cards and everything the Kid says about a miss.

It has no trailer, brand-kit page or launch posts yet.
