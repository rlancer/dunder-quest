extends "res://tests/bot.gd"

## The bot's run, slowed down, saving a screenshot the first time each kind
## of moment appears in a scene: the title card, the opening bicker, a lesson
## card, the pad, the rehearsal and Sharon's interruption, the plan playing
## out, the squint close-up, the freeze frame and the end card.
## Needs a window (not --headless):
##   godot --path . res://tests/shots.tscn [-- scene=3]   ->  tests/shots/*.png

var _taken: Dictionary = {}


func _init() -> void:
	line_frames = 40
	pace = 0.5


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/"))
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await tree.create_timer(1.2).timeout
	await _save("00_title")
	tree.change_scene_to_file("res://ui/map.tscn")
	await tree.create_timer(0.8).timeout
	await _save("00_map")
	tree.current_scene.queue_free()
	await super()


func moment(name: String) -> void:
	if name.begins_with("pad"):
		await _frames(6)
		var key := "%d_pad" % scene.scene_id
		if not _taken.has(key):
			_taken[key] = true
			await _save("%02d_pad" % scene.scene_id)


func _physics_process(_delta: float) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var hud := scene.hud
	if not hud._title.is_empty():
		_shot("title")
	if not hud._card.is_empty():
		_shot("card")
	if not hud._rant.is_empty():
		_shot("rant")
	if not hud._panic.is_empty():
		_shot("panic")
	if hud._sepia > 0.0 and hud._rant.is_empty():
		_shot("rehearsal")
	if hud._code_plan != null and not hud._code_sepia and not hud.bubble.is_empty():
		_shot("run")
	if not hud.bubble.is_empty() and scene.state == "intro":
		_shot("opening")
	if not hud._closeup.is_empty() and scene.state == "ending":
		_shot("squint")
	if hud._freeze > 0.0 and hud._end.is_empty():
		_shot("freeze")
	if not hud._end.is_empty():
		_shot("end")


func _shot(kind: String) -> void:
	var key := "%d_%s" % [scene.scene_id, kind]
	if _taken.has(key):
		return
	_taken[key] = true
	_save.call_deferred("%02d_%s" % [scene.scene_id, kind])


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/shots/%s.png" % name))
