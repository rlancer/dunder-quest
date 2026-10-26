class_name CodeBlock
extends Control

## A few lines of colored Rust on a strip of legal-pad yellow, for cards.

var code: String = "":
	set(value):
		code = value
		custom_minimum_size = Vector2(424, 6 + code.split("\n").size() * CodeDraw.LINE)
		size = custom_minimum_size
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.PAD)
	draw_rect(Rect2(Vector2.ZERO, Vector2(2, size.y)), Palette.RUST)
	var y := 3.0 + CodeDraw.LINE - 2.0
	for line in code.split("\n"):
		CodeDraw.draw_line(self, Vector2(7, y), line)
		y += CodeDraw.LINE
