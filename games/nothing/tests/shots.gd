extends "res://tests/bot.gd"

## The bot's run, slowed a little, saving a screenshot at every moment worth
## looking at: the title, each page of the prologue, every episode's title
## card, every line of talk, every one of Stu's sets, every scene as briefed,
## missed, cued, rolling and aired, each end card and the TV guide after it.
## Needs a window (not --headless):
##
##     godot --path . res://tests/shots.tscn   ->  tests/shots/*.png

var _taken: Dictionary = {}
var _count: int = 0


func _init() -> void:
	linger = 8
	EpisodeScene.bot_frames = 24
	EpisodeScene.watch = true


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots/"))
	# Keep Godot from importing the screenshots as game art.
	FileAccess.open("res://tests/shots/.gdignore", FileAccess.WRITE).close()
	super()


func moment(name: String) -> void:
	if _taken.has(name):
		return
	_taken[name] = true
	_count += 1
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://tests/shots/%03d_%s.png" % [_count, name])
