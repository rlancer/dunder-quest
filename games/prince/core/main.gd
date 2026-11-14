class_name Main
extends RefCounted

## Scene changes. Every room is the same script, built from its entry in
## data/levels.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"


static func play(tree: SceneTree, id: int) -> void:
	if Story.level(id).is_empty():
		push_error("No room %d" % id)
		return
	Progress.current = id
	tree.paused = false
	var node := Room.new()
	node.level_id = id
	tree.change_scene_to_node(node)


static func title(tree: SceneTree) -> void:
	tree.paused = false
	tree.change_scene_to_file(TITLE)
