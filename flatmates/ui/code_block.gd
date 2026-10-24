class_name CodeBlock
extends Control

## A few lines of colored code on a dark strip, for lesson cards.

var code: String = "":
	set(value):
		code = value
		custom_minimum_size = Vector2(344, 6 + code.split("\n").size() * CodeDraw.LINE)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.CODE_BG)
	draw_rect(Rect2(Vector2.ZERO, Vector2(2, size.y)), Palette.JS)
	var y := 3.0 + CodeDraw.LINE - 2.0
	for line in code.split("\n"):
		CodeDraw.draw_line(self, Vector2(7, y), line)
		y += CodeDraw.LINE
