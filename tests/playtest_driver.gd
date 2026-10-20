extends Node

@export var level_scene: PackedScene
@export var section_spawn: Vector2 = Vector2(-1, -1)
@export var section_limit: int = 0
@export var section_goal: String = "cache"

var _player: CharacterBody2D
var _hud: StageHud
var _stage_index: int = 0
var _frames: int = 0
var _l1_gap: bool = false
var _l1_stomp: bool = false
var _l1_bump: bool = false
var _l1_break: bool = false
var _l1_pickup: bool = false
var _l1_gate: bool = false
var _l2_gap: bool = false
var _l2_stomp: bool = false
var _l2_bump: bool = false
var _l2_break: bool = false
var _l2_pickup: bool = false
var _l2_gate: bool = false
var _jump_left: int = 0
var _jump_cooldown: int = 0
var _crossed_gap: bool = false
var _saw_enemy: bool = false
var _stomped: bool = false
var _bumped: bool = false
var _saw_clay: bool = false
var _broke: bool = false
var _collected: bool = false
var _a_landed: bool = false
var _b_landed: bool = false
var _kiln_landed: bool = false
var _span_hold_hop: bool = false
var _span_clay_hop: bool = false
var _shot_queue: Array[String] = []
var _shots: Dictionary = {}
var _done_frames: int = -1
var _result_ok: bool = false


func _init() -> void:
	process_physics_priority = -100


func _ready() -> void:
	process_physics_priority = -100
	# Chain the stages directly instead of returning to the world map,
	# and keep the bot's clears out of the player's save.
	GameProgression.came_from_map = false
	GameProgression.persist = false
	GameProgression.load_data()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	if level_scene == null:
		push_error("Playtest is missing the level scene")
		get_tree().quit(1)
		return
	add_child(level_scene.instantiate())
	if section_limit > 0 and section_goal != "clear" and section_goal != "route":
		for node in get_tree().get_nodes_in_group(&"copperling"):
			node.remove_from_group(&"copperling")
			node.set_physics_process(false)
			node.set(&"collision_layer", 0)
			node.set(&"collision_mask", 0)
			node.queue_free()
	if not _sync_stage():
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
	if not _sync_stage():
		if _frames > 30:
			push_error("Playtest lost the stage")
			_finish_soon(false)
		return
	_tick_jump()
	_refresh_flags()
	if section_limit > 0 and _frames <= 8:
		_player.global_position = section_spawn
		_player.velocity = Vector2.ZERO
		_set_move(0.0)
		Input.action_release(&"jump")
		return
	if section_limit > 0 and _section_done():
		return
	if _stage_index == 3 and _hud.is_cleared():
		_finish_soon(_level_one_clear() and _level_two_clear() and _crossed_gap and _stomped and _bumped and _broke and _collected)
		return
	if _frames > 160 * 60:
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
			"PLAYTEST t=%s stage=%s x=%.0f y=%.0f vx=%.0f axis=%.0f enemy=%.0f,%.0f floor=%s gap=%s stomp=%s bump=%s break=%s pickup=%s"
			% [
				_frames / 60,
				_stage_index,
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
	if _stage_index == 2:
		_steer_span()
	elif _stage_index == 3:
		_steer_kiln()
	else:
		_steer()


func _process(_delta: float) -> void:
	if _shot_queue.is_empty():
		return
	var tag := str(_shot_queue.pop_front())
	if DisplayServer.get_name() == "headless":
		return
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


func _sync_stage() -> bool:
	var stage := _living_in_group(&"stage")
	if stage == null:
		return false
	var index := int(stage.call(&"stage_index"))
	var player_ok := _player != null and is_instance_valid(_player) and not _player.is_queued_for_deletion()
	if index == _stage_index and player_ok:
		return true
	if _stage_index == 1:
		_l1_gap = _crossed_gap
		_l1_stomp = _stomped
		_l1_bump = _bumped
		_l1_break = _broke
		_l1_pickup = _collected
		_l1_gate = true
		print("PLAYTEST enter Cinder Span")
	elif _stage_index == 2:
		_l2_gap = _crossed_gap
		_l2_stomp = _stomped
		_l2_bump = _bumped
		_l2_break = _broke
		_l2_pickup = _collected
		_l2_gate = true
		print("PLAYTEST enter Kiln Mouth")
	_stage_index = index
	_crossed_gap = false
	_saw_enemy = false
	_stomped = false
	_bumped = false
	_saw_clay = false
	_broke = false
	_collected = false
	_jump_left = 0
	_jump_cooldown = 0
	_a_landed = false
	_b_landed = false
	_kiln_landed = false
	_span_hold_hop = false
	_span_clay_hop = false
	Input.action_release(&"jump")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	var player := _living_in_group(&"player") as CharacterBody2D
	var hud := _living_in_group(&"stage_hud") as StageHud
	_player = player
	_hud = hud
	return _player != null and _hud != null


func _living_in_group(group_name: StringName) -> Node:
	var found: Node = null
	for node in get_tree().get_nodes_in_group(group_name):
		if node.is_queued_for_deletion():
			continue
		found = node
	return found


func _level_one_clear() -> bool:
	return _l1_gap and _l1_stomp and _l1_bump and _l1_break and _l1_pickup and _l1_gate


func _level_two_clear() -> bool:
	return _l2_gap and _l2_stomp and _l2_bump and _l2_break and _l2_pickup and _l2_gate


func _refresh_flags() -> void:
	var position := _player.global_position
	var crossed := false
	if _stage_index == 2:
		crossed = position.x > 580.0 and position.y > 190.0 and position.y < 250.0
	elif _stage_index == 3:
		crossed = position.x > 700.0 and position.y > 190.0 and position.y < 250.0
	else:
		crossed = position.x > 260.0 and position.y < 250.0
	if crossed and not _crossed_gap:
		_crossed_gap = true
		_shot("gap")
	if _hud.passage_shown:
		_shot("passage")
	var enemy := get_tree().get_first_node_in_group(&"copperling")
	if enemy != null:
		_saw_enemy = true
	elif _saw_enemy and not _stomped:
		_stomped = true
		_shot("stomp")
	if _cache_spent() and not _bumped:
		_bumped = true
		_span_hold_hop = true
		_shot("bump")
	var clay := get_tree().get_nodes_in_group(&"clay_brick")
	if not clay.is_empty():
		_saw_clay = true
	elif _saw_clay and not _broke:
		_broke = true
		_span_clay_hop = true
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


func _section_done() -> bool:
	var finished := false
	var ok := false
	if section_goal == "clear" or section_goal == "route":
		finished = _hud.is_cleared() or _frames >= section_limit
		ok = _hud.is_cleared() and _stomped and _bumped and _broke
		if section_goal == "route":
			ok = ok and _collected
	elif section_goal == "span_exit":
		var parked := (
			_broke
			and _player.is_on_floor()
			and _player.global_position.x > 2500.0
			and _player.global_position.y < 230.0
		)
		finished = parked or _frames >= section_limit
		ok = parked and _bumped
	else:
		finished = _cache_spent() or _frames >= section_limit
		ok = _cache_spent()
	if not finished:
		return false
	print(
		"SECTION result=%s x=%.0f y=%.0f vx=%.0f t=%d stomp=%s bump=%s break=%s pickup=%s goal=%s"
		% [
			"ok" if ok else "fail",
			_player.global_position.x,
			_player.global_position.y,
			_player.velocity.x,
			_frames,
			_stomped,
			_bumped,
			_broke,
			_collected,
			_hud.is_cleared(),
		]
	)
	get_tree().quit(0 if ok else 1)
	return true


func _steer_kiln() -> void:
	var x := _player.global_position.x
	var y := _player.global_position.y
	var on_floor := _player.is_on_floor()
	if y > 260.0:
		_set_move(0.0)
		return
	if on_floor and _jump_left == 0:
		_jump_cooldown = 0
	if x < 400.0:
		_kiln_landed = false
	if y > 226.0:
		if on_floor and x > 336.0 and x < 356.0:
			_start_jump(1)
		_set_move(1.0)
		return
	if x < 140.0:
		if on_floor and x >= 100.0 and x < 112.0:
			_start_jump(8)
		_set_move(1.0)
		return
	if x < 620.0:
		if on_floor and x >= 592.0 and x < 604.0:
			_start_jump(1)
		_set_move(1.0)
		return
	if x < 860.0:
		if on_floor and x >= 752.0 and x < 764.0:
			_start_jump(1)
		if on_floor and x >= 848.0 and x < 860.0:
			_start_jump(1)
		_set_move(1.0)
		return
	if x < 1136.0:
		_steer_kiln_island(x, on_floor)
		return
	if not _bumped and x < 1260.0:
		_set_move(_line_up_and_jump(x, 1200.0, on_floor))
		return
	if not _broke:
		if not on_floor and _bumped:
			_set_move(0.0)
			return
		_set_move(_line_up_and_jump(x, 1296.0, on_floor))
		return
	if not on_floor and x < 1376.0:
		_set_move(0.0)
		return
	if on_floor and x >= 1344.0 and x < 1356.0:
		_start_jump(1)
	_set_move(1.0)


func _steer_kiln_island(x: float, on_floor: bool) -> void:
	var foe := _kiln_foe()
	if on_floor and x > 1016.0 and x < 1090.0:
		_kiln_landed = true
	if not _kiln_landed:
		if not on_floor and x > 970.0:
			_set_move(1.0)
			return
		if foe == null:
			if on_floor and x >= 976.0 and x < 990.0:
				_start_jump(1)
			_set_move(1.0)
			return
		if not _kiln_release(foe):
			if x < 930.0:
				_set_move(1.0)
			elif x > 956.0:
				_set_move(-1.0)
			elif x > 944.0:
				_set_move(0.0)
			else:
				_set_move(1.0)
			return
		if on_floor and x >= 976.0 and x < 990.0 and _kiln_opening(foe):
			_start_jump(1)
		_set_move(1.0)
		return
	if foe == null:
		if not on_floor and x < 1090.0:
			_set_move(0.0)
			return
		if on_floor and x >= 1104.0 and x < 1116.0:
			_start_jump(1)
		_set_move(1.0)
		return
	_set_move(0.0)
	if not on_floor:
		return
	var dx := foe.global_position.x - x
	if dx > 4.0 and dx < 30.0 and foe.velocity.x < 0.0 and absf(_player.velocity.x) < 40.0:
		_start_jump(8)


func _kiln_release(foe: CharacterBody2D) -> bool:
	return foe.velocity.x > 0.0 and foe.global_position.x > 1064.0 and foe.global_position.x < 1076.0


func _kiln_opening(foe: CharacterBody2D) -> bool:
	return foe.velocity.x > 0.0 and foe.global_position.x > 1056.0 and foe.global_position.x < 1090.0


func _kiln_foe() -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group(&"copperling"):
		if node.is_queued_for_deletion():
			continue
		return node as CharacterBody2D
	return null


func _steer_span() -> void:
	var x := _player.global_position.x
	var y := _player.global_position.y
	var on_floor := _player.is_on_floor()
	if y > 260.0:
		_set_move(0.0)
		return
	# A human can jump again on landing. The driver's cooldown is only anti-mash.
	if on_floor and _jump_left == 0:
		_jump_cooldown = 0
	if y > 226.0 and x < 960.0:
		if on_floor and x > 904.0 and x < 922.0:
			_start_jump(4)
		_set_move(1.0)
		return
	if y > 120.0 and y < 160.0 and x > 1480.0 and x < 1560.0:
		if on_floor and x > 1530.0:
			_start_jump(1)
		_set_move(1.0)
		return
	if y > 168.0 and y < 205.0 and x > 1064.0 and x < 1140.0:
		if on_floor and x > 1088.0:
			_start_jump(8)
		_set_move(1.0)
		return
	if y > 170.0 and y < 205.0 and x > 1404.0 and x < 1476.0:
		if on_floor and x > 1436.0 and x < 1452.0:
			_start_jump(14)
		_set_move(1.0)
		return
	if y > 192.0 and y < 210.0 and x > 1320.0 and x < 1380.0:
		if on_floor and x > 1362.0 and x < 1378.0:
			_start_jump(1)
		_set_move(1.0)
		return
	if x < 400.0:
		_a_landed = false
		_b_landed = false
		_span_hold_hop = false
		_span_clay_hop = false
	if x > 1688.0 and (x < 2040.0 or _span_crawler(1700.0, 2100.0) != null):
		_set_move(_span_fight(x, on_floor))
		return
	var move := _span_ground(x, y, on_floor)
	_set_move(move)


func _span_ground(x: float, y: float, on_floor: bool) -> float:
	if _span_hold_hop and not on_floor and x > 2200.0:
		return 0.0
	if _span_clay_hop and not on_floor and x > 2300.0:
		return 0.0
	if y <= 205.0 or y >= 245.0:
		return 1.0
	if x < 140.0:
		if on_floor and x > 92.0 and x < 108.0:
			_start_jump(8)
		return 1.0
	if x < 300.0:
		if on_floor and x > 372.0:
			return 1.0
		if on_floor and x > 258.0 and x < 276.0:
			_start_jump(1)
		return 1.0
	if x < 470.0:
		if on_floor and x > 372.0 and x < 386.0:
			_start_jump(1)
		if on_floor and x > 452.0 and x < 466.0:
			_start_jump(40)
		return 1.0
	if x < 720.0:
		if on_floor and x > 684.0 and x < 696.0:
			_start_jump(1)
		return 1.0
	if x < 1040.0:
		if on_floor and x > 996.0 and x < 1012.0:
			_start_jump(8)
		return 1.0
	if x < 1320.0:
		if on_floor and x > 1284.0 and x < 1298.0:
			_start_jump(1)
		return 1.0
	if x < 1688.0:
		if on_floor and x > 1648.0 and x < 1666.0:
			_start_jump(1)
		return 1.0
	if x < 2210.0:
		if on_floor and x > 2178.0 and x < 2194.0:
			_start_jump(1)
		return 1.0
	if not _bumped and x < 2300.0:
		var cache_move := _line_up_and_jump(x, 2248.0, on_floor)
		if _jump_left > 0:
			_span_hold_hop = true
		return cache_move
	if not _broke and x < 2340.0:
		if _span_hold_hop and not on_floor:
			return 0.0
		if _span_hold_hop and on_floor:
			_span_hold_hop = false
		if on_floor and x > 2274.0 and x < 2292.0:
			_start_jump(16)
		return 1.0
	if not _broke and x < 2460.0:
		var clay_move := _line_up_and_jump(x, 2392.0, on_floor)
		if _jump_left > 0:
			_span_clay_hop = true
		return clay_move
	if _span_clay_hop and not on_floor:
		return 0.0
	if _span_clay_hop and on_floor:
		_span_clay_hop = false
	if on_floor and x > 2418.0 and x < 2436.0:
		_start_jump(4)
	return 1.0


func _span_fight(x: float, on_floor: bool) -> float:
	if on_floor and x > 1808.0 and x < 1900.0:
		_a_landed = true
	if on_floor and x > 1936.0 and x < 2100.0:
		_b_landed = true
	var foe_a := _span_crawler(1780.0, 1900.0)
	if foe_a != null or x < 1900.0:
		return _span_fight_a(foe_a, x, on_floor)
	return _span_fight_b(x, on_floor)


func _span_fight_a(foe: CharacterBody2D, x: float, on_floor: bool) -> float:
	if foe == null:
		return _span_fight_b(x, on_floor)
	if not _a_landed:
		if not on_floor:
			return 1.0
		var away := foe.global_position.x >= 1830.0 and foe.velocity.x > 0.0
		if away:
			if x > 1756.0 and x < 1768.0:
				_start_jump(1)
			return 1.0
		return _hold_span(x, 1724.0, 1712.0)
	if not on_floor:
		return 0.0
	return _span_plant(foe, x, 1816.0)


func _span_fight_b(x: float, on_floor: bool) -> float:
	var foe := _span_crawler(1920.0, 2100.0)
	if foe == null:
		if on_floor and x > 1998.0 and x < 2018.0:
			_start_jump(40)
		return 1.0
	if not _b_landed:
		# The stomp on Copperling A leaves the body airborne. Running here
		# walks off that platform before the next jump is ready.
		if x < 1900.0 and not on_floor:
			return 0.0
		if not on_floor:
			return 1.0
		var away := foe.global_position.x >= 1988.0 and foe.velocity.x > 0.0
		if away:
			if x > 1864.0 and x < 1876.0:
				_start_jump(1)
			return 1.0
		return _hold_span(x, 1848.0, 1824.0)
	if not on_floor:
		return 0.0
	return _span_plant(foe, x, 1956.0)


func _span_plant(foe: CharacterBody2D, x: float, plant_x: float) -> float:
	var dx := foe.global_position.x - x
	if x < plant_x and foe.velocity.x > 0.0 and dx > 18.0:
		return 1.0
	if foe.velocity.x <= 0.0 and dx > 8.0 and dx < 34.0 and absf(_player.velocity.x) < 36.0:
		_start_jump(8)
	return 0.0


func _hold_span(x: float, target: float, left_limit: float) -> float:
	if x < left_limit:
		return 1.0
	if x < target - 6.0:
		return 1.0
	if x > target + 6.0:
		return -1.0
	return 0.0


func _span_crawler(x0: float, x1: float) -> CharacterBody2D:
	for node in get_tree().get_nodes_in_group(&"copperling"):
		if node.is_queued_for_deletion():
			continue
		var body := node as CharacterBody2D
		if body == null:
			continue
		var enemy_x := body.global_position.x
		if enemy_x >= x0 and enemy_x <= x1:
			return body
	return null


func _hop(on_floor: bool, x: float, y: float, y_min: float, y_max: float, x_min: float, x_max: float, frames: int) -> void:
	if on_floor and y > y_min and y < y_max and x > x_min and x < x_max:
		_start_jump(frames)


func _cross_to_crawler(x: float, enemy: CharacterBody2D) -> float:
	var opening := enemy.global_position.x > 1510.0 and enemy.velocity.x > 0.0
	if not opening:
		if x > 1384.0:
			return -1.0
		if x < 1348.0:
			return 1.0
		return 0.0
	if x > 1404.0:
		_start_jump(8)
	return 1.0


func _stomp_crawler(x: float, on_floor: bool, enemy: CharacterBody2D) -> float:
	if x < 1488.0:
		return 1.0
	if x > 1544.0:
		return -1.0
	var dx := enemy.global_position.x - x
	var closing := dx * enemy.velocity.x <= 16.0
	if on_floor and absf(_player.velocity.x) < 36.0 and absf(dx) < 22.0 and closing:
		_start_jump(10)
	return 0.0


func _line_up_and_jump(x: float, target: float, on_floor: bool) -> float:
	var dx := target - x
	if absf(dx) <= 8.0 and absf(_player.velocity.x) < 28.0 and on_floor:
		_start_jump(30)
		return 0.0
	if absf(dx) <= 8.0:
		return 0.0
	return signf(dx)


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
	if _hud != null and is_instance_valid(_hud):
		goal_open = _hud.is_cleared()
	print(
		"PLAYTEST result=%s l1=%s,%s,%s,%s,%s,%s l2=%s,%s,%s,%s,%s,%s l3=%s,%s,%s,%s,%s goal=%s"
		% [
			"ok" if _result_ok else "fail",
			_l1_gap,
			_l1_stomp,
			_l1_bump,
			_l1_break,
			_l1_pickup,
			_l1_gate,
			_l2_gap,
			_l2_stomp,
			_l2_bump,
			_l2_break,
			_l2_pickup,
			_l2_gate,
			_crossed_gap,
			_stomped,
			_bumped,
			_broke,
			_collected,
			goal_open,
		]
	)
	get_tree().quit(0 if _result_ok else 1)
