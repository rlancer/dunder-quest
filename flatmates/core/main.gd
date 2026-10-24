class_name Main
extends RefCounted

## Scene changes. Stages are built in code (res://stages/stage_N.gd), so
## they go in as nodes rather than packed scenes.

const TITLE := "res://ui/boot.tscn"
const MAP := "res://ui/line_map.tscn"


static func play_stage(tree: SceneTree, id: int) -> void:
	var script := load("res://stages/stage_%d.gd" % id) as GDScript
	if script == null:
		push_error("No stage %d" % id)
		return
	Progress.current_stage = id
	tree.paused = false
	tree.change_scene_to_node(script.new() as Node)
