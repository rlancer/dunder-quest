extends Node

## Plays the high country (Smelter's Fork -> Bellows Bridge -> Crucible
## Crown) end to end with real input and a generic bot: it runs right, hops
## pits and ember by reading the live tilemap, jumps copperlings, climbs steps,
## reads every lesson card, solves each gadget the way a player would, and
## sits each wizard's full trial (missing one question on purpose in the
## finale). The stages chain into one another through their waygates.
##
## Then it checks that the wrong answers fail for real: a dial turned to the
## wrong heat keeps its gate shut, short and long bridges crumble and the bare
## chasm kills, and the A and C stairs cannot reach the crown. Last, every
## stage's seed total matches what the world map promises.
## godot --headless --path . res://tests/high_country_check.tscn   ->  HIGH result=ok

const FORK := preload("res://levels/level_04.tscn")
const BRIDGE := preload("res://levels/level_05.tscn")
const CROWN := preload("res://levels/level_06.tscn")
const TILE := 16
const FULL_HOLD := 40
## How far each jump hold carries the body at full run speed, flat to flat.
const HOPS: Array[Vector2i] = [Vector2i(1, 58), Vector2i(4, 72), Vector2i(8, 86), Vector2i(FULL_HOLD, 114)]
const STAGE_FRAMES := 150 * 60
const FLOOR_Y := 214.0

var _fails: PackedStringArray = []
var _stage: StageLevel
var _jump_left := 0
var _cooldown := 0
var _quiz_frames := 0
var _card_frames := 0
var _missed_once := false
var _answers := 0
## Lesson cards closed on the run, scrolls and all.
var _cards := 0
## While set, the bot only steers into the crown wall (stair checks).
var _climb_only := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	GameProgression.persist = false
	GameProgression.came_from_map = false
	GameProgression.load_data()
	StageAudio.web_audio_unlocked = true
	_run.call_deferred()


func _run() -> void:
	await _play_through()
	await _check_fork_gates()
	await _check_bridge()
	await _check_stairs()
	await _check_seed_totals()
	for fail in _fails:
		print("HIGH fail ", fail)
	print("HIGH result=%s fails=%d" % ["ok" if _fails.is_empty() else "fail", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- The full run ----------------------------------------------------------

func _play_through() -> void:
	_open(FORK)
	for expected in [4, 5, 6]:
		var stage := _stage
		_answers = 0
		var done := false
		for _frame in STAGE_FRAMES:
			await get_tree().physics_frame
			if not is_instance_valid(stage):
				break
			if stage.hud.passage_shown or stage.hud.is_cleared():
				done = true
				break
			_drive()
			if _frame % 300 == 299 and OS.get_cmdline_user_args().has("--trace"):
				var pl := stage.player
				print("HIGH trace stage=%d x=%.0f y=%.0f vx=%.0f floor=%s card=%s quiz=%s controls=%s" % [expected, pl.global_position.x, pl.global_position.y, pl.velocity.x, pl.is_on_floor(), stage.hud.is_card_open(), stage.hud.is_quiz_open(), pl.controls_enabled])
		_release_all()
		var tag := "stage %d" % expected
		_expect(done, "%s: the bot reaches the waygate (stopped at x=%.0f)" % [tag, stage.player.global_position.x if is_instance_valid(stage) else -1.0])
		if not done:
			return
		var wizard := get_tree().get_first_node_in_group(&"wizard") as Wizard
		var trial := Lessons.trial(expected)
		_expect(wizard != null and wizard.banished, "%s: the wizard was banished" % tag)
		var wanted := trial + (1 if expected == 6 else 0)
		_expect(_answers == wanted, "%s: the trial took %d answers (wanted %d)" % [tag, _answers, wanted])
		_expect(stage.hud.scroll_found == stage.hud.scroll_total, "%s: every scroll read (%d/%d)" % [tag, stage.hud.scroll_found, stage.hud.scroll_total])
		print("HIGH %s clear time=%.1f falls=%d seeds=%d/%d answers=%d cards=%d" % [tag, float(stage.get(&"_elapsed")), stage.hud.falls, stage.hud.seed_count, stage.hud.seed_total, _answers, _cards])
		_cards = 0
		if expected == 6:
			_expect(stage.hud.is_cleared(), "the crown ends the trail on the clear card")
			_expect(GameProgression.is_cleared(6), "the last stage is marked cleared")
			stage.queue_free()
			await _frames(2)
			return
		# The waygate chains straight into the next stage.
		var next: StageLevel = null
		for _wait in 8 * 60:
			await get_tree().physics_frame
			for node in get_tree().get_nodes_in_group(&"stage"):
				if node != stage and is_instance_valid(node) and not node.is_queued_for_deletion() and int(node.call(&"stage_index")) == expected + 1:
					next = node as StageLevel
			if next != null:
				break
		_expect(next != null, "stage %d chains into stage %d" % [expected, expected + 1])
		if next == null:
			return
		_stage = next
		_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
		await _frames(2)


## One frame of play: cards, the quiz, gadgets, then plain running.
func _drive() -> void:
	_tick_jump()
	var hud := _stage.hud
	if hud.is_card_open():
		_release_moves()
		_card_frames += 1
		if _card_frames == 1:
			_cards += 1
		elif _card_frames % 30 == 0:
			_tap(&"confirm")
		return
	_card_frames = 0
	if hud.is_quiz_open():
		_release_moves()
		_answer_quiz(hud)
		return
	_quiz_frames = 0
	var player := _stage.player
	if bool(player.call(&"is_dead")) or not player.controls_enabled:
		_release_moves()
		return
	if _climb_only:
		_run_right()
		return
	if _solve_gadget():
		return
	_run_right()


func _answer_quiz(hud: StageHud) -> void:
	_quiz_frames += 1
	if hud.is_quiz_asking():
		if _quiz_frames < 20:
			return
		var pick := hud.quiz_answer_index()
		if _stage.stage_index() == 6 and not _missed_once:
			_missed_once = true
			pick = posmod(pick + 1, 4)
		_answers += 1
		_quiz_frames = -1000
		(hud.get_node("QuizPanel/Center/QuizBox/Rows/Options/Option%d" % pick) as Button).pressed.emit()
		return
	if _quiz_frames < 0:
		_quiz_frames = 0
	if _quiz_frames == 40:
		_tap(&"confirm")


# --- Gadgets -----------------------------------------------------------------

## Walks to the block that solves this stage's gadget and bumps it from below
## until the gadget gives way. False when there is nothing to solve here.
func _solve_gadget() -> bool:
	var x := _stage.player.global_position.x
	match _stage.stage_index():
		4:
			var gates := _nodes(&"truth_gate")
			for index in gates.size():
				var gate := gates[index] as TruthGate
				var dial := _block(index)
				if gate.is_open() or x < dial.global_position.x - 100.0 or x > gate.global_position.x:
					continue
				if not bool(_stage.call(&"heat_opens", index, int(dial.label_text))):
					_bump(dial)
				else:
					_set_move(1.0)
				return true
		5:
			if not bool(_stage.call(&"is_bridged")):
				var block := _block(int(_stage.call(&"bridge_answer")))
				if x > block.global_position.x - 100.0 and x < 1360.0:
					if bool(_stage.get(&"_building")):
						_release_moves()
					else:
						_bump(block)
					return true
		6:
			var answer := int(_stage.call(&"stair_answer"))
			if int(_stage.get(&"_built")) != answer or bool(_stage.get(&"_building")):
				var block := _block(answer)
				if x > block.global_position.x - 100.0 and x < 1600.0:
					if bool(_stage.get(&"_building")):
						_release_moves()
					else:
						_bump(block)
					return true
	return false


## Lines up under `block` and jumps into it.
func _bump(block: RuneBlock) -> void:
	var player := _stage.player
	var dx := block.global_position.x - player.global_position.x
	if absf(dx) > 3.0:
		_set_move(signf(dx))
		return
	_set_move(0.0)
	if player.is_on_floor() and absf(player.velocity.x) < 10.0:
		_start_jump(FULL_HOLD)


# --- Running -----------------------------------------------------------------

## Holds right, and on the ground decides whether the next step needs a jump:
## a copperling close ahead, a wall or a step up, or a pit or ember, which
## gets the shortest hold that still carries the body onto the far side.
func _run_right() -> void:
	_set_move(1.0)
	var player := _stage.player
	if not player.is_on_floor():
		return
	var x := player.global_position.x
	var feet := _feet_row()
	for foe in _nodes(&"copperling"):
		var body := foe as Node2D
		if bool(foe.get(&"_dead")):
			continue
		var dx := body.global_position.x - x
		if dx > 0.0 and dx < 44.0 and absf(body.global_position.y - (player.global_position.y + 8.0)) < 16.0:
			_start_jump(FULL_HOLD)
			return
	var col := int((x + 10.0) / TILE)
	if _solid(col, feet - 1) or _solid(col, feet - 2):
		_start_jump(FULL_HOLD)
		return
	var surface := _surface(col, feet)
	if surface.y >= 0 and surface.y < feet:
		# A step up: just enough jump to land on it rather than sail past.
		_start_jump(_hold_for_rise(feet - surface.y))
		return
	if surface.y >= 0 and not bool(surface.x):
		return
	# A pit or ember: find the first safe column and pick the shortest hop.
	for ahead in range(col + 1, col + 10):
		var land := _surface(ahead, feet)
		if land.y >= 0 and not bool(land.x):
			var need := float(ahead * TILE + 5) - x
			if land.y < feet:
				_start_jump(_hold_for_rise(feet - land.y))
				return
			for hop in HOPS:
				if float(hop.y) >= need + 4.0 or hop.x == FULL_HOLD:
					_start_jump(hop.x)
					return
	_start_jump(FULL_HOLD)


## The shortest hold that lifts the feet `rise` tiles: hold 4 peaks near
## 2.3 tiles, hold 8 near 3.4, and a full jump near 4.7.
func _hold_for_rise(rise: int) -> int:
	if rise <= 1:
		return 1
	if rise == 2:
		return 4
	if rise == 3:
		return 8
	return FULL_HOLD


func _feet_row() -> int:
	return int((_stage.player.global_position.y + 9.0) / TILE)


## The top of whatever the body would stand on in column `col`, scanning down
## from a few rows above the feet: Vector2i(is_ember, row), or row -1 for a
## pit. Ash shelves still standing count as ground.
func _surface(col: int, feet: int) -> Vector2i:
	var tiles := _stage.tiles
	for row in range(maxi(feet - 4, 1), 18):
		var cell := Vector2i(col, row)
		# A top surface: a tile with open air above it.
		if tiles.get_cell_source_id(cell) == -1 or tiles.get_cell_source_id(Vector2i(col, row - 1)) != -1:
			continue
		var ember := tiles.get_cell_atlas_coords(cell) == StageTileset.EMBER
		return Vector2i(1 if ember else 0, row)
	var center := float(col * TILE + 8)
	for shelf in _nodes(&"ash_shelf"):
		var body := shelf as Node2D
		var half := float(shelf.get(&"span")) * 0.5
		if body.visible and int(shelf.get(&"collision_layer")) != 0 and absf(center - body.global_position.x) <= half:
			return Vector2i(0, int(body.global_position.y / TILE))
	return Vector2i(0, -1)


## A full tile the body can't pass sideways (one-way planks don't count).
func _solid(col: int, row: int) -> bool:
	var cell := Vector2i(col, row)
	if _stage.tiles.get_cell_source_id(cell) == -1:
		return false
	return _stage.tiles.get_cell_atlas_coords(cell) != StageTileset.ONE_WAY


# --- Wrong answers -----------------------------------------------------------

func _check_fork_gates() -> void:
	_open(FORK)
	await _frames(4)
	var gates := _nodes(&"truth_gate")
	_expect(gates.size() == 2, "Smelter's Fork has two truth gates")
	var answers: Array = _stage.call(&"gate_answers")
	_expect(answers == [2, 3], "each gate has one heat that opens it (got %s)" % [answers])
	for index in gates.size():
		var gate := gates[index] as TruthGate
		var dial := _block(index)
		_expect(not gate.is_open(), "gate %d starts shut at heat 0" % index)
		for heat in [1, 2, 3, 0]:
			dial.receive_head_bump()
			await _frames(2)
			_expect(dial.label_text == str(heat), "dial %d reads %d" % [index, heat])
			_expect(gate.is_open() == (heat == answers[index]), "gate %d at heat %d is %s" % [index, heat, "open" if gate.is_open() else "shut"])
	# A shut gate holds a body running into it.
	var gate := gates[0] as TruthGate
	_place(Vector2(gate.global_position.x - 40.0, FLOOR_Y))
	_set_move(1.0)
	await _frames(60)
	_release_all()
	_expect(_stage.player.global_position.x < gate.global_position.x, "a shut gate stops the player")
	_close()


func _check_bridge() -> void:
	_open(BRIDGE)
	await _frames(4)
	var chasm: Vector2i = _stage.get_script().get_script_constant_map()["CHASM"]
	_expect(int(_stage.call(&"bridge_answer")) == 5, "only span(5) fits the chasm")
	for arg in [4, 6, 3]:
		_block(arg).receive_head_bump()
		await _frames(6)
		_expect(_stage.tiles.get_cell_source_id(Vector2i(chasm.x, 14)) != -1, "span(%d) lays planks" % arg)
		await _frames(90)
		_expect(not bool(_stage.call(&"is_bridged")), "span(%d) does not hold" % arg)
		var left := 0
		for x in range(chasm.x, chasm.y + 1):
			if _stage.tiles.get_cell_source_id(Vector2i(x, 14)) != -1:
				left += 1
		_expect(left == 0, "span(%d)'s planks crumble (%d left)" % [arg, left])
	# With no bridge, the best jump falls short.
	var falls := _stage.hud.falls
	_place(Vector2(float(chasm.x * TILE) - 60.0, FLOOR_Y))
	_climb_only = true
	for _frame in 150:
		await get_tree().physics_frame
		_tick_jump()
		if _stage.hud.falls > falls:
			break
		_run_right()
	_climb_only = false
	_release_all()
	_expect(_stage.hud.falls > falls, "the bare chasm can't be jumped")
	await _frames(60)
	_block(5).receive_head_bump()
	await _frames(60)
	_expect(bool(_stage.call(&"is_bridged")), "span(5) holds")
	_block(4).receive_head_bump()
	await _frames(60)
	_expect(_stage.tiles.get_cell_source_id(Vector2i(chasm.y, 14)) != -1, "a built bridge ignores later calls")
	_close()


func _check_stairs() -> void:
	_open(CROWN)
	await _frames(4)
	_expect(int(_stage.call(&"stair_answer")) == 1, "only forge B's stair reaches")
	for index in [0, 2]:
		_block(index).receive_head_bump()
		await _until(func() -> bool: return not bool(_stage.get(&"_building")), 120)
		_place(Vector2(1540.0, FLOOR_Y))
		_climb_only = true
		var highest := 999.0
		for _frame in 6 * 60:
			await get_tree().physics_frame
			_tick_jump()
			if bool(_stage.player.call(&"is_dead")):
				continue
			_run_right()
			highest = minf(highest, _stage.player.global_position.y)
		_climb_only = false
		_release_all()
		_expect(highest > 100.0, "forge %s's stair can't reach the crown (got to y=%.0f)" % [["A", "B", "C"][index], highest])
	_close()


func _check_seed_totals() -> void:
	for stage_id in range(1, GameProgression.get_stage_count() + 1):
		var data := GameProgression.get_stage_data(stage_id)
		_open(load(str(data["scene"])) as PackedScene)
		await _frames(3)
		_expect(_stage.hud.seed_total == int(data["max_seeds"]), "stage %d has %d seeds; the map says %d" % [stage_id, _stage.hud.seed_total, int(data["max_seeds"])])
		var wizard := get_tree().get_first_node_in_group(&"wizard") as Wizard
		_expect(wizard != null and wizard.ward_total == Lessons.trial(stage_id), "stage %d's wizard wants %d answers" % [stage_id, Lessons.trial(stage_id)])
		_close()


# --- Helpers -----------------------------------------------------------------

func _open(packed: PackedScene) -> void:
	_close()
	GameProgression.load_data()
	_stage = packed.instantiate() as StageLevel
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stage)


func _close() -> void:
	_release_all()
	get_tree().paused = false
	for node in get_tree().get_nodes_in_group(&"stage"):
		node.queue_free()
	_stage = null


func _nodes(group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if _stage.is_ancestor_of(node) and not node.is_queued_for_deletion():
			found.append(node)
	return found


func _block(index: int) -> RuneBlock:
	for node in _nodes(&"rune_block"):
		if (node as RuneBlock).index == index:
			return node as RuneBlock
	return null


func _place(at: Vector2) -> void:
	_stage.player.global_position = at
	_stage.player.velocity = Vector2.ZERO


func _set_move(direction: float) -> void:
	if direction < 0.0:
		Input.action_press(&"move_left")
		Input.action_release(&"move_right")
	elif direction > 0.0:
		Input.action_press(&"move_right")
		Input.action_release(&"move_left")
	else:
		_release_moves()


func _release_moves() -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")


func _release_all() -> void:
	_release_moves()
	Input.action_release(&"jump")
	_jump_left = 0
	_cooldown = 0


func _start_jump(frames: int) -> void:
	if _jump_left > 0 or _cooldown > 0:
		return
	Input.action_press(&"jump")
	_jump_left = frames
	_cooldown = frames + 8


func _tick_jump() -> void:
	if _cooldown > 0:
		_cooldown -= 1
	if _jump_left <= 0:
		return
	_jump_left -= 1
	if _jump_left == 0:
		Input.action_release(&"jump")


func _tap(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event.call_deferred(release)


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _until(condition: Callable, limit: int) -> void:
	for _index in limit:
		if condition.call():
			return
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fails.append(label)
