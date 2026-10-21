extends StageLevel

## Kiln Mouth. Lesson 3: Loops & range.
## Ember and an ash shelf are taught on solid ground, then both cross a pit.
## Short by design, with no lantern. The waygate leads on to Smelter's Fork.
##
## On the last run a forge block runs `for i in range(1, 9, 2)`: bumped, it
## drops a seed on each number the loop visits along a floor ruler, lighting
## 1, 3, 5, 7 and never 9. The Kiln Archmage waits past it.

const WIDTH := 121
const FORGE_TINT := Color(0.5, 1.0, 0.65)
const FORGE_AT := Vector2(1496, 152)
const RULER_AT := Vector2(1512, 224)
const FORGE_RANGE: Array[int] = [1, 9, 2]
const FORGE_BEAT := 0.3

var _forge_spent: bool = false
var _ruler: RangeRuler
const _FAR := preload("res://assets/backgrounds/kiln_far.png")
const _MID := preload("res://assets/backgrounds/kiln_mid.png")
const _NEAR := preload("res://assets/backgrounds/kiln_near.png")


func stage_index() -> int:
	return 3


func _passage_detail() -> String:
	return "Smelter's Fork awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	_add_parallax("FarKiln", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(0.85, 0.78, 0.78))
	# The pots are bright, so they sit back behind a heavier tint.
	_add_parallax("MidPots", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.6, 0.52, 0.55))
	_add_parallax("NearSlag", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.7, 0.62, 0.66))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 7),
		Vector2i(10, 17),
		Vector2i(22, 36),
		Vector2i(41, 46),
		Vector2i(55, 60),
		Vector2i(63, 68),
		Vector2i(71, 83),
		Vector2i(86, 118),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	_paint_ember(8, 9, true)
	_paint_solid(18, 21, 15)
	_paint_roof(26, 34, 11)
	_paint_ember(38, 39, false)


func _spawn_actors() -> void:
	_spawn_shelf(Vector2(320, 224), 96.0, 1.0, 40.0)
	_spawn_shelf(Vector2(816, 224), 64.0, 1.25, 64.0)
	_spawn_crawler(Vector2(1064, 224), 32.0)
	_spawn_cache(Vector2(1200, 152))
	_spawn(clay_brick_scene, Vector2(1296, 152))
	var seed_points: Array[Vector2] = [
		Vector2(608, 200),
		Vector2(624, 200),
		Vector2(640, 200),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(104, 222), "loop_for")
	_spawn_scroll(Vector2(424, 222), "loop_range")
	_spawn_scroll(Vector2(920, 222), "loop_total")
	_spawn_scroll(Vector2(1160, 222), "loop_while")
	_build_forge()
	# The final exam, on the long last run past the forge.
	_spawn_wizard(Vector2(1744, 224), "Kiln Archmage", Color(0.5, 1.0, 0.65))
	_spawn_gate(Vector2(1840, 224))


func _build_forge() -> void:
	var start: int = FORGE_RANGE[0]
	var stop: int = FORGE_RANGE[1]
	var step: int = FORGE_RANGE[2]
	_spawn_sign(FORGE_AT + Vector2(56.0, -18.0), "for i in range(%d, %d, %d):\n    seed(i)" % [start, stop, step], FORGE_TINT)
	var block := _spawn_rune_block(FORGE_AT, 0, "for", FORGE_TINT)
	block.bumped.connect(_on_forge_bumped)
	_ruler = RangeRuler.new()
	_ruler.count = stop + 1
	_ruler.tint = FORGE_TINT
	_ruler.position = RULER_AT
	add_child(_ruler)


func _gadget_seeds() -> int:
	return 0 if _forge_spent else range(FORGE_RANGE[0], FORGE_RANGE[1], FORGE_RANGE[2]).size()


## Runs the loop one beat at a time: each i lights its tick and drops a seed.
func _on_forge_bumped(block: RuneBlock) -> void:
	var above := block.global_position + Vector2(-30.0, -14.0)
	if _forge_spent:
		Fx.float_text(self, above, "The loop has run", FORGE_TINT.lightened(0.3))
		return
	_forge_spent = true
	block.set_lit(true)
	block.flash(FORGE_TINT)
	for i in range(FORGE_RANGE[0], FORGE_RANGE[1], FORGE_RANGE[2]):
		await get_tree().create_timer(FORGE_BEAT, false).timeout
		if not is_inside_tree():
			return
		_ruler.light(i)
		var at := _ruler.tick_position(i)
		Fx.float_text(self, at + Vector2(-4.0, -24.0), "i=%d" % i, FORGE_TINT.lightened(0.4))
		var seed := _spawn(emberseed_scene, at + Vector2(0.0, -6.0))
		_bind_seed(seed)
		if seed != null:
			seed.call(&"pop_up")
	await get_tree().create_timer(FORGE_BEAT, false).timeout
	if is_inside_tree():
		Fx.float_text(self, _ruler.tick_position(FORGE_RANGE[1]) + Vector2(-64.0, -36.0), "stops before %d" % FORGE_RANGE[1], FORGE_TINT.lightened(0.4))
