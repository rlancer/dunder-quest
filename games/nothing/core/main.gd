class_name Main
extends RefCounted

## Scene changes. Every episode is the same script, built from its entry in
## data/episodes.json, so it goes in as a node rather than a packed scene.

const TITLE := "res://ui/boot.tscn"
const BOARD := "res://ui/board.tscn"
const SCENE := preload("res://world/episode.gd")


static func play_episode(tree: SceneTree, id: int) -> void:
	if Story.episode(id).is_empty():
		push_error("No episode %d" % id)
		return
	Progress.current_episode = id
	tree.paused = false
	var node := SCENE.new() as EpisodeScene
	node.episode_id = id
	tree.change_scene_to_node(node)


## The prologue, and then episode `then` (0 goes back to the title).
static func play_intro(tree: SceneTree, then: int) -> void:
	Intro.then = then
	tree.paused = false
	tree.change_scene_to_node(Intro.new())
