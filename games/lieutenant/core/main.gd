class_name Main
extends RefCounted

## Scene changes. Every case is the same script, built from its entry in
## data/cases.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"
const FILES := "res://ui/files.tscn"
const SCENE := preload("res://world/case_scene.gd")


static func play_case(tree: SceneTree, id: int) -> void:
	if Story.case(id).is_empty():
		push_error("No case %d" % id)
		return
	Progress.current_case = id
	tree.paused = false
	var node := SCENE.new() as CaseScene
	node.case_id = id
	tree.change_scene_to_node(node)


## The prologue, and then case `then` (0 goes back to the title).
static func play_intro(tree: SceneTree, then: int) -> void:
	Intro.then = then
	tree.paused = false
	tree.change_scene_to_node(Intro.new())
