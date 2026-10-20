extends Node

## Opens each screen in a real window and saves one settled capture of it.
## godot --path . res://tests/look_tour.tscn   ->  tests/shots/tour_*.png

const STEPS: Array[Dictionary] = [
	{"tag": "title", "scene": "res://ui/title_screen.tscn"},
	{"tag": "map", "scene": "res://levels/world_map.tscn"},
	{"tag": "amber_start", "scene": "res://levels/level_01.tscn", "at": Vector2(120, 214)},
	{"tag": "amber_blocks", "scene": "res://levels/level_01.tscn", "at": Vector2(600, 214)},
	{"tag": "amber_pause", "scene": "res://levels/level_01.tscn", "at": Vector2(300, 214), "pause": true},
	{"tag": "amber_clear", "scene": "res://levels/level_01.tscn", "at": Vector2(1150, 214), "clear": true},
	{"tag": "amber_wizard", "scene": "res://levels/level_01.tscn", "at": Vector2(930, 214)},
	{"tag": "amber_quiz", "scene": "res://levels/level_01.tscn", "at": Vector2(982, 214)},
	{"tag": "span_wizard", "scene": "res://levels/level_02.tscn", "at": Vector2(580, 214)},
	{"tag": "span_quiz", "scene": "res://levels/level_02.tscn", "at": Vector2(630, 214)},
	{"tag": "span_quiz_wrong", "scene": "res://levels/level_02.tscn", "at": Vector2(630, 214), "answer": "wrong"},
	{"tag": "kiln_wizard", "scene": "res://levels/level_03.tscn", "at": Vector2(664, 214)},
	{"tag": "kiln_quiz", "scene": "res://levels/level_03.tscn", "at": Vector2(694, 214)},
	{"tag": "kiln_quiz_right", "scene": "res://levels/level_03.tscn", "at": Vector2(694, 214), "answer": "right"},
	{"tag": "kiln_banish", "scene": "res://levels/level_03.tscn", "at": Vector2(694, 214), "answer": "right", "skip_at": 70, "shot_at": 80},
	{"tag": "span_lantern", "scene": "res://levels/level_02.tscn", "at": Vector2(1190, 214)},
	{"tag": "span_ember", "scene": "res://levels/level_02.tscn", "at": Vector2(2000, 214)},
	{"tag": "kiln_final", "scene": "res://levels/level_03.tscn", "at": Vector2(1400, 214), "final": true},
]

var _step := -1
var _frames := 0
var _current: Node


func _ready() -> void:
	GameProgression.persist = false
	GameProgression.came_from_map = false
	StageAudio.web_audio_unlocked = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	_next()


func _process(_delta: float) -> void:
	_frames += 1
	var step: Dictionary = STEPS[_step]
	var player := _current.get_node_or_null(^"Player") as PlayerBody
	if player != null and step.has("at") and _frames < 40:
		player.global_position = step["at"]
		player.velocity = Vector2.ZERO
		if _frames == 2:
			player.reset_camera()
	if _frames == 30:
		var hud := _current.get_node_or_null(^"Hud") as StageHud
		if hud != null and step.get("pause", false):
			hud.open_pause()
		if hud != null and step.get("clear", false):
			hud.seed_count = 4
			hud.show_passage("Cinder Span awaits", 41.3, true)
		if hud != null and step.get("final", false):
			hud.show_clear(63.8, false)
		if hud != null and step.has("answer") and hud.is_quiz_asking():
			# Press the option button itself, as a mouse click would.
			var pick := hud.quiz_answer_index()
			if step["answer"] == "wrong":
				pick = posmod(pick + 1, 4)
			var option := hud.get_node("QuizPanel/Center/QuizBox/Rows/Options/Option%d" % pick) as Button
			option.pressed.emit()
	if _frames == int(step.get("skip_at", -1)):
		# Confirm skips the rest of the verdict, as a player would.
		var press := InputEventAction.new()
		press.action = &"confirm"
		press.pressed = true
		Input.parse_input_event(press)
		var release := InputEventAction.new()
		release.action = &"confirm"
		Input.parse_input_event.call_deferred(release)
	if _frames == int(step.get("shot_at", 60)):
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://tests/shots/tour_%s.png" % step["tag"]))
		print("TOUR shot ", step["tag"])
		_next()


func _next() -> void:
	get_tree().paused = false
	if _current != null:
		_current.queue_free()
	_step += 1
	_frames = 0
	if _step >= STEPS.size():
		print("TOUR done")
		get_tree().quit(0)
		return
	var packed := load(STEPS[_step]["scene"]) as PackedScene
	_current = packed.instantiate()
	add_child(_current)
