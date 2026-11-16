class_name Marker
extends RefCounted

## The little signs over heads and props: "!" (something to put to them),
## "?" (a record worth a look), "ok" (settled).


static func draw(canvas: CanvasItem, at: Vector2, kind: String) -> void:
	match kind:
		"!", "?":
			canvas.draw_rect(Rect2(at + Vector2(-5, -9), Vector2(10, 13)), Palette.INK)
			canvas.draw_rect(Rect2(at + Vector2(-4, -8), Vector2(8, 11)), Palette.NOTE)
			if kind == "!":
				canvas.draw_rect(Rect2(at + Vector2(-1, -7), Vector2(2, 6)), Palette.EMBER)
				canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 2)), Palette.EMBER)
			else:
				var c := Palette.SYN_KEYWORD
				canvas.draw_rect(Rect2(at + Vector2(-2, -7), Vector2(4, 2)), c)
				canvas.draw_rect(Rect2(at + Vector2(1, -6), Vector2(2, 3)), c)
				canvas.draw_rect(Rect2(at + Vector2(-1, -3), Vector2(2, 2)), c)
				canvas.draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 2)), c)
		"ok":
			canvas.draw_line(at + Vector2(-4, -3), at + Vector2(-1, 0), Palette.GREEN, 2.0)
			canvas.draw_line(at + Vector2(-1, 0), at + Vector2(5, -7), Palette.GREEN, 2.0)
