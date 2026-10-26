class_name Main
extends RefCounted

## Scene changes. Every scene is the same script, built from its entry in
## data/scenes.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"
const MAP := "res://ui/map.tscn"
const SCENE := preload("res://scenes/curb_scene.gd")


static func play_scene(tree: SceneTree, id: int) -> void:
	if Story.scene(id).is_empty():
		push_error("No scene %d" % id)
		return
	Progress.current_scene = id
	tree.paused = false
	var node := SCENE.new() as CurbScene
	node.scene_id = id
	tree.change_scene_to_node(node)
