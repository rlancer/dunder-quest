extends Node

@export var level_scene: PackedScene

var _player: CharacterBody2D
var _hud: StageHud
var _frames: int = 0
var _jump_left: int = 0
var _jump_cooldown: int = 0
var _crossed_gap: bool = false
var _saw_enemy: bool = false
var _stomped: bool = false
var _bumped: bool = false
var _saw_clay: bool = false
var _broke: bool = false
var _collected: bool = false
var _shot_queue: Array[String] = []
var _shots: Dictionary = {}
var _done_frames: int = -1
var _result_ok: bool = false


func _init() -> void:
	process_physics_priority = -100


func _ready() -> void:
	process_physics_priority = -100
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	if level_scene == null:
		push_error("Playtest is missing the level scene")
		get_tree().quit(1)
		return
	add_child(level_scene.instantiate())
	_player = get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	_hud = get_tree().get_first_node_in_group(&"stage_hud") as StageHud
	if _player == null or _hud == null:
		push_error("Playtest could not find the player or HUD")
		get_tree().quit(1)
		return
	_shot("start")
	print("PLAYTEST start")


func _physics_process(_delta: float) -> void:
	if _done_frames == 0:
		_report()
		return
	if _done_frames > 0:
		if _done_frames == 12:
			_shot("goal" if _result_ok else "fail")
		_done_frames -= 1
		return
	_frames += 1
	_tick_jump()
	if _player == null or _hud == null:
		return
	_refresh_flags()
	if _hud.is_cleared():
		_finish_soon(_crossed_gap and _stomped and _bumped and _broke and _collected)
		return
	if _frames > 70 * 60:
		_shot("fail")
		_finish_soon(false)
		return
	if _frames % 60 == 0:
		var enemy := get_tree().get_first_node_in_group(&"copperling") as Node2D
		var enemy_x := -1.0
		var enemy_y := -1.0
		if enemy != null:
			enemy_x = enemy.global_position.x
			enemy_y = enemy.global_position.y
		print(
			"PLAYTEST t=%s x=%.0f y=%.0f vx=%.0f axis=%.0f enemy=%.0f,%.0f floor=%s gap=%s stomp=%s bump=%s break=%s pickup=%s"
			% [
				_frames / 60,
				_player.global_position.x,
				_player.global_position.y,
				_player.velocity.x,
				Input.get_axis(&"move_left", &"move_right"),
				enemy_x,
				enemy_y,
				_player.is_on_floor(),
				_crossed_gap,
				_stomped,
				_bumped,
				_broke,
				_collected,
			]
		)
	_steer()


func _process(_delta: float) -> void:
	if _shot_queue.is_empty():
		return
	var tag := str(_shot_queue.pop_front())
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		print("PLAYTEST shot empty ", tag)
		return
	var path := ProjectSettings.globalize_path("res://tests/shots/%s.png" % tag)
	image.save_png(path)
	print("PLAYTEST shot ", tag)


func _refresh_flags() -> void:
	var position := _player.global_position
	if position.x > 260.0 and position.y < 250.0 and not _crossed_gap:
		_crossed_gap = true
		_shot("gap")
	var enemy := get_tree().get_first_node_in_group(&"copperling")
	if enemy != null:
		_saw_enemy = true
	elif _saw_enemy and not _stomped:
		_stomped = true
		_shot("stomp")
	if _cache_spent() and not _bumped:
		_bumped = true
		_shot("bump")
	var clay := get_tree().get_nodes_in_group(&"clay_brick")
	if not clay.is_empty():
		_saw_clay = true
	elif _saw_clay and not _broke:
		_broke = true
		_shot("break")
	if _hud.seed_count > 0 and not _collected:
		_collected = true
		_shot("pickup")


func _steer() -> void:
	var x := _player.global_position.x
	var y := _player.global_position.y
	var on_floor := _player.is_on_floor()
	var move := 1.0
	if y > 300.0:
		_set_move(0.0)
		return
	if on_floor and y > 200.0 and x > 165.0 and x < 198.0:
		_start_jump(22)
	if on_floor and y > 200.0 and x > 300.0 and x < 348.0:
		_start_jump(16)

	var enemy := get_tree().get_first_node_in_group(&"copperling") as CharacterBody2D
	if not _stomped:
		if enemy != null and y < 205.0 and x > 330.0 and x < 510.0:
			move = _stomp_move(enemy, x, on_floor)
		elif x > 500.0:
			move = -1.0
	elif not _bumped:
		if x > 560.0:
			move = -1.0
		if y > 180.0 and x > 500.0 and x < 575.0:
			_start_jump(26)
	elif not _broke:
		if x < 600.0:
			move = 1.0
		elif x > 628.0:
			move = -1.0
		else:
			move = 0.0
			if on_floor and y > 200.0:
				_start_jump(26)
	elif x < 900.0:
		if on_floor and y > 200.0 and x > 710.0 and x < 765.0:
			_start_jump(22)
	_set_move(move)


func _stomp_move(enemy: CharacterBody2D, x: float, on_floor: bool) -> float:
	if x < 390.0:
		return 1.0
	if x > 440.0:
		return -1.0
	var dx := enemy.global_position.x - x
	if absf(dx) > 50.0:
		if is_zero_approx(dx):
			return 0.0
		return signf(dx)
	var closing := dx * enemy.velocity.x <= 12.0
	if on_floor and absf(_player.velocity.x) < 40.0 and absf(dx) < 32.0 and closing:
		_start_jump(14)
	return 0.0


func _cache_spent() -> bool:
	var block := get_tree().get_first_node_in_group(&"cache_stone")
	return block != null and bool(block.get(&"spent"))


func _set_move(direction: float) -> void:
	if direction < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	elif direction > 0.0:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")
	else:
		Input.action_release(&"move_left")
		Input.action_release(&"move_right")


func _start_jump(frames: int) -> void:
	if _jump_left > 0 or _jump_cooldown > 0:
		return
	if not Input.is_action_pressed(&"jump"):
		Input.action_press(&"jump")
	_jump_left = frames
	_jump_cooldown = frames + 8


func _tick_jump() -> void:
	if _jump_cooldown > 0:
		_jump_cooldown -= 1
	if _jump_left <= 0:
		return
	_jump_left -= 1
	if _jump_left == 0:
		Input.action_release(&"jump")
	else:
		Input.action_press(&"jump")


func _shot(tag: String) -> void:
	if _shots.has(tag):
		return
	_shots[tag] = true
	_shot_queue.append(tag)


func _finish_soon(ok: bool) -> void:
	if _done_frames >= 0:
		return
	_result_ok = ok
	_done_frames = 20
	_set_move(0.0)
	Input.action_release(&"jump")


func _report() -> void:
	_done_frames = -2
	var goal_open := false
	if _hud != null:
		goal_open = _hud.is_cleared()
	print(
		"PLAYTEST result=%s gap=%s stomp=%s bump=%s break=%s pickup=%s goal=%s"
		% [
			"ok" if _result_ok else "fail",
			_crossed_gap,
			_stomped,
			_bumped,
			_broke,
			_collected,
			goal_open,
		]
	)
	get_tree().quit(0 if _result_ok else 1)
