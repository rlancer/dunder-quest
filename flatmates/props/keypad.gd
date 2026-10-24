class_name Keypad
extends Gadget

## A door keypad that a script types into: `keypad.enter(code)`. The right
## code opens the slabs in `holds`; a wrong one says what it got, so the
## player sees exactly what the template literal built.

@export var code: String = "0000"
var holds: Array[Slab] = []
var solved: bool = false
var _flash: float = 0.0
var _good: bool = false


func js_methods() -> PackedStringArray:
	return PackedStringArray(["enter"])


func js_call(method: String, args: Array) -> Variant:
	if method != "enter":
		return null
	var typed := JsRunner.text_of(args[0]) if not args.is_empty() else "undefined"
	_flash = 0.6
	_good = typed == code
	if _good:
		if not solved:
			solved = true
			for slab in holds:
				slab.open()
		stage.call(&"speech_at", global_position + Vector2(0, -30), "%s: ACCEPTED" % typed)
		StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
		emit_event("open")
	else:
		stage.call(&"speech_at", global_position + Vector2(0, -30), "\"%s\"? DENIED" % typed)
		StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
	return _good


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	pixel_rect(Rect2(Vector2(-6, -30), Vector2(12, 16)), Palette.STEEL_DARK)
	pixel_rect(Rect2(Vector2(-5, -29), Vector2(10, 4)), (Palette.GREEN if _good else Palette.RED) if _flash > 0.0 else (Palette.GREEN if solved else Palette.INK))
	for row in 3:
		for col in 3:
			pixel_rect(Rect2(Vector2(-5 + col * 4, -24 + row * 3), Vector2(2, 2)), Palette.STEEL)
	draw_name(Vector2(0, -34))
