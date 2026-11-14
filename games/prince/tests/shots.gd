extends "res://tests/bot.gd"

## The bot's run, saving a screenshot at every moment it names: each room's
## title card, the dagger's console after every command, the deaths, the
## Vizier, the conflict and the lesson cards. Needs a window (not --headless):
##
##     godot --path . res://tests/shots.tscn [-- room=3]   ->  tests/shots/*.png


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/"))
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await tree.create_timer(1.2).timeout
	await _save("0_title")
	tree.current_scene.queue_free()
	await super()


func moment(name: String) -> void:
	for _i in 4:
		await get_tree().process_frame
	await _save(name)


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://tests/shots/%s.png" % name))
