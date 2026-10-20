extends StageLevel

## Kiln Mouth. Ember and an ash shelf are taught on solid ground, then both cross a pit.
## Short by design, with no lantern. The waygate ends the run.

const WIDTH := 96
const _FAR := preload("res://assets/backgrounds/kiln_far.png")
const _MID := preload("res://assets/backgrounds/kiln_mid.png")
const _NEAR := preload("res://assets/backgrounds/kiln_near.png")


func stage_index() -> int:
	return 3


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
		Vector2i(86, 95),
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
	# On the ledge between the seed hop and the second shelf.
	_spawn_wizard(Vector2(720, 224), "Kiln Archmage", Color(0.5, 1.0, 0.65))
	_spawn_gate(Vector2(1456, 224))
