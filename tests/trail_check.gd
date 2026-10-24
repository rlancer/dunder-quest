extends Node

## Plays the whole trail, Shrubbery Wood to Castle Aargh, end to end with real
## input and one generic bot: it runs right, hops pits and ember by reading
## the live tilemap, jumps copperlings, climbs steps, reads every lesson card,
## solves each gadget the way a player would, and fights each wizard duel,
## hopping his ward waves, stepping out from under his hexes, and bumping the
## right answer block (missing one on purpose in the finale). The stages
## chain into one another through their waygates.
##
## Then it checks that the wrong answers fail for real: short slices drop
## Amber's planks, three-lap loops leave Kiln's lift short of the wall, a wrong heat
## keeps a Fork gate shut, short and long bridges crumble and the bare chasm
## kills, and the A and C stairs cannot reach the crown. Last, every stage's
## seed total matches what the world map promises.
## godot --headless --path . res://tests/trail_check.tscn   ->  TRAIL result=ok
## Add `-- --from=4` to start the run at a later stage, `-- --trace` to log,
## and `-- --at=960` to drop the player there first (with `--fine`, log often).
## `-- --checks` skips the run and does only the wrong-answer checks.

const TILE := 16
const FULL_HOLD := 40
## How far each jump hold carries the body at full run speed, flat to flat.
const HOPS: Array[Vector2i] = [Vector2i(1, 63), Vector2i(4, 78), Vector2i(8, 90), Vector2i(12, 102), Vector2i(16, 111), Vector2i(FULL_HOLD, 138)]
const STAGE_FRAMES := 200 * 60
const FLOOR_Y := 214.0

var _fails: PackedStringArray = []
var _stage: StageLevel
var _jump_left := 0
var _cooldown := 0
var _card_frames := 0
var _missed_once := false
## Bumps aimed at duel blocks on this stage's run.
var _duel_bumps := 0
## Lesson cards closed on the run, scrolls and all.
var _cards := 0
## While set, the bot only runs right and hops (wrong-answer checks).
var _run_only := false
var _trace := false
var _fine := false
## Whether the body has left the ground since the jump button went down.
var _airborne := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100
	GameProgression.persist = false
	GameProgression.came_from_map = false
	GameProgression.load_data()
	StageAudio.web_audio_unlocked = true
	_trace = OS.get_cmdline_user_args().has("--trace")
	_fine = OS.get_cmdline_user_args().has("--fine")
	_run.call_deferred()


func _run() -> void:
	var from := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--from="):
			from = int(arg.trim_prefix("--from="))
	if not OS.get_cmdline_user_args().has("--checks"):
		await _play_through(from)
	await _check_amber_slices()
	await _check_kiln_lift()
	await _check_fork_gates()
	await _check_bridge()
	await _check_stairs()
	await _check_seed_totals()
	for fail in _fails:
		print("TRAIL fail ", fail)
	print("TRAIL result=%s fails=%d" % ["ok" if _fails.is_empty() else "fail", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- The full run ----------------------------------------------------------

func _play_through(from: int) -> void:
	_open(load(str(GameProgression.get_stage_data(from)["scene"])) as PackedScene)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--at="):
			await _frames(2)
			_place(Vector2(float(arg.trim_prefix("--at=")), FLOOR_Y))
	for expected in range(from, GameProgression.get_stage_count() + 1):
		var stage := _stage
		_duel_bumps = 0
		var done := false
		for _frame in STAGE_FRAMES:
			await get_tree().physics_frame
			if not is_instance_valid(stage):
				break
			if stage.hud.passage_shown or stage.hud.is_cleared():
				done = true
				break
			_drive()
			if _trace and _frame % (4 if _fine else 300) == (3 if _fine else 299):
				var pl := stage.player
				print("TRAIL trace ts=%.2f stage=%d x=%.0f y=%.0f vx=%.0f floor=%s card=%s duel=%s controls=%s falls=%d" % [Engine.time_scale, expected, pl.global_position.x, pl.global_position.y, pl.velocity.x, pl.is_on_floor(), stage.hud.is_card_open(), stage.hud.is_duel_open(), pl.controls_enabled, stage.hud.falls])
		_release_all()
		var tag := "stage %d" % expected
		_expect(done, "%s: the bot reaches the waygate (stopped at x=%.0f)" % [tag, stage.player.global_position.x if is_instance_valid(stage) else -1.0])
		if not done:
			return
		var duel := stage.duel()
		var trial := Lessons.trial(expected)
		_expect(duel.wizard.banished and duel.is_won(), "%s: the wizard was banished" % tag)
		_expect(duel.answers - duel.misses == trial, "%s: the duel took %d right answers (wanted %d)" % [tag, duel.answers - duel.misses, trial])
		if expected == 6:
			_expect(duel.misses >= 1, "%s: the planned miss was counted" % tag)
		_expect(stage.hud.scroll_found == stage.hud.scroll_total, "%s: every scroll read (%d/%d)" % [tag, stage.hud.scroll_found, stage.hud.scroll_total])
		print("TRAIL %s clear time=%.1f falls=%d seeds=%d/%d answers=%d misses=%d sparks=%d cards=%d" % [tag, float(stage.get(&"_elapsed")), stage.hud.falls, stage.hud.seed_count, stage.hud.seed_total, duel.answers, duel.misses, duel.sparks, _cards])
		_cards = 0
		if expected == GameProgression.get_stage_count():
			_expect(stage.hud.is_cleared(), "the crown ends the trail on the clear card")
			_expect(GameProgression.is_cleared(expected), "the last stage is marked cleared")
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


## One frame of play: cards, the duel, gadgets, then plain running.
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
	var player := _stage.player
	if player.is_dead() or not player.controls_enabled:
		_release_moves()
		return
	if _run_only:
		_run_right()
		return
	var duel := _stage.duel()
	if duel != null and duel.is_engaged():
		_fight(duel)
		return
	if _solve_gadget():
		return
	_run_right()


# --- The duel ----------------------------------------------------------------

## Hops a ward wave about to arrive, steps out from under a hex, and otherwise
## lines up under the answer block and jumps into it.
func _fight(duel: WizardDuel) -> void:
	var player := _stage.player
	var x := player.global_position.x
	for spell in get_tree().get_nodes_in_group(&"duel_spell"):
		if not duel.is_ancestor_of(spell) or spell.is_queued_for_deletion():
			continue
		var dx := (spell as Node2D).global_position.x - x
		if spell is WardWave:
			var closing := dx * float((spell as WardWave).direction) < 0.0
			if closing and absf(dx) < 34.0 and absf(dx) > 6.0 and player.is_on_floor():
				_start_jump(8)
				return
		elif spell is HexStrike and not (spell as HexStrike).is_striking() and absf(dx) < 18.0:
			# Step away toward the open side of the arena.
			_set_move(-1.0 if dx >= 0.0 and x > duel.global_position.x + 60.0 else 1.0)
			return
	if not duel.is_asking():
		_set_move(0.0)
		return
	var pick := duel.answer_index()
	if _stage.stage_index() == 6 and not _missed_once:
		pick = posmod(pick + 1, 4)
	var target := duel.block(pick)
	if target.cracked:
		target = duel.block(duel.answer_index())
	if _bump(target):
		_duel_bumps += 1
		if pick != duel.answer_index():
			_missed_once = true


# --- Gadgets -----------------------------------------------------------------

## Walks to the block that solves this stage's gadget and bumps it from below
## until the gadget gives way. False when there is nothing to solve here.
func _solve_gadget() -> bool:
	var x := _stage.player.global_position.x
	match _stage.stage_index():
		1:
			# The bonus scroll: bump row[2], then wait for the scroll to land.
			var bonus := _scroll_node("list_change")
			if bonus != null:
				var gap := bonus.global_position.x - x
				_set_move(signf(gap) if absf(gap) > 2.0 else 0.0)
				return true
			if not bool(_stage.get(&"_loot_given")) and x < 260.0:
				for node in _nodes(&"rune_block"):
					var row_block := node as RuneBlock
					if row_block.index == 2 and row_block.global_position.x < 300.0:
						_bump(row_block)
						return true
			if not bool(_stage.call(&"is_bridged")):
				var block := _labeled("1:11")
				if x > block.global_position.x - 140.0 and x < float(57 * TILE):
					if bool(_stage.get(&"_building")):
						_release_moves()
					else:
						_bump(block)
					return true
		2:
			var door := _nodes(&"vault_door")[0] as VaultDoor
			var held: Dictionary = _stage.get(&"_held")
			if not door.is_open() and not held.is_empty():
				var block := _block(int(held.keys()[0]))
				if x > block.global_position.x - 120.0 and x < door.global_position.x:
					_bump(block)
					return true
		3:
			if x < float(105 * TILE) and _stage.player.global_position.y > 60.0:
				var lift := _stage.call(&"lift") as KilnLift
				var answer := int(_stage.call(&"forge_answer"))
				if int(_stage.call(&"loaded_forge")) != answer:
					var block := _block(answer)
					if x > block.global_position.x - 140.0:
						_bump(block)
						return true
					return false
				_ride_lift(lift)
				return true
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


## Steps onto the lift, stands still while it runs its laps, and at the top
## jumps for the wall to the right.
func _ride_lift(lift: KilnLift) -> void:
	var player := _stage.player
	if not player.is_on_floor():
		_set_move(1.0)
		return
	if lift.is_topped():
		_set_move(1.0)
		_start_jump(FULL_HOLD)
		return
	var dx := lift.global_position.x - player.global_position.x
	_set_move(signf(dx) if absf(dx) > 3.0 and lift.state == KilnLift.State.REST else 0.0)


## Lines up under `block` and jumps into it. True on the frame it jumps.
func _bump(block: RuneBlock) -> bool:
	var player := _stage.player
	var dx := block.global_position.x - player.global_position.x
	if absf(dx) > 3.0:
		_set_move(signf(dx))
		return false
	_set_move(0.0)
	if player.is_on_floor() and absf(player.velocity.x) < 10.0 and _jump_left <= 0 and _cooldown <= 0:
		_start_jump(FULL_HOLD)
		return true
	return false


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
		# A wall or a step: hop just high enough to clear its top.
		var top := feet - 1
		while top > 0 and _solid(col, top - 1):
			top -= 1
		_start_jump(_hold_for_rise(feet - top))
		return
	var surface := _surface(col, feet)
	if surface.y >= 0 and surface.y < feet:
		# A step up: just enough jump to land on it rather than sail past.
		_start_jump(_hold_for_rise(feet - surface.y))
		return
	if surface.y >= 0 and not bool(surface.x):
		return
	# A pit or ember: find the first safe column and pick the shortest hop.
	# Under a low roof every hop is short, so hold it to float the furthest.
	if _low_roof(col, feet) or _low_roof(col + 1, feet):
		_start_jump(FULL_HOLD)
		return
	for ahead in range(col + 1, col + 10):
		var land := _surface(ahead, feet)
		if land.y >= 0 and not bool(land.x):
			var need := float(ahead * TILE + 5) - x
			if land.y < feet:
				# Up and across: the farther the ledge, the more jump it wants.
				var rise := feet - land.y + (1 if need > 32.0 else 0)
				_start_jump(FULL_HOLD if need > 64.0 else _hold_for_rise(rise))
				return
			for hop in HOPS:
				if float(hop.y) >= need + 4.0 or hop.x == FULL_HOLD:
					_start_jump(hop.x)
					return
	_start_jump(FULL_HOLD)


## The shortest hold that lifts the feet `rise` tiles: hold 1 peaks near 1.4
## tiles, hold 4 near 2.4, hold 8 near 3.6, and a full jump near 5.
func _hold_for_rise(rise: int) -> int:
	if rise <= 1:
		return 1
	if rise == 2:
		return 4
	if rise == 3:
		return 8
	return FULL_HOLD


## A solid tile a few rows over the floor in column `col`: a jump here bonks.
func _low_roof(col: int, feet: int) -> bool:
	for row in range(feet - 4, feet - 1):
		if _solid(col, row):
			return true
	return false


func _feet_row() -> int:
	return int((_stage.player.global_position.y + 9.0) / TILE)


## The top of whatever the body would stand on in column `col`, scanning down
## from two rows above the feet (taller steps are walls, measured where they
## stand): Vector2i(is_ember, row), or row -1 for a pit. Ash shelves still
## standing count as ground.
func _surface(col: int, feet: int) -> Vector2i:
	var tiles := _stage.tiles
	for row in range(maxi(feet - 2, 1), 18):
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

## Runs the bot right from `start` for up to `frames`, the gadget left alone.
## Returns the farthest x reached; `falls` says whether it fell meanwhile.
func _try_cross(start: Vector2, frames: int) -> float:
	_place(start)
	_run_only = true
	var farthest := start.x
	var falls := _stage.hud.falls
	for _frame in frames:
		await get_tree().physics_frame
		if _stage.hud.falls > falls:
			break
		_drive()
		farthest = maxf(farthest, _stage.player.global_position.x)
	_run_only = false
	_release_all()
	await _frames(70)
	return farthest


func _check_amber_slices() -> void:
	_open(load("res://levels/level_01.tscn") as PackedScene)
	await _frames(4)
	_dismiss_lessons()
	_expect(int(_stage.call(&"bridge_answer")) == 1, "only planks[1:11] spans Amber's pit")
	var far_edge := float((57 + 11) * TILE)
	for label in ["1:10", "2:11", ":10"]:
		_labeled(label).receive_head_bump()
		await _frames(30)
		_expect(not bool(_stage.call(&"is_bridged")), "planks[%s] does not hold" % label)
		await _frames(60)
		var left := 0
		for x in range(58, 68):
			if _stage.tiles.get_cell_source_id(Vector2i(x, 14)) != -1:
				left += 1
		_expect(left == 0, "planks[%s] crumbles (%d left)" % [label, left])
	var falls := _stage.hud.falls
	var reached := await _try_cross(Vector2(880.0, FLOOR_Y), 240)
	_expect(_stage.hud.falls > falls and reached < far_edge, "the bare pit can't be jumped (reached %.0f)" % reached)
	_labeled("1:11").receive_head_bump()
	await _frames(50)
	_expect(bool(_stage.call(&"is_bridged")), "planks[1:11] holds")
	falls = _stage.hud.falls
	reached = await _try_cross(Vector2(880.0, FLOOR_Y), 240)
	_expect(_stage.hud.falls == falls and reached > far_edge, "the bridge carries the player across (reached %.0f)" % reached)
	_close()


func _check_kiln_lift() -> void:
	_open(load("res://levels/level_03.tscn") as PackedScene)
	await _frames(4)
	_dismiss_lessons()
	_expect(int(_stage.call(&"forge_answer")) == 1, "only forge B's range(4) makes four laps")
	var lift := _stage.call(&"lift") as KilnLift
	var wall_x := float(105 * TILE)
	var expected: Array = [[1, 4, 7], [0, 1, 2, 3], [10, 11, 12]]
	for index in [0, 2, 1]:
		# Off the plate first, so the loop only runs once it is ridden.
		_place(Vector2(lift.global_position.x - 40.0, FLOOR_Y))
		_block(index).receive_head_bump()
		await _until(func() -> bool: return lift.state == KilnLift.State.REST, 240)
		_expect(lift.values == expected[index], "forge %s loads %s (got %s)" % [["A", "B", "C"][index], expected[index], lift.values])
		var on_wall := false
		var topped := false
		for _frame in 8 * 60:
			await get_tree().physics_frame
			_tick_jump()
			topped = topped or lift.is_topped()
			_ride_lift(lift)
			var player := _stage.player
			if player.is_on_floor() and player.global_position.x > wall_x and player.global_position.y < 70.0:
				on_wall = true
				break
		_release_all()
		_expect(topped, "forge %s's lift runs its laps when ridden" % ["A", "B", "C"][index])
		_expect(on_wall == (index == 1), "forge %s's lift %s (rose %.0f px)" % [["A", "B", "C"][index], "reaches the wall top" if index == 1 else "falls short", lift.height()])
	# Nobody gets pinned: a plate sinking over the pit waits for whoever is in it.
	_place(Vector2(lift.global_position.x - 60.0, FLOOR_Y))
	_block(0).receive_head_bump()
	await _until(func() -> bool: return lift.state == KilnLift.State.REST, 240)
	_place(Vector2(lift.global_position.x, FLOOR_Y))
	await _until(func() -> bool: return lift.is_topped(), 240)
	_place(Vector2(lift.global_position.x, 230.0))
	await _frames(150)
	_expect(lift.height() > 20.0 and lift.state == KilnLift.State.SINKING, "the lift waits over a player in its pit (at %.0f)" % lift.height())
	_place(Vector2(lift.global_position.x - 60.0, FLOOR_Y))
	await _frames(90)
	_expect(lift.state == KilnLift.State.REST, "the lift sinks once the pit is clear")
	_close()


func _check_fork_gates() -> void:
	_open(load("res://levels/level_04.tscn") as PackedScene)
	await _frames(4)
	var gates := _nodes(&"truth_gate")
	_expect(gates.size() == 2, "Ministry of Walks has two truth gates")
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
	_open(load("res://levels/level_05.tscn") as PackedScene)
	await _frames(4)
	_dismiss_lessons()
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
	await _try_cross(Vector2(float(chasm.x * TILE) - 60.0, FLOOR_Y), 150)
	_expect(_stage.hud.falls > falls, "the bare chasm can't be jumped")
	_block(5).receive_head_bump()
	await _frames(60)
	_expect(bool(_stage.call(&"is_bridged")), "span(5) holds")
	_block(4).receive_head_bump()
	await _frames(60)
	_expect(_stage.tiles.get_cell_source_id(Vector2i(chasm.y, 14)) != -1, "a built bridge ignores later calls")
	_close()


func _check_stairs() -> void:
	_open(load("res://levels/level_06.tscn") as PackedScene)
	await _frames(4)
	_dismiss_lessons()
	_expect(int(_stage.call(&"stair_answer")) == 1, "only forge B's stair reaches")
	for index in [0, 2]:
		_block(index).receive_head_bump()
		await _until(func() -> bool: return not bool(_stage.get(&"_building")), 120)
		_place(Vector2(1540.0, FLOOR_Y))
		_run_only = true
		var highest := 999.0
		for _frame in 6 * 60:
			await get_tree().physics_frame
			_tick_jump()
			if _stage.player.is_dead():
				continue
			_run_right()
			highest = minf(highest, _stage.player.global_position.y)
		_run_only = false
		_release_all()
		_expect(highest > 100.0, "forge %s's stair can't reach the crown (got to y=%.0f)" % [["A", "B", "C"][index], highest])
	_close()


func _check_seed_totals() -> void:
	for stage_id in range(1, GameProgression.get_stage_count() + 1):
		var data := GameProgression.get_stage_data(stage_id)
		_open(load(str(data["scene"])) as PackedScene)
		await _frames(3)
		_expect(_stage.hud.seed_total == int(data["max_seeds"]), "stage %d has %d seeds; the map says %d" % [stage_id, _stage.hud.seed_total, int(data["max_seeds"])])
		var duel := _stage.duel()
		_expect(duel != null and duel.wizard.ward_total == Lessons.trial(stage_id), "stage %d's wizard wants %d answers" % [stage_id, Lessons.trial(stage_id)])
		var gate := _nodes(&"waygate")[0] as Node2D
		_expect(duel != null and gate.global_position.x > duel.arena_span().y, "stage %d's waygate stands past the arena" % stage_id)
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


## Wrong-answer checks measure the level alone: no cards, no keys, no wizard.
func _dismiss_lessons() -> void:
	for node in _nodes(&"lore_scroll"):
		node.call(&"dismiss")


func _nodes(group: StringName) -> Array[Node]:
	var found: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if _stage.is_ancestor_of(node) and not node.is_queued_for_deletion():
			found.append(node)
	return found


## The stage's own gadget block with this index (never a duel block).
func _block(index: int) -> RuneBlock:
	for node in _nodes(&"rune_block"):
		if (node as RuneBlock).index == index:
			return node as RuneBlock
	return null


func _scroll_node(scroll_id: String) -> LoreScroll:
	for node in _nodes(&"lore_scroll"):
		var scroll := node as LoreScroll
		if scroll.scroll_id == scroll_id and not scroll.taken:
			return scroll
	return null


func _labeled(label: String) -> RuneBlock:
	for node in _nodes(&"rune_block"):
		if (node as RuneBlock).label_text == label:
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
	_airborne = false


func _tick_jump() -> void:
	if _cooldown > 0:
		_cooldown -= 1
		# Back on the ground with the button up, the next jump may come soon.
		if _jump_left <= 0 and _stage != null and _stage.player.is_on_floor():
			_cooldown = mini(_cooldown, 4)
	if _jump_left <= 0:
		return
	_jump_left -= 1
	# Landed with the button still down: let go, as a player would.
	var player := _stage.player if _stage != null else null
	if player != null and not player.is_on_floor():
		_airborne = true
	var landed := _airborne and player != null and player.is_on_floor()
	if _jump_left == 0 or landed:
		_jump_left = 0
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
