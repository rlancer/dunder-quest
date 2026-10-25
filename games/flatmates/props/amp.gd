class_name Amp
extends Gadget

## A guitar amp. `amp.switchOn()` lights it and lifts its stage riser, so a
## row of amps switched on in order makes a stair.

var riser: Lift
var lit: bool = false


func js_methods() -> PackedStringArray:
	return PackedStringArray(["switchOn"])


func js_call(method: String, _args: Array) -> Variant:
	if method == "switchOn" and not lit:
		lit = true
		if riser != null:
			riser.rise(riser.top_floor)
		StageAudio.play(get_tree(), preload("res://assets/audio/pickup.wav"))
		Fx.sparks(get_parent(), global_position + Vector2(0, -10), Palette.JS, 8)
		emit_event("on")
		queue_redraw()
	return null


func js_get(prop: String) -> Variant:
	return lit if prop == "on" else null


func _draw() -> void:
	pixel_rect(Rect2(Vector2(-8, -14), Vector2(16, 14)), Palette.INK.lightened(0.12))
	pixel_rect(Rect2(Vector2(-7, -13), Vector2(14, 4)), Palette.WOOD_DARK)
	pixel_rect(Rect2(Vector2(-7, -8), Vector2(14, 7)), Palette.INK.lightened(0.25))
	pixel_rect(Rect2(Vector2(4, -12), Vector2(2, 2)), Palette.GREEN if lit else Palette.RED.darkened(0.4))
	draw_name(Vector2(0, -18))
