extends Node

## Times the real Copperling patrol, then tries approach-and-stomp policies.
## Temporary. The winning windows go into the playtest driver.

const LEVEL := preload("res://levels/level_02.tscn")
const WAIT_X := 1724.0
const LIMIT := 420

var _level: Node = null
var _player: CharacterBody2D = null
var _policies: Array[Dictionary] = []
var _index := -1
var _phase := "boot"
var _frame := 0
var _jump_left := 0
var _jump_cooldown := 0
var _patrol_min := 9999.0
var _patrol_max := 0.0
var _last_dir := 0.0
var _committed := false
var _jumped := false
var _on_plat := false
var _dropped := false
var _jump_px := 0.0
var _jump_ex := 0.0
var _land_px := 0.0
var _land_ex := 0.0
var _land_vx := 0.0
var _prev_px := 0.0
var _prev_py := 0.0
var _prev_ex := 0.0
var _prev_ey := 0.0
var _wins: Array[String] = []


func _init() -> void:
	process_physics_priority = -100


func _ready() -> void:
	process_physics_priority = -100


func _physics_process(_delta: float) -> void:
	_tick_jump()
	if _phase == "boot" or _phase == "reload":
		_spawn_if_clear()
		return
	if _player == null or not is_instance_valid(_player):
		return
	var foe := _active_foe()
	_frame += 1
	if _phase == "patrol":
		_patrol(foe)
		return
	if _phase == "settle":
		_settle()
		return
	_fight(foe)


func _spawn_if_clear() -> void:
	if _level != null and is_instance_valid(_level):
		return
	_level = LEVEL.instantiate()
	add_child(_level)
	_player = _level.get_node(^"Player") as CharacterBody2D
	_reset_policy_flags()
	_frame = 0
	if _index < 0:
		_phase = "patrol"
		_player.set_controls_enabled(false)
		print("PROBE patrol")
	else:
		_phase = "settle"
		_player.set_controls_enabled(true)


func _patrol(foe: CharacterBody2D) -> void:
	_player.global_position = Vector2(WAIT_X, 216)
	_player.velocity = Vector2.ZERO
	if foe == null:
		return
	var ex := foe.global_position.x
	_patrol_min = minf(_patrol_min, ex)
	_patrol_max = maxf(_patrol_max, ex)
	var dir := foe.velocity.x
	if not is_zero_approx(_last_dir) and signf(dir) != signf(_last_dir) and not is_zero_approx(dir):
		print("TURN x=%.0f dir=%.0f" % [ex, dir])
	if not is_zero_approx(dir):
		_last_dir = dir
	if _frame < 240:
		return
	print("PATROL min=%.0f max=%.0f" % [_patrol_min, _patrol_max])
	_build_policies()
	_index = 0
	_begin_reload()


func _build_policies() -> void:
	var built: Array[Dictionary] = []
	built.append(_late_a("a_1756"))
	built.append(_late_a("a_1762"))
	_policies = built


func _jump_spec(policy_name: String, ready: float, j0: float, j1: float, hold: int) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "jump",
		"ready": ready,
		"j0": j0,
		"j1": j1,
		"hold": hold,
		"stomp": "now",
		"wait": WAIT_X,
		"drop": 0.0,
		"plant": 4,
	}


func _away_spec(policy_name: String, stand_x: float, hold: int, enemy_min: float, enemy_max: float) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "away",
		"ready": enemy_min,
		"j0": enemy_min,
		"j1": enemy_max,
		"hold": hold,
		"stomp": "wait",
		"wait": stand_x,
		"drop": 0.0,
		"plant": 8,
	}


func _runaway_spec(policy_name: String, enemy_min: float) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "runaway",
		"ready": enemy_min,
		"j0": 1748.0,
		"j1": 1762.0,
		"hold": 1,
		"stomp": "wait",
		"wait": WAIT_X,
		"drop": 0.0,
		"plant": 8,
	}


func _stand_spec(policy_name: String, ready: float, stand_x: float, hold: int) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "stand",
		"ready": ready,
		"j0": stand_x - 3.0,
		"j1": stand_x + 3.0,
		"hold": hold,
		"stomp": "plant",
		"wait": stand_x,
		"drop": 0.0,
	}


func _drop_spec(policy_name: String, drop_x: float, stomp: String) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "drop",
		"ready": _patrol_max - 2.0,
		"j0": 0.0,
		"j1": 0.0,
		"hold": 0,
		"stomp": stomp,
		"wait": WAIT_X,
		"drop": drop_x,
	}


func _late_a(policy_name: String) -> Dictionary:
	var jump_at := 1762.0
	if policy_name == "a_1756":
		jump_at = 1756.0
	return {
		"name": policy_name,
		"kind": "runaway",
		"band": "a",
		"ready": 1830.0,
		"j0": jump_at,
		"j1": jump_at + 14.0,
		"hold": 1,
		"stomp": "wait",
		"wait": 1724.0,
		"drop": 0.0,
		"plant": 8,
		"plant_x": 1816.0,
		"land_x": 1796.0,
	}


func _b_spec(policy_name: String, ready: float, hold: int, plant_x: float) -> Dictionary:
	return {
		"name": policy_name,
		"kind": "runaway",
		"band": "b",
		"ready": ready,
		"j0": 1864.0,
		"j1": 1876.0,
		"hold": hold,
		"stomp": "wait",
		"wait": 1848.0,
		"drop": 0.0,
		"plant": 8,
		"plant_x": plant_x,
		"land_x": 1924.0,
	}


func _settle() -> void:
	if _frame == 1:
		if str(_policies[_index]["band"]) == "b":
			_park_a()
		var spot := float(_policies[_index]["wait"])
		_player.global_position = Vector2(spot, 216)
		_player.velocity = Vector2.ZERO
		_player.jump_buffer_timer = 0.0
		_release_input()
	if _frame < 12:
		return
	if not _player.is_on_floor():
		if _frame > 40:
			_finish("NOFLOOR", _foe())
		return
	print("FIGHT %s" % str(_policies[_index]["name"]))
	_phase = "fight"
	_frame = 0


func _fight(foe: CharacterBody2D) -> void:
	var px := _player.global_position.x
	var py := _player.global_position.y
	if foe != null:
		_prev_ex = foe.global_position.x
		_prev_ey = foe.global_position.y
	if _frame > 8 and (px < 1500.0 or py > 270.0):
		_finish("DIE", foe)
		return
	if _frame > 8 and foe == null and _on_plat:
		_finish("STOMP", null)
		return
	if _frame >= LIMIT:
		_finish("TIMEOUT", foe)
		return
	_set_move(_axis(foe))
	_prev_px = px
	_prev_py = py


func _drop_axis(foe: CharacterBody2D, spec: Dictionary) -> float:
	if not _dropped:
		_player.global_position = Vector2(WAIT_X, 216)
		_player.velocity = Vector2.ZERO
		var ready := foe.global_position.x >= float(spec["ready"]) and foe.velocity.x < 0.0
		if not ready:
			return 0.0
		_player.global_position = Vector2(float(spec["drop"]), 190)
		_player.velocity = Vector2(0, 40)
		_dropped = true
		_jump_px = float(spec["drop"])
		_jump_ex = foe.global_position.x
		return 0.0
	if _player.global_position.x > 1808.0 and _player.is_on_floor():
		if not _on_plat:
			_on_plat = true
			_land_px = _player.global_position.x
			_land_ex = foe.global_position.x
		return _stomp_axis(foe, str(spec["stomp"]))
	return 0.0


func _jump_axis(foe: CharacterBody2D, spec: Dictionary) -> float:
	var x := _player.global_position.x
	var ready := foe.global_position.x >= float(spec["ready"]) and foe.velocity.x < 0.0
	if not _committed:
		if not ready:
			return _hold_at(x, WAIT_X)
		_committed = true
	if not _jumped and _player.is_on_floor() and x >= float(spec["j0"]) and x <= float(spec["j1"]):
		_start_jump(int(spec["hold"]))
		_jumped = true
		_jump_px = x
		_jump_ex = foe.global_position.x
	return _after_takeoff(foe)


func _axis(foe: CharacterBody2D) -> float:
	if foe == null:
		return 0.0
	var spec := _policies[_index]
	var kind := str(spec["kind"])
	if kind == "drop":
		return _drop_axis(foe, spec)
	if kind == "away":
		return _away_axis(foe, spec)
	if kind == "runaway":
		return _runaway_axis(foe, spec)
	if kind == "stand":
		return _stand_axis(foe, spec)
	return _jump_axis(foe, spec)


func _away_axis(foe: CharacterBody2D, spec: Dictionary) -> float:
	var x := _player.global_position.x
	if not _committed:
		var spot := float(spec["wait"])
		if not _player.is_on_floor() or absf(x - spot) > 6.0:
			return _hold_at(x, spot)
		if absf(_player.velocity.x) > 16.0:
			return 0.0
		var ex := foe.global_position.x
		var going_away := foe.velocity.x > 0.0 and ex >= float(spec["j0"]) and ex <= float(spec["j1"])
		if not going_away:
			return 0.0
		_start_jump(int(spec["hold"]))
		_committed = true
		_jumped = true
		_jump_px = x
		_jump_ex = ex
		return 1.0
	return _after_takeoff(foe)


func _runaway_axis(foe: CharacterBody2D, spec: Dictionary) -> float:
	var x := _player.global_position.x
	if not _committed:
		var going_away := foe.velocity.x > 0.0 and foe.global_position.x >= float(spec["ready"])
		if not going_away:
			return _hold_at(x, float(spec["wait"]))
		_committed = true
	if not _jumped and _player.is_on_floor() and x >= float(spec["j0"]) and x <= float(spec["j1"]):
		_start_jump(int(spec["hold"]))
		_jumped = true
		_jump_px = x
		_jump_ex = foe.global_position.x
	return _after_takeoff(foe)


func _stand_axis(foe: CharacterBody2D, spec: Dictionary) -> float:
	var x := _player.global_position.x
	if not _committed:
		if not _player.is_on_floor():
			return _hold_at(x, float(spec["wait"]))
		if absf(x - float(spec["wait"])) > 4.0:
			return _hold_at(x, float(spec["wait"]))
		if absf(_player.velocity.x) > 16.0:
			return 0.0
		var ready := foe.global_position.x >= float(spec["ready"]) and foe.velocity.x < 0.0
		if not ready:
			return 0.0
		_start_jump(int(spec["hold"]))
		_committed = true
		_jumped = true
		_jump_px = x
		_jump_ex = foe.global_position.x
		return 1.0
	return _after_takeoff(foe)


func _after_takeoff(foe: CharacterBody2D) -> float:
	if _on_plat:
		return _plant_axis(foe)
	var land_x := float(_policies[_index]["land_x"])
	if _player.global_position.x > land_x and _player.is_on_floor() and _player.global_position.y < 240.0:
		_on_plat = true
		_land_px = _player.global_position.x
		_land_ex = foe.global_position.x
		_land_vx = _player.velocity.x
		return _plant_axis(foe)
	return 1.0


func _plant_axis(foe: CharacterBody2D) -> float:
	var spec := _policies[_index]
	var x := _player.global_position.x
	var dx := foe.global_position.x - x
	var on_floor := _player.is_on_floor()
	var closing := foe.velocity.x <= 0.0
	if str(spec["stomp"]) == "now":
		if on_floor and closing and dx > 6.0 and dx < 42.0:
			_start_jump(int(spec["plant"]))
		return 0.0
	var plant_x := float(spec["plant_x"])
	if on_floor and plant_x > 0.0 and x < plant_x and foe.velocity.x > 0.0 and dx > 18.0:
		return 1.0
	if on_floor and closing and dx > 8.0 and dx < 34.0 and absf(_player.velocity.x) < 36.0:
		_start_jump(int(spec["plant"]))
	return 0.0


func _hold_at(x: float, wait_x: float) -> float:
	if x < wait_x - 6.0:
		return 1.0
	if x > wait_x + 6.0:
		return -1.0
	return 0.0


func _stomp_axis(foe: CharacterBody2D, mode: String) -> float:
	var dx := foe.global_position.x - _player.global_position.x
	var on_floor := _player.is_on_floor()
	var closing := foe.velocity.x <= 0.0
	if mode == "chase":
		if on_floor and dx > 6.0 and dx < 34.0 and closing:
			_start_jump(8)
		if dx > 22.0:
			return 1.0
		if dx < -6.0:
			return 1.0
		return 0.0
	if on_floor and dx > 8.0 and dx < 32.0 and closing and absf(_player.velocity.x) < 36.0:
		_start_jump(8)
	if dx < -10.0:
		return 1.0
	return 0.0


func _finish(result: String, foe: CharacterBody2D) -> void:
	var spec := _policies[_index]
	var ex := _prev_ex
	var ey := _prev_ey
	if foe != null:
		ex = foe.global_position.x
		ey = foe.global_position.y
	print(
		"RESULT %s %s f=%d jump=%.0f,%.0f land=%.0f,%.0f vx=%.0f end=%.0f,%.0f foe=%.0f,%.0f"
		% [
			str(spec["name"]),
			result,
			_frame,
			_jump_px,
			_jump_ex,
			_land_px,
			_land_ex,
			_land_vx,
			_prev_px,
			_prev_py,
			ex,
			ey,
		]
	)
	if result == "STOMP":
		_wins.append(str(spec["name"]))
	_index += 1
	if _index >= _policies.size():
		print("PROBE wins=%d %s" % [_wins.size(), _win_line()])
		get_tree().quit(0 if _wins.size() > 0 else 1)
		return
	_begin_reload()


func _win_line() -> String:
	var line := ""
	for policy_name in _wins:
		if line != "":
			line += " "
		line += policy_name
	return line


func _begin_reload() -> void:
	_release_input()
	if _level != null and is_instance_valid(_level):
		_level.queue_free()
	_level = null
	_player = null
	_phase = "reload"
	_frame = 0


func _reset_policy_flags() -> void:
	_committed = false
	_jumped = false
	_on_plat = false
	_dropped = false
	_jump_px = 0.0
	_jump_ex = 0.0
	_land_px = 0.0
	_land_ex = 0.0
	_land_vx = 0.0
	_jump_left = 0
	_jump_cooldown = 0
	_prev_px = WAIT_X
	_prev_py = 216.0


func _active_foe() -> CharacterBody2D:
	if _index >= 0 and str(_policies[_index]["band"]) == "b":
		return _foe_between(1920.0, 2200.0)
	return _foe()


func _park_a() -> void:
	for node in get_tree().get_nodes_in_group(&"copperling"):
		var body := node as CharacterBody2D
		if body == null or body.global_position.x > 1920.0:
			continue
		body.set_physics_process(false)
		body.collision_layer = 0
		body.collision_mask = 0
		body.global_position = Vector2(-200, -200)


func _foe() -> CharacterBody2D:
	return _foe_between(0.0, 1920.0)


func _foe_between(x0: float, x1: float) -> CharacterBody2D:
	var found: CharacterBody2D = null
	for node in get_tree().get_nodes_in_group(&"copperling"):
		if node.is_queued_for_deletion():
			continue
		var body := node as CharacterBody2D
		if body == null or not body.is_in_group(&"stompable"):
			continue
		var enemy_x := body.global_position.x
		if enemy_x >= x0 and enemy_x < x1:
			found = body
	return found


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


func _release_input() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")


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
