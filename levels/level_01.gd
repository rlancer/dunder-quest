extends StageLevel

## Amber Hollow. Lesson 1: Lists & Indexing.
## The run opens on a row of index blocks under a slate reading row[2]:
## counting from zero, the third block holds a bonus scroll. Scrolls on the
## way teach indexing, negative indexes and slices before the Ash Hexer's quiz.

const _FAR := preload("res://assets/backgrounds/amber_far.png")
const _MID := preload("res://assets/backgrounds/amber_mid.png")
const _NEAR := preload("res://assets/backgrounds/amber_near.png")
const INDEX_TINT := Color(0.55, 0.85, 1.0)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## What the index blocks hold, left to right. The slate asks for row[LOOT].
const ROW: Array[String] = ["ash", "clay", "scroll", "ember"]
const LOOT := 2
const ROW_X := 88.0
const ROW_Y := 152.0

var _loot_given: bool = false


func stage_index() -> int:
	return 1


func _stage_width() -> int:
	return 84


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	_add_parallax("FarSky", _FAR, Vector2(0.08, 0.0), -40, 2.0)
	_add_parallax("MidHills", _MID, Vector2(0.3, 0.0), -30, 2.0)
	# Dimmed so the foreground brush never competes with the play lane.
	_add_parallax("NearBrush", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.72, 0.62, 0.7))


func _passage_detail() -> String:
	return "Cinder Span awaits"


func _paint_stage() -> void:
	var spans: Array[Vector2i] = [
		Vector2i(0, 11),
		Vector2i(15, 20),
		Vector2i(31, 47),
		Vector2i(52, _stage_width() - 1),
	]
	for span in spans:
		_paint_solid(span.x, span.y, 14)
	_paint_row(21, 30, 12, StageTileset.SLAB)
	_paint_row(56, 60, 12, StageTileset.ONE_WAY)
	_paint_row(64, 70, 10, StageTileset.SLAB)


func _spawn_actors() -> void:
	_build_index_row()
	_spawn_scroll(Vector2(76, 222), "list_zero")
	_spawn_scroll(Vector2(288, 222), "list_negative")
	_spawn_scroll(Vector2(504, 222), "list_slice")
	_spawn(copperling_scene, Vector2(416, 188))
	_spawn_cache(Vector2(552, 136))
	_spawn(clay_brick_scene, Vector2(616, 136))
	var seed_xs: Array[int] = [680, 696, 712, 728, 744]
	for seed_x in seed_xs:
		_bind_seed(_spawn(emberseed_scene, Vector2(float(seed_x), 210.0)))
	# On the flat run past the seed gap, where the route walks without jumping.
	_spawn_wizard(Vector2(1008, 224), "Ash Hexer", Color(0.55, 0.85, 1.0))
	_spawn_gate(Vector2(1224, 224))


## Four blocks overhead at the start, marked only "?", under a slate asking for
## row[2]. Each bump reveals that block's index and what it holds.
func _build_index_row() -> void:
	_spawn_sign(Vector2(ROW_X + 24.0, ROW_Y - 10.0), "loot = row[%d]" % LOOT, INDEX_TINT)
	for index in ROW.size():
		var block := _spawn_rune_block(Vector2(ROW_X + 16.0 * index, ROW_Y), index, "?", INDEX_TINT)
		block.bumped.connect(_on_index_bumped)


func _on_index_bumped(block: RuneBlock) -> void:
	block.set_label(str(block.index))
	var above := block.global_position + Vector2(-28.0, -14.0)
	if block.index != LOOT:
		block.flash(BAD)
		Fx.float_text(self, above, "row[%d] is \"%s\"" % [block.index, ROW[block.index]], BAD.lightened(0.3))
		return
	block.flash(GOOD)
	block.set_lit(true)
	if _loot_given:
		return
	_loot_given = true
	Fx.float_text(self, above, "row[%d] is the scroll!" % LOOT, GOOD.lightened(0.3))
	var scroll := _spawn_scroll(block.global_position + Vector2(0.0, -6.0), "list_change", true)
	scroll.pop_to(Vector2(block.global_position.x, 222.0))
