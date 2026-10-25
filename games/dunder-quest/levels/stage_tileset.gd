class_name StageTileset
extends RefCounted

const SOURCE := 0
const GROUND := Vector2i(0, 0)
const FILL := Vector2i(1, 0)
const SLAB := Vector2i(2, 0)
const ONE_WAY := Vector2i(3, 0)
const EMBER := Vector2i(4, 0)
const EMBER_FRAMES := 3


static func build(texture: Texture2D) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	tileset.add_source(source, SOURCE)
	for atlas in [GROUND, FILL, SLAB, ONE_WAY, EMBER]:
		source.create_tile(atlas)
	# Ember flickers through the frames painted to its right in the sheet.
	if texture.get_width() >= (EMBER.x + EMBER_FRAMES) * 16:
		source.set_tile_animation_columns(EMBER, 0)
		source.set_tile_animation_frames_count(EMBER, EMBER_FRAMES)
		source.set_tile_animation_speed(EMBER, 6.0)

	_add_polygon(source.get_tile_data(GROUND, 0), _full_square(), false)
	_add_polygon(source.get_tile_data(FILL, 0), _full_square(), false)
	_add_polygon(source.get_tile_data(SLAB, 0), _full_square(), false)
	_add_polygon(source.get_tile_data(ONE_WAY, 0), _top_strip(), true)
	_add_polygon(source.get_tile_data(EMBER, 0), _full_square(), false)
	return tileset


static func _add_polygon(tile_data: TileData, points: PackedVector2Array, one_way: bool) -> void:
	if tile_data == null:
		push_error("Stage tile is missing collision data")
		return
	tile_data.add_collision_polygon(0)
	var index := tile_data.get_collision_polygons_count(0) - 1
	tile_data.set_collision_polygon_points(0, index, points)
	if one_way:
		tile_data.set_collision_polygon_one_way(0, index, true)
		tile_data.set_collision_polygon_one_way_margin(0, index, 8.0)


static func _full_square() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-8, -8),
		Vector2(8, -8),
		Vector2(8, 8),
		Vector2(-8, 8),
	])


static func _top_strip() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-8, -8),
		Vector2(8, -8),
		Vector2(8, -3),
		Vector2(-8, -3),
	])
