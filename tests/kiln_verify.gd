extends Node

## Headless measurement of Kiln Mouth.
## Scans the live tilemap, then runs the real player at real jump holds.

const HOLDS: Array[int] = [1, 4, 8, 40]

var _level: Node2D
var _tiles: TileMapLayer
var _player: CharacterBody2D
var _spawn := Vector2.ZERO
var _surfaces: Array[Dictionary] = []
var _trials: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _failures: Array[String] = []
var _seeds: Array[Vector2] = []
var _teach_shelf: Dictionary = {}
var _pit_shelf: Dictionary = {}
var _supported_ember: Dictionary = {}
var _open_ember: Dictionary = {}
var _roof: Dictionary = {}
var _island: Dictionary = {}
var _cache_pos := Vector2.ZERO
var _clay_pos := Vector2.ZERO
var _gate_pos := Vector2.ZERO
var _foe_home := Vector2.ZERO
var _trial := 0
var _frame := 0
var _jump_left := 0
var _jumped := false
var _airborne := false
var _floor_run := 0
var _min_y := 0.0
var _start_floor := false
var _actor_pos := Vector2(-1, -1)
var _reported := false
var _stomp_phase := 0
var _stomp_floor := 0
var _seed_before := 0


func _init() -> void:
	process_physics_priority = -100


func _ready() -> void:
	process_physics_priority = -100
	var packed := load("res://levels/level_03.tscn") as PackedScene
	_level = packed.instantiate() as Node2D
	add_child(_level)
	_tiles = _level.get_node(^"Tiles") as TileMapLayer
	_player = _level.get_node(^"Player") as CharacterBody2D
	_spawn = _level.call(&"_spawn_position")
	_audit()
	_silence_pests()
	_build_trials()
	print("VERIFY trials=%d surfaces=%d" % [_trials.size(), _surfaces.size()])


func _physics_process(_delta: float) -> void:
	if _reported:
		return
	if _trial >= _trials.size():
		_report()
		return
	var spec: Dictionary = _trials[_trial]
	if _frame == 0:
		_begin_trial(spec)
	var mode := str(spec["mode"])
	if mode == "stomp":
		_tick_stomp(spec)
		return
	if mode == "bump":
		_tick_bump(spec)
		return
	if _frame < int(spec["settle"]):
		if _frame == int(spec["settle"]) - 1:
			_start_floor = _player.is_on_floor()
		_player.global_position = spec["start"]
		_player.velocity = Vector2.ZERO
		_set_move(0.0)
		_frame += 1
		return
	_tick_jump()
	_set_move(float(spec["move"]))
	if float(spec["move"]) > 0.0:
		_player.velocity.x = 180.0
	_min_y = minf(_min_y, _player.global_position.y)
	if _is_dead():
		_finish("MISS", "")
		return
	if mode == "jump" and not _jumped and _player.global_position.x >= float(spec["jump_at"]) - 0.5:
		_begin_jump(int(spec["hold"]))
		_jumped = true
	if mode == "jump" and _jumped and not _player.is_on_floor():
		_airborne = true
	if mode == "jump" and _airborne and _player.is_on_floor() and _player.velocity.y >= 0.0:
		_floor_run += 1
	else:
		_floor_run = 0
	if mode == "jump" and _floor_run >= 2:
		_finish_landing(spec)
		return
	var ran := _frame - int(spec["settle"])
	var limit := int(spec["wait"]) if mode == "wait" else 90
	if ran >= limit:
		if mode == "wait":
			_finish("ALIVE", "")
		else:
			_finish("MISS", "")
		return
	_frame += 1


func _begin_trial(spec: Dictionary) -> void:
	# Cancel any knock-out still playing from the previous trial.
	_level.call(&"_respawn_player")
	get_tree().call_group(&"ash_shelf", &"reset_piece")
	_silence_foe()
	_set_blocks(false)
	_player.call(&"set_controls_enabled", true)
	_player.set(&"jump_buffer_timer", 0.0)
	_player.global_position = spec["start"]
	_player.velocity = Vector2.ZERO
	Input.action_release(&"jump")
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	_jump_left = 0
	_jumped = false
	_airborne = false
	_floor_run = 0
	_min_y = float(spec["start"].y)
	_start_floor = false
	_actor_pos = Vector2(-1, -1)
	_stomp_phase = 0
	_stomp_floor = 0
	if str(spec["tag"]) == "seed_hop":
		var hud := _level.get_node(^"Hud") as StageHud
		_seed_before = hud.seed_count
		for node in get_tree().get_nodes_in_group(&"emberseed"):
			node.set(&"monitoring", true)
	if str(spec["mode"]) == "stomp":
		_arm_foe(spec["foe"], float(spec["foe_dir"]))
	elif str(spec["mode"]) == "bump":
		_set_blocks(true)


func _tick_stomp(spec: Dictionary) -> void:
	var foe := get_tree().get_first_node_in_group(&"copperling") as CharacterBody2D
	if _frame < int(spec["settle"]):
		_player.global_position = spec["start"]
		_player.velocity = Vector2.ZERO
		if foe != null:
			foe.global_position = spec["foe"]
			foe.velocity = Vector2.ZERO
			foe.set(&"direction", float(spec["foe_dir"]))
			_actor_pos = foe.global_position
		_set_move(0.0)
		_frame += 1
		return
	_tick_jump()
	if foe != null:
		_actor_pos = foe.global_position
	if foe == null or not foe.is_in_group(&"stompable"):
		_finish("STOMP", "", _actor_pos)
		return
	if _is_dead():
		_finish("MISS", "", _actor_pos)
		return
	if _stomp_phase == 0:
		_set_move(1.0)
		_player.velocity.x = 180.0
		if not _jumped and _player.global_position.x >= float(spec["jump_at"]) - 0.5:
			_begin_jump(int(spec["approach_hold"]))
			_jumped = true
		if _jumped and not _player.is_on_floor():
			_airborne = true
		if _airborne and _player.is_on_floor() and _player.velocity.y >= 0.0:
			_stomp_floor += 1
		else:
			_stomp_floor = 0
		if _stomp_floor >= 2:
			_stomp_phase = 1
			_jumped = false
			_airborne = false
			_jump_left = 0
			Input.action_release(&"jump")
			var foe_x := -1.0 if foe == null else foe.global_position.x
			print("STAMP land x=%.0f y=%.0f foe=%.0f" % [_player.global_position.x, _player.global_position.y, foe_x])
	else:
		_set_move(0.0)
		if _player.is_on_floor() and _jump_left == 0:
			_jumped = false
		var dx := foe.global_position.x - _player.global_position.x
		if (
			not _jumped
			and _player.is_on_floor()
			and dx > 4.0
			and dx < 28.0
			and foe.velocity.x < 0.0
			and absf(_player.velocity.x) < 40.0
		):
			_begin_jump(int(spec["hold"]))
			_jumped = true
			print("STAMP plant dx=%.0f foe=%.0f player=%.0f" % [dx, foe.global_position.x, _player.global_position.x])
	var ran := _frame - int(spec["settle"])
	if ran >= int(spec["wait"]):
		_finish("MISS", "", _actor_pos)
		return
	_frame += 1


func _tick_bump(spec: Dictionary) -> void:
	if _frame < int(spec["settle"]):
		_player.global_position = spec["start"]
		_player.velocity = Vector2.ZERO
		_set_move(0.0)
		_frame += 1
		return
	_tick_jump()
	_set_move(0.0)
	if not _jumped:
		_begin_jump(int(spec["hold"]))
		_jumped = true
	_actor_pos = spec["foe"]
	if _bump_done(str(spec["tag"])):
		_finish("BUMP", "", _actor_pos)
		return
	if _is_dead():
		_finish("MISS", "", _actor_pos)
		return
	var ran := _frame - int(spec["settle"])
	if ran >= int(spec["wait"]):
		_finish("MISS", "", _actor_pos)
		return
	_frame += 1


func _bump_done(tag: String) -> bool:
	if tag == "cache_bump":
		var block := get_tree().get_first_node_in_group(&"cache_stone")
		return block != null and bool(block.get(&"spent"))
	var clay := get_tree().get_first_node_in_group(&"clay_brick")
	return clay == null


func _finish_landing(spec: Dictionary) -> void:
	var feet := _player.global_position + Vector2(0.0, 8.0)
	var surf := _surface_at(feet.x, feet.y)
	if surf.is_empty():
		_finish("MISS", "")
		return
	var on_id := str(surf["id"])
	if on_id == str(spec["start_id"]) or float(surf["x0"]) < float(spec["lip"]) - 8.0:
		_finish("SAME", on_id)
		return
	_finish("LAND", on_id)


func _finish(result: String, on_id: String, actor := Vector2(-1, -1)) -> void:
	var spec: Dictionary = _trials[_trial]
	var pos := _player.global_position
	var rise := float(spec["start"].y) - _min_y
	var actor_text := "-"
	if actor.x >= 0.0:
		actor_text = "%.0f,%.0f" % [actor.x, actor.y]
	print(
		"TRIAL %s %s x=%.0f y=%.0f rise=%.0f on=%s actor=%s start_floor=%s"
		% [
			spec["name"],
			result,
			pos.x,
			pos.y,
			rise,
			on_id if on_id != "" else "-",
			actor_text,
			_start_floor,
		]
	)
	var gained := 0
	if str(spec["tag"]) == "seed_hop":
		var hud := _level.get_node(^"Hud") as StageHud
		gained = hud.seed_count - _seed_before
		print("SEED count=%d gained=%d" % [hud.seed_count, gained])
	_results.append({
		"name": str(spec["name"]),
		"tag": str(spec["tag"]),
		"hold": int(spec["hold"]),
		"result": result,
		"x": pos.x,
		"y": pos.y,
		"rise": rise,
		"on": on_id,
		"start_id": str(spec["start_id"]),
		"next_id": str(spec["next_id"]),
		"lip": float(spec["lip"]),
		"start_y": float(spec["start"].y),
		"start_x": float(spec["start"].x),
		"jump_at": float(spec["jump_at"]),
		"seeds": gained,
	})
	_trial += 1
	_frame = 0


func _audit() -> void:
	_scan_tiles()
	_scan_shelves()
	_scan_seeds()
	_scan_hazards()
	for surf in _surfaces:
		var tiles := int(round((float(surf["x1"]) - float(surf["x0"])) / 16.0))
		print(
			"SURF %s %s x=%.0f-%.0f y=%.0f tiles=%d"
			% [surf["id"], surf["kind"], surf["x0"], surf["x1"], surf["top"], tiles]
		)
	_audit_identity()
	_audit_embers()
	_audit_shelves()
	_audit_enemy()
	_audit_seeds()
	_audit_blocks()
	_audit_backdrop()
	_audit_wizard()

## The wizard must stand on one flat ground run the route already walks, with
## his barrier closed and a run-up past it to the lip of that run.
func _audit_wizard() -> void:
	var wizards: Array[Wizard] = []
	for node in get_tree().get_nodes_in_group(&"wizard"):
		if _level.is_ancestor_of(node):
			wizards.append(node as Wizard)
	if wizards.size() != 1:
		_fail("wizard count=%d" % wizards.size())
		return
	var wizard := wizards[0]
	var span := wizard.blocked_span()
	var home: Dictionary = {}
	for surf in _surfaces:
		if (
			str(surf["kind"]) == "ground"
			and is_equal_approx(float(surf["top"]), wizard.global_position.y)
			and float(surf["x0"]) <= span.x
			and float(surf["x1"]) >= span.y
		):
			home = surf
	if home.is_empty():
		_fail("wizard not on one flat ground run span=%.0f-%.0f" % [span.x, span.y])
		return
	var run_up := float(home["x1"]) - span.x
	if run_up < 64.0:
		_fail("wizard run-up %.0f" % run_up)
		return
	if wizard.barrier_open():
		_fail("wizard barrier starts open")
		return
	print("AUDIT pass wizard %s x=%.0f on=%s span=%.0f-%.0f run_up=%.0f" % [wizard.title, wizard.global_position.x, home["id"], span.x, span.y, run_up])


func _scan_tiles() -> void:
	var width := int(_level.call(&"_stage_width"))
	var open := {}
	for row in 17:
		for x in width:
			var kind := _standable_kind(x, row)
			if kind == "":
				_close_run(open, row)
				continue
			if bool(open.get("live", false)) and str(open["kind"]) == kind and int(open["end"]) == x - 1:
				open["end"] = x
				continue
			_close_run(open, row)
			open = {"live": true, "kind": kind, "row": row, "start": x, "end": x}
		_close_run(open, row)
		open = {}


func _close_run(open: Dictionary, row: int) -> void:
	if not bool(open.get("live", false)):
		return
	var start := int(open["start"])
	var end := int(open["end"])
	var top := float(row * 16)
	_surfaces.append({
		"id": "%s%d_%d" % [str(open["kind"])[0], row, start * 16],
		"kind": str(open["kind"]),
		"row": row,
		"x0": float(start * 16),
		"x1": float((end + 1) * 16),
		"top": top,
	})
	open["live"] = false


func _standable_kind(x: int, row: int) -> String:
	var atlas := _atlas_at(x, row)
	if atlas == StageTileset.ONE_WAY:
		return "one_way"
	if atlas != StageTileset.GROUND and atlas != StageTileset.SLAB:
		return ""
	if row > 0 and _blocks_feet(x, row - 1):
		return ""
	return "ground" if atlas == StageTileset.GROUND else "slab"


func _blocks_feet(x: int, row: int) -> bool:
	var atlas := _atlas_at(x, row)
	return (
		atlas == StageTileset.GROUND
		or atlas == StageTileset.SLAB
		or atlas == StageTileset.FILL
		or atlas == StageTileset.EMBER
	)


func _scan_shelves() -> void:
	for node in get_tree().get_nodes_in_group(&"ash_shelf"):
		var shelf := node as Node2D
		if shelf == null:
			continue
		var span := float(shelf.get(&"span"))
		var top := shelf.global_position.y
		_surfaces.append({
			"id": "shelf_%d" % int(round(shelf.global_position.x)),
			"kind": "shelf",
			"row": int(top / 16.0),
			"x0": shelf.global_position.x - span * 0.5,
			"x1": shelf.global_position.x + span * 0.5,
			"top": top,
		})


func _scan_seeds() -> void:
	for node in get_tree().get_nodes_in_group(&"emberseed"):
		var seed := node as Node2D
		if seed != null:
			_seeds.append(seed.global_position)


func _scan_hazards() -> void:
	var width := int(_level.call(&"_stage_width"))
	var ember_start := -1
	var ember_supported := false
	for x in width + 1:
		var is_ember := x < width and _atlas_at(x, 14) == StageTileset.EMBER
		if is_ember and ember_start < 0:
			ember_start = x
			ember_supported = _atlas_at(x, 15) != Vector2i(-1, -1)
		elif not is_ember and ember_start >= 0:
			var run := {
				"x0": float(ember_start * 16),
				"x1": float(x * 16),
				"supported": ember_supported,
			}
			if ember_supported:
				_supported_ember = run
			else:
				_open_ember = run
			ember_start = -1
	var roof_start := -1
	for x in width + 1:
		var is_roof := x < width and _atlas_at(x, 11) == StageTileset.SLAB and _atlas_at(x, 14) == StageTileset.GROUND
		if is_roof and roof_start < 0:
			roof_start = x
		elif not is_roof and roof_start >= 0:
			_roof = {"x0": float(roof_start * 16), "x1": float(x * 16)}
			roof_start = -1
	for surf in _surfaces:
		if str(surf["kind"]) != "shelf":
			continue
		var mid := (float(surf["x0"]) + float(surf["x1"])) * 0.5
		var supported := _atlas_at(int(mid / 16.0), 15) != Vector2i(-1, -1)
		if supported and absf(float(surf["top"]) - 224.0) < 6.0:
			_teach_shelf = surf
		elif not supported:
			_pit_shelf = surf
	var foe := get_tree().get_first_node_in_group(&"copperling") as Node2D
	if foe != null:
		_foe_home = foe.global_position
		_island = _surface_under(_foe_home.x, 224.0)
	var cache := get_tree().get_first_node_in_group(&"cache_stone") as Node2D
	if cache != null:
		_cache_pos = cache.global_position
	var clay := get_tree().get_first_node_in_group(&"clay_brick") as Node2D
	if clay != null:
		_clay_pos = clay.global_position
	var gate := get_tree().get_first_node_in_group(&"waygate") as Node2D
	if gate != null:
		_gate_pos = gate.global_position


func _audit_identity() -> void:
	if int(_level.call(&"stage_index")) != 3:
		_fail("stage index")
	else:
		print("AUDIT pass index")
	var next := _level.get(&"next_stage") as PackedScene
	if next == null or next.resource_path != "res://levels/level_04.tscn":
		_fail("next stage is not Smelter's Fork")
	else:
		print("AUDIT pass next stage")
	if int(_level.call(&"_stage_width")) != 121:
		_fail("width")
	if _player.global_position.distance_to(_spawn) > 2.0:
		_fail("spawn")
	else:
		print("AUDIT pass spawn")
	if _has_checkpoint(_level):
		_fail("checkpoint")
	else:
		print("AUDIT pass no checkpoint")
	var title := _level.get_node_or_null(^"Hud/Title") as Label
	if title == null or title.text != "Kiln Mouth":
		_fail("title")
	else:
		print("AUDIT pass title")


func _has_checkpoint(node: Node) -> bool:
	if str(node.name).to_lower().contains("checkpoint"):
		return true
	if node.is_in_group(&"checkpoint"):
		return true
	for child in node.get_children():
		if _has_checkpoint(child):
			return true
	return false


func _audit_embers() -> void:
	var supported := 0
	var open := 0
	var width := int(_level.call(&"_stage_width"))
	for x in width:
		if _atlas_at(x, 14) != StageTileset.EMBER:
			continue
		if _atlas_at(x, 15) != Vector2i(-1, -1):
			supported += 1
		else:
			open += 1
	if supported < 2 or open < 2 or _supported_ember.is_empty() or _open_ember.is_empty():
		_fail("ember supported=%d open=%d" % [supported, open])
	elif float(_open_ember["x0"]) <= float(_supported_ember["x1"]):
		_fail("open ember is not after the teach ember")
	else:
		print("AUDIT pass ember supported=%d open=%d" % [supported, open])


func _audit_shelves() -> void:
	var shelves := get_tree().get_nodes_in_group(&"ash_shelf")
	if shelves.size() != 2 or _teach_shelf.is_empty() or _pit_shelf.is_empty():
		_fail("shelves teach=%s pit=%s" % [not _teach_shelf.is_empty(), not _pit_shelf.is_empty()])
		return
	if float(_pit_shelf["x0"]) <= float(_teach_shelf["x1"]):
		_fail("pit shelf does not follow the teach shelf")
	else:
		print("AUDIT pass shelves")


func _audit_enemy() -> void:
	var crawlers := get_tree().get_nodes_in_group(&"copperling")
	if crawlers.size() != 1 or _island.is_empty():
		_fail("copperlings %d" % crawlers.size())
		return
	var tiles := int(round((float(_island["x1"]) - float(_island["x0"])) / 16.0))
	var left_empty := _atlas_at(int(float(_island["x0"]) / 16.0) - 1, int(_island["row"])) == Vector2i(-1, -1)
	var right_empty := _atlas_at(int(float(_island["x1"]) / 16.0), int(_island["row"])) == Vector2i(-1, -1)
	if tiles < 4 or tiles > 8 or not left_empty or not right_empty:
		_fail("island tiles=%d left=%s right=%s" % [tiles, left_empty, right_empty])
	else:
		print("AUDIT pass copperling")


func _audit_seeds() -> void:
	if _seeds.size() < 3:
		_fail("seeds %d" % _seeds.size())
		return
	var off := 0
	for point in _seeds:
		var atlas := _atlas_at(int(point.x / 16.0), 14)
		if atlas != StageTileset.GROUND and atlas != StageTileset.SLAB:
			off += 1
	if off < 3:
		_fail("seeds over pit %d" % off)
	else:
		print("AUDIT pass seeds")


func _audit_blocks() -> void:
	if _cache_pos == Vector2.ZERO or _clay_pos == Vector2.ZERO or _gate_pos == Vector2.ZERO:
		_fail("cache, clay, or waygate missing")
		return
	var cache_floor := _surface_under(_cache_pos.x, 224.0)
	var clay_floor := _surface_under(_clay_pos.x, 224.0)
	if cache_floor.is_empty() or clay_floor.is_empty():
		_fail("blocks are not over a floor")
	else:
		print("AUDIT pass blocks")


func _audit_backdrop() -> void:
	var layers: Array[Parallax2D] = []
	_collect_parallax(_level, layers)
	if layers.size() < 3:
		_fail("parallax layers %d" % layers.size())
	else:
		var previous := -1.0
		var ordered := true
		for layer in layers:
			var scale := layer.scroll_scale.x
			if scale <= previous:
				ordered = false
			previous = scale
		if not ordered:
			_fail("parallax scales are not increasing")
		else:
			print("AUDIT pass parallax")
	if _canvas_color_rects(_level) > 0:
		_fail("flat sky ColorRect still present")
	else:
		print("AUDIT pass sky")


func _collect_parallax(node: Node, into: Array[Parallax2D]) -> void:
	if node is Parallax2D:
		into.append(node)
	for child in node.get_children():
		_collect_parallax(child, into)


func _canvas_color_rects(node: Node) -> int:
	# The HUD's fade and dim overlays are not a sky.
	if node.is_in_group(&"stage_hud"):
		return 0
	var count := 0
	if node is ColorRect and node.get_parent() is CanvasLayer:
		count += 1
	for child in node.get_children():
		count += _canvas_color_rects(child)
	return count


func _build_trials() -> void:
	if _only() == "stomp":
		_add_stomp_trial()
		return
	if _only() == "seed":
		_add_seed_hop()
		return
	for surf in _surfaces:
		var lip := float(surf["x1"])
		var nxt := _next_surface(lip, float(surf["top"]), str(surf["id"]))
		if nxt.is_empty():
			continue
		var settle := 3 if str(surf["kind"]) == "shelf" else 6
		var start_x := maxf(float(surf["x0"]) + 8.0, lip - 14.0)
		for hold in HOLDS:
			_add_trial({
				"name": "lip%d_h%d" % [int(round(lip)), hold],
				"tag": "lip",
				"mode": "jump",
				"hold": hold,
				"move": 1.0,
				"start": Vector2(start_x, float(surf["top"]) - 8.0),
				"jump_at": lip,
				"settle": settle,
				"wait": 0,
				"start_id": str(surf["id"]),
				"next_id": str(nxt["id"]),
				"lip": lip,
				"foe": Vector2(-1, -1),
			})
	_add_scripted()


func _only() -> String:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and str(args[0]) == "--only":
		return str(args[1])
	return ""


func _add_scripted() -> void:
	var only := _only()
	if only == "stomp":
		_add_stomp_trial()
		return
	if only == "seed":
		_add_seed_hop()
		return
	if not _supported_ember.is_empty():
		var ember_x := float(_supported_ember["x0"])
		var left := _surface_under(ember_x - 8.0, 224.0)
		_add_trial({
			"name": "ember_walk",
			"tag": "ember_walk",
			"mode": "wait",
			"hold": 0,
			"move": 1.0,
			"start": Vector2(ember_x - 32.0, 216.0),
			"jump_at": ember_x,
			"settle": 4,
			"wait": 40,
			"start_id": str(left.get("id", "")),
			"next_id": "",
			"lip": ember_x,
			"foe": Vector2(-1, -1),
		})
		_add_trial({
			"name": "ember_clear",
			"tag": "ember_clear",
			"mode": "jump",
			"hold": 8,
			"move": 1.0,
			"start": Vector2(ember_x - 40.0, 216.0),
			"jump_at": ember_x - 28.0,
			"settle": 6,
			"wait": 0,
			"start_id": str(left.get("id", "")),
			"next_id": "",
			"lip": ember_x - 28.0,
			"foe": Vector2(-1, -1),
		})
		if not _open_ember.is_empty():
			var open_mid := (float(_open_ember["x0"]) + float(_open_ember["x1"])) * 0.5
			_add_trial({
				"name": "ember_drop",
				"tag": "ember_drop",
				"mode": "wait",
				"hold": 0,
				"move": 0.0,
				"start": Vector2(open_mid, 160.0),
				"jump_at": 99999.0,
				"settle": 4,
				"wait": 50,
				"start_id": "",
				"next_id": "",
				"lip": float(_open_ember["x0"]),
				"foe": Vector2(-1, -1),
			})
	if not _teach_shelf.is_empty():
		_add_wait_on_shelf("teach_cross", _teach_shelf, float(_teach_shelf["x0"]) - 20.0, 1.0, 55)
		_add_wait_on_shelf("teach_wait", _teach_shelf, (float(_teach_shelf["x0"]) + float(_teach_shelf["x1"])) * 0.5, 0.0, 180)
	if not _roof.is_empty():
		_add_trial({
			"name": "arch_walk",
			"tag": "arch_walk",
			"mode": "wait",
			"hold": 0,
			"move": 1.0,
			"start": Vector2(float(_roof["x0"]) + 24.0, 216.0),
			"jump_at": 99999.0,
			"settle": 6,
			"wait": 36,
			"start_id": "",
			"next_id": "",
			"lip": float(_roof["x0"]),
			"foe": Vector2(-1, -1),
		})
	if not _open_ember.is_empty():
		var approach := _ground_before(float(_open_ember["x0"]))
		if not approach.is_empty():
			_add_trial({
				"name": "open_walk",
				"tag": "open_walk",
				"mode": "wait",
				"hold": 0,
				"move": 1.0,
				"start": Vector2(float(approach["x1"]) - 24.0, float(approach["top"]) - 8.0),
				"jump_at": 99999.0,
				"settle": 6,
				"wait": 50,
				"start_id": str(approach["id"]),
				"next_id": "",
				"lip": float(approach["x1"]),
				"foe": Vector2(-1, -1),
			})
	if not _pit_shelf.is_empty():
		_add_wait_on_shelf("pit_wait", _pit_shelf, (float(_pit_shelf["x0"]) + float(_pit_shelf["x1"])) * 0.5, 0.0, 180)
		var escape_x := float(_pit_shelf["x1"]) - 12.0
		_add_trial({
			"name": "pit_escape",
			"tag": "pit_escape",
			"mode": "jump",
			"hold": 8,
			"move": 1.0,
			"start": Vector2(escape_x, float(_pit_shelf["top"]) - 8.0),
			"jump_at": escape_x - 1.0,
			"settle": 3,
			"wait": 0,
			"start_id": str(_pit_shelf["id"]),
			"next_id": "",
			"lip": float(_pit_shelf["x1"]),
			"foe": Vector2(-1, -1),
		})
	_add_stomp_trial()
	_add_bump("cache_bump", _cache_pos)
	_add_bump("clay_bump", _clay_pos)
	_add_seed_hop()


func _add_seed_hop() -> void:
	if _open_ember.is_empty():
		return
	var approach := _ground_before(float(_open_ember["x0"]))
	if approach.is_empty():
		return
	var lip := float(approach["x1"])
	_add_trial({
		"name": "seed_hop",
		"tag": "seed_hop",
		"mode": "jump",
		"hold": 1,
		"move": 1.0,
		"start": Vector2(maxf(float(approach["x0"]) + 8.0, lip - 14.0), float(approach["top"]) - 8.0),
		"jump_at": lip,
		"settle": 6,
		"wait": 0,
		"start_id": str(approach["id"]),
		"next_id": "",
		"lip": lip,
		"foe": Vector2(-1, -1),
	})


func _add_stomp_trial() -> void:
	if _island.is_empty():
		return
	var approach := _surface_by_id("g14_880")
	var start_x := float(_island["x0"]) - 46.0
	if not approach.is_empty():
		start_x = maxf(float(approach["x0"]) + 8.0, float(approach["x1"]) - 14.0)
	var stand := Vector2(start_x, 216.0)
	var foe_at := Vector2(float(_island["x0"]) + 64.0, float(_island["top"]))
	_add_trial({
		"name": "stomp",
		"tag": "stomp",
		"mode": "stomp",
		"hold": 8,
		"approach_hold": 1,
		"move": 1.0,
		"start": stand,
		"jump_at": float(_island["x0"]) - 32.0,
		"settle": 6,
		"wait": 240,
		"start_id": str(approach.get("id", "")),
		"next_id": str(_island["id"]),
		"lip": float(_island["x0"]) - 32.0,
		"foe": foe_at,
		"foe_dir": 1.0,
	})


func _add_wait_on_shelf(tag: String, shelf: Dictionary, x: float, move: float, wait: int) -> void:
	_add_trial({
		"name": tag,
		"tag": tag,
		"mode": "wait",
		"hold": 0,
		"move": move,
		"start": Vector2(x, float(shelf["top"]) - 8.0),
		"jump_at": 99999.0,
		"settle": 4,
		"wait": wait,
		"start_id": str(shelf["id"]),
		"next_id": "",
		"lip": float(shelf["x1"]),
		"foe": Vector2(-1, -1),
	})


func _add_bump(tag: String, at: Vector2) -> void:
	if at == Vector2.ZERO:
		return
	var floor_surf := _surface_under(at.x, 224.0)
	if floor_surf.is_empty():
		return
	var start := Vector2(at.x, float(floor_surf["top"]) - 8.0)
	_add_trial({
		"name": tag,
		"tag": tag,
		"mode": "bump",
		"hold": 30,
		"move": 0.0,
		"start": start,
		"jump_at": at.x,
		"settle": 6,
		"wait": 80,
		"start_id": str(floor_surf["id"]),
		"next_id": "",
		"lip": at.x,
		"foe": at,
	})


func _add_trial(spec: Dictionary) -> void:
	_trials.append(spec)


func _next_surface(lip: float, top: float, current_id: String) -> Dictionary:
	var best: Dictionary = {}
	var best_dx := 100000.0
	var best_dy := 100000.0
	for surf in _surfaces:
		if str(surf["id"]) == current_id:
			continue
		var x0 := float(surf["x0"])
		if x0 < lip - 1.0:
			continue
		var dx := x0 - lip
		var dy := absf(float(surf["top"]) - top)
		if dx < best_dx - 0.5 or (absf(dx - best_dx) <= 0.5 and dy < best_dy):
			best = surf
			best_dx = dx
			best_dy = dy
	return best


func _surface_at(feet_x: float, feet_y: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dy := 12.0
	for surf in _surfaces:
		if feet_x < float(surf["x0"]) - 4.0 or feet_x > float(surf["x1"]) + 4.0:
			continue
		var dy := absf(feet_y - float(surf["top"]))
		if dy <= best_dy:
			best = surf
			best_dy = dy
	return best


func _surface_under(x: float, top: float) -> Dictionary:
	var best: Dictionary = {}
	var best_dy := 24.0
	for surf in _surfaces:
		if x < float(surf["x0"]) or x > float(surf["x1"]):
			continue
		var dy := absf(float(surf["top"]) - top)
		if dy < best_dy:
			best = surf
			best_dy = dy
	return best


func _ground_before(x_limit: float) -> Dictionary:
	var best: Dictionary = {}
	var best_x := -1.0
	for surf in _surfaces:
		if str(surf["kind"]) != "ground":
			continue
		if absf(float(surf["top"]) - 224.0) > 6.0:
			continue
		if float(surf["x1"]) <= x_limit + 1.0 and float(surf["x1"]) > best_x:
			best = surf
			best_x = float(surf["x1"])
	return best


func _surface_by_id(id: String) -> Dictionary:
	for surf in _surfaces:
		if str(surf["id"]) == id:
			return surf
	return {}


func _silence_pests() -> void:
	# Trials measure the level alone; the playtest covers the wizard and
	# lesson_check covers the lesson pieces (scrolls, keys, blocks, the vault).
	get_tree().call_group(&"wizard", &"dismiss")
	get_tree().call_group(&"lesson", &"dismiss")
	_silence_foe()
	for node in get_tree().get_nodes_in_group(&"waygate"):
		node.set(&"monitoring", false)
	for node in get_tree().get_nodes_in_group(&"emberseed"):
		node.set(&"monitoring", false)
	_set_blocks(false)


func _silence_foe() -> void:
	for node in get_tree().get_nodes_in_group(&"copperling"):
		node.set_physics_process(false)
		node.set(&"collision_layer", 0)
		node.set(&"collision_mask", 0)


func _arm_foe(at: Vector2, direction: float) -> void:
	var foe := get_tree().get_first_node_in_group(&"copperling") as CharacterBody2D
	if foe == null:
		return
	foe.set_physics_process(true)
	foe.set(&"collision_layer", 4)
	foe.set(&"collision_mask", 1)
	foe.global_position = at
	foe.velocity = Vector2.ZERO
	foe.set(&"direction", direction)


func _set_blocks(active: bool) -> void:
	var layer := 1 if active else 0
	for group_name in [&"cache_stone", &"clay_brick"]:
		for node in get_tree().get_nodes_in_group(group_name):
			node.set(&"collision_layer", layer)


func _report() -> void:
	if _reported:
		return
	_reported = true
	_print_lips()
	_check_tag("ember_walk", "MISS", false, 0.0, 0.0)
	_check_tag("ember_clear", "LAND", false, 0.0, 0.0)
	_check_tag("ember_drop", "MISS", false, 0.0, 0.0)
	_check_tag("open_walk", "MISS", false, 0.0, 0.0)
	_check_teach_cross()
	_check_tag("teach_wait", "ALIVE", true, 8.0, 0.0)
	_check_arch()
	_check_tag("pit_wait", "MISS", false, 0.0, 0.0)
	_check_tag("pit_escape", "LAND", false, 0.0, 0.0)
	_check_tag("stomp", "STOMP", false, 0.0, 0.0)
	_check_tag("cache_bump", "BUMP", false, 0.0, 0.0)
	_check_tag("clay_bump", "BUMP", false, 0.0, 0.0)
	_check_seed_hop()
	_check_maw()
	var path := _build_route()
	if not _teach_shelf.is_empty() and not path.has(str(_teach_shelf["id"])):
		_fail("route skips the teach shelf")
	if not _pit_shelf.is_empty() and not path.has(str(_pit_shelf["id"])):
		_fail("route skips the pit shelf")
	var gate := _surface_under(_gate_pos.x, 224.0)
	if gate.is_empty() or not path.has(str(gate["id"])):
		_fail("route does not reach the waygate")
	else:
		print("AUDIT pass route")
	print("VERIFY result=%s fails=%d" % ["ok" if _failures.is_empty() else "fail", _failures.size()])
	for failure in _failures:
		print("VERIFY fail ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _print_lips() -> void:
	var grouped: Dictionary = {}
	for row in _results:
		if str(row["tag"]) != "lip":
			continue
		var key := str(row["start_id"])
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(row)
	for key in grouped.keys():
		var rows: Array = grouped[key]
		var by_hold: Dictionary = {}
		for row in rows:
			by_hold[int(row["hold"])] = row
		var bits: PackedStringArray = []
		for hold in HOLDS:
			if not by_hold.has(hold):
				bits.append("h%d=?" % hold)
				continue
			var row: Dictionary = by_hold[hold]
			bits.append("h%d=%s:%.0f" % [hold, row["result"], row["x"]])
		var sample: Dictionary = rows[0]
		print(
			"LIP %s lip=%.0f next=%s %s"
			% [key, sample["lip"], sample["next_id"], " ".join(bits)]
		)


func _check_tag(tag: String, expect: String, want_drop: bool, drop: float, _unused: float) -> void:
	for row in _results:
		if str(row["tag"]) != tag:
			continue
		var ok := str(row["result"]) == expect
		if want_drop:
			ok = ok and float(row["y"]) >= float(row["start_y"]) + drop
		if ok:
			print("AUDIT pass %s" % tag)
		else:
			_fail("%s got %s y=%.0f" % [tag, row["result"], row["y"]])
		return
	_fail("%s missing" % tag)


func _check_teach_cross() -> void:
	for row in _results:
		if str(row["tag"]) != "teach_cross":
			continue
		var ok := str(row["result"]) == "ALIVE" and float(row["y"]) < 226.0 and float(row["x"]) > float(_teach_shelf["x1"])
		if ok:
			print("AUDIT pass teach_cross")
		else:
			_fail("teach_cross got %s x=%.0f y=%.0f" % [row["result"], row["x"], row["y"]])
		return
	_fail("teach_cross missing")


func _check_arch() -> void:
	for row in _results:
		if str(row["tag"]) != "arch_walk":
			continue
		var ok := str(row["result"]) == "ALIVE" and float(row["x"]) > float(row["start_x"]) + 40.0 and float(row["y"]) < 230.0
		if ok:
			print("AUDIT pass arch_walk")
		else:
			_fail("arch_walk got %s x=%.0f y=%.0f" % [row["result"], row["x"], row["y"]])
		return
	_fail("arch_walk missing")


func _check_seed_hop() -> void:
	for row in _results:
		if str(row["tag"]) != "seed_hop":
			continue
		if str(row["result"]) == "LAND" and int(row["seeds"]) >= 1:
			print("AUDIT pass seed_hop count=%d" % int(row["seeds"]))
		else:
			_fail("seed_hop got %s count=%d" % [row["result"], int(row["seeds"])])
		return
	_fail("seed_hop missing")


func _check_maw() -> void:
	if _open_ember.is_empty():
		_fail("maw missing")
		return
	for row in _results:
		if str(row["result"]) != "LAND":
			continue
		if float(row["start_x"]) < float(_open_ember["x0"]) and float(row["x"]) > float(_open_ember["x1"]):
			print("AUDIT pass maw %s land=%.0f,%.0f" % [row["name"], row["x"], row["y"]])
			return
	_fail("no measured landing across the open ember")


func _build_route() -> Dictionary:
	var reached: Dictionary = {}
	var spawn_surf := _surface_under(_spawn.x, 224.0)
	var gate := _surface_under(_gate_pos.x, 224.0)
	if spawn_surf.is_empty() or gate.is_empty():
		_fail("route missing spawn or gate surface")
		return reached
	var current := spawn_surf
	reached[str(current["id"])] = true
	for _step in 24:
		if str(current["id"]) == str(gate["id"]):
			return reached
		var walked := _best_walk(current, reached)
		if not walked.is_empty():
			print("ROUTE walk from=%s top=%.0f to=%s" % [current["id"], current["top"], walked["id"]])
			current = walked
			reached[str(current["id"])] = true
			continue
		var jump := _best_jump(current)
		if jump.is_empty():
			_fail("route stuck at %s" % current["id"])
			return reached
		var dest: Dictionary = jump["dest"]
		print(
			"ROUTE jump from=%s top=%.0f to=%s at=%.0f hold=%d land=%.0f,%.0f"
			% [current["id"], current["top"], dest["id"], jump["at"], jump["hold"], jump["x"], jump["y"]]
		)
		current = dest
		reached[str(current["id"])] = true
	if str(current["id"]) != str(gate["id"]):
		_fail("route loop at %s" % current["id"])
	return reached


func _best_walk(current: Dictionary, reached: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_x1 := float(current["x1"])
	for surf in _surfaces:
		if str(surf["id"]) == str(current["id"]) or reached.has(str(surf["id"])):
			continue
		if absf(float(surf["top"]) - float(current["top"])) > 6.0:
			continue
		if float(surf["x0"]) > float(current["x1"]) + 8.0:
			continue
		if float(surf["x1"]) <= float(current["x1"]) + 8.0:
			continue
		if float(surf["x1"]) > best_x1:
			best = surf
			best_x1 = float(surf["x1"])
	return best


func _best_jump(current: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_x0 := 100000.0
	var best_hold := 999
	for row in _results:
		if str(row["start_id"]) != str(current["id"]) or str(row["result"]) != "LAND":
			continue
		var dest := _surface_by_id(str(row["on"]))
		if dest.is_empty() or float(dest["x1"]) <= float(current["x1"]) + 4.0:
			continue
		var x0 := float(dest["x0"])
		var hold := int(row["hold"])
		if x0 > best_x0 + 0.5:
			continue
		if x0 < best_x0 - 0.5 or hold < best_hold:
			best = {
				"dest": dest,
				"at": float(row["jump_at"]),
				"hold": hold,
				"x": float(row["x"]),
				"y": float(row["y"]),
			}
			best_x0 = x0
			best_hold = hold
	return best


func _fail(reason: String) -> void:
	_failures.append(reason)
	print("AUDIT fail ", reason)


func _atlas_at(x: int, row: int) -> Vector2i:
	var cell := Vector2i(x, row)
	if _tiles.get_cell_source_id(cell) != StageTileset.SOURCE:
		return Vector2i(-1, -1)
	return _tiles.get_cell_atlas_coords(cell)


func _is_dead() -> bool:
	if bool(_player.call(&"is_dead")):
		return true
	var pos := _player.global_position
	if pos.y > 270.0:
		return true
	var spec: Dictionary = _trials[_trial]
	var start: Vector2 = spec["start"]
	if start.distance_to(_spawn) > 24.0 and pos.distance_to(_spawn) < 12.0 and _frame > 2:
		return true
	return false


func _begin_jump(frames: int) -> void:
	Input.action_press(&"jump")
	_jump_left = frames


func _tick_jump() -> void:
	if _jump_left <= 0:
		return
	_jump_left -= 1
	if _jump_left == 0:
		Input.action_release(&"jump")
	else:
		Input.action_press(&"jump")


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
