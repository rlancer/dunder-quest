extends StageLevel

## Shrubbery Wood. Lesson 1: Lists & Indexing. The first stage, so it teaches
## the moves one at a time: a hop, a copperling to stomp, a step up, a drop.
##
## Over the start, a row of index blocks under a slate reading row[2]:
## counting from zero, the third block holds a bonus scroll.
##
## Near the end a pit ten tiles wide is too far to jump. A ruler numbers its
## cells as a list, 0 to 11, from the near edge to the far one, and four
## slice blocks hang before it. Bumping one lays planks on the cells its
## slice takes. Only a bridge that touches both edges holds: planks[1:11]
## covers the pit's cells 1 to 10, and every other slice crumbles.
## The Knight Who Says Mi duels in the arena past it.

const WIDTH := 112
const INDEX_TINT := Color(0.55, 0.85, 1.0)
const BRIDGE_TINT := Color(1.0, 0.8, 0.45)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## What the index blocks hold, left to right. The slate asks for row[LOOT].
const ROW: Array[String] = ["ham", "spam", "scroll", "shrub"]
const LOOT := 2
const ROW_X := 152.0
const ROW_Y := 152.0
## The planks list: cell 0 is the near edge's last tile, cells 1 to 10 the
## pit, cell 11 the far edge's first tile.
const PLANK_START := 57
const PLANK_CELLS := 12
const SLICES: Array[Vector2i] = [Vector2i(1, 10), Vector2i(1, 11), Vector2i(2, 11), Vector2i(0, 10)]
const SLICE_LABELS: Array[String] = ["1:10", "1:11", "2:11", ":10"]
const SLICE_X := 776.0
const SLICE_GAP := 40.0
const PLANK_BEAT := 0.05
const WRONG_HOLD := 0.7
const ARENA := 76
const SHRUB := preload("res://assets/sprites/shrub.png")
## Where the shrubberies stand along the floor, in pixels.
const SHRUBS: Array[float] = [30.0, 190.0, 430.0, 760.0, 880.0, 1180.0]

const _FAR := preload("res://assets/backgrounds/wood_far.png")
const _MID := preload("res://assets/backgrounds/wood_mid.png")
const _NEAR := preload("res://assets/backgrounds/wood_near.png")

var _loot_given: bool = false
var _building: bool = false
var _bridged: bool = false
var _plank_cells: Array[Vector2i] = []
var _slice_blocks: Array[RuneBlock] = []


func stage_index() -> int:
	return 1


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# Shrubbery Wood: old oaks and neatly trimmed shrubberies. The busy layers sit back
	# behind darker tints so they never compete with the play lane.
	_add_parallax("FarWood", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(0.9, 0.9, 0.9))
	_add_parallax("MidTrees", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.7, 0.7, 0.72))
	_add_parallax("NearBrush", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.5, 0.48, 0.52))


func _passage_detail() -> String:
	return "The Cheese Shoppe awaits"


func _paint_stage() -> void:
	var spans: Array[Vector2i] = [
		Vector2i(0, 13),
		Vector2i(16, 27),
		Vector2i(39, PLANK_START),
		Vector2i(PLANK_START + PLANK_CELLS - 1, ARENA),
	]
	for span in spans:
		_paint_solid(span.x, span.y, 14)
	# A step up two tiles, then a drop over a short gap.
	_paint_solid(28, 35, 12)


func _spawn_actors() -> void:
	_build_index_row()
	_spawn_scroll(Vector2(104, 222), "list_zero")
	_spawn_scroll(Vector2(488, 190), "list_negative")
	_spawn_scroll(Vector2(712, 222), "list_slice")
	_spawn(copperling_scene, Vector2(392, 224))
	_spawn_cache(Vector2(296, 152))
	_spawn(clay_brick_scene, Vector2(328, 152))
	var seed_points: Array[Vector2] = [
		Vector2(232, 196),
		Vector2(248, 186),
		Vector2(264, 196),
		Vector2(520, 170),
		Vector2(536, 170),
		Vector2(1128, 210),
		Vector2(1144, 210),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_checkpoint(Vector2(664, 224))
	_build_slice_bridge()
	_build_arena(ARENA, "The Knight Who Says Mi", Color(0.55, 0.85, 1.0))
	for x in SHRUBS:
		_spawn_prop(SHRUB, Vector2(x, 224.0))


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


func _build_slice_bridge() -> void:
	_spawn_sign(Vector2(SLICE_X + SLICE_GAP * 1.5, ROW_Y - 12.0), "bridge = planks[?]\n# the pit is cells 1 to %d" % (PLANK_CELLS - 2), BRIDGE_TINT)
	for index in SLICES.size():
		var block := RUNE_BLOCK.new() as RuneBlock
		block.index = index
		block.label_text = SLICE_LABELS[index]
		block.label_width = 36.0
		block.tint = BRIDGE_TINT
		block.position = Vector2(SLICE_X + SLICE_GAP * index, ROW_Y)
		add_child(block)
		block.bumped.connect(_on_slice_bumped)
		_slice_blocks.append(block)
	var ruler := RangeRuler.new()
	ruler.count = PLANK_CELLS
	ruler.tint = BRIDGE_TINT
	ruler.position = Vector2(float(PLANK_START * TILE + 8), 224.0)
	add_child(ruler)


## The cells planks[a:b] lays planks on, as tiles on the floor row.
static func slice_cells(slice: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for index in range(slice.x, slice.y):
		cells.append(Vector2i(PLANK_START + index, 14))
	return cells


## A bridge holds only when it touches both edges: every pit cell is planked.
static func slice_holds(slice: Vector2i) -> bool:
	return slice.x <= 1 and slice.y >= PLANK_CELLS - 1


## Lays the slice's planks one beat at a time, then the stage says whether
## the bridge reaches both edges. A bridge that doesn't crumbles.
func _on_slice_bumped(block: RuneBlock) -> void:
	var above := block.global_position + Vector2(-36.0, -14.0)
	if _bridged:
		Fx.float_text(self, above, "The bridge holds", BRIDGE_TINT.lightened(0.3))
		return
	if _building:
		return
	_building = true
	var slice := SLICES[block.index]
	Fx.float_text(self, above, "planks[%s]: cells %d to %d" % [SLICE_LABELS[block.index], slice.x, slice.y - 1], BRIDGE_TINT.lightened(0.4))
	_plank_cells.clear()
	for cell in slice_cells(slice):
		# Cells on the edges are ground already; only the pit takes planks.
		if tiles.get_cell_source_id(cell) == -1:
			_plank_cells.append(cell)
	if not await _raise_tiles(_plank_cells, StageTileset.ONE_WAY, PLANK_BEAT):
		return
	var middle := tiles.map_to_local(Vector2i(PLANK_START + PLANK_CELLS / 2, 14))
	if slice_holds(slice):
		_bridged = true
		_building = false
		block.flash(GOOD)
		block.set_lit(true)
		Fx.float_text(self, middle + Vector2(-48.0, -24.0), "Edge to edge: it holds!", GOOD.lightened(0.3))
		return
	block.flash(BAD)
	var gap := "cell %d" % (PLANK_CELLS - 2) if slice.y < PLANK_CELLS - 1 else "cell 1"
	Fx.float_text(self, middle + Vector2(-48.0, -24.0), "No plank on %s!" % gap, BAD.lightened(0.3))
	await get_tree().create_timer(WRONG_HOLD, false).timeout
	if not is_inside_tree():
		return
	_crumble_tiles(_plank_cells)
	_plank_cells.clear()
	_building = false


func is_bridged() -> bool:
	return _bridged


## Test hook: the slice block whose bridge holds.
func bridge_answer() -> int:
	for index in SLICES.size():
		if slice_holds(SLICES[index]):
			return index
	return -1
