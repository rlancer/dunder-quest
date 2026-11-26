class_name Main
extends RefCounted

## Scene changes. Every job is the same script, built from its entry in
## data/jobs.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"
const BOARD := "res://ui/board.tscn"
const SCENE := preload("res://world/job.gd")


static func play_job(tree: SceneTree, id: int) -> void:
	if Story.job(id).is_empty():
		push_error("No job %d" % id)
		return
	Progress.current_job = id
	tree.paused = false
	var node := SCENE.new() as JobScene
	node.job_id = id
	tree.change_scene_to_node(node)


## The prologue, and then job `then` (0 goes back to the title).
static func play_intro(tree: SceneTree, then: int) -> void:
	Intro.then = then
	tree.paused = false
	tree.change_scene_to_node(Intro.new())
