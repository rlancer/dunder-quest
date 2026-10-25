class_name Laptop
extends Gadget

## A laptop on a pile of books, open on the other flatmate's to-do list.
## Press Use beside it to edit the script. Running it sends whoever the
## script is for back to `home` first, so every run starts the same way,
## and puts back anything listed in `resets`.

var program: JsProgram
## Where the scripted flatmate stands when a run starts (global).
var home: Vector2 = Vector2.INF
var resets: Array[Node] = []
## What the editor's footer says while this script is open: the inner voice.
var hint: String = ""
## Runs so far, and whether the last run did its job (the stage decides).
var runs: int = 0
var solved: bool = false
var _blink: float = 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _draw() -> void:
	# A stack of library books under the laptop.
	pixel_rect(Rect2(Vector2(-9, -6), Vector2(18, 3)), Palette.RED.darkened(0.2))
	pixel_rect(Rect2(Vector2(-8, -3), Vector2(16, 3)), Palette.CLIVE.darkened(0.3))
	pixel_rect(Rect2(Vector2(-7, -9), Vector2(14, 3)), Palette.STEEL_DARK)
	pixel_rect(Rect2(Vector2(-6, -19), Vector2(12, 10)), Palette.INK.lightened(0.18))
	var screen := Palette.CODE_BG.lightened(0.1) if solved else Palette.CODE_BG
	pixel_rect(Rect2(Vector2(-5, -18), Vector2(10, 8)), screen)
	# Lines of code on the screen; the cursor blinks until it's solved.
	pixel_rect(Rect2(Vector2(-4, -17), Vector2(5, 1)), Palette.JS)
	pixel_rect(Rect2(Vector2(-4, -15), Vector2(7, 1)), Palette.SYN_CALL)
	if solved:
		pixel_rect(Rect2(Vector2(-4, -13), Vector2(6, 1)), Palette.GREEN)
	elif int(_blink * 2.0) % 2 == 0:
		pixel_rect(Rect2(Vector2(-4, -13), Vector2(2, 1)), Palette.PAPER)
	if program != null:
		var font := Palette.mono()
		var text := program.file_name
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL).x
		var at := Vector2(-width * 0.5, -24).round()
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, 3, Palette.INK)
		var tint := Palette.tint_of(program.runs_on).lightened(0.3) if program.runs_on != "" else Palette.JS
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, tint)
