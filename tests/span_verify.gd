extends Node

## Headless measurement of Cinder Span.
## Scans the live tilemap, then runs the real player at real jump holds.

const SPAWN := Vector2(56, 214)
const HOLDS: Array[int] = [1, 4, 8, 40]

var _level: Node2D
var _tiles: TileMapLayer
var _player: CharacterBody2D
var _surfaces: Array[Dictionary] = []
var _trials: Array[Dictionary] = []
var _results: Array[Dictionary] = []
var _failures: Array[String] = []
var _seeds: Array[Vector2] = []
var _trial := 0
var _frame := 0
var _jump_left := 0
var _jumped := false
var _airborne := false
var _floor_run := 0
var _min_y := 0.0
var _start_floor := false


func _init() -> void:
	process_physics_priority = -100


func _ready() -> void:
	process_physics_priority = -100
	var packed := load("res://levels/level_02.tscn") as PackedScene
	_level = packed.instantiate() as Node2D
	add_child(_level)
	_tiles = _level.get_node(^"Tiles") as TileMapLayer
	_player = _level.get_node(^"Player") as CharacterBody2D
	_audit()
	_silence_pests()
	_build_trials()
	print("VERIFY trials=%d surfaces=%d" % [_trials.size(), _surfaces.size()])


func _physics_process(_delta: float) -> void:
	if _trial >= _trials.size():
		_report()
		return
	var spec: Dictionary = _trials[_trial]
	if _frame == 0:
		_begin_trial(spec)
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
	var mode := str(spec["mode"])
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


func _finish(result: String, on_id: String) -> void:
	var spec: Dictionary = _trials[_trial]
	var pos := _player.global_position
	var rise := float(spec["start"].y) - _min_y
	print(
		"TRIAL %s %s x=%.0f y=%.0f rise=%.0f on=%s start_floor=%s"
		% [spec["name"], result, pos.x, pos.y, rise, on_id if on_id != "" else "-", _start_floor]
	)
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
		"ceil": bool(spec["ceil"]),
		"start_y": float(spec["start"].y),
	})
	_trial += 1
	_frame = 0


func _audit() -> void:
	_scan_tiles()
	_scan_shelves()
	_scan_seeds()
	for surf in _surfaces:
		var tiles := int(round((float(surf["x1"]) - float(surf["x0"])) / 16.0))
		print(
			"SURF %s %s x=%.0f-%.0f y=%.0f tiles=%d"
			% [surf["id"], surf["kind"], surf["x0"], surf["x1"], surf["top"], tiles]
		)
	_audit_floors()
	_audit_enemies()
	_audit_embers()
	_audit_one_ways()
	_audit_pickups()
	_audit_shelves()
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


func _audit_floors() -> void:
	var bad := false
	for surf in _surfaces:
		if str(surf["kind"]) == "one_way" or str(surf["kind"]) == "shelf":
			continue
		if float(surf["top"]) < 32.0:
			continue
		var tiles := int(round((float(surf["x1"]) - float(surf["x0"])) / 16.0))
		var spawn_run := float(surf["x0"]) == 0.0 and int(surf["row"]) == 14
		if tiles > 8 and not spawn_run:
			bad = true
			_fail("floor %s is %d tiles" % [surf["id"], tiles])
	if not bad:
		print("AUDIT pass floors")


func _audit_enemies() -> void:
	var crawlers := get_tree().get_nodes_in_group(&"copperling")
	if crawlers.size() < 2:
		_fail("copperlings %d" % crawlers.size())
		return
	var trapped := false
	for node in crawlers:
		var body := node as Node2D
		var row := int(round(body.global_position.y / 16.0))
		for surf in _surfaces:
			if int(surf["row"]) != row:
				continue
			if body.global_position.x < float(surf["x0"]) or body.global_position.x > float(surf["x1"]):
				continue
			var tiles := int(round((float(surf["x1"]) - float(surf["x0"])) / 16.0))
			var left_empty := _atlas_at(int(surf["x0"] / 16.0) - 1, row) == Vector2i(-1, -1)
			var right_empty := _atlas_at(int(surf["x1"] / 16.0), row) == Vector2i(-1, -1)
			if tiles <= 5 and left_empty and right_empty:
				trapped = true
	if not trapped:
		_fail("no copperling on a short platform with empty sides")
	else:
		print("AUDIT pass copperlings")


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
	if supported < 2 or open < 3:
		_fail("ember supported=%d open=%d" % [supported, open])
	else:
		print("AUDIT pass ember supported=%d open=%d" % [supported, open])


func _audit_one_ways() -> void:
	var rows: Dictionary = {}
	var ways: Array[Dictionary] = []
	for surf in _surfaces:
		if str(surf["kind"]) != "one_way":
			continue
		rows[int(surf["row"])] = true
		ways.append(surf)
	var stretch := _empty_ground_stretch()
	var climbed := false
	for high in ways:
		for low in ways:
			if int(high["row"]) < int(low["row"]) and float(high["x0"]) < float(low["x0"]):
				climbed = true
	if rows.size() < 2 or stretch < 8 or not climbed:
		_fail("one-ways rows=%d stretch=%d climb=%s" % [rows.size(), stretch, climbed])
	else:
		print("AUDIT pass one-ways rows=%d stretch=%d" % [rows.size(), stretch])


func _empty_ground_stretch() -> int:
	var width := int(_level.call(&"_stage_width"))
	var best := 0
	var run := 0
	for x in width:
		var atlas := _atlas_at(x, 14)
		var solid := atlas == StageTileset.GROUND or atlas == StageTileset.SLAB
		if solid:
			best = maxi(best, run)
			run = 0
		else:
			run += 1
	return maxi(best, run)


func _audit_pickups() -> void:
	if _seeds.size() < 3:
		_fail("seeds %d" % _seeds.size())
	else:
		var off := true
		for point in _seeds:
			var tile_x := int(point.x / 16.0)
			var over_pit := _atlas_at(tile_x, 14) != StageTileset.GROUND and _atlas_at(tile_x, 14) != StageTileset.SLAB
			if not over_pit and point.y >= 170.0:
				off = false
				_fail("seed at %s is on the safe line" % point)
		if off:
			print("AUDIT pass seeds")
	var cache := get_tree().get_first_node_in_group(&"cache_stone") as Node2D
	var clay := get_tree().get_first_node_in_group(&"clay_brick") as Node2D
	if cache == null or clay == null:
		_fail("cache or clay missing")
		return
	if _platform_tiles(cache.global_position) > 4 or _platform_tiles(clay.global_position) > 4:
		_fail("cache/clay platform is wide")
	else:
		print("AUDIT pass blocks")


func _platform_tiles(at: Vector2) -> int:
	for surf in _surfaces:
		if str(surf["kind"]) == "one_way" or str(surf["kind"]) == "shelf":
			continue
		if at.x < float(surf["x0"]) or at.x > float(surf["x1"]):
			continue
		if absf(at.y - float(surf["top"])) > 80.0:
			continue
		return int(round((float(surf["x1"]) - float(surf["x0"])) / 16.0))
	return 99


func _audit_shelves() -> void:
	var shelves := get_tree().get_nodes_in_group(&"ash_shelf")
	if shelves.size() != 2:
		_fail("shelves %d" % shelves.size())
		return
	var taught := false
	var pit := false
	for node in shelves:
		var shelf := node as Node2D
		var top := shelf.global_position.y
		var tile_x := int(shelf.global_position.x / 16.0)
		if absf(top - 224.0) < 6.0 and _atlas_at(tile_x, 15) != Vector2i(-1, -1):
			taught = true
		if top < 200.0 and _atlas_at(tile_x, 14) != StageTileset.GROUND and _atlas_at(tile_x, 14) != StageTileset.SLAB:
			pit = true
	if not taught or not pit:
		_fail("shelf teach=%s pit=%s" % [taught, pit])
	else:
		print("AUDIT pass shelves")


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
	for surf in _surfaces:
		var lip := float(surf["x1"])
		var nxt := _next_surface(lip, float(surf["top"]), str(surf["id"]))
		if nxt.is_empty():
			continue
		var ceil := _gap_has_roof(lip, float(nxt["x0"]))
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
				"ceil": ceil,
			})
	_add_scripted()


func _add_scripted() -> void:
	_add_trial({
		"name": "ember_walk",
		"tag": "ember_walk",
		"mode": "wait",
		"hold": 0,
		"move": 1.0,
		"start": Vector2(96, 216),
		"jump_at": 99999.0,
		"settle": 4,
		"wait": 40,
		"start_id": "",
		"next_id": "",
		"lip": 128.0,
		"ceil": false,
	})
	_add_trial({
		"name": "ember_clear",
		"tag": "ember_clear",
		"mode": "jump",
		"hold": 8,
		"move": 1.0,
		"start": Vector2(88, 216),
		"jump_at": 100.0,
		"settle": 6,
		"wait": 0,
		"start_id": "spawn",
		"next_id": "",
		"lip": 100.0,
		"ceil": false,
	})
	_add_shelf_script("teach_drop", 224.0, "wait", 0, 0.0, 40, false)
	_add_shelf_script("pit_drop", 192.0, "wait", 0, 0.0, 120, false)
	_add_shelf_script("pit_escape", 192.0, "jump", 8, 1.0, 0, true)
	_add_trial({
		"name": "trench_hop",
		"tag": "trench_hop",
		"mode": "jump",
		"hold": 4,
		"move": 1.0,
		"start": Vector2(900, 232),
		"jump_at": 916.0,
		"settle": 6,
		"wait": 0,
		"start_id": "g15_832",
		"next_id": "g14_944",
		"lip": 916.0,
		"ceil": false,
	})
	_add_trial({
		"name": "seed_h14",
		"tag": "seed",
		"mode": "jump",
		"hold": 14,
		"move": 1.0,
		"start": Vector2(1424, 184),
		"jump_at": 1448.0,
		"settle": 4,
		"wait": 0,
		"start_id": "seed_start",
		"next_id": "",
		"lip": 1448.0,
		"ceil": false,
	})
	_add_trial({
		"name": "seed_h40",
		"tag": "seed",
		"mode": "jump",
		"hold": 40,
		"move": 1.0,
		"start": Vector2(1424, 184),
		"jump_at": 1448.0,
		"settle": 4,
		"wait": 0,
		"start_id": "seed_start",
		"next_id": "",
		"lip": 1448.0,
		"ceil": false,
	})


func _add_shelf_script(tag: String, top: float, mode: String, hold: int, move: float, wait: int, from_right: bool) -> void:
	for surf in _surfaces:
		if str(surf["kind"]) != "shelf" or absf(float(surf["top"]) - top) > 6.0:
			continue
		var start_x := (float(surf["x0"]) + float(surf["x1"])) * 0.5
		if from_right:
			start_x = float(surf["x1"]) - 12.0
		_add_trial({
			"name": tag,
			"tag": tag,
			"mode": mode,
			"hold": hold,
			"move": move,
			"start": Vector2(start_x, float(surf["top"]) - 8.0),
			"jump_at": start_x - 1.0,
			"settle": 3,
			"wait": wait,
			"start_id": str(surf["id"]),
			"next_id": "",
			"lip": float(surf["x1"]),
			"ceil": false,
		})
		return


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


func _gap_has_roof(lip: float, next_x: float) -> bool:
	var from_x := int(floor(lip / 16.0)) - 1
	var to_x := int(floor(next_x / 16.0))
	var hits := 0
	for x in range(from_x, to_x + 1):
		if _blocks_feet(x, 10) and _blocks_feet(x, 9):
			hits += 1
	return hits >= 2


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


func _silence_pests() -> void:
	# Trials measure the level alone; the playtest covers the wizard.
	get_tree().call_group(&"wizard", &"dismiss")
	for node in get_tree().get_nodes_in_group(&"copperling"):
		node.set_physics_process(false)
		node.set(&"collision_layer", 0)
		node.set(&"collision_mask", 0)
	for node in get_tree().get_nodes_in_group(&"waygate"):
		node.set(&"monitoring", false)


func _report() -> void:
	var grouped: Dictionary = {}
	for row in _results:
		if str(row["tag"]) != "lip":
			continue
		var key := str(row["start_id"])
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(row)
	var got_max := false
	var got_pad := false
	var got_ceil := false
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
			"LIP %s lip=%.0f next=%s ceil=%s %s"
			% [key, sample["lip"], sample["next_id"], sample["ceil"], " ".join(bits)]
		)
		if _hold_is(by_hold, 1, "MISS", "SAME") and _hold_is(by_hold, 4, "MISS", "SAME") and _hold_is(by_hold, 40, "LAND", ""):
			got_max = true
			print("HINT max_jump lip=%.0f land=%.0f,%.0f" % [sample["lip"], by_hold[40]["x"], by_hold[40]["y"]])
		if _hold_is(by_hold, 1, "LAND", "") and str(by_hold[1]["on"]) == str(sample["next_id"]) and _hold_is(by_hold, 40, "MISS", ""):
			got_pad = true
			print("HINT small_pad lip=%.0f land=%.0f,%.0f" % [sample["lip"], by_hold[1]["x"], by_hold[1]["y"]])
		if bool(sample["ceil"]) and _hold_is(by_hold, 1, "LAND", "") and str(by_hold[1]["on"]) == str(sample["next_id"]) and not _hold_is(by_hold, 40, "LAND", ""):
			got_ceil = true
			print("HINT ceiling lip=%.0f land=%.0f,%.0f" % [sample["lip"], by_hold[1]["x"], by_hold[1]["y"]])
	if not got_max:
		_fail("no max jump (tap and short hold miss, full hold lands)")
	if not got_pad:
		_fail("no small pad (tap lands, full hold dies)")
	if not got_ceil:
		_fail("no ceiling (tap lands, full hold does not)")
	_check_tag("ember_walk", "MISS", 0.0, false)
	_check_tag("ember_clear", "LAND", 0.0, false)
	_check_tag("teach_drop", "ALIVE", 8.0, true)
	_check_tag("trench_hop", "LAND", 0.0, false)
	_check_tag("pit_drop", "MISS", 0.0, false)
	_check_tag("pit_escape", "LAND", 0.0, false)
	var seed_hit := false
	for row in _results:
		if str(row["result"]) != "LAND":
			continue
		if str(row["on"]).begins_with("s9_"):
			seed_hit = true
			print("HINT seed %s land=%.0f,%.0f" % [row["name"], row["x"], row["y"]])
	if not seed_hit:
		_fail("no measured landing on the seed branch")
	print("VERIFY result=%s fails=%d" % ["ok" if _failures.is_empty() else "fail", _failures.size()])
	for failure in _failures:
		print("VERIFY fail ", failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _hold_is(by_hold: Dictionary, hold: int, result: String, also: String) -> bool:
	if not by_hold.has(hold):
		return false
	var got := str(by_hold[hold]["result"])
	return got == result or (also != "" and got == also)


func _check_tag(tag: String, expect: String, drop: float, want_drop: bool) -> void:
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
	if start.distance_to(SPAWN) > 24.0 and pos.distance_to(SPAWN) < 12.0 and _frame > 2:
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
