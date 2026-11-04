extends Node

## Loads the title and every built episode for a few frames and quits.
## godot --headless --path . res://tests/smoke.tscn   ->  SMOKE result=ok


func _ready() -> void:
	Progress.persist = false
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	for _i in 10:
		await tree.process_frame
	print("ok title")
	for ep in Season.episodes():
		var node := Episode.new()
		node.episode_id = int(ep["id"])
		tree.change_scene_to_node(node)
		for _i in 30:
			await tree.process_frame
		print("ok episode ", ep["id"])
	print("SMOKE result=ok")
	tree.quit(0)
