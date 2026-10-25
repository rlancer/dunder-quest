extends Node

## Screenshots of the title, the line map and each stage (as it opens, and
## with its first laptop's editor up), into tests/shots/. Needs a window.
## godot --path . res://tests/shots.tscn
## Pass `-- stage=N` to shoot only one stage.

const OUT := "res://tests/shots/"


func _ready() -> void:
	Progress.persist = false
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var only := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("stage="):
			only = int(arg.get_slice("=", 1))
	if only == 0:
		tree.change_scene_to_file("res://ui/boot.tscn")
		await _frames(40)
		_shoot("title")
		tree.change_scene_to_file("res://ui/line_map.tscn")
		await _frames(30)
		_shoot("map")
	var id := 1
	while ResourceLoader.exists("res://stages/stage_%d.gd" % id):
		if only == 0 or only == id:
			await _stage_shots(id)
		id += 1
	tree.quit(0)


func _stage_shots(id: int) -> void:
	var tree := get_tree()
	Main.play_stage(tree, id)
	await _frames(20)
	var stage := tree.current_scene as Stage
	# Close any card that opened at the start.
	if stage.hud.is_busy():
		stage.hud._close_card()
	await _frames(20)
	_shoot("stage%d_start" % id)
	if not stage._laptops.is_empty():
		var laptop: Laptop = stage._laptops[0]
		stage.active.global_position = laptop.global_position + Vector2(0, -8)
		await _frames(20)
		_shoot("stage%d_laptop" % id)
		stage.editor.open(laptop, stage.active.who)
		await _frames(10)
		_shoot("stage%d_editor" % id)
		stage.editor.close()
	var card_id := ""
	for entry in stage._thoughts:
		if entry.has("card"):
			card_id = str(entry["card"])
			break
	if card_id != "":
		stage.hud.open_card(Lessons.card(card_id))
		await _frames(10)
		_shoot("stage%d_card" % id)
		stage.hud._close_card()
	tree.paused = false


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _shoot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("shot ", name)
