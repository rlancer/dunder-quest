class_name Console
extends Control

## The Dagger of HEAD, drawn: a git console made of buttons. Time stands
## still while it's open. It shows the sand trail (the commit graph), what
## `git status` would say, and the commands this room has unlocked; each
## button carries the exact command it runs, and the terminal at the bottom
## shows that command and git's own output. Nothing is typed.
##
## Every button has an "act" (commit, menu:reset, pick:<rev>, keep:<file>:ours,
## commit_merge, merge_abort, close, restart, back), which is how the bot
## presses them: through `press`, on the buttons that are really there.

const PROMPTS: Dictionary = {
	"reset": "git reset --hard: back to which commit?",
	"revert": "git revert: undo which commit, with a new one?",
	"switch_c": "git switch -c: name the new branch",
	"switch": "git switch: step onto which branch?",
	"merge": "git merge: bring which branch into this one?",
}

var room: Room

var _mode: String = "menu"
var _list: GridContainer
var _scroll: ScrollContainer
var _last: Dictionary = {}
var _clock: float = 0.0


## Git argv as you'd type it: arguments with spaces go in quotes.
static func shown(cmd: Array) -> String:
	var parts := PackedStringArray()
	for arg: String in cmd:
		parts.append("\"%s\"" % arg if " " in arg else arg)
	return " ".join(parts)


func _ready() -> void:
	size = Room.VIEW
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(8, 109)
	_scroll.size = Vector2(464, 98)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_list = GridContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"h_separation", 4)
	_list.add_theme_constant_override(&"v_separation", 3)
	_scroll.add_child(_list)


func _process(delta: float) -> void:
	_clock += delta
	position = Vector2(room.hud.margin(), 0)
	if visible:
		queue_redraw()


func open() -> void:
	_last = {}
	_show("menu")
	show()


func mode() -> String:
	return _mode


## Presses the button with this act, if it's there. The bot's hands.
func press(act: String) -> bool:
	if not visible:
		return false
	for child in _list.get_children():
		if not child.is_queued_for_deletion() and String(child.get_meta(&"act", "")) == act:
			(child as Button).pressed.emit()
			return true
	return false


func acts() -> PackedStringArray:
	var out := PackedStringArray()
	for child in _list.get_children():
		if not child.is_queued_for_deletion():
			out.append(String(child.get_meta(&"act", "")))
	return out


# --- what's on offer ---------------------------------------------------------

func _who(sha: String) -> String:
	var author: String = room.repo.commits[sha].author
	return "" if author == "prince" else "  (%s)" % String(GitRepo.AUTHORS[author][0])


func _items() -> Array:
	var repo := room.repo
	var level := room.level
	var unlocked := Story.commands(room.level_id)
	var dead := not room.prince.alive
	var others: Array = repo.branches.keys().filter(func(name: String) -> bool: return name != repo.head)
	var items := []
	match _mode:
		"menu":
			if not repo.merging.is_empty():
				var ours := repo.tree(repo.head_sha())
				var theirs := repo.tree(repo.merging.head)
				for file in repo.unresolved():
					items.append(["keep:%s:ours" % file, "keep HEAD's:  %s = %s" % [file, String(ours[file]).strip_edges()]])
					items.append(["keep:%s:theirs" % file, "keep %s's:  %s = %s" % [repo.merging.name, file, String(theirs[file]).strip_edges()]])
				if repo.unresolved().is_empty():
					items.append(["commit_merge", "git commit -m \"%s\"" % repo.merge_message()])
				items.append(["merge_abort", "git merge --abort"])
				items.append(["menu:reset", "git reset --hard ..."])
				items.append(["restart", "Start the room over"])
				return items
			if not dead and "commit" in unlocked:
				if repo.modified().is_empty():
					items.append(["commit", "git commit   (nothing has changed)"])
				else:
					items.append(["commit", "git commit -am \"%s\"" % Steps.message_for(repo, level)])
			if "reset" in unlocked:
				items.append(["menu:reset", "git reset --hard ..."])
			if not dead and "revert" in unlocked:
				items.append(["menu:revert", "git revert ..."])
			if not dead and "switch_c" in unlocked and not _free_names().is_empty():
				items.append(["menu:switch_c", "git switch -c ..."])
			if "switch" in unlocked and not others.is_empty():
				items.append(["menu:switch", "git switch ..."])
			if not dead and "merge" in unlocked and not others.is_empty():
				items.append(["menu:merge", "git merge ..."])
			if not dead:
				items.append(["close", "Sheathe the dagger"])
			items.append(["restart", "Start the room over"])
		"reset":
			var head := repo.head_sha()
			items.append(["pick:HEAD", "HEAD        %s %s   (drop what isn't committed)" % [repo.short(head), repo.subject(head)]])
			for sha: String in repo.history():
				if sha != head:
					items.append(["pick:" + sha, "%s  %s%s" % [repo.short(sha), repo.subject(sha), _who(sha)]])
			if repo.orig_head != "" and repo.orig_head != head:
				items.append(["pick:ORIG_HEAD", "ORIG_HEAD   %s %s   (where HEAD was)" % [repo.short(repo.orig_head), repo.subject(repo.orig_head)]])
			items.append(["back", "Back"])
		"revert":
			for sha: String in repo.history():
				if repo.can_revert(sha):
					items.append(["pick:" + sha, "%s  %s%s" % [repo.short(sha), repo.subject(sha), _who(sha)]])
			items.append(["back", "Back"])
		"switch_c":
			for name: String in _free_names():
				items.append(["pick:" + name, "git switch -c %s" % name])
			items.append(["back", "Back"])
		"switch":
			for name: String in others:
				items.append(["pick:" + name, "git switch %s" % name])
			items.append(["back", "Back"])
		"merge":
			for name: String in others:
				items.append(["pick:" + name, "git merge %s" % name])
			items.append(["back", "Back"])
	return items


func _free_names() -> Array:
	return (room.level.get("branches", []) as Array).filter(func(name: String) -> bool: return not room.repo.branches.has(name))


func _show(mode_name: String) -> void:
	_mode = mode_name
	for child in _list.get_children():
		child.queue_free()
	var items := _items()
	_list.columns = 2 if _mode == "menu" else 1
	var first: Button = null
	for item: Array in items:
		var button := Button.new()
		button.text = item[1]
		button.set_meta(&"act", item[0])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.custom_minimum_size = Vector2(228 if _list.columns == 2 else 458, 22)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var plain: bool = item[0] in ["close", "restart", "back"]
		button.add_theme_font_override(&"font", Palette.pixel() if plain else Palette.mono())
		button.add_theme_font_size_override(&"font_size", 11 if plain else 14)
		if not plain:
			button.add_theme_color_override(&"font_color", Palette.SAND_PALE)
		button.pressed.connect(_on_press.bind(String(item[0])))
		_list.add_child(button)
		if first == null:
			first = button
	_scroll.scroll_vertical = 0
	if first != null and not TouchControls.active:
		first.grab_focus.call_deferred()
	queue_redraw()


func _on_press(act: String) -> void:
	if room.state != "dagger":
		return
	if act == "close":
		room.sheathe()
	elif act == "restart":
		Main.play(get_tree(), room.level_id)
	elif act == "back":
		_show("menu")
	elif act.begins_with("menu:"):
		_show(act.substr(5))
	elif act == "commit":
		_ran(room.run_git(["commit"]), true)
	elif act == "commit_merge":
		_ran(room.run_git(["commit_merge"]), true)
	elif act == "merge_abort":
		_ran(room.run_git(["merge_abort"]), false)
	elif act.begins_with("keep:"):
		_ran(room.run_git(["resolve", act.get_slice(":", 1), act.get_slice(":", 2)]), false)
	elif act.begins_with("pick:"):
		_ran(room.run_git([_mode, act.substr(5)]), true)


## Shows what git said. A command that worked puts the dagger away after a
## moment; one that failed (or left a conflict) keeps it out.
func _ran(result: Dictionary, then_sheathe: bool) -> void:
	_last = result
	if room.state != "dagger":
		return
	_show("menu")
	if int(result.exit) != 0 or not then_sheathe or not room.repo.merging.is_empty():
		return
	if not Room.test_fast:
		await get_tree().create_timer(1.1).timeout
	if visible and _last == result:
		room.sheathe()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	var repo := room.repo
	var wide := room.hud.margin()
	draw_rect(Rect2(-wide, 31, size.x + wide * 2.0, size.y - 31), Color(Palette.INK, 0.8))
	# The trail, and what `git status` says.
	var trail := Rect2(8, 35, 296, 60)
	draw_rect(trail, Color(0.04, 0.05, 0.1, 0.9))
	draw_rect(trail, Color(Palette.SAND, 0.5), false, 1.0)
	Trail.paint(self, repo, trail.grow(-3), Palette.pixel(), true, _clock)
	var status := Rect2(308, 35, 164, 60)
	draw_rect(status, Color(0.04, 0.05, 0.1, 0.9))
	draw_rect(status, Color(Palette.TEAL, 0.6), false, 1.0)
	var y := status.position.y + 11.0
	var x := status.position.x + 5.0
	if not repo.merging.is_empty() and not repo.unresolved().is_empty():
		var file: String = repo.unresolved()[0]
		draw_string(Palette.mono(), Vector2(x, y), "%s  (both modified)" % file, HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.CRIMSON.lightened(0.35))
		var lines := String(repo.work[file]).strip_edges().split("\n")
		for index in lines.size():
			var color := Palette.STEEL
			if index == 1:
				color = Palette.LANES[1]
			elif index == 3:
				color = Palette.LANES[2]
			draw_string(Palette.mono(), Vector2(x, y + 9.0 * (index + 1)), lines[index], HORIZONTAL_ALIGNMENT_LEFT, 156, 11, color)
	else:
		draw_string(Palette.mono(), Vector2(x, y), "On branch %s" % repo.head, HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.PAPER)
		var changed := repo.modified()
		if not repo.merging.is_empty():
			draw_string(Palette.mono(), Vector2(x, y + 11), "All conflicts fixed:", HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.GREEN)
			draw_string(Palette.mono(), Vector2(x, y + 22), "commit to finish the merge", HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.GREEN)
		elif changed.is_empty():
			draw_string(Palette.mono(), Vector2(x, y + 11), "nothing to commit,", HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.STEEL)
			draw_string(Palette.mono(), Vector2(x, y + 22), "working tree clean", HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.STEEL)
		else:
			draw_string(Palette.mono(), Vector2(x, y + 11), "Changes not committed:", HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.STEEL)
			for index in mini(changed.size(), 3):
				draw_string(Palette.mono(), Vector2(x, y + 22 + index * 10.0), "  modified: %s" % changed[index], HORIZONTAL_ALIGNMENT_LEFT, 156, 12, Palette.CRIMSON.lightened(0.35))
	var prompt := "The Dagger of HEAD"
	if _mode != "menu":
		prompt = PROMPTS[_mode]
	elif not room.prince.alive:
		prompt = "The Prince is dead. Turn back the sands: git reset --hard"
	elif not repo.merging.is_empty():
		prompt = "Merge conflict: two timelines changed the same line. Choose."
	draw_string(Palette.pixel(), Vector2(10, 105), prompt, HORIZONTAL_ALIGNMENT_LEFT, 460, 11, Palette.SAND)
	# The terminal: the last command, and what git printed.
	var term := Rect2(8, 210, 464, 56)
	draw_rect(term, Color(0.02, 0.02, 0.05, 0.95))
	draw_rect(term, Color(Palette.STEEL, 0.4), false, 1.0)
	if _last.is_empty():
		draw_string(Palette.mono(), term.position + Vector2(5, 12), "$ git status", HORIZONTAL_ALIGNMENT_LEFT, 452, 13, Color(Palette.STEEL, 0.7))
		return
	var ok := int(_last.exit) == 0
	draw_string(Palette.mono(), term.position + Vector2(5, 12), "$ git " + shown(_last.cmd), HORIZONTAL_ALIGNMENT_LEFT, 452, 13, Palette.SAND_PALE)
	var out: Array = _last.out
	for index in mini(out.size(), 4):
		var line := String(out[index]).replace("\t", "    ")
		var color := Palette.PAPER if ok else Palette.CRIMSON.lightened(0.4)
		if line.begins_with("CONFLICT"):
			color = Palette.CRIMSON.lightened(0.4)
		draw_string(Palette.mono(), term.position + Vector2(5, 23 + index * 10.0), line, HORIZONTAL_ALIGNMENT_LEFT, 452, 12, color)
