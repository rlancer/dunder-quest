class_name Slab
extends Gadget

## A solid strip that comes and goes: a door that slides up into the frame,
## a plank bridge that folds out over a gap, a ticket barrier. `size` is in
## tiles from the top-left corner. While it's off it lets everything through.

enum Look { DOOR, PLANKS, BARRIER, GATE }

const TILE := 16.0
const SLIDE := 0.25

@export var size_tiles: Vector2i = Vector2i(1, 3)
@export var look: Look = Look.DOOR
@export var on: bool = true

var _body: StaticBody2D
var _shape: CollisionShape2D
## 1 shown, 0 gone, eased between.
var _amount: float = 1.0
var _tween: Tween
var _close_serial: int = 0


func _ready() -> void:
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(size_tiles) * TILE
	_shape.shape = rect
	_shape.position = rect.size * 0.5
	_body.add_child(_shape)
	_amount = 1.0 if on else 0.0
	_shape.set_deferred(&"disabled", not on)


func set_on(value: bool) -> void:
	if value == on:
		return
	on = value
	_close_serial += 1
	_shape.set_deferred(&"disabled", not on)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_amount", 1.0 if on else 0.0, SLIDE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	Fx.dust(get_parent(), global_position + Vector2(size_tiles) * TILE * Vector2(0.5, 1.0), 4)
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))


func open() -> void:
	set_on(false)


func close() -> void:
	set_on(true)


## Opens, then shuts again after `seconds` unless something reopened it.
func open_for(seconds: float) -> void:
	set_on(false)
	_close_serial += 1
	var serial := _close_serial
	await get_tree().create_timer(seconds, false).timeout
	if serial == _close_serial and is_inside_tree():
		set_on(true)


func js_methods() -> PackedStringArray:
	return PackedStringArray(["open", "close"]) if js_name != "" else PackedStringArray()


func js_call(method: String, _args: Array) -> Variant:
	if method == "open":
		open()
	elif method == "close":
		close()
	return null


func js_get(prop: String) -> Variant:
	return not on if prop == "isOpen" else null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var full := Vector2(size_tiles) * TILE
	match look:
		Look.DOOR:
			# Slides up into its frame.
			var shown := roundf(full.y * _amount)
			pixel_rect(Rect2(Vector2(-2, -3), Vector2(full.x + 4, 3)), Palette.WOOD_DARK)
			if shown > 0.0:
				pixel_rect(Rect2(Vector2.ZERO, Vector2(full.x, shown)), Palette.WOOD)
				pixel_rect(Rect2(Vector2(2, 2), Vector2(full.x - 4, maxf(shown - 4, 0))), Palette.WOOD.lightened(0.08))
				pixel_rect(Rect2(Vector2(full.x - 5, minf(shown - 10, full.y * 0.5)), Vector2(2, 2)), Palette.JS)
		Look.PLANKS:
			# Folds out from the left edge.
			var shown := roundf(full.x * _amount)
			if shown > 0.0:
				for x in range(0, int(shown), 8):
					var w := minf(8.0, shown - float(x))
					pixel_rect(Rect2(Vector2(x, 0), Vector2(w, 5)), Palette.WOOD if (x / 8) % 2 == 0 else Palette.WOOD.darkened(0.12))
				pixel_rect(Rect2(Vector2(0, 5), Vector2(shown, 1)), Palette.WOOD_DARK)
		Look.BARRIER:
			# A ticket barrier's paddles swing apart.
			var shown := roundf(full.y * _amount)
			pixel_rect(Rect2(Vector2(-3, 0), Vector2(3, full.y)), Palette.STEEL_DARK)
			if shown > 0.0:
				pixel_rect(Rect2(Vector2(0, full.y - shown), Vector2(full.x, shown)), Palette.RED.lerp(Palette.PAPER, 0.15))
				pixel_rect(Rect2(Vector2(0, full.y - shown), Vector2(full.x, 2)), Palette.PAPER)
		Look.GATE:
			# A farm gate that lifts.
			var lift := roundf(full.y * (1.0 - _amount))
			for row in range(0, int(full.y), 6):
				pixel_rect(Rect2(Vector2(0, row - lift), Vector2(full.x, 2)), Palette.WOOD)
			pixel_rect(Rect2(Vector2(0, -lift), Vector2(2, full.y)), Palette.WOOD_DARK)
			pixel_rect(Rect2(Vector2(full.x - 2, -lift), Vector2(2, full.y)), Palette.WOOD_DARK)
	draw_name(Vector2(full.x * 0.5, -6.0))
