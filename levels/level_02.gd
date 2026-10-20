extends StageLevel

## Cinder Span. Short floors, a full-jump pit, a tap-only pad, and a low roof.
## Ember tiles kill on touch. Ash shelves crack, then fall. Both reset on respawn.
## The longest stage, so two lanterns hold the respawn point.

const WIDTH := 166
const _FAR := preload("res://assets/backgrounds/span_far.png")
const _MID := preload("res://assets/backgrounds/span_mid.png")
const _NEAR := preload("res://assets/backgrounds/span_near.png")


func stage_index() -> int:
	return 2


func _passage_detail() -> String:
	return "Kiln Mouth awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	_add_parallax("FarSky", _FAR, Vector2(0.08, 0.0), -40, 2.0)
	_add_parallax("MidRuins", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.85, 0.8, 0.85))
	_add_parallax("NearSilhouette", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.7, 0.62, 0.66))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 7),
		Vector2i(10, 16),
		Vector2i(20, 23),
		Vector2i(27, 28),
		Vector2i(35, 42),
		Vector2i(47, 51),
		Vector2i(59, 62),
		Vector2i(73, 80),
		Vector2i(106, 109),
		Vector2i(113, 116),
		Vector2i(121, 125),
		Vector2i(132, 136),
		Vector2i(139, 142),
		Vector2i(148, 151),
		Vector2i(156, 163),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	_paint_ember(8, 9, true)
	_paint_ember(127, 130, false)
	_paint_solid(52, 58, 15)
	_paint_roof(40, 46, 10)
	_paint_roof(79, 82, 10)
	_paint_row(83, 85, 13, StageTileset.ONE_WAY)
	_paint_row(88, 91, 12, StageTileset.ONE_WAY)
	_paint_row(93, 96, 9, StageTileset.SLAB)
	_paint_row(95, 98, 14, StageTileset.ONE_WAY)
	_paint_row(101, 103, 14, StageTileset.ONE_WAY)


func _spawn_actors() -> void:
	_spawn_shelf(Vector2(856, 224), 48.0, 0.20, 14.0)
	_spawn_shelf(Vector2(1104, 192), 64.0, 0.70, 48.0)
	_spawn_checkpoint(Vector2(1216, 224))
	_spawn_checkpoint(Vector2(1728, 224))
	_spawn_crawler(Vector2(1850, 224), 32.0)
	_spawn_crawler(Vector2(1988, 224), 26.0)
	_spawn_cache(Vector2(2248, 152))
	_spawn(clay_brick_scene, Vector2(2392, 152))
	var seed_points: Array[Vector2] = [
		Vector2(1496, 132),
		Vector2(1512, 132),
		Vector2(1536, 132),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_gate(Vector2(2568, 224))
