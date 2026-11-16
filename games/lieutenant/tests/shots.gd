extends "res://tests/bot.gd"

## The bot's run, slowed a little, saving a screenshot at every moment worth
## looking at: the title, the case files, each page of the prologue, every
## cold-open caption, title card, lesson card, notebook page, printout,
## speech bubble with a pose, the freeze frame and the end card.
## Needs a window (not --headless):
##
##     godot --path . res://tests/shots.tscn [-- case=3]   ->  tests/shots/*.png

var _taken: Dictionary = {}
var _queue: Array = []
var _busy: bool = false


func _init() -> void:
	line_frames = 30
	printout_frames = 30
	page_frames = 260
	pace = 0.6
	# Errors worth a picture: a count with no GROUP BY (the one rule stricter
	# than SQLite), a count in WHERE, and a column two tables share.
	extra_tries = {
		"4b": [{"select": ["patient", "COUNT(*)"], "from": "prescriptions"}],
		"4c": [{"select": ["patient", "COUNT(*)"], "from": "prescriptions", "where": ["COUNT(*) > 2"], "group": "patient"}],
		"5a": [{"select": ["seat", "orders.dish"], "from": "seating", "join": ["JOIN orders ON seating.seat = orders.seat"]}],
		"3b": [{"select": ["phones.owner", "calls.at"], "from": "calls", "where": ["calls.receiver = '555-0142'"]}],
	}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/"))
	# Keep Godot from importing the screenshots as game art.
	FileAccess.open("res://tests/shots/.gdignore", FileAccess.WRITE).close()
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await tree.create_timer(1.2).timeout
	await _save("00_title")
	tree.change_scene_to_file("res://ui/files.tscn")
	await tree.create_timer(0.8).timeout
	await _save("00_files")
	tree.current_scene.queue_free()
	await super()


func moment(name: String) -> void:
	if name.begins_with("prologue"):
		await _save("0p_%s" % name.replace(" ", "_"))
	elif name.begins_with("notebook") or name.begins_with("solution"):
		await _frames(4)
		await _save("%d_%s" % [scene.case_id, name.replace(" ", "_")])


func _physics_process(_delta: float) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var hud := scene.hud
	var id := scene.case_id
	if not hud._caption.is_empty():
		_shot("%d_cold_%d" % [id, hud.caption_count])
	if not hud._title.is_empty():
		_shot("%d_titlecard" % id)
	if not hud._card.is_empty():
		_shot("%d_card_%s" % [id, hud._card.id])
	if not hud.bubble.is_empty() and scene.state != "intro":
		_shot("%d_say_%s_%s" % [id, scene.beat_index, hud.bubble.mood])
	if not hud.bubble.is_empty() and scene.state == "intro":
		_shot("%d_opening" % id)
	if scene.notebook.is_open() and scene.notebook.mode == "printout":
		var result: Dictionary = scene.notebook.verdict.result
		var what := str(scene.notebook.verdict.verdict)
		if not result.ok:
			what = str(result.error.msg).get_slice(":", 0).get_slice(" must", 0).replace(" ", "_").replace("\"", "").left(24)
		_shot("%d_printout_%s_%s" % [id, scene.current_beat().get("id", ""), what])
	if scene.notebook.is_open() and scene.notebook.mode == "dialing":
		_shot("%d_dialing" % id)
	if not hud._slip.is_empty() and hud.bubble.is_empty():
		_shot("%d_slip_%d" % [id, scene.tables.size()])
	if hud._freeze > 0.0 and hud._end.is_empty():
		_shot("%d_freeze" % id)
	if not hud._end.is_empty():
		_shot("%d_end" % id)
	if scene.state == "free" and scene.lt.walk_dir != 0.0:
		_shot("%d_walk_%d" % [id, scene.beat_index])


func _shot(key: String) -> void:
	if _taken.has(key):
		return
	_taken[key] = true
	_save.call_deferred(key)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/shots/%s.png" % name))
