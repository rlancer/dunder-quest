extends Node

## Opens each screen in a real window and saves one settled capture of it.
## godot --path . res://tests/look_tour.tscn   ->  tests/shots/tour_*.png
## Add `-- --only=fork` to shoot just the steps whose tag contains "fork".

const STEPS: Array[Dictionary] = [
	{"tag": "title", "scene": "res://ui/title_screen.tscn"},
	{"tag": "map", "scene": "res://levels/world_map.tscn"},
	{"tag": "map_high", "scene": "res://levels/world_map.tscn", "cleared": 5},
	{"tag": "amber_start", "scene": "res://levels/level_01.tscn", "at": Vector2(120, 214)},
	{"tag": "amber_scroll", "scene": "res://levels/level_01.tscn", "at": Vector2(76, 214)},
	{"tag": "amber_index", "scene": "res://levels/level_01.tscn", "at": Vector2(150, 214), "bump": [1, 2], "shot_at": 75},
	{"tag": "amber_blocks", "scene": "res://levels/level_01.tscn", "at": Vector2(600, 214)},
	{"tag": "amber_pause", "scene": "res://levels/level_01.tscn", "at": Vector2(300, 214), "pause": true},
	{"tag": "amber_book", "scene": "res://levels/level_01.tscn", "at": Vector2(300, 214), "learn": ["list_zero", "list_negative", "dict_hash"], "pause": true, "book": true},
	{"tag": "amber_clear", "scene": "res://levels/level_01.tscn", "at": Vector2(1150, 214), "clear": true},
	{"tag": "amber_wizard", "scene": "res://levels/level_01.tscn", "at": Vector2(900, 214)},
	{"tag": "amber_quiz", "scene": "res://levels/level_01.tscn", "at": Vector2(982, 214)},
	{"tag": "amber_hint", "scene": "res://levels/level_01.tscn", "at": Vector2(982, 214), "learn": ["list_zero", "list_negative", "list_slice"], "hints": 1},
	{"tag": "amber_hint2", "scene": "res://levels/level_01.tscn", "at": Vector2(982, 214), "learn": ["list_zero"], "hints": 2},
	{"tag": "span_key", "scene": "res://levels/level_02.tscn", "at": Vector2(1256, 214)},
	{"tag": "span_vault", "scene": "res://levels/level_02.tscn", "at": Vector2(2560, 214), "bump": [1], "shot_at": 50},
	{"tag": "span_wizard", "scene": "res://levels/level_02.tscn", "at": Vector2(2740, 214), "open_vault": true},
	{"tag": "span_quiz", "scene": "res://levels/level_02.tscn", "at": Vector2(2774, 214), "open_vault": true},
	{"tag": "span_quiz_wrong", "scene": "res://levels/level_02.tscn", "at": Vector2(2774, 214), "open_vault": true, "answer": "wrong"},
	{"tag": "kiln_forge", "scene": "res://levels/level_03.tscn", "at": Vector2(1470, 214), "bump": [0], "shot_at": 130},
	{"tag": "kiln_wizard", "scene": "res://levels/level_03.tscn", "at": Vector2(1660, 214)},
	{"tag": "kiln_quiz", "scene": "res://levels/level_03.tscn", "at": Vector2(1718, 214)},
	{"tag": "kiln_quiz_right", "scene": "res://levels/level_03.tscn", "at": Vector2(1718, 214), "answer": "right"},
	{"tag": "kiln_banish", "scene": "res://levels/level_03.tscn", "at": Vector2(1718, 214), "answer": "right", "skip_at": 70, "shot_at": 80},
	{"tag": "span_lantern", "scene": "res://levels/level_02.tscn", "at": Vector2(1190, 214)},
	{"tag": "span_ember", "scene": "res://levels/level_02.tscn", "at": Vector2(2000, 214)},
	{"tag": "fork_start", "scene": "res://levels/level_04.tscn", "at": Vector2(160, 214)},
	{"tag": "fork_shelf", "scene": "res://levels/level_04.tscn", "at": Vector2(1200, 214)},
	{"tag": "fork_gate_shut", "scene": "res://levels/level_04.tscn", "at": Vector2(950, 214), "bump": [0], "shot_at": 50},
	{"tag": "fork_gate_open", "scene": "res://levels/level_04.tscn", "at": Vector2(950, 214), "bump": [0, 0], "shot_at": 70},
	{"tag": "fork_gate_two", "scene": "res://levels/level_04.tscn", "at": Vector2(1976, 214), "bump": [1, 1, 1], "shot_at": 70},
	{"tag": "fork_quiz", "scene": "res://levels/level_04.tscn", "at": Vector2(2226, 214), "open_gates": true, "answer": "right", "skip_at": 70, "shot_at": 110},
	{"tag": "bridge_start", "scene": "res://levels/level_05.tscn", "at": Vector2(240, 180)},
	{"tag": "bridge_calls", "scene": "res://levels/level_05.tscn", "at": Vector2(1290, 214)},
	{"tag": "bridge_short", "scene": "res://levels/level_05.tscn", "at": Vector2(1360, 214), "bump": [4], "shot_at": 72},
	{"tag": "bridge_built", "scene": "res://levels/level_05.tscn", "at": Vector2(1440, 214), "bump": [5], "shot_at": 90},
	{"tag": "bridge_wizard", "scene": "res://levels/level_05.tscn", "at": Vector2(2300, 214)},
	{"tag": "crown_climb", "scene": "res://levels/level_06.tscn", "at": Vector2(600, 118)},
	{"tag": "crown_forges", "scene": "res://levels/level_06.tscn", "at": Vector2(1420, 214)},
	{"tag": "crown_steep", "scene": "res://levels/level_06.tscn", "at": Vector2(1600, 214), "bump": [2], "shot_at": 70},
	{"tag": "crown_stair", "scene": "res://levels/level_06.tscn", "at": Vector2(1600, 214), "bump": [1], "shot_at": 90},
	{"tag": "crown_wizard", "scene": "res://levels/level_06.tscn", "at": Vector2(2040, 86)},
	{"tag": "crown_quiz", "scene": "res://levels/level_06.tscn", "at": Vector2(2114, 86)},
	{"tag": "kiln_final", "scene": "res://levels/level_03.tscn", "at": Vector2(1400, 214), "final": true},
	{"tag": "crown_final", "scene": "res://levels/level_06.tscn", "at": Vector2(2200, 86), "final": true},
]

var _step := -1
var _frames := 0
var _current: Node
var _only := ""


func _ready() -> void:
	GameProgression.persist = false
	GameProgression.came_from_map = false
	StageAudio.web_audio_unlocked = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.trim_prefix("--only=")
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
		if hud != null and step.get("book", false):
			hud.call(&"_open_spellbook")
		for index: int in step.get("bump", []):
			for block in get_tree().get_nodes_in_group(&"rune_block"):
				if _current.is_ancestor_of(block) and int(block.get(&"index")) == index:
					block.call(&"receive_head_bump")
		if hud != null and step.has("hints") and hud.is_quiz_asking():
			for _hint in int(step["hints"]):
				hud.quiz_hint_requested.emit()
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
	while _only != "" and _step < STEPS.size() and not str(STEPS[_step]["tag"]).contains(_only):
		_step += 1
	_frames = 0
	if _step >= STEPS.size():
		print("TOUR done")
		get_tree().quit(0)
		return
	GameProgression.load_data()
	for stage_id in range(1, int(STEPS[_step].get("cleared", 0)) + 1):
		GameProgression.mark_cleared(stage_id, GameProgression.get_stage_data(stage_id).get("max_seeds", 0))
	GameProgression.just_cleared_id = 0
	GameProgression.current_stage_id = maxi(1, int(STEPS[_step].get("cleared", 0)))
	for scroll_id: String in STEPS[_step].get("learn", []):
		GameProgression.learn_scroll(scroll_id)
	var packed := load(STEPS[_step]["scene"]) as PackedScene
	_current = packed.instantiate()
	# The tour runs while paused; the stage must still pause for lesson cards.
	_current.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_current)
	if STEPS[_step].get("open_vault", false):
		get_tree().call_group(&"vault_door", &"open_now")
	if STEPS[_step].get("open_gates", false):
		get_tree().call_group(&"truth_gate", &"open_now")
