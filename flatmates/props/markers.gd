class_name Marker
extends Node2D

## Fixed furniture of a stage that isn't scriptable: the way out (both
## flatmates have to be there), and the Wi-Fi routers that mark where a
## fallen flatmate comes back.

enum Kind { EXIT, ROUTER }

const EXIT_HALF := 20.0

@export var kind: Kind = Kind.EXIT
## The exit's sign, e.g. "Out".
@export var caption: String = "Way out"
var lit: bool = false
var _time: float = 0.0


func _ready() -> void:
	z_index = -2


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## How many flatmates are standing in the way out.
func count_inside() -> int:
	var inside := 0
	for body in get_tree().get_nodes_in_group(&"flatmate"):
		if holds(body as Node2D):
			inside += 1
	return inside


func holds(mate: Node2D) -> bool:
	return absf(mate.global_position.x - global_position.x) <= EXIT_HALF and absf(mate.global_position.y + 8.0 - global_position.y) <= 20.0


func _draw() -> void:
	match kind:
		Kind.EXIT:
			draw_rect(Rect2(Vector2(-14, -38), Vector2(28, 38)), Palette.WOOD_DARK)
			draw_rect(Rect2(Vector2(-12, -36), Vector2(24, 36)), Palette.CLIVE.darkened(0.45))
			draw_rect(Rect2(Vector2(-12, -36), Vector2(24, 4)), Palette.JS if lit else Palette.STEEL_DARK)
			draw_rect(Rect2(Vector2(7, -18), Vector2(2, 2)), Palette.JS)
			var font := Palette.mono()
			var width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL).x
			var at := Vector2(-width * 0.5, -42).round()
			draw_string_outline(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, 3, Palette.INK)
			draw_string(font, at, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.SMALL, Palette.JS)
		Kind.ROUTER:
			draw_rect(Rect2(Vector2(-6, -5), Vector2(12, 5)), Palette.INK.lightened(0.2))
			draw_rect(Rect2(Vector2(-5, -9), Vector2(1, 4)), Palette.INK.lightened(0.2))
			draw_rect(Rect2(Vector2(4, -9), Vector2(1, 4)), Palette.INK.lightened(0.2))
			for index in 3:
				var on := lit and int(_time * 4.0 + index) % 3 != 0
				draw_rect(Rect2(Vector2(-4 + index * 3, -3), Vector2(1, 1)), Palette.GREEN if on else Palette.STEEL_DARK)
