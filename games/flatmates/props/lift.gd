class_name Lift
extends Gadget

## A platform that rides up and down a shaft in steps of `step_tiles`: an
## office lift (`lift.goTo(floor)`), or a stack of speakers that climbs a
## notch per strum. Whoever stands on it rides along.

const TILE := 16.0
const SPEED := 70.0

enum Look { LIFT, SPEAKERS, HAY }

@export var width_tiles: int = 2
@export var step_tiles: int = 3
@export var top_floor: int = 3
@export var look: Look = Look.LIFT
## A strum this close raises it one level.
@export var rises_on_strum: bool = false
## Seconds between goTo() and moving: the doors closing.
@export var depart_delay: float = 0.0
## Back down to the ground floor after standing empty this long (0: never).
@export var return_after: float = 0.0
## Speaker stacks topple past this level (0: they don't).
@export var topple_above: int = 0

var level: int = 0
var _body: AnimatableBody2D
var _base_y: float = 0.0
var _arrived: Array[JsPromise] = []
var _depart: float = 0.0
var _pending: int = -1
var _empty_time: float = 0.0


func _ready() -> void:
	_base_y = position.y
	_body = AnimatableBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_body.sync_to_physics = true
	add_child(_body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width_tiles * TILE, 6.0)
	shape.shape = rect
	shape.position = Vector2(width_tiles * TILE * 0.5, 3.0)
	# You can jump up through it from underneath and land on top.
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	_body.add_child(shape)


func target_y() -> float:
	return -float(level * step_tiles) * TILE


func go_to(target: int) -> JsPromise:
	var promise := JsPromise.new()
	_arrived.append(promise)
	if depart_delay > 0.0:
		_pending = clampi(target, 0, top_floor)
		_depart = depart_delay
		stage.call(&"speech_at", global_position + Vector2(width_tiles * 8.0 - 20.0, -float(level * step_tiles) * TILE - 18.0), "Doors closing...")
	else:
		level = clampi(target, 0, top_floor)
	return promise


func rise(by: int = 1) -> void:
	level = clampi(level + by, 0, top_floor)
	if topple_above > 0 and level > topple_above:
		_topple()


## Too loud: the landlord pulls the plug and the stack comes down.
func _topple() -> void:
	stage.call(&"speech_at", global_position + Vector2(-30, -float(level * step_tiles) * TILE - 20.0), "TOO LOUD! The landlord pulled the plug.")
	StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
	Fx.dust(get_parent(), global_position + Vector2(width_tiles * 8.0, -8.0), 12)
	level = 0


## Someone standing on the platform.
func ridden() -> bool:
	var top := global_position.y + _body.position.y
	for body in get_tree().get_nodes_in_group(&"flatmate"):
		var mate := body as Node2D
		if absf(mate.global_position.y + 8.0 - top) <= 3.0 and mate.global_position.x >= global_position.x - 3.0 and mate.global_position.x <= global_position.x + width_tiles * TILE + 3.0:
			return true
	return false


func reset_piece() -> void:
	level = 0
	_pending = -1
	_body.position.y = 0.0
	for promise in _arrived:
		promise.resolve()
	_arrived.clear()


func js_methods() -> PackedStringArray:
	return PackedStringArray(["goTo"]) if look == Look.LIFT else PackedStringArray()


func js_call(method: String, args: Array) -> Variant:
	if method == "goTo":
		if args.is_empty() or not (args[0] is int or args[0] is float):
			return JsError.make("TypeError", "lift.goTo() needs a floor number, not %s" % (JsProgram.code(args[0]) if not args.is_empty() else "nothing"))
		if int(args[0]) > top_floor or int(args[0]) < 0:
			stage.call(&"speech_at", global_position + Vector2(width_tiles * 8.0, -20.0), "No floor %s." % JsRunner.text_of(args[0]))
			return JsPromise.resolved()
		return go_to(int(args[0]))
	return null


func js_get(prop: String) -> Variant:
	return level if prop == "floor" else null


func hear_strum(_by: Flatmate) -> void:
	if rises_on_strum:
		rise(1)


func _physics_process(delta: float) -> void:
	if _pending >= 0:
		_depart -= delta
		if _depart <= 0.0:
			level = _pending
			_pending = -1
	if return_after > 0.0 and level != 0 and _pending < 0 and is_equal_approx(_body.position.y, target_y()):
		_empty_time = 0.0 if ridden() else _empty_time + delta
		if _empty_time >= return_after:
			_empty_time = 0.0
			level = 0
	var goal := target_y()
	if not is_equal_approx(_body.position.y, goal):
		_body.position.y = move_toward(_body.position.y, goal, SPEED * delta)
	elif not _arrived.is_empty():
		for promise in _arrived:
			promise.resolve()
		_arrived.clear()
	queue_redraw()


func _draw() -> void:
	var w := width_tiles * TILE
	var y := roundf(_body.position.y)
	match look:
		Look.LIFT:
			# The shaft's cable and the car's floor.
			pixel_rect(Rect2(Vector2(w * 0.5 - 1, -float(top_floor * step_tiles) * TILE - 16), Vector2(2, float(top_floor * step_tiles) * TILE + 16 + y)), Palette.STEEL_DARK)
			pixel_rect(Rect2(Vector2(0, y), Vector2(w, 6)), Palette.STEEL)
			pixel_rect(Rect2(Vector2(0, y + 5), Vector2(w, 1)), Palette.STEEL_DARK)
			for at in top_floor + 1:
				var mark := -float(at * step_tiles) * TILE
				pixel_rect(Rect2(Vector2(w + 2, mark - 1), Vector2(4, 2)), Palette.JS if at == level else Palette.STEEL_DARK)
			draw_name(Vector2(w * 0.5, y - 4.0))
		Look.SPEAKERS:
			# A stack of cabinets fills down to the floor.
			var top := y
			var row := 0
			while top + row * 12 < 0.0 + 1.0:
				var cab_y := top + row * 12
				pixel_rect(Rect2(Vector2(0, cab_y), Vector2(w, 12)), Palette.INK.lightened(0.1))
				pixel_rect(Rect2(Vector2(1, cab_y + 1), Vector2(w - 2, 10)), Palette.INK.lightened(0.2))
				draw_circle(Vector2(w * 0.5, cab_y + 6), 3.0, Palette.STEEL_DARK)
				row += 1
			pixel_rect(Rect2(Vector2(0, y), Vector2(w, 3)), Palette.STEEL)
		Look.HAY:
			var height := -y
			if height > 0.0:
				pixel_rect(Rect2(Vector2(0, y), Vector2(w, height)), Palette.AMBER.darkened(0.15))
			pixel_rect(Rect2(Vector2(0, y), Vector2(w, 4)), Palette.AMBER)
