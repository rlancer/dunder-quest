extends StageLevel

## Amber Hollow. The waygate opens the next stage.

const _FAR := preload("res://assets/backgrounds/amber_far.png")
const _MID := preload("res://assets/backgrounds/amber_mid.png")
const _NEAR := preload("res://assets/backgrounds/amber_near.png")


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
	_spawn(copperling_scene, Vector2(416, 188))
	_spawn_cache(Vector2(552, 136))
	_spawn(clay_brick_scene, Vector2(616, 136))
	var seed_xs: Array[int] = [680, 696, 712, 728, 744]
	for seed_x in seed_xs:
		_bind_seed(_spawn(emberseed_scene, Vector2(float(seed_x), 210.0)))
	# On the flat run past the seed gap, where the route walks without jumping.
	_spawn_wizard(Vector2(1008, 224), "Ash Hexer", Color(0.55, 0.85, 1.0))
	_spawn_gate(Vector2(1224, 224))
