extends StageLevel

## Smelter's Fork. Lesson 4: Booleans & Conditions.
## A pit with a stepping plank, supported ember, an ash shelf over a long pit,
## and a raised smelter floor with the cache and a copperling. Two lanterns.
##
## Two truth gates bar the way. Each stands on an `if`, with a heat dial
## block before it: every bump turns heat through 0, 1, 2, 3 and the gate
## re-checks its condition, opening only while it is True. The first needs
## `heat > 1 and heat != 3`; the second `heat % 2 == 1 and not heat == 1`.
## The Smelt Oracle waits past the second.

const WIDTH := 150
const GATE_TINT := Color(0.7, 0.8, 1.0)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
const HEAT_STEPS := 4
## Each gate: where its dial hangs, where the gate stands, and its `if`.
const GATES: Array[Dictionary] = [
	{"dial": Vector2(952, 152), "gate": Vector2(1032, 224), "code": "heat > 1 and heat != 3"},
	{"dial": Vector2(1976, 152), "gate": Vector2(2056, 224), "code": "heat % 2 == 1 and not heat == 1"},
]

var _gates: Array[TruthGate] = []
var _dials: Array[RuneBlock] = []
var _heat: Array[int] = []
const _FAR := preload("res://assets/backgrounds/kiln_far.png")
const _MID := preload("res://assets/backgrounds/kiln_mid.png")
const _NEAR := preload("res://assets/backgrounds/kiln_near.png")


func stage_index() -> int:
	return 4


func _passage_detail() -> String:
	return "Bellows Bridge awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# The kiln's backdrop under a cold blue cast: the smelter's quench yard.
	_add_parallax("FarSmelter", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(0.62, 0.7, 0.95))
	_add_parallax("MidPots", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.45, 0.48, 0.62))
	_add_parallax("NearSlag", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.55, 0.56, 0.7))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 14),
		Vector2i(18, 30),
		Vector2i(33, 44),
		Vector2i(50, 74),
		Vector2i(83, 90),
		Vector2i(100, 104),
		Vector2i(109, 134),
		Vector2i(137, WIDTH - 1),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	_paint_ember(31, 32, true)
	_paint_row(46, 48, 12, StageTileset.ONE_WAY)
	# The smelter floor, three tiles up, with the cache over it.
	_paint_solid(91, 99, 11)
	_paint_ember(135, 136, false)


func _spawn_actors() -> void:
	_spawn_crawler(Vector2(416, 224), 24.0)
	_spawn_checkpoint(Vector2(832, 224))
	_spawn_shelf(Vector2(1264, 224), 64.0, 1.0, 40.0)
	_spawn_checkpoint(Vector2(1760, 224))
	# Patrols the smelter floor, which its ledges keep it on.
	_spawn_crawler(Vector2(1560, 176), 22.0)
	_spawn_cache(Vector2(1528, 104))
	_spawn(clay_brick_scene, Vector2(1576, 104))
	var seed_points: Array[Vector2] = [
		Vector2(504, 190),
		Vector2(520, 190),
		Vector2(760, 176),
		Vector2(776, 176),
		Vector2(1264, 196),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(120, 222), "bool_compare")
	_spawn_scroll(Vector2(600, 222), "bool_ops")
	_spawn_scroll(Vector2(1096, 222), "bool_elif")
	_spawn_scroll(Vector2(1488, 174), "bool_truthy")
	_spawn_scroll(Vector2(1800, 222), "bool_chain")
	_build_gates()
	# The final exam, on the long last run past the second gate.
	_spawn_wizard(Vector2(2256, 224), "Smelt Oracle", Color(0.6, 0.78, 1.0))
	_spawn_gate(Vector2(2352, 224))


func _build_gates() -> void:
	for index in GATES.size():
		var spec: Dictionary = GATES[index]
		var dial_at: Vector2 = spec["dial"]
		var gate_at: Vector2 = spec["gate"]
		_heat.append(0)
		var dial := _spawn_rune_block(dial_at, index, "0", GATE_TINT)
		dial.bumped.connect(_on_dial_bumped)
		_dials.append(dial)
		var gate := TruthGate.new()
		gate.tint = GATE_TINT
		gate.position = gate_at
		add_child(gate)
		_gates.append(gate)
		_spawn_sign(Vector2((dial_at.x + gate_at.x) * 0.5, dial_at.y - 12.0), "if %s:\n    gate.open()" % spec["code"], GATE_TINT)


## Turns this dial's heat one notch and lets its gate re-check its `if`.
func _on_dial_bumped(dial: RuneBlock) -> void:
	var index := dial.index
	_heat[index] = (_heat[index] + 1) % HEAT_STEPS
	var heat := _heat[index]
	dial.set_label(str(heat))
	var truth := heat_opens(index, heat)
	dial.flash(GOOD if truth else BAD)
	dial.set_lit(truth)
	_gates[index].set_open(truth)
	var above := dial.global_position + Vector2(-34.0, -14.0)
	Fx.float_text(self, above, "heat = %d: %s" % [heat, "True" if truth else "False"], (GOOD if truth else BAD).lightened(0.3))


## The `if` over gate `index`, evaluated for `heat`, the way Python would.
func heat_opens(index: int, heat: int) -> bool:
	if index == 0:
		return heat > 1 and heat != 3
	return heat % 2 == 1 and not heat == 1


## Test hook: the one heat that opens each gate.
func gate_answers() -> Array[int]:
	var answers: Array[int] = []
	for index in GATES.size():
		for heat in HEAT_STEPS:
			if heat_opens(index, heat):
				answers.append(heat)
	return answers
