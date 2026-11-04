class_name Portrait
extends Control

## A cast member's close-up: assets/portraits/<who>.png, 48×48 pixel art made
## by tools/art.py, on a pale green tile. Drawn crisp at whole multiples of
## 48 and smoothed at any other size.

const SIZE := 48

var who: String = "":
	set(v):
		who = v
		_face = load("res://assets/portraits/%s.png" % v) as Texture2D if v != "" else null
		queue_redraw()
var _face: Texture2D


func _init(person: String = "") -> void:
	who = person
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)
	resized.connect(_pick_filter)


func _pick_filter() -> void:
	var side := minf(size.x, size.y)
	var whole := side >= SIZE and is_zero_approx(fmod(side, SIZE))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if whole else CanvasItem.TEXTURE_FILTER_LINEAR


func _draw() -> void:
	if _face == null:
		return
	var side := minf(size.x, size.y)
	var r := Rect2((size - Vector2(side, side)) / 2.0, Vector2(side, side))
	draw_rect(r, Palette.GREEN_PALE)
	draw_texture_rect(_face, r, false)
