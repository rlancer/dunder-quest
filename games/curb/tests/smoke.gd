extends Node

## Loads the title, the map and every scene for a few frames and quits.
## godot --headless --path . res://tests/smoke.tscn

func _ready() -> void:
	Progress.persist = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	for path in ["res://ui/boot.tscn", "res://ui/map.tscn"]:
		tree.change_scene_to_file(path)
		for _i in 10:
			await tree.process_frame
		print("ok ", path)
	for id in range(1, Story.count() + 1):
		Main.play_scene(tree, id)
		for _i in 30:
			await tree.physics_frame
		print("ok scene ", id)
	print("SMOKE result=ok")
	tree.quit(0)
