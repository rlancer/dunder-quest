class_name Spot
extends Gadget

## A named place a script can send someone: `clive.reach(altar)`. Also the
## stage's markers drawn as something to stand by: a car, a stage, a door mat.

enum Look { NONE, ALTAR, CAR, MIC, SIGN }

@export var look: Look = Look.NONE
@export var caption: String = ""
## Methods a script may call on it, by name: {"drive": Callable}. Each
## gets the call's arguments as an Array and returns what the call does.
var actions: Dictionary = {}


func js_methods() -> PackedStringArray:
	return PackedStringArray(actions.keys())


func js_call(method: String, args: Array) -> Variant:
	return (actions[method] as Callable).call(args) if actions.has(method) else null


func _ready() -> void:
	z_index = -1


func _draw() -> void:
	match look:
		Look.ALTAR:
			pixel_rect(Rect2(Vector2(-12, -14), Vector2(24, 14)), Palette.PAPER)
			pixel_rect(Rect2(Vector2(-12, -14), Vector2(24, 2)), Palette.JS)
			pixel_rect(Rect2(Vector2(-1, -24), Vector2(2, 10)), Palette.AMBER)
			pixel_rect(Rect2(Vector2(-4, -21), Vector2(8, 2)), Palette.AMBER)
		Look.MIC:
			pixel_rect(Rect2(Vector2(-1, -18), Vector2(2, 18)), Palette.STEEL_DARK)
			pixel_rect(Rect2(Vector2(-2, -21), Vector2(4, 4)), Palette.STEEL)
			pixel_rect(Rect2(Vector2(-4, -1), Vector2(8, 1)), Palette.STEEL_DARK)
		Look.CAR:
			pixel_rect(Rect2(Vector2(-22, -14), Vector2(44, 9)), Palette.RED)
			pixel_rect(Rect2(Vector2(-12, -21), Vector2(22, 8)), Palette.RED.darkened(0.15))
			pixel_rect(Rect2(Vector2(-10, -19), Vector2(8, 5)), Palette.CODE.darkened(0.3))
			pixel_rect(Rect2(Vector2(0, -19), Vector2(8, 5)), Palette.CODE.darkened(0.3))
			draw_circle(Vector2(-12, -4), 4.0, Palette.INK)
			draw_circle(Vector2(12, -4), 4.0, Palette.INK)
		Look.SIGN:
			pixel_rect(Rect2(Vector2(-1, -20), Vector2(2, 20)), Palette.STEEL_DARK)
	if caption != "":
		var font := Palette.mono()
		var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL).x
		var at := Vector2(-width * 0.5, -26).round()
		draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, 3, Palette.INK)
		draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, Palette.PAPER)
	draw_name(Vector2(0, -36 if caption != "" else -28))
