class_name Tiles
extends RefCounted

## The stage tileset: one row of 16x16 tiles per theme in
## assets/sprites/tiles.png (see tools/paint.py). Columns: floor top, fill
## under it, a solid shelf, and a one-way plank you can jump up through.

const SOURCE := 0
const FLOOR := 0
const FILL := 1
const SHELF := 2
const PLANK := 3
const COLUMNS := 4


static func build(texture: Texture2D, rows: int) -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer(0)
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(16, 16)
	tileset.add_source(source, SOURCE)
	for row in rows:
		for column in COLUMNS:
			var atlas := Vector2i(column, row)
			source.create_tile(atlas)
			var data := source.get_tile_data(atlas, 0)
			data.add_collision_polygon(0)
			if column == PLANK:
				data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]))
				data.set_collision_polygon_one_way(0, 0, true)
				data.set_collision_polygon_one_way_margin(0, 0, 8.0)
			else:
				data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	return tileset
