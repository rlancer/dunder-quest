# Prince of Versions: design

A cinematic pixel-art platformer that teaches **Git**. It's a spoof of a certain late-80s palace-run platformer and its time-rewinding sequel: a nimble prince, deadly palace rooms, a scheming vizier, a countdown, and a dagger that turns back the sands. Here the dagger is version control. Homage names only, original rooms, sprites and music, and the original series is never named in anything players see (see `AGENTS.md`).

## The one idea

**The Dagger of HEAD only takes you back to a moment you sealed.** A seal is a commit. Everything in a room that can change (torches, gates, bridges, spikes, the door) is a one-line file in a real Git repo, and the room is drawn from the working tree. Pull a lever and `gate` changes from `shut` to `open`, unstaged, until you commit it. Fall on the spikes and time stops: the only way on is the dagger, and the only places it can take you are commits.

So knowing *when* to commit is the first skill, and every later Git command is a new power of the dagger.

Three rules hold in every room, and each is real Git:

1. **Commits are the only save points.** `git reset --hard` puts the files back as they were in a commit, and the dagger puts the Prince back where he stood when he made it. Anything not committed is lost.
2. **The exit door only opens for history on `main`, committed.** The palace honours the main line and nothing else, so a level is cleared on `main` with a clean working tree (`git status` says nothing to commit).
3. **The Prince never types.** The dagger's console builds every command from buttons (phone first), but it always shows the exact command it runs (`git reset --hard 3f2a1c9`) and Git's real output. Commit messages are written from the change (`Light the first torch`).

The commit ids on screen are real. The game's Git model (`git/repo.gd`) hashes blobs, trees and commits the way Git does, with a fixed author date, so `tests/verify_git.ts` can replay every level's commands against the real `git` and demand the same ids, the same files, the same conflicts and the same output lines.

## The cast

| Name | Who | Git |
|---|---|---|
| The Prince | the hero: a nimble young man in a white tunic and red sash | you |
| Grand Vizier Rebasir | the villain, in black and purple, who rewrites history | commits sabotage into your log; later rebases and force-pushes |
| Princess Shirin | locked in the tower, she keeps the palace ledger | her commits are already in `main` (later: she's `origin`) |
| The Sultan of Main | offstage; his main line is the only history the palace honours | `main` |
| The palace guard | a hook, not a man | a real `pre-commit` hook that refuses commits straight to `main` |

The dagger is the **Dagger of HEAD**; its sand is the **Sands of HEAD**. The sand trail along the top of the screen is the commit graph, always visible: one grain per commit, branch names as banners, `HEAD` as the glint of the dagger.

## Curriculum

The order follows what a newcomer needs, and what someone building with an AI needs first: save your work, undo what broke, try things safely, combine them.

| # | Git | What the player must understand |
|---|---|---|
| 1 | `git commit -am`, `git status`, `git reset --hard HEAD` | A commit is a snapshot of every file. Uncommitted changes are gone after a hard reset. |
| 2 | `git log`, `git reset --hard <commit>` | You can go back further than the last commit, and everything after it leaves the branch. |
| 3 | `git revert`, `ORIG_HEAD` | Undo one commit with a new commit, keeping the ones after it. A reset would throw away good work. |
| 4 | `git switch -c`, `git switch`, fast-forward `git merge`, protected `main` | Branches are parallel timelines. Switching swaps the files. Uncommitted changes follow you unless they'd be overwritten. Merging a branch that's ahead just moves `main` forward. |
| 5 | three-way `git merge`, conflicts, `git add`, `git merge --abort` | Git merges what it can on its own; when two timelines changed the same line, you decide, then commit the merge. Which side is "yours" depends on where you merge from. |
| 6 | `git stash`, `git stash pop` | Put a change down, switch timelines, pick it back up. |
| 7 | `git cherry-pick` | Take one commit from another timeline without the rest. |
| 8 | `git bisect` | Find which commit sprang the trap by halving the history. |
| 9 | `git reflog` | The last resort: every place HEAD has been, even after a reset deleted the branch. |
| 10 | `git rebase`, `git push --force-with-lease`, `git pull` | Rewriting history, and why you don't rewrite the shared ledger. |

`git checkout` is taught on the lesson cards as the older spelling of `git switch` and `git restore`, since tutorials and AI assistants still use it everywhere.

## Mechanics, one per concept

| Git | In the palace |
|---|---|
| working tree | the room: every torch, gate, bridge and spike field is drawn from its file |
| modified file | a mechanism you changed since the last seal glows faintly (`git status` lists it) |
| commit | sealing the moment with the dagger: a grain joins the sand trail |
| `reset --hard` | the sands run backward, the room snaps back, the Prince rewinds to where he sealed |
| death | the Prince is impaled or falls; time freezes in sepia until you reset |
| `revert` | a new grain that undoes an old one: the Vizier's bar slides off the door, the Princess's bridge stays |
| `ORIG_HEAD` | the dagger remembers where it was before the last reset or merge |
| branch | a second timeline; its banner flies on the sand trail |
| `switch` | stepping between timelines: the room and the Prince change to that branch's last seal |
| protected `main` | the palace guard (a real `pre-commit` hook) refuses seals straight onto `main` |
| fast-forward merge | `main`'s banner slides along the trail to the branch's grain |
| merge conflict | the gate flickers between both timelines and stays shut until you choose, in the conflict markers Git really writes |
| the countdown | each room has an hourglass, as the original had its hour. It runs only while you play (never while the dagger is out); if it empties, the room starts over |

## Levels

Act I is the vertical slice in this build. Act II is designed and not built.

### Act I: The Sands of HEAD

1. **The Hall of Seals** (`commit`, `reset --hard HEAD`). Three torches along a hall of spike pits, and a door that opens when all three burn. Light a torch, seal it, and a fall only costs you the way back to the last seal. The door won't open until the third torch is committed on `main`.
2. **The Vizier's Seal** (`log`, `reset --hard <commit>`). A plate lowers a bridge. On the far side the Vizier appears on a balcony and commits sabotage of his own (`Arm the spikes and bar the door`), sweeping in anything you hadn't committed. Resetting to `HEAD` changes nothing: his commit *is* `HEAD`. Reset to the one before it.
3. **The Princess's Bridge** (`revert`, `ORIG_HEAD`). The room arrives with history: the palace's first commit, then the Vizier's `Bar the door`, then the Princess's `Lower the bridge for you`. Reset past the Vizier and the Princess's bridge goes with him, over a chasm no one can jump (`git reset --hard ORIG_HEAD` brings it back). `git revert` undoes just his commit.
4. **Two Doors** (`switch -c`, `switch`, fast-forward `merge`). The palace guard refuses commits on `main`. Two drops lead to two levers you can't both reach. Try each on its own branch, see which opens the gate and which arms the spikes, then switch to `main` and merge the one that worked.
5. **The Vizier's Gate** (boss: three-way `merge`, conflicts). The tower lever opens the gate. The winch lowers the drawbridge, but its counterweight bars the gate. Each is a one-way drop. Pull each on its own branch and merge both: the bridge merges cleanly, the gate conflicts. Keep `open` (it's `HEAD`'s side or the other one's, depending on which you merged first), commit the merge and walk past the Vizier. Pick wrong and the gate stays barred; `git reset --hard ORIG_HEAD` and merge again.

### Act II: The Vizier Rewrites History (designed, not built)

6. **The Pantry Ledge** (`stash`). You're carrying a lit torch (uncommitted) when you need to switch timelines, and the switch would overwrite it. Stash it, switch, come back, pop.
7. **The Borrowed Step** (`cherry-pick`). One branch built the stair you need and also flooded the cellar. Take only the stair.
8. **The Thousand Steps** (`bisect`). Twenty commits of the Vizier's renovations and one of them sprang the trap. `git bisect good`/`bad` halves the corridor until the culprit is found, then revert it.
9. **The Lost Sands** (`reflog`). The Vizier hard-resets your branch away. `git reflog` remembers every place HEAD has been; branch from the lost commit.
10. **The Ledger** (boss: `rebase`, `push`, `pull`). The Princess's ledger is `origin`. The Vizier rebases and force-pushes over it; you pull, see the rewritten history, and restore it with `--force-with-lease` lessons on why nobody rewrites a shared branch.

## Controls

- **Keyboard:** arrows or A/D to run, Space/W/Up to jump, E or Down to pull a lever or read a scroll, Q or Tab to draw the dagger. In the dagger, arrows and Enter (or the mouse) pick a command.
- **Touch:** left and right on the left thumb; JUMP and DAGGER on the right. The dagger is all big buttons. Landscape, like the other games.
- **Gamepad:** d-pad or stick, A to jump, X to use, Y to draw the dagger.

## Checks

- `tests/replay.gd` runs every level's history, triggers and solution through the in-game Git model and writes what it did (each command, its exit code, output lines, commit ids, branch tips, files) to `tests/out/replay.json`.
- `tests/verify_git.ts` runs the same commands with the real `git` (fixed author dates, the level's real `pre-commit` hook) and demands the same commit ids, branches, files, conflicts, exit codes and output lines, and that each solution leaves `main` clean with the exit open.
- `tests/bot.tscn` plays every level with the real input actions and the real dagger buttons, making the level's mistake first (dying uncommitted, resetting to `HEAD` when the Vizier's commit *is* `HEAD`, committing on guarded `main`, picking the wrong side of the conflict), and checks each level clears.
