extends StageLevel

## Crucible Crown. Lesson 6: Comprehensions. The last stage.
## A two-step climb to a high plateau, a long drop, ember, and an ash shelf
## over a pit, then the crown wall: eight tiles of sheer stone with the
## wizard and the waygate on top.
##
## Three forge blocks hang before the wall, A, B and C, each running a list
## comprehension from the slate above. Bumping one builds a stair of plank
## steps up the wall, one step per number in its list, that many tiles high;
## a 0 builds nothing. Only B's [2, 4, 6, 8] makes a stair that can be
## climbed. The Crucible King holds the crown.

const WIDTH := 150
const STAIR_TINT := Color(1.0, 0.86, 0.4)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## The crown wall's first column and its top surface row.
const WALL_X := 113
const CROWN_ROW := 6
## How wide each step is, in tiles.
const STEP := 4
## The highest rise a jump can climb, in tiles.
const MAX_RISE := 4
const FORGE_X := 1384.0
const FORGE_Y := 152.0
const FORGE_GAP := 32.0
const STEP_BEAT := 0.05
## Each forge: its letter, the comprehension on the slate, and what it builds.
const FORGES: Array[Dictionary] = [
	{"name": "A", "code": "[n for n in range(3)]", "steps": [0, 1, 2]},
	{"name": "B", "code": "[n * 2 for n in range(1, 5)]", "steps": [2, 4, 6, 8]},
	{"name": "C", "code": "[n * 4 for n in range(3) if n != 1]", "steps": [0, 8]},
]

var _building: bool = false
var _stair_cells: Array[Vector2i] = []
var _built: int = -1
var _forges: Array[RuneBlock] = []
const _FAR := preload("res://assets/backgrounds/amber_far.png")
const _MID := preload("res://assets/backgrounds/amber_mid.png")
const _NEAR := preload("res://assets/backgrounds/amber_near.png")


func stage_index() -> int:
	return 6


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# Amber Hollow's sky again, burned to crimson: the trail comes home.
	_add_parallax("FarSky", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(1.0, 0.62, 0.55))
	_add_parallax("MidHills", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.78, 0.5, 0.5))
	_add_parallax("NearBrush", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.6, 0.42, 0.46))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 12),
		Vector2i(17, 26),
		Vector2i(46, 60),
		Vector2i(63, 74),
		Vector2i(82, WALL_X - 1),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	# The climb: two ledges of three tiles each up to the plateau.
	_paint_solid(27, 34, 11)
	_paint_solid(35, 42, 8)
	_paint_ember(61, 62, true)
	# The crown: sheer to the top, then flat to the end of the stage.
	_paint_solid(WALL_X, WIDTH - 1, CROWN_ROW)


func _spawn_actors() -> void:
	_spawn_crawler(Vector2(368, 224), 24.0)
	_spawn_checkpoint(Vector2(800, 224))
	_spawn_shelf(Vector2(1248, 224), 64.0, 0.9, 40.0)
	_spawn_checkpoint(Vector2(1336, 224))
	_spawn_crawler(Vector2(1984, 96), 26.0)
	_spawn_cache(Vector2(872, 152))
	_spawn(clay_brick_scene, Vector2(920, 152))
	var seed_points: Array[Vector2] = [
		Vector2(700, 118),
		Vector2(716, 134),
		Vector2(732, 150),
		Vector2(1248, 196),
		Vector2(1872, 70),
		Vector2(1888, 70),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(104, 222), "comp_basic")
	_spawn_scroll(Vector2(616, 126), "comp_filter")
	_spawn_scroll(Vector2(1056, 222), "comp_strings")
	_spawn_scroll(Vector2(1360, 222), "comp_dict")
	_spawn_scroll(Vector2(1856, 94), "comp_sum")
	_build_forges()
	# The final exam, on the crown itself.
	_spawn_wizard(Vector2(2144, 96), "Crucible King", Color(1.0, 0.82, 0.36))
	_spawn_gate(Vector2(2304, 96))


func _build_forges() -> void:
	var lines: PackedStringArray = []
	for forge: Dictionary in FORGES:
		lines.append("%s: %s" % [forge["name"], forge["code"]])
	lines.append("steps = ?  # up the crown")
	_spawn_sign(Vector2(FORGE_X + FORGE_GAP, FORGE_Y - 12.0), "\n".join(lines), STAIR_TINT)
	for index in FORGES.size():
		var block := _spawn_rune_block(Vector2(FORGE_X + FORGE_GAP * index, FORGE_Y), index, str(FORGES[index]["name"]), STAIR_TINT)
		block.bumped.connect(_on_forge_bumped)
		_forges.append(block)


## The cells of the stair a list of step heights builds: one STEP-wide plank
## per nonzero height, packed against the wall in list order.
func stair_cells(steps: Array) -> Array[Vector2i]:
	var heights: Array[int] = []
	for height: Variant in steps:
		if int(height) > 0:
			heights.append(int(height))
	var cells: Array[Vector2i] = []
	for k in heights.size():
		var left := WALL_X - STEP * (heights.size() - k)
		for x in range(left, left + STEP):
			cells.append(Vector2i(x, 14 - heights[k]))
	return cells


## Runs the forge's comprehension: the old stair crumbles and the new one
## rises, step by step, then the stage says whether it reaches the crown.
func _on_forge_bumped(block: RuneBlock) -> void:
	if _building or block.index == _built:
		return
	_building = true
	var forge: Dictionary = FORGES[block.index]
	var steps: Array = forge["steps"]
	var above := block.global_position + Vector2(-36.0, -14.0)
	Fx.float_text(self, above, "%s = %s" % [forge["name"], str(steps)], STAIR_TINT.lightened(0.4))
	_crumble_tiles(_stair_cells)
	for forge_block in _forges:
		forge_block.set_lit(false)
	_built = block.index
	_stair_cells = stair_cells(steps)
	if not await _raise_tiles(_stair_cells, StageTileset.ONE_WAY, STEP_BEAT):
		return
	_building = false
	var reaches := stair_reaches(steps)
	block.flash(GOOD if reaches else BAD)
	block.set_lit(reaches)
	var top := tiles.map_to_local(Vector2i(WALL_X - 2, CROWN_ROW))
	Fx.float_text(self, top + Vector2(-48.0, -10.0), "The stair reaches!" if reaches else "Too steep to climb", (GOOD if reaches else BAD).lightened(0.3))


## Whether a list of heights makes a stair: it must end level with the crown,
## and no rise between neighbours (or from the floor) may top MAX_RISE.
static func stair_reaches(steps: Array) -> bool:
	var last := 0
	for height: Variant in steps:
		if int(height) <= 0:
			continue
		if int(height) - last > MAX_RISE:
			return false
		last = int(height)
	return last == 14 - CROWN_ROW


## Test hook: the forge whose stair reaches the crown.
func stair_answer() -> int:
	for index in FORGES.size():
		if stair_reaches(FORGES[index]["steps"]):
			return index
	return -1
