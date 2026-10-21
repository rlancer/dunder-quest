extends StageLevel

## Bellows Bridge. Lesson 5: Functions & return.
## A raised bellows deck, a low roof, supported ember, and a raised cache
## floor near the end. Lanterns before and after the chasm.
##
## The chasm is fourteen tiles wide, too far for any jump. A slate defines
## `span(n)` and four call blocks hang before the edge, one per argument.
## Bumping a block calls span with its number and lays a plank bridge as long
## as the value returned: short bridges crumble into the chasm, long ones
## crash into the far cliff and break, and only span(5) == 14 holds.
## The Bellows Sage duels in the arena at the far end.

const WIDTH := 177
const ARENA := 141
const BRIDGE_TINT := Color(1.0, 0.66, 0.36)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## The chasm's tiles, inclusive, on the floor row.
const CHASM := Vector2i(85, 98)
const ARGS: Array[int] = [3, 4, 5, 6]
const CALLS_X := 1240.0
const CALLS_Y := 152.0
const PLANK_BEAT := 0.04
## How long a wrong bridge stands before it gives way.
const WRONG_HOLD := 0.6

var _building: bool = false
var _bridged: bool = false
var _plank_cells: Array[Vector2i] = []
const _FAR := preload("res://assets/backgrounds/span_far.png")
const _MID := preload("res://assets/backgrounds/span_mid.png")
const _NEAR := preload("res://assets/backgrounds/span_near.png")


func stage_index() -> int:
	return 5


func _passage_detail() -> String:
	return "Crucible Crown awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# The span's ruins at a deeper, smokier dusk: the bellows works.
	_add_parallax("FarSky", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(1.0, 0.72, 0.62))
	_add_parallax("MidRuins", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.72, 0.56, 0.52))
	_add_parallax("NearSilhouette", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.6, 0.48, 0.46))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 12),
		Vector2i(21, 28),
		Vector2i(34, 50),
		Vector2i(53, 64),
		Vector2i(69, CHASM.x - 1),
		Vector2i(CHASM.y + 1, 114),
		Vector2i(118, 124),
		Vector2i(133, ARENA),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	# The bellows deck, two tiles up.
	_paint_solid(13, 20, 12)
	_paint_roof(37, 43, 10)
	_paint_ember(51, 52, true)
	# The cache floor, three tiles up.
	_paint_solid(125, 132, 11)


func _spawn_actors() -> void:
	_spawn_crawler(Vector2(768, 224), 24.0)
	_spawn_checkpoint(Vector2(864, 224))
	_spawn_checkpoint(Vector2(1136, 224))
	_spawn_checkpoint(Vector2(1616, 224))
	_spawn_crawler(Vector2(1760, 224), 28.0)
	_spawn_cache(Vector2(2056, 104))
	_spawn(clay_brick_scene, Vector2(2104, 104))
	var seed_points: Array[Vector2] = [
		Vector2(264, 160),
		Vector2(280, 160),
		Vector2(824, 190),
		Vector2(840, 190),
		Vector2(1048, 190),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(104, 222), "func_def")
	_spawn_scroll(Vector2(272, 190), "func_return")
	_spawn_scroll(Vector2(928, 222), "func_none")
	_spawn_scroll(Vector2(1168, 222), "func_default")
	_spawn_scroll(Vector2(1680, 222), "func_scope")
	_build_calls()
	_build_arena(ARENA, "Bellows Sage", Color(1.0, 0.62, 0.4))


func _build_calls() -> void:
	_spawn_sign(Vector2(CALLS_X + 24.0, CALLS_Y - 12.0), "def span(n):\n    return n * 2 + 4\nbridge = span(?)  # gap %d" % _gap(), BRIDGE_TINT)
	for index in ARGS.size():
		var block := _spawn_rune_block(Vector2(CALLS_X + 16.0 * index, CALLS_Y), ARGS[index], str(ARGS[index]), BRIDGE_TINT)
		block.bumped.connect(_on_call_bumped)


func _gap() -> int:
	return CHASM.y - CHASM.x + 1


## span(n) as the slate defines it.
static func span(n: int) -> int:
	return n * 2 + 4


## Calls span with the block's number and lays that many planks from the
## near edge. Only an exact fit stays up.
func _on_call_bumped(block: RuneBlock) -> void:
	var above := block.global_position + Vector2(-40.0, -14.0)
	if _bridged:
		Fx.float_text(self, above, "The bridge holds", BRIDGE_TINT.lightened(0.3))
		return
	if _building:
		return
	_building = true
	var length := span(block.index)
	var fits := length == _gap()
	Fx.float_text(self, above, "span(%d) returns %d" % [block.index, length], BRIDGE_TINT.lightened(0.4))
	_plank_cells.clear()
	for offset in mini(length, _gap()):
		_plank_cells.append(Vector2i(CHASM.x + offset, 14))
	if not await _raise_tiles(_plank_cells, StageTileset.ONE_WAY, PLANK_BEAT):
		return
	var end := tiles.map_to_local(Vector2i(CHASM.x + mini(length, _gap()) - 1, 14))
	if fits:
		_bridged = true
		_building = false
		block.flash(GOOD)
		block.set_lit(true)
		Fx.float_text(self, end + Vector2(-40.0, -20.0), "%d == gap: it holds!" % length, GOOD.lightened(0.3))
		return
	block.flash(BAD)
	var verdict := "%d < %d: too short!" % [length, _gap()] if length < _gap() else "%d > %d: won't fit!" % [length, _gap()]
	Fx.float_text(self, end + Vector2(-40.0, -20.0), verdict, BAD.lightened(0.3))
	if length > _gap():
		Fx.sparks(self, end + Vector2(8.0, -4.0), BAD, 12, 60.0)
	await get_tree().create_timer(WRONG_HOLD, false).timeout
	if not is_inside_tree():
		return
	_crumble_tiles(_plank_cells)
	_plank_cells.clear()
	_building = false


func is_bridged() -> bool:
	return _bridged


## Test hook: the argument whose span fits the chasm.
func bridge_answer() -> int:
	for n in ARGS:
		if span(n) == _gap():
			return n
	return -1
