class_name Switch
extends Gadget

## Things you use by standing at them and pressing Use (or, in a script,
## `jazz.press()`): a lever, a doorbell, a big red button. A lever flips the
## slabs in `holds` each pull; a bell and a button just fire their event.

enum Look { LEVER, BELL, BUTTON }

@export var look: Look = Look.LEVER
## The event it fires: "pull", "ring", "press".
@export var event: String = "pull"
var holds: Array[Slab] = []
var thrown: bool = false
## Some buttons (a ticket barrier's) open their slabs for this long instead.
var open_seconds: float = 0.0
var _flash: float = 0.0


func use(_by: Flatmate) -> bool:
	thrown = not thrown
	_flash = 0.4
	for slab in holds:
		if not is_instance_valid(slab):
			continue
		if open_seconds > 0.0:
			slab.open_for(open_seconds)
		else:
			slab.set_on(not slab.on)
	StageAudio.play(get_tree(), preload("res://assets/audio/pickup.wav") if look == Look.BELL else preload("res://assets/audio/bump.wav"))
	if look == Look.BELL:
		Fx.float_text(get_parent(), global_position + Vector2(-12, -26), "Ding!", Palette.JS)
	emit_event(event)
	return true


func js_get(prop: String) -> Variant:
	return thrown if prop == "thrown" else null


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	match look:
		Look.LEVER:
			pixel_rect(Rect2(Vector2(-5, -4), Vector2(10, 4)), Palette.STEEL_DARK)
			var tip := Vector2(5, -14) if thrown else Vector2(-5, -14)
			draw_line(Vector2(0, -3), tip, Palette.STEEL, 2.0)
			draw_circle(tip, 2.5, Palette.RED)
		Look.BELL:
			pixel_rect(Rect2(Vector2(-1, -22), Vector2(2, 22)), Palette.WOOD_DARK)
			pixel_rect(Rect2(Vector2(-4, -26), Vector2(8, 6)), Palette.AMBER if _flash <= 0.0 else Palette.JS)
			pixel_rect(Rect2(Vector2(-1, -28), Vector2(2, 2)), Palette.AMBER.darkened(0.3))
		Look.BUTTON:
			pixel_rect(Rect2(Vector2(-2, -18), Vector2(4, 18)), Palette.STEEL_DARK)
			pixel_rect(Rect2(Vector2(-5, -24), Vector2(10, 7)), Palette.STEEL)
			pixel_rect(Rect2(Vector2(-3, -23), Vector2(6, 4)), Palette.GREEN if _flash > 0.0 else Palette.RED)
	draw_name(Vector2(0, -30))
