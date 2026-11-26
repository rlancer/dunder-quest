class_name Ui
extends RefCounted

## The pieces every screen is drawn from: steel panels, ticket paper, chips,
## shell text coloured by what each word is, terminal listings, stars, ticks.

const PORTRAITS := "res://assets/sprites/%s.png"
## A row of a listing, and how many of them a panel shows.
const ROW := 13.0
const ROWS := 7

static var _portraits: Dictionary = {}


static func portrait(who: String) -> Texture2D:
	if not _portraits.has(who):
		var path := PORTRAITS % who
		_portraits[who] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _portraits[who]


## A panel of brushed steel.
static func steel(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.STEEL_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.STEEL)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, 1), Palette.STEEL_LIGHT)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Color(Palette.STEEL_DARK, 0.5))
	for x: float in [rect.position.x + 4.0, rect.end.x - 6.0]:
		for y: float in [rect.position.y + 4.0, rect.end.y - 7.0]:
			canvas.draw_rect(Rect2(x, y, 2, 2), Palette.STEEL_DARK)
			canvas.draw_rect(Rect2(x, y, 1, 1), Palette.STEEL_LIGHT)
	Fit.cover(rect)


## A sheet of ticket paper.
static func paper(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PAPER_LINE)
	canvas.draw_rect(rect.grow(-1), Palette.PAPER)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Palette.PAPER_DARK)
	canvas.draw_rect(Rect2(rect.end.x - 3, rect.position.y + 1, 2, rect.size.y - 2), Palette.PAPER_DARK)
	Fit.cover(rect)


## A strip of green tape over each top corner of a sheet.
static func tape(canvas: CanvasItem, rect: Rect2) -> void:
	for x: float in [rect.position.x - 3.0, rect.end.x - 15.0]:
		canvas.draw_rect(Rect2(x, rect.position.y - 2, 18, 6), Color(Palette.GREEN, 0.9))
		canvas.draw_rect(Rect2(x, rect.position.y - 2, 18, 1), Color(Palette.GREEN_LIGHT, 0.7))


## A terminal's black glass.
static func screen(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.STEEL_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.TERM)
	Fit.cover(rect)


## A chip: a piece of a command on a little tile. Its width is `chip_width`.
static func chip(canvas: CanvasItem, rect: Rect2, token: String, lit: bool, on_paper: bool = false) -> void:
	var face := Palette.PAPER_DARK if on_paper else Palette.CREAM
	canvas.draw_rect(rect, Palette.LAMP_LIGHT if lit else Palette.STEEL_DARK)
	canvas.draw_rect(rect.grow(-1), face.lightened(0.3) if lit else face)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), face.darkened(0.18))
	var wide := Fit.width(Palette.mono(), token, 16)
	code(canvas, Vector2(roundf(rect.position.x + (rect.size.x - wide) / 2.0), rect.position.y + rect.size.y - 6.0), token, false)


static func chip_width(token: String) -> float:
	return maxf(18.0, Fit.width(Palette.mono(), token, 16) + 10.0)


## What a word of a line is: "command", "pipe" (and the arrow), "option",
## "file" or "word".
static func kind(word: String) -> String:
	if word == "|" or word == ">" or word == "<":
		return "pipe"
	if Shell.commands().has(word):
		return "command"
	if word.begins_with("-") and word.length() > 1:
		return "option"
	if word.contains("."):
		return "file"
	return "word"


static func kind_color(word: String, dark: bool) -> Color:
	match kind(word):
		"command":
			return Palette.LAMP_LIGHT if dark else Palette.BLUE
		"pipe":
			return Palette.CREAM if dark else Palette.INK
		"option":
			return Palette.RED_LIGHT if dark else Palette.RED
		"file":
			return Palette.GREEN_LIGHT if dark else Palette.GREEN
	return Palette.TERM_TEXT if dark else Palette.INK


## Shell text with its baseline starting at `at`, each word in the colour of
## what it is (on a terminal's black if `dark`). Returns its width.
static func code(canvas: CanvasItem, at: Vector2, words: String, dark: bool) -> float:
	var font := Palette.mono()
	var x := at.x
	var space := Fit.width(font, " ", 16)
	var first := true
	for word: String in words.split(" "):
		if not first:
			x += space
		first = false
		if word != "":
			x += Fit.text(canvas, font, Vector2(x, at.y), word, 16, kind_color(word, dark))
	return x - at.x


## `lines` as a terminal shows them in a window `wide` across: a line too
## long for it carries on underneath, as it would on a real one.
static func wrapped(lines: Array, wide: float) -> Array:
	var font := Palette.mono()
	var out: Array = []
	for line: String in lines:
		var rest := line
		while Fit.width(font, rest, 16) > wide and rest.length() > 1:
			var cut := rest.length() - 1
			while cut > 1 and Fit.width(font, rest.left(cut), 16) > wide:
				cut -= 1
			out.append(rest.left(cut))
			rest = rest.substr(cut)
		out.append(rest)
	return out


## A listing in a panel: `lines` from the baseline of its first row, as many
## rows as there are (`Ui.ROWS` at most; if there are more, the last row
## says how many it left out). Returns the rows as shown.
static func listing(canvas: CanvasItem, at: Vector2, lines: Array, wide: float, color: Color, more: Color) -> Array:
	var rows := wrapped(lines, wide)
	var shown := rows
	if rows.size() > ROWS:
		shown = rows.slice(0, ROWS - 1)
	for i in shown.size():
		Fit.text(canvas, Palette.mono(), at + Vector2(0, i * ROW), str(shown[i]), 16, color)
	if rows.size() > ROWS:
		Fit.text(canvas, Palette.mono(), at + Vector2(0, (ROWS - 1) * ROW), "+ %d more lines" % (rows.size() - ROWS + 1), 16, more)
	return shown


static func star(canvas: CanvasItem, centre: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		points.append(centre + Vector2(cos(a), sin(a)) * r)
	canvas.draw_colored_polygon(points, color)


static func tick(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_line(at + Vector2(0, 4), at + Vector2(3, 7), color, 2.0)
	canvas.draw_line(at + Vector2(3, 7), at + Vector2(9, 0), color, 2.0)


static func cross(canvas: CanvasItem, at: Vector2, color: Color) -> void:
	canvas.draw_line(at + Vector2(1, 0), at + Vector2(8, 7), color, 2.0)
	canvas.draw_line(at + Vector2(8, 0), at + Vector2(1, 7), color, 2.0)


## A small label on a coloured tab.
static func tab(canvas: CanvasItem, rect: Rect2, words: String, fill: Color, ink: Color) -> void:
	canvas.draw_rect(rect, fill)
	var font := Palette.pixel()
	Fit.centred(canvas, font, rect.position.x + rect.size.x / 2.0, rect.end.y - 3.0, words, 10, ink)


## The line along the foot of a screen that says what to press.
static func prompt(canvas: CanvasItem, words: String) -> void:
	var font := Palette.pixel()
	var wide := Fit.width(font, words, 10)
	var rect := Rect2(472.0 - wide - 8.0, 257.0, wide + 8.0, 12.0)
	canvas.draw_rect(rect, Color(Palette.STEEL_DARK, 0.85))
	Fit.cover(rect)
	Fit.text(canvas, font, Vector2(rect.position.x + 4.0, 266.0), words, 10, Palette.LAMP_LIGHT)
