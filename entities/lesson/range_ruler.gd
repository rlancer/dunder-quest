class_name RangeRuler
extends Node2D

## Numbered tick marks along the floor, one per tile, so a range() can be
## seen: each number the loop visits lights up as it lands.

const TILE := 16.0
const TICK := Color(0.92, 0.86, 1.0, 0.85)
const HOT := Color(1.0, 0.7, 0.3)

var count: int = 10
var tint: Color = Color(0.5, 1.0, 0.65)

var _lit: Dictionary = {}
var _numbers: Array[Label] = []


func _ready() -> void:
	add_to_group(&"lesson")
	z_index = 3
	for index in count:
		var label := Label.new()
		label.text = str(index)
		label.add_theme_font_override(&"font", preload("res://assets/fonts/VT323.ttf"))
		label.add_theme_font_size_override(&"font_size", 16)
		label.add_theme_constant_override(&"outline_size", 4)
		label.add_theme_color_override(&"font_color", TICK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.size = Vector2(TILE, 14.0)
		label.position = Vector2(float(index) * TILE - TILE * 0.5, 2.0)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_numbers.append(label)


## World position of tick `index`, on the floor line.
func tick_position(index: int) -> Vector2:
	return global_position + Vector2(float(index) * TILE, 0.0)


func light(index: int) -> void:
	_lit[index] = true
	if index >= 0 and index < _numbers.size():
		_numbers[index].add_theme_color_override(&"font_color", HOT)
	queue_redraw()


func dismiss() -> void:
	hide()


func _draw() -> void:
	for index in count:
		var x := float(index) * TILE
		var color := HOT if _lit.has(index) else TICK
		draw_rect(Rect2(x - 0.5, -3.0, 1.0, 4.0), color)
	draw_rect(Rect2(-TILE * 0.5, 0.0, float(count) * TILE, 1.0), Color(TICK.r, TICK.g, TICK.b, 0.25))
