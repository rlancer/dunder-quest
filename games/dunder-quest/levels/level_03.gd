extends StageLevel

## Cave of the Bunny. Lesson 3: Loops & range.
## Ember and an ash shelf are taught on solid ground, then both cross a pit.
##
## Then the kiln wall: ten tiles of sheer brick, too tall for any jump. At its
## foot an iron lift runs a for loop, rising one notch for every lap, and
## three forge blocks before it each load a different range. Only a loop of
## four laps lifts the player high enough to jump onto the wall. The numbers
## mislead on purpose: range(1, 9, 3) and range(10, 13) look bigger than
## range(4), but each makes only three laps. A gauge on the wall marks each
## notch. Tom the Enchanter duels in the arena past the wall.

const WIDTH := 156
const FORGE_TINT := Color(0.5, 1.0, 0.65)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## The kiln wall's first column, its top surface row, and its last column.
const WALL_X := 105
const WALL_ROW := 4
const WALL_END := 112
## The lift sits in a one-tile recess in the two columns before the wall.
const LIFT_X := 103
const FORGE_X := 1448.0
const FORGE_Y := 152.0
const FORGE_GAP := 32.0
## Each forge: its letter and its range(start, stop, step).
const FORGES: Array[Dictionary] = [
	{"name": "A", "range": [1, 9, 3]},
	{"name": "B", "range": [4]},
	{"name": "C", "range": [10, 13]},
]
## Laps the lift needs to bring the wall top within a jump.
const NEEDED_LAPS := 4
const ARENA := 120

var _lift: KilnLift
var _loaded: int = -1
var _forges: Array[RuneBlock] = []
const _FAR := preload("res://assets/backgrounds/cave_far.png")
const _MID := preload("res://assets/backgrounds/cave_mid.png")
const _NEAR := preload("res://assets/backgrounds/cave_near.png")


func stage_index() -> int:
	return 3


func _passage_detail() -> String:
	return "Ministry of Walks awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# Cave of the Bunny: a dim burrow-pocked cave. The busy layers sit back
	# behind darker tints so they never compete with the play lane.
	_add_parallax("FarCave", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(0.85, 0.85, 0.9))
	_add_parallax("MidRocks", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.6, 0.6, 0.66))
	_add_parallax("NearRubble", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.5, 0.48, 0.54))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 7),
		Vector2i(10, 17),
		Vector2i(22, 36),
		Vector2i(41, 46),
		Vector2i(55, 60),
		Vector2i(63, 68),
		Vector2i(71, 83),
		Vector2i(86, LIFT_X - 1),
		Vector2i(WALL_END + 1, ARENA),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	_paint_ember(8, 9, true)
	_paint_solid(18, 21, 15)
	_paint_roof(26, 34, 11)
	_paint_ember(38, 39, false)
	_paint_solid(LIFT_X, LIFT_X + 1, 15)
	_paint_solid(WALL_X, WALL_END, WALL_ROW)


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
		Vector2(1736, 50),
		Vector2(1752, 50),
		Vector2(1768, 50),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(104, 222), "loop_for")
	_spawn_scroll(Vector2(424, 222), "loop_range")
	_spawn_scroll(Vector2(920, 222), "loop_total")
	_spawn_scroll(Vector2(1160, 222), "loop_while")
	_spawn_checkpoint(Vector2(1400, 224))
	_build_lift()
	_build_arena(ARENA, "Tom the Enchanter", Color(0.5, 1.0, 0.65))


func _build_lift() -> void:
	var lines: PackedStringArray = ["for i in ?:", "    lift.rise()  # one notch"]
	for forge: Dictionary in FORGES:
		lines.append("%s: %s" % [forge["name"], range_text(forge["range"])])
	_spawn_sign(Vector2(FORGE_X + FORGE_GAP, FORGE_Y - 12.0), "\n".join(lines), FORGE_TINT)
	for index in FORGES.size():
		var block := _spawn_rune_block(Vector2(FORGE_X + FORGE_GAP * index, FORGE_Y), index, str(FORGES[index]["name"]), FORGE_TINT)
		block.bumped.connect(_on_forge_bumped)
		_forges.append(block)
	_lift = KilnLift.new()
	_lift.tint = FORGE_TINT
	_lift.position = Vector2(float((LIFT_X + 1) * TILE), 224.0)
	add_child(_lift)
	_lift.ran.connect(_on_lift_ran)
	var gauge := _Gauge.new()
	gauge.tint = FORGE_TINT
	gauge.position = Vector2(float(WALL_X * TILE), 224.0)
	add_child(gauge)


## "range(1, 9, 3)", the way the slate writes a forge's loop.
static func range_text(bounds: Array) -> String:
	var parts: PackedStringArray = []
	for value: Variant in bounds:
		parts.append(str(value))
	return "range(%s)" % ", ".join(parts)


## The values a forge's loop hands to i, the way Python's range would.
static func loop_values(bounds: Array) -> Array[int]:
	var values: Array[int] = []
	var start := 0 if bounds.size() == 1 else int(bounds[0])
	var stop := int(bounds[0]) if bounds.size() == 1 else int(bounds[1])
	var step := int(bounds[2]) if bounds.size() > 2 else 1
	for i in range(start, stop, step):
		values.append(i)
	return values


## Loads the forge's loop into the lift. Riding the plate runs it.
func _on_forge_bumped(block: RuneBlock) -> void:
	var bounds: Array = FORGES[block.index]["range"]
	var above := block.global_position + Vector2(-30.0, -14.0)
	if block.index == _loaded:
		Fx.float_text(self, above, "Loaded. Ride the lift!", FORGE_TINT.lightened(0.3))
		return
	_loaded = block.index
	for forge_block in _forges:
		forge_block.set_lit(forge_block == block)
	block.flash(FORGE_TINT)
	_lift.load_loop(loop_values(bounds))
	Fx.float_text(self, _lift.global_position + Vector2(-60.0, -12.0), "%s loaded" % range_text(bounds), FORGE_TINT.lightened(0.4))


func _on_lift_ran(laps: int) -> void:
	var at := _lift.global_position + Vector2(-56.0, -24.0)
	if laps >= NEEDED_LAPS:
		Fx.float_text(self, at, "%d laps: jump for the top!" % laps, GOOD.lightened(0.3))
	else:
		Fx.float_text(self, at, "Only %d laps: too low!" % laps, BAD.lightened(0.3))


func lift() -> KilnLift:
	return _lift


func loaded_forge() -> int:
	return _loaded


## Test hook: the forge whose loop lifts high enough.
func forge_answer() -> int:
	for index in FORGES.size():
		if loop_values(FORGES[index]["range"]).size() >= NEEDED_LAPS:
			return index
	return -1


## Notches up the kiln wall's face, one per lap of the lift, numbered so the
## player can see how many laps the climb takes.
class _Gauge extends Node2D:
	var tint: Color = Color(0.5, 1.0, 0.65)

	func _ready() -> void:
		z_index = 2
		for lap in range(1, 6):
			var label := Label.new()
			label.text = str(lap)
			label.add_theme_font_override(&"font", preload("res://assets/fonts/VT323.ttf"))
			label.add_theme_font_size_override(&"font_size", 16)
			label.add_theme_constant_override(&"outline_size", 4)
			label.add_theme_color_override(&"font_color", tint.lightened(0.3) if lap == NEEDED_LAPS else Color(0.9, 0.86, 1.0, 0.7))
			label.position = Vector2(3.0, -KilnLift.LAP_RISE * float(lap) - 8.0)
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(label)

	func _draw() -> void:
		for lap in range(1, 6):
			var y := -KilnLift.LAP_RISE * float(lap)
			var color := tint if lap == NEEDED_LAPS else Color(0.9, 0.86, 1.0, 0.5)
			draw_rect(Rect2(0.0, y, 3.0, 1.0), color)
