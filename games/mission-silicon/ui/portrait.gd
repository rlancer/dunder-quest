class_name Portrait
extends Control

## A cast member's close-up, drawn in pixels from their `look` in
## data/season.json: skin, hair and its style, beard, shades, shirt, tie.
## Aleister Jr. is a monitor with a green face. Placeholder art until the
## cast is painted like Curb's.

var who: String = "":
	set(v):
		who = v
		queue_redraw()


func _init(person: String = "") -> void:
	who = person
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)


func _draw() -> void:
	if who == "":
		return
	var look: Dictionary = Season.person(who).get("look", {})
	var s := minf(size.x, size.y) / 16.0
	var o := (size - Vector2(16, 16) * s) / 2.0
	var px := func(x: float, y: float, w: float, h: float, c: Color) -> void:
		draw_rect(Rect2(o + Vector2(x, y) * s, Vector2(w, h) * s), c)
	px.call(0, 0, 16, 16, Palette.GREEN_PALE)
	if look.get("screen", false):
		px.call(2, 2, 12, 9, Palette.SLATE)
		px.call(3, 3, 10, 7, Palette.BLACK)
		px.call(5, 5, 2, 2, Palette.GREEN)
		px.call(9, 5, 2, 2, Palette.GREEN)
		px.call(5, 8, 6, 1, Palette.GREEN)
		px.call(7, 11, 2, 2, Palette.SLATE)
		px.call(4, 13, 8, 2, Palette.SLATE_MID)
		return
	var skin := Color(look.get("skin", "#e8c0a0"))
	var hair := Color(look.get("hair", "#3a2a20"))
	var shirt := Color(look.get("shirt", "#5b6675"))
	var style: String = look.get("style", "short")
	# Shoulders and neck.
	px.call(2, 13, 12, 3, shirt)
	px.call(6, 11, 4, 2, skin.darkened(0.1))
	if look.get("tie", false):
		px.call(7, 13, 2, 3, Palette.SLATE)
	# Hair behind the head.
	if style == "long":
		px.call(3, 4, 10, 10, hair)
	elif style == "bob":
		px.call(3, 4, 10, 7, hair)
	elif style == "shaggy":
		px.call(3, 3, 10, 7, hair)
	# Face.
	px.call(4, 4, 8, 8, skin)
	# Hair on top.
	match style:
		"curly":
			px.call(3, 2, 10, 3, hair)
			px.call(3, 4, 1, 2, hair)
			px.call(12, 4, 1, 2, hair)
		"spiky":
			px.call(4, 2, 8, 2, hair)
			px.call(4, 1, 1, 1, hair)
			px.call(7, 1, 1, 1, hair)
			px.call(10, 1, 1, 1, hair)
		"neat":
			px.call(4, 3, 8, 2, hair)
		_:
			px.call(4, 2, 8, 3, hair)
	# Eyes.
	if look.get("shades", false):
		px.call(4, 7, 8, 2, Palette.BLACK)
	else:
		px.call(6, 7, 1, 1, Palette.BLACK)
		px.call(9, 7, 1, 1, Palette.BLACK)
	if look.get("beard", false):
		px.call(4, 9, 8, 3, hair)
		px.call(6, 10, 4, 1, skin.darkened(0.3))
	else:
		px.call(6, 10, 4, 1, skin.darkened(0.3))
