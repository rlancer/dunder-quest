extends Node

## Opens each screen in a real window and saves one settled capture of it.
## godot --path . res://tests/look_tour.tscn   ->  tests/shots/tour_*.png
## Add `-- --only=fork` to shoot just the steps whose tag contains "fork".
##
## Step keys: `at` holds the player at a spot for the first 40 frames, and
## `duel` holds them just inside the wizard's arena instead. At frame 30 the
## step's actions run: `bump` heads-bumps gadget blocks by index, `bump_label`
## by label, `pause`, `book`, `clear` and `final` open HUD cards. Once the
## duel is asking, `hints`, `answer` ("right"/"wrong") and `spell`
## ("wave"/"hex") play out. `shot_at` is the capture frame.

const STEPS: Array[Dictionary] = [
	{"tag": "title", "scene": "res://ui/title_screen.tscn"},
	{"tag": "map", "scene": "res://levels/world_map.tscn"},
	{"tag": "map_high", "scene": "res://levels/world_map.tscn", "cleared": 5},
	{"tag": "amber_start", "scene": "res://levels/level_01.tscn", "at": Vector2(120, 214)},
	{"tag": "amber_scroll", "scene": "res://levels/level_01.tscn", "at": Vector2(76, 214)},
	{"tag": "amber_index", "scene": "res://levels/level_01.tscn", "at": Vector2(150, 214), "bump": [1, 2], "shot_at": 75},
	{"tag": "amber_slice", "scene": "res://levels/level_01.tscn", "at": Vector2(900, 214), "bump_label": ["1:10"], "shot_at": 62},
	{"tag": "amber_bridge", "scene": "res://levels/level_01.tscn", "at": Vector2(900, 214), "bump_label": ["1:11"], "shot_at": 72},
	{"tag": "amber_pause", "scene": "res://levels/level_01.tscn", "at": Vector2(300, 214), "pause": true},
	{"tag": "amber_book", "scene": "res://levels/level_01.tscn", "at": Vector2(300, 214), "learn": ["list_zero", "list_negative", "dict_hash"], "pause": true, "book": true},
	{"tag": "amber_clear", "scene": "res://levels/level_01.tscn", "at": Vector2(1640, 214), "clear": true},
	{"tag": "amber_wizard", "scene": "res://levels/level_01.tscn", "at": Vector2(1160, 214)},
	{"tag": "amber_duel", "scene": "res://levels/level_01.tscn", "duel": true, "learn": ["list_zero", "list_negative", "list_slice"], "spell": "wave", "shot_at": 175},
	{"tag": "amber_hint", "scene": "res://levels/level_01.tscn", "duel": true, "learn": ["list_zero", "list_negative", "list_slice"], "hints": 1, "shot_at": 150},
	{"tag": "amber_hint2", "scene": "res://levels/level_01.tscn", "duel": true, "learn": ["list_zero"], "hints": 2, "shot_at": 150},
	{"tag": "span_key", "scene": "res://levels/level_02.tscn", "at": Vector2(1256, 214)},
	{"tag": "span_planks", "scene": "res://levels/level_02.tscn", "at": Vector2(1300, 214)},
	{"tag": "span_vault", "scene": "res://levels/level_02.tscn", "at": Vector2(2560, 214), "bump": [1], "shot_at": 50},
	{"tag": "span_duel_wrong", "scene": "res://levels/level_02.tscn", "duel": true, "open_vault": true, "answer": "wrong", "shot_at": 150},
	{"tag": "kiln_forge", "scene": "res://levels/level_03.tscn", "at": Vector2(1480, 214), "bump": [0], "shot_at": 50},
	{"tag": "kiln_lift", "scene": "res://levels/level_03.tscn", "at": Vector2(1664, 214), "bump": [1], "shot_at": 112},
	{"tag": "kiln_top", "scene": "res://levels/level_03.tscn", "at": Vector2(1664, 214), "bump": [1], "shot_at": 170},
	{"tag": "kiln_duel_hex", "scene": "res://levels/level_03.tscn", "duel": true, "spell": "hex", "shot_at": 160},
	{"tag": "kiln_banish", "scene": "res://levels/level_03.tscn", "duel": true, "answer": "win", "shot_at": 262},
	{"tag": "span_lantern", "scene": "res://levels/level_02.tscn", "at": Vector2(1190, 214)},
	{"tag": "span_ember", "scene": "res://levels/level_02.tscn", "at": Vector2(2000, 214)},
	{"tag": "fork_start", "scene": "res://levels/level_04.tscn", "at": Vector2(160, 214)},
	{"tag": "fork_shelf", "scene": "res://levels/level_04.tscn", "at": Vector2(1200, 214)},
	{"tag": "fork_gate_shut", "scene": "res://levels/level_04.tscn", "at": Vector2(950, 214), "bump": [0], "shot_at": 50},
	{"tag": "fork_gate_open", "scene": "res://levels/level_04.tscn", "at": Vector2(950, 214), "bump": [0, 0], "shot_at": 70},
	{"tag": "fork_gate_two", "scene": "res://levels/level_04.tscn", "at": Vector2(1976, 214), "bump": [1, 1, 1], "shot_at": 70},
	{"tag": "fork_duel", "scene": "res://levels/level_04.tscn", "duel": true, "open_gates": true, "answer": "right", "shot_at": 140},
	{"tag": "bridge_start", "scene": "res://levels/level_05.tscn", "at": Vector2(240, 180)},
	{"tag": "bridge_calls", "scene": "res://levels/level_05.tscn", "at": Vector2(1290, 214)},
	{"tag": "bridge_short", "scene": "res://levels/level_05.tscn", "at": Vector2(1360, 214), "bump": [4], "shot_at": 72},
	{"tag": "bridge_built", "scene": "res://levels/level_05.tscn", "at": Vector2(1440, 214), "bump": [5], "shot_at": 90},
	{"tag": "bridge_duel", "scene": "res://levels/level_05.tscn", "duel": true, "spell": "wave", "shot_at": 190},
	{"tag": "crown_climb", "scene": "res://levels/level_06.tscn", "at": Vector2(600, 118)},
	{"tag": "crown_forges", "scene": "res://levels/level_06.tscn", "at": Vector2(1420, 214)},
	{"tag": "crown_steep", "scene": "res://levels/level_06.tscn", "at": Vector2(1600, 214), "bump": [2], "shot_at": 70},
	{"tag": "crown_stair", "scene": "res://levels/level_06.tscn", "at": Vector2(1600, 214), "bump": [1], "shot_at": 90},
	{"tag": "crown_top", "scene": "res://levels/level_06.tscn", "at": Vector2(1830, 86)},
	{"tag": "crown_duel", "scene": "res://levels/level_06.tscn", "duel": true, "answer": "right", "shot_at": 140},
	{"tag": "kiln_final", "scene": "res://levels/level_03.tscn", "at": Vector2(1400, 214), "final": true},
	{"tag": "crown_final", "scene": "res://levels/level_06.tscn", "at": Vector2(2200, 214), "final": true},
]

var _step := -1
var _frames := 0
var _current: Node
var _only := ""
var _acted := false


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
	var duel: WizardDuel = _current.call(&"duel") if _current.has_method(&"duel") else null
	var hold: Variant = step.get("at")
	if step.get("duel", false) and duel != null:
		hold = duel.global_position + Vector2(80.0, -10.0)
	if player != null and hold != null and _frames < 40:
		player.global_position = hold
		player.velocity = Vector2.ZERO
		if _frames == 2:
			player.reset_camera()
	if _frames == 30:
		var hud := _current.get_node_or_null(^"Hud") as StageHud
		if hud != null and step.get("pause", false):
			hud.open_pause()
		if hud != null and step.get("clear", false):
			hud.seed_count = 6
			hud.show_passage("The Cheese Shoppe awaits", 41.3, true)
		if hud != null and step.get("final", false):
			hud.show_clear(63.8, false)
		if hud != null and step.get("book", false):
			hud.call(&"_open_spellbook")
		for index: int in step.get("bump", []):
			for block in get_tree().get_nodes_in_group(&"rune_block"):
				if _current.is_ancestor_of(block) and int(block.get(&"index")) == index:
					block.call(&"receive_head_bump")
		for label: String in step.get("bump_label", []):
			for block in get_tree().get_nodes_in_group(&"rune_block"):
				if _current.is_ancestor_of(block) and str(block.get(&"label_text")) == label:
					block.call(&"receive_head_bump")
	if duel != null and not _acted and duel.is_asking() and _frames > 100:
		_act(step, duel)
	if _frames == int(step.get("shot_at", 60)):
		var image := get_viewport().get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("res://tests/shots/tour_%s.png" % step["tag"]))
		print("TOUR shot ", step["tag"])
		_next()


## The duel's part of a step, played once the wizard is asking.
func _act(step: Dictionary, duel: WizardDuel) -> void:
	_acted = true
	var hud := _current.get_node(^"Hud") as StageHud
	for _hint in int(step.get("hints", 0)):
		hud.duel_hint_requested.emit()
	match str(step.get("spell", "")):
		"wave":
			duel.call(&"_cast_wave", 90.0)
		"hex":
			duel.call(&"_cast_hex", duel.player.global_position.x)
	match str(step.get("answer", "")):
		"right":
			duel.block(duel.answer_index()).receive_head_bump()
		"wrong":
			duel.block(posmod(duel.answer_index() + 1, 4)).receive_head_bump()
		"win":
			duel.wizard.wards_left = 1
			duel.block(duel.answer_index()).receive_head_bump()


func _next() -> void:
	get_tree().paused = false
	if _current != null:
		_current.queue_free()
	_step += 1
	_acted = false
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
