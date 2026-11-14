class_name Steps
extends RefCounted

## The step language data/levels.json uses for a room's history, its
## triggers (the Vizier's sabotage), its solution and the probes. The game,
## tests/replay.gd and the bot all run steps through here, so the commands the
## dagger runs are the commands the replay records and the real git repeats.
##
##   ["set", file, value]            a change in the room (lever, plate, torch)
##   ["commit"]                      git commit -am "<message written from the change>"
##   ["commit", {message, author}]   ... with this message, as someone else
##   ["reset", rev]                  git reset --hard <rev>  (rev: HEAD, ORIG_HEAD, HEAD~1, msg:<subject>)
##   ["revert", rev]                 git revert --no-edit <rev>
##   ["switch_c", name] / ["switch", name] / ["merge", name] / ["merge_abort"]
##   ["resolve", file, "ours"|"theirs"]   keep one side, then git add
##   ["commit_merge"]                git commit -m "Merge branch '<name>'"
##   ["die"]                         the Prince dies (the game's business, not git's)
##
## A step may end in {"fails": true}: that command must fail (the replay
## checks the model, verify_git.ts checks git).


static func options(step: Array) -> Dictionary:
	return step[-1] if step.size() > 1 and step[-1] is Dictionary else {}


## The commit message for whatever the working tree changed, in the room's
## words: "Light the first torch", "Lower the bridge and open the gate".
static func message_for(repo: GitRepo, level: Dictionary) -> String:
	var phrases := PackedStringArray()
	var said: Dictionary = level.get("messages", {})
	for file in repo.modified():
		var val := repo.value(file)
		var by_file: Dictionary = said.get(file, {})
		phrases.append(String(by_file.get(val, "Set the %s to %s" % [file.replace("_", " "), val])))
	if phrases.is_empty():
		return "Seal the moment"
	if phrases.size() == 1:
		return phrases[0]
	var last := phrases[-1]
	phrases.remove_at(phrases.size() - 1)
	var text := ", ".join(phrases) + " and " + last.substr(0, 1).to_lower() + last.substr(1)
	return text.substr(0, 1).to_upper() + text.substr(1)


## Runs one step. Returns the command's result ({exit, out, cmd}), or {} for
## steps that aren't git commands.
static func run(repo: GitRepo, level: Dictionary, step: Array) -> Dictionary:
	var opts := options(step)
	match String(step[0]):
		"set":
			repo.set_file(step[1], step[2])
			return {}
		"commit":
			var message: String = opts.get("message", message_for(repo, level))
			return repo.commit_all(message, opts.get("author", "prince"))
		"reset":
			return repo.reset_hard(step[1])
		"revert":
			return repo.revert(step[1], opts.get("author", "prince"))
		"switch_c":
			return repo.switch_create(step[1])
		"switch":
			return repo.switch_to(step[1])
		"merge":
			return repo.merge(step[1])
		"merge_abort":
			return repo.merge_abort()
		"resolve":
			return repo.resolve_conflict(step[1], step[2])
		"commit_merge":
			return repo.commit_merge()
		"die":
			return {}
	push_error("unknown step %s" % [step])
	return {}


## A fresh repo for a room: its files, first commit and history.
static func open_room(level: Dictionary) -> GitRepo:
	var repo := GitRepo.new()
	var first: Dictionary = level.get("initial", {})
	repo.init(level.files, first.get("message", "The room as you found it"), first.get("author", "palace"))
	for step: Array in level.get("history", []):
		run(repo, level, step)
	# The guard arrives after the room's own history is written.
	repo.protect_main = bool(level.get("protect_main", false))
	return repo


## Whether the room's exit opens: on main, clean, and every exit condition
## holds in the files.
static func exit_open(repo: GitRepo, level: Dictionary) -> bool:
	if repo.head != "main" or not repo.is_clean():
		return false
	var want: Dictionary = level.get("exit_when", {})
	for file: String in want:
		if repo.value(file) != String(want[file]):
			return false
	return true


## Steps with every ["trigger", n] replaced by that trigger's own steps.
static func expand(level: Dictionary, steps: Array) -> Array:
	var out := []
	for step: Array in steps:
		if String(step[0]) == "trigger":
			out.append_array(level.triggers[int(step[1])].steps)
		else:
			out.append(step)
	return out
