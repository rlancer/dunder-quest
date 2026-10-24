extends Node

## Loads the title, the line map and every stage for a few frames and quits.
## godot --headless --path . res://tests/smoke.tscn

func _ready() -> void:
	Progress.persist = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	# Outlive the scene changes below.
	reparent(tree.root)
	tree.current_scene = null
	for path in ["res://ui/boot.tscn", "res://ui/line_map.tscn"]:
		tree.change_scene_to_file(path)
		for _i in 10:
			await tree.process_frame
		print("ok ", path)
	var id := 1
	while ResourceLoader.exists("res://stages/stage_%d.gd" % id):
		Main.play_stage(tree, id)
		for _i in 30:
			await tree.physics_frame
		print("ok stage ", id)
		id += 1
	tree.quit(0)
