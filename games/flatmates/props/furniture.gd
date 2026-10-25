class_name Furniture
extends Node2D

## Set dressing drawn on whole pixels, standing on its bottom-center: the
## sofa Jazz drifts back to, Clive's armchair, and the rest of each room.

@export var kind: String = "sofa"


func _ready() -> void:
	z_index = -3


func _r(x: float, y: float, w: float, h: float, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c)


func _draw() -> void:
	match kind:
		"sofa":
			var c := Color(0.42, 0.5, 0.36)
			_r(-18, -14, 36, 10, c.darkened(0.15))
			_r(-18, -8, 36, 6, c)
			_r(-20, -12, 4, 10, c.darkened(0.25))
			_r(16, -12, 4, 10, c.darkened(0.25))
			_r(-6, -10, 8, 3, Color(0.88, 0.78, 0.4))
			_r(-17, -2, 2, 2, Palette.WOOD_DARK)
			_r(15, -2, 2, 2, Palette.WOOD_DARK)
		"armchair":
			var c := Color(0.55, 0.4, 0.5)
			_r(-9, -16, 18, 10, c.darkened(0.15))
			_r(-9, -8, 18, 6, c)
			_r(-11, -12, 3, 10, c.darkened(0.25))
			_r(8, -12, 3, 10, c.darkened(0.25))
			_r(-9, -2, 2, 2, Palette.WOOD_DARK)
			_r(7, -2, 2, 2, Palette.WOOD_DARK)
		"beanbag":
			draw_circle(Vector2(0, -6), 8.0, Color(0.85, 0.5, 0.2))
			_r(-8, -6, 16, 6, Color(0.85, 0.5, 0.2))
			_r(-4, -10, 6, 2, Color(0.95, 0.65, 0.3))
		"fridge":
			_r(-8, -34, 16, 34, Color(0.88, 0.88, 0.84))
			_r(-8, -22, 16, 1, Color(0.6, 0.6, 0.58))
			_r(5, -30, 1, 6, Color(0.5, 0.5, 0.5))
			_r(5, -19, 1, 6, Color(0.5, 0.5, 0.5))
			_r(-5, -31, 5, 4, Palette.JS)
			_r(-6, -26, 4, 3, Palette.RED)
		"telly":
			_r(-12, -10, 24, 10, Palette.WOOD_DARK)
			_r(-10, -26, 20, 16, Palette.INK)
			_r(-9, -25, 18, 13, Color(0.3, 0.45, 0.6))
			_r(-7, -22, 6, 2, Color(0.55, 0.7, 0.85))
		"plant":
			_r(-4, -7, 8, 7, Color(0.7, 0.36, 0.24))
			draw_circle(Vector2(0, -12), 6.0, Color(0.3, 0.55, 0.3))
			draw_circle(Vector2(-4, -16), 4.0, Color(0.36, 0.62, 0.34))
		"desk":
			_r(-16, -14, 32, 3, Palette.WOOD)
			_r(-15, -11, 2, 11, Palette.WOOD_DARK)
			_r(13, -11, 2, 11, Palette.WOOD_DARK)
			_r(-8, -24, 12, 10, Palette.INK.lightened(0.2))
			_r(-7, -23, 10, 7, Color(0.3, 0.5, 0.7))
			_r(6, -18, 5, 4, Palette.PAPER)
		"watercooler":
			_r(-5, -12, 10, 12, Palette.STEEL)
			_r(-4, -24, 8, 12, Color(0.6, 0.8, 0.95, 0.8))
			_r(-1, -10, 2, 2, Palette.RED)
		"drumkit":
			_r(-14, -12, 12, 12, Palette.RED.darkened(0.2))
			draw_circle(Vector2(-8, -6), 4.0, Palette.PAPER)
			_r(2, -14, 10, 3, Palette.STEEL)
			_r(6, -14, 1, 14, Palette.STEEL_DARK)
			_r(-2, -22, 12, 2, Palette.AMBER)
			_r(4, -22, 1, 8, Palette.STEEL_DARK)
		"bar":
			_r(-24, -18, 48, 18, Palette.WOOD_DARK)
			_r(-26, -20, 52, 3, Palette.WOOD)
			for x in [-16, -6, 6]:
				_r(x, -28, 3, 8, Color(0.4, 0.6, 0.3, 0.9))
		"haybale":
			_r(-12, -12, 24, 12, Color(0.85, 0.7, 0.32))
			_r(-12, -12, 24, 2, Color(0.95, 0.82, 0.45))
			_r(-12, -7, 24, 1, Color(0.7, 0.55, 0.22))
		"sheep":
			_r(-7, -10, 14, 8, Palette.PAPER)
			_r(5, -11, 5, 5, Palette.INK.lightened(0.15))
			_r(-5, -2, 2, 2, Palette.INK)
			_r(3, -2, 2, 2, Palette.INK)
		"bench":
			_r(-14, -8, 28, 2, Palette.STEEL)
			_r(-12, -6, 2, 6, Palette.STEEL_DARK)
			_r(10, -6, 2, 6, Palette.STEEL_DARK)
			_r(-14, -14, 28, 2, Palette.STEEL)
		"pew":
			_r(-18, -10, 36, 3, Palette.WOOD)
			_r(-18, -20, 3, 20, Palette.WOOD_DARK)
			_r(15, -20, 3, 20, Palette.WOOD_DARK)
			_r(-15, -18, 30, 2, Palette.WOOD_DARK)
		"flowers":
			_r(-1, -12, 2, 12, Color(0.3, 0.55, 0.3))
			draw_circle(Vector2(-3, -14), 3.0, Color(0.95, 0.75, 0.85))
			draw_circle(Vector2(3, -15), 3.0, Palette.PAPER)
			draw_circle(Vector2(0, -18), 3.0, Color(0.95, 0.75, 0.85))
		"cake":
			_r(-10, -8, 20, 8, Palette.PAPER)
			_r(-7, -14, 14, 6, Palette.PAPER.darkened(0.05))
			_r(-4, -19, 8, 5, Palette.PAPER)
			_r(-10, -5, 20, 1, Color(0.95, 0.75, 0.85))
			_r(-1, -22, 1, 3, Palette.JS)
		"poster":
			_r(-10, -40, 20, 26, Palette.INK.lightened(0.1))
			_r(-9, -39, 18, 24, Palette.RED.darkened(0.1))
			_r(-6, -36, 12, 3, Palette.JS)
			_r(-6, -30, 12, 1, Palette.PAPER)
			_r(-6, -27, 8, 1, Palette.PAPER)
		"window":
			_r(-14, -44, 28, 24, Palette.PAPER)
			_r(-12, -42, 24, 20, Color(0.45, 0.55, 0.7))
			_r(-1, -42, 2, 20, Palette.PAPER)
			_r(-12, -33, 24, 2, Palette.PAPER)
			_r(-8, -40, 4, 3, Color(0.6, 0.7, 0.82))
		"clock":
			draw_circle(Vector2(0, -46), 7.0, Palette.PAPER)
			draw_arc(Vector2(0, -46), 7.0, 0.0, TAU, 16, Palette.INK, 1.0)
			_r(0, -51, 1, 5, Palette.INK)
			_r(0, -46, 4, 1, Palette.INK)
