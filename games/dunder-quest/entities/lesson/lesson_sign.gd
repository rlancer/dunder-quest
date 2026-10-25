class_name LessonSign
extends Node2D

## A carved slate hanging in the scenery with a line or two of code on it.
## It has no collision; it only sets the puzzle the blocks below it answer.

const SLATE := Color(0.08, 0.05, 0.1, 0.86)

var text: String = ""
var tint: Color = Color(0.6, 0.85, 1.0)


func _ready() -> void:
	add_to_group(&"lesson")
	z_index = 1
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(&"font", preload("res://assets/fonts/VT323.ttf"))
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_constant_override(&"line_spacing", -4)
	label.add_theme_color_override(&"font_color", Color(0.9, 0.96, 0.9))
	var box := StyleBoxFlat.new()
	box.bg_color = SLATE
	box.border_color = tint
	box.border_width_left = 2
	box.content_margin_left = 5.0
	box.content_margin_right = 5.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	box.anti_aliasing = false
	label.add_theme_stylebox_override(&"normal", box)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	# Centered over the sign's position, growing upward.
	label.reset_size()
	label.position = Vector2(-label.size.x * 0.5, -label.size.y).round()


func dismiss() -> void:
	hide()
