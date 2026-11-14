class_name GitRepo
extends RefCounted

## A small Git, in GDScript: just enough for the Dagger of HEAD, and exact
## where it goes. Every file is one line in a flat folder. Blobs, trees and
## commits are hashed the way Git hashes them (with a fixed author date), so
## the ids on screen are the ones the real git computes for the same commands;
## tests/verify_git.ts holds it to that.
##
## Every command returns {exit, out, cmd} and is appended to `log`, where
## `cmd` is the git argv as the player sees it and the real git runs it.

const DATE := "1000000000 +0000"
const AUTHORS: Dictionary = {
	"prince": ["The Prince", "prince@palace.example"],
	"vizier": ["Grand Vizier Rebasir", "vizier@palace.example"],
	"princess": ["Princess Shirin", "shirin@palace.example"],
	"palace": ["The Palace Builders", "builders@palace.example"],
}
## What the palace guard (a real pre-commit hook) says on a protected main.
const GUARD := "The palace guard: no commits straight onto main. Make a branch (git switch -c)."

## sha -> {tree: Dictionary, parents: Array, author: String, message: String}
var commits: Dictionary = {}
var branches: Dictionary = {}
var head: String = "main"
var work: Dictionary = {}
var orig_head: String = ""
## Empty, or {head, name, conflicts: Array, resolved: Dictionary, touched: Array}
var merging: Dictionary = {}
var protect_main: bool = false
## Every command run, in order, for the replay and the console.
var log: Array = []
## The order files are listed in (the level's), for messages and status.
var order: PackedStringArray = []


func init(files: Dictionary, message: String, author: String) -> void:
	order = PackedStringArray(files.keys())
	for name: String in files:
		work[name] = _line(files[name])
	var sha := _make_commit(work.duplicate(), [], author, message)
	branches["main"] = sha
	head = "main"
	log.append({"init": files.duplicate(), "message": message, "author": author})


# --- reading ---------------------------------------------------------------

func head_sha() -> String:
	return branches.get(head, "")


func tree(sha: String) -> Dictionary:
	return commits[sha].tree if commits.has(sha) else {}


func short(sha: String) -> String:
	return sha.substr(0, 7)


func subject(sha: String) -> String:
	return String(commits[sha].message).get_slice("\n", 0)


## The value a file holds in the working tree, without its newline. A
## conflicted file reads as "conflict".
func value(name: String) -> String:
	var text: String = work.get(name, "")
	if text.begins_with("<<<<<<<"):
		return "conflict"
	return text.strip_edges()


func modified() -> PackedStringArray:
	var out := PackedStringArray()
	var base := tree(head_sha())
	for name in order:
		if work.get(name, "") != base.get(name, ""):
			out.append(name)
	return out


func is_clean() -> bool:
	return merging.is_empty() and modified().is_empty()


func unresolved() -> PackedStringArray:
	var out := PackedStringArray()
	if merging.is_empty():
		return out
	for name: String in merging.conflicts:
		if not merging.resolved.has(name):
			out.append(name)
	return out


func ancestors(sha: String) -> Dictionary:
	var seen := {}
	var queue: Array = [sha]
	while not queue.is_empty():
		var at: String = queue.pop_back()
		if at == "" or seen.has(at):
			continue
		seen[at] = true
		queue.append_array(commits[at].parents)
	return seen


## Commits reachable from every branch, newest first by depth, for the trail.
func reachable() -> Array:
	var seen := {}
	for name: String in branches:
		seen.merge(ancestors(branches[name]))
	if orig_head != "":
		seen.merge(ancestors(orig_head))
	return seen.keys()


func depth(sha: String) -> int:
	var parents: Array = commits[sha].parents
	if parents.is_empty():
		return 0
	var best := 0
	for p: String in parents:
		best = maxi(best, depth(p) + 1)
	return best


## The commits on the current branch, newest first (first parents and
## merged-in commits too), as git log lists them.
func history() -> Array:
	var shas: Array = ancestors(head_sha()).keys()
	shas.sort_custom(func(a: String, b: String) -> bool: return depth(a) > depth(b) or (depth(a) == depth(b) and a < b))
	return shas


## A revision the console names: HEAD, ORIG_HEAD, HEAD~n, a branch, a short
## or full id, or msg:<subject> (the newest reachable commit with it).
func resolve(rev: String) -> String:
	if rev == "HEAD":
		return head_sha()
	if rev == "ORIG_HEAD":
		return orig_head
	if rev.begins_with("HEAD~"):
		var sha := head_sha()
		for _i in int(rev.substr(5)):
			sha = commits[sha].parents[0] if not commits[sha].parents.is_empty() else ""
			if sha == "":
				return ""
		return sha
	if branches.has(rev):
		return branches[rev]
	if rev.begins_with("msg:"):
		var want := rev.substr(4)
		var best := ""
		for sha: String in commits:
			if subject(sha) == want and (best == "" or depth(sha) > depth(best)):
				best = sha
		return best
	for sha: String in commits:
		if sha.begins_with(rev):
			return sha
	return ""


# --- commands --------------------------------------------------------------

## A change in the room (a lever, a plate, a torch): the working tree only.
func set_file(name: String, text: String) -> void:
	work[name] = _line(text)
	log.append({"write": {name: work[name]}})


## git commit -am "<message>"
func commit_all(message: String, author: String = "prince") -> Dictionary:
	var cmd := ["commit", "-am", message]
	if not merging.is_empty():
		return _done(cmd, 128, ["fatal: You have not concluded your merge (MERGE_HEAD exists)."], author)
	if protect_main and head == "main":
		return _done(cmd, 1, [GUARD], author)
	var changed := modified()
	if changed.is_empty():
		return _done(cmd, 1, ["On branch %s" % head, "nothing to commit, working tree clean"], author)
	var sha := _make_commit(work.duplicate(), [head_sha()], author, message)
	branches[head] = sha
	return _done(cmd, 0, ["[%s %s] %s" % [head, short(sha), message], _stat(changed.size())], author)


## git reset --hard <rev>
func reset_hard(rev: String) -> Dictionary:
	var sha := resolve(rev)
	var shown := rev if rev in ["HEAD", "ORIG_HEAD"] or rev.begins_with("HEAD~") else short(sha)
	var cmd := ["reset", "--hard", shown]
	if sha == "":
		return _done(cmd, 128, ["fatal: ambiguous argument '%s': unknown revision or path not in the working tree." % shown])
	orig_head = head_sha()
	branches[head] = sha
	work = tree(sha).duplicate()
	merging = {}
	return _done(cmd, 0, ["HEAD is now at %s %s" % [short(sha), subject(sha)]])


## Whether reverting this commit would apply cleanly here (the console only
## offers the ones that would; the dagger can't untangle a conflicted revert).
func can_revert(sha: String) -> bool:
	if not commits.has(sha) or commits[sha].parents.size() != 1 or not merging.is_empty():
		return false
	if not ancestors(head_sha()).has(sha):
		return false
	var plan := _three_way(tree(sha), tree(head_sha()), tree(commits[sha].parents[0]))
	return plan.conflicts.is_empty()


## git revert --no-edit <commit>
func revert(rev: String, author: String = "prince") -> Dictionary:
	var sha := resolve(rev)
	var cmd := ["revert", "--no-edit", short(sha)]
	if not can_revert(sha):
		return _done(cmd, 1, ["The dagger can't revert that one cleanly."], author)
	var ours := tree(head_sha())
	var plan := _three_way(tree(sha), ours, tree(commits[sha].parents[0]))
	var touched := _touched(plan.result, ours, [])
	var blocked := _dirty_in(touched)
	if not blocked.is_empty():
		return _done(cmd, 128, _overwritten("merge", blocked) + ["fatal: revert failed"], author)
	var message := "Revert \"%s\"\n\nThis reverts commit %s." % [subject(sha), sha]
	var next: Dictionary = plan.result.duplicate()
	var new_sha := _make_commit(next, [head_sha()], author, message)
	branches[head] = new_sha
	_apply(next, ours)
	return _done(cmd, 0, ["[%s %s] Revert \"%s\"" % [head, short(new_sha), subject(sha)], _stat(touched.size())], author)


## git switch -c <name>
func switch_create(name: String) -> Dictionary:
	var cmd := ["switch", "-c", name]
	if not merging.is_empty():
		return _done(cmd, 128, ["fatal: cannot switch branch while merging"])
	if branches.has(name):
		return _done(cmd, 128, ["fatal: a branch named '%s' already exists" % name])
	branches[name] = head_sha()
	head = name
	var out := []
	out.append("Switched to a new branch '%s'" % name)
	return _done(cmd, 0, out)


## git switch <name>
func switch_to(name: String) -> Dictionary:
	var cmd := ["switch", name]
	if not merging.is_empty():
		return _done(cmd, 128, ["fatal: cannot switch branch while merging"])
	if not branches.has(name):
		return _done(cmd, 128, ["fatal: invalid reference: %s" % name])
	if name == head:
		return _done(cmd, 0, ["Already on '%s'" % name])
	var ours := tree(head_sha())
	var theirs := tree(branches[name])
	var blocked := _dirty_in(_touched(theirs, ours, []))
	if not blocked.is_empty():
		return _done(cmd, 1, _overwritten("checkout", blocked, "switch branches"))
	_apply(theirs, ours)
	head = name
	var out := _carried_lines()
	out.append("Switched to branch '%s'" % name)
	return _done(cmd, 0, out)


## git merge <name>
func merge(name: String) -> Dictionary:
	var cmd := ["merge", name]
	if not merging.is_empty():
		return _done(cmd, 128, ["fatal: You have not concluded your merge (MERGE_HEAD exists)."])
	if not branches.has(name):
		return _done(cmd, 1, ["merge: %s - not something we can merge" % name])
	var ours_sha := head_sha()
	var theirs_sha: String = branches[name]
	var ours := tree(ours_sha)
	var theirs := tree(theirs_sha)
	# git notes where HEAD was before it looks at what the merge would do.
	orig_head = ours_sha
	if ancestors(ours_sha).has(theirs_sha):
		return _done(cmd, 0, ["Already up to date."])
	if ancestors(theirs_sha).has(ours_sha):
		var touched := _touched(theirs, ours, [])
		var blocked := _dirty_in(touched)
		if not blocked.is_empty():
			return _done(cmd, 1, _overwritten("merge", blocked, "merge"))
		branches[head] = theirs_sha
		_apply(theirs, ours)
		var out := ["Updating %s..%s" % [short(ours_sha), short(theirs_sha)], "Fast-forward"]
		out.append_array(_diffstat(touched))
		out.append(_stat(touched.size()))
		return _done(cmd, 0, out)
	var base := tree(_merge_base(ours_sha, theirs_sha))
	var plan := _three_way(base, ours, theirs)
	var touched := _touched(plan.result, ours, plan.conflicts)
	var blocked := _dirty_in(touched)
	if not blocked.is_empty():
		return _done(cmd, 2, _overwritten("merge", blocked, "merge") + ["Merge with strategy ort failed."])
	if plan.conflicts.is_empty():
		var message := "Merge branch '%s'" % name if head == "main" else "Merge branch '%s' into %s" % [name, head]
		var sha := _make_commit(plan.result.duplicate(), [ours_sha, theirs_sha], "prince", message)
		branches[head] = sha
		_apply(plan.result, ours)
		var out := ["Merge made by the 'ort' strategy."]
		out.append_array(_diffstat(touched))
		out.append(_stat(touched.size()))
		return _done(cmd, 0, out)
	var next: Dictionary = plan.result.duplicate()
	var out := []
	for file: String in plan.both:
		out.append("Auto-merging %s" % file)
		if file in plan.conflicts:
			out.append("CONFLICT (content): Merge conflict in %s" % file)
			next[file] = "<<<<<<< HEAD\n%s=======\n%s>>>>>>> %s\n" % [ours[file], theirs[file], name]
	_apply(next, ours)
	merging = {"head": theirs_sha, "name": name, "conflicts": plan.conflicts, "resolved": {}, "touched": touched}
	out.append("Automatic merge failed; fix conflicts and then commit the result.")
	return _done(cmd, 1, out)


## Settles a conflicted file on one side's line: the edit, then git add.
func resolve_conflict(file: String, side: String) -> Dictionary:
	var ours := tree(head_sha())
	var theirs := tree(merging.head)
	set_file(file, ours[file] if side == "ours" else theirs[file])
	merging.resolved[file] = true
	return _done(["add", file], 0, [])


func merge_message() -> String:
	return "Merge branch '%s'" % merging.get("name", "")


## git commit -m "Merge branch '<name>'", once every conflict is added.
func commit_merge(author: String = "prince") -> Dictionary:
	var message := merge_message()
	var cmd := ["commit", "-m", message]
	if merging.is_empty():
		return commit_all(message, author)
	if not unresolved().is_empty():
		return _done(cmd, 128, ["error: Committing is not possible because you have unmerged files."], author)
	# The guard's hook lets a merge through: it checks for MERGE_HEAD.
	var sha := _make_commit(work.duplicate(), [head_sha(), merging.head], author, message)
	branches[head] = sha
	merging = {}
	return _done(cmd, 0, ["[%s %s] %s" % [head, short(sha), message]], author)


## git merge --abort
func merge_abort() -> Dictionary:
	var cmd := ["merge", "--abort"]
	if merging.is_empty():
		return _done(cmd, 128, ["fatal: There is no merge to abort (MERGE_HEAD missing)."])
	var ours := tree(head_sha())
	for file: String in merging.touched:
		work[file] = ours.get(file, "")
	merging = {}
	return _done(cmd, 0, [])


# --- internals -------------------------------------------------------------

func _line(text: String) -> String:
	return text if text.ends_with("\n") else text + "\n"


func _done(cmd: Array, code: int, out: Array, author: String = "") -> Dictionary:
	var entry := {"cmd": cmd, "exit": code, "out": out}
	if author != "" and author != "prince":
		entry["author"] = author
	entry["state"] = {"head": head, "branches": branches.duplicate(), "work": work.duplicate(), "orig_head": orig_head, "merge_head": merging.get("head", "")}
	log.append(entry)
	return entry


func _stat(files: int) -> String:
	if files == 1:
		return " 1 file changed, 1 insertion(+), 1 deletion(-)"
	return " %d files changed, %d insertions(+), %d deletions(-)" % [files, files, files]


func _diffstat(files: Array) -> Array:
	var width := 0
	for f: String in files:
		width = maxi(width, f.length())
	var out := []
	for f: String in files:
		out.append(" %s | 2 +-" % f.rpad(width))
	return out


## Files the operation would change, in level order.
func _touched(next: Dictionary, ours: Dictionary, conflicts: Array) -> Array:
	var out := []
	for name in order:
		if next.get(name, "") != ours.get(name, "") or name in conflicts:
			out.append(name)
	return out


func _dirty_in(files: Array) -> Array:
	var dirty := modified()
	return files.filter(func(f: String) -> bool: return f in dirty)


func _overwritten(what: String, files: Array, before: String = "") -> Array:
	var out := ["error: Your local changes to the following files would be overwritten by %s:" % what]
	for f: String in files:
		out.append("\t" + f)
	out.append("Please commit your changes or stash them before you %s." % (before if before != "" else "merge"))
	out.append("Aborting")
	return out


## Moves the working tree from `ours` to `next`, keeping local changes in
## files the move doesn't touch (as git does).
func _apply(next: Dictionary, ours: Dictionary) -> void:
	for name in order:
		if work.get(name, "") == ours.get(name, ""):
			work[name] = next.get(name, "")


## git lists the files it carried across: "M\t<file>".
func _carried_lines() -> Array:
	var out := []
	for f in modified():
		out.append("M\t" + f)
	return out


func _merge_base(a: String, b: String) -> String:
	var common := ancestors(a)
	var theirs := ancestors(b)
	var best := ""
	for sha: String in common:
		if theirs.has(sha) and (best == "" or depth(sha) > depth(best)):
			best = sha
	return best


## The per-file three-way merge. With one line per file it is exactly git's.
func _three_way(base: Dictionary, ours: Dictionary, theirs: Dictionary) -> Dictionary:
	var result := {}
	var conflicts := []
	var both := []
	for name in order:
		var b: String = base.get(name, "")
		var o: String = ours.get(name, "")
		var t: String = theirs.get(name, "")
		if o == t:
			result[name] = o
		elif o == b:
			result[name] = t
		elif t == b:
			result[name] = o
		else:
			result[name] = o
			conflicts.append(name)
			both.append(name)
	return {"result": result, "conflicts": conflicts, "both": both}


func _make_commit(files: Dictionary, parents: Array, author: String, message: String) -> String:
	var who: Array = AUTHORS[author]
	var ident := "%s <%s> %s" % [who[0], who[1], DATE]
	var text := "tree %s\n" % _tree_sha(files)
	for p: String in parents:
		text += "parent %s\n" % p
	text += "author %s\ncommitter %s\n\n%s\n" % [ident, ident, message]
	var sha := _hash("commit", text.to_utf8_buffer()).hex_encode()
	commits[sha] = {"tree": files, "parents": parents.duplicate(), "author": author, "message": message}
	return sha


func _tree_sha(files: Dictionary) -> String:
	var names: Array = files.keys()
	names.sort()
	var body := PackedByteArray()
	for name: String in names:
		body.append_array(("100644 %s" % name).to_utf8_buffer())
		body.append(0)
		body.append_array(_hash("blob", String(files[name]).to_utf8_buffer()))
	return _hash("tree", body).hex_encode()


static func _hash(kind: String, body: PackedByteArray) -> PackedByteArray:
	var data := ("%s %d" % [kind, body.size()]).to_utf8_buffer()
	data.append(0)
	data.append_array(body)
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	ctx.update(data)
	return ctx.finish()
