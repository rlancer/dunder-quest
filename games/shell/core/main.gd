class_name Main
extends RefCounted

## Scene changes. Every shift is the same script, built from its entry in
## data/shifts.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"
const BOARD := "res://ui/board.tscn"
const SCENE := preload("res://world/shift.gd")


static func play_shift(tree: SceneTree, id: int) -> void:
	if Story.shift(id).is_empty():
		push_error("No shift %d" % id)
		return
	Progress.current_shift = id
	tree.paused = false
	var node := SCENE.new() as ShiftScene
	node.shift_id = id
	tree.change_scene_to_node(node)


## The prologue, and then shift `then` (0 goes back to the title).
static func play_intro(tree: SceneTree, then: int) -> void:
	Intro.then = then
	tree.paused = false
	tree.change_scene_to_node(Intro.new())
