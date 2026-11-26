class_name Ui
extends RefCounted

## The pieces every screen is drawn from: plum panels, script paper, cue
## cards, JavaScript coloured by what each word is, stars, ticks.

const PORTRAITS := "res://assets/sprites/%s.png"
## A row of code or of a list.
const ROW := 12.0

const KEYWORDS := ["const", "async", "function", "await", "new", "return", "let"]
const CALLS := ["setTimeout", "queueMicrotask", "Promise", "resolve", "then", "log", "wait", "console"]

static var _portraits: Dictionary = {}


static func portrait(who: String) -> Texture2D:
	if not _portraits.has(who):
		var path := PORTRAITS % who
		_portraits[who] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _portraits[who]


## A panel of the apartment's plum.
static func panel(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PLUM_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.PLUM)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, 1), Palette.PLUM_LIGHT)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Color(Palette.PLUM_DARK, 0.6))
	Fit.cover(rect)


## A sheet of script paper.
static func paper(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PAPER_LINE)
	canvas.draw_rect(rect.grow(-1), Palette.PAPER)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Palette.PAPER_DARK)
	canvas.draw_rect(Rect2(rect.end.x - 3, rect.position.y + 1, 2, rect.size.y - 2), Palette.PAPER_DARK)
	Fit.cover(rect)


## Two brass brads down the left of a script page.
static func brads(canvas: CanvasItem, rect: Rect2) -> void:
	for y: float in [rect.position.y + 24.0, rect.end.y - 24.0]:
		canvas.draw_rect(Rect2(rect.position.x + 3, y - 2, 4, 4), Palette.MUSTARD)
		canvas.draw_rect(Rect2(rect.position.x + 3, y - 2, 4, 1), Palette.MUSTARD_LIGHT)


## A studio monitor's dark glass.
static func glass(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PLUM_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.GLASS)
	Fit.cover(rect)


## A cue card: a little white card with a teal edge and its code on it.
static func chip(canvas: CanvasItem, rect: Rect2, cue: String, lit: bool, used: bool = false) -> void:
	var face := Palette.PAPER_DARK if used else Palette.CREAM
	canvas.draw_rect(rect, Palette.MUSTARD_LIGHT if lit else Palette.PLUM_DARK)
	canvas.draw_rect(rect.grow(-1), face.lightened(0.25) if lit and not used else face)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, 2, rect.size.y - 2), Palette.PAPER_LINE if used else Palette.TEAL)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), face.darkened(0.15))
	var label := Loop.cue_label(cue)
	var wide := Fit.width(Palette.mono(), label, 16)
	var at := Vector2(roundf(rect.position.x + 2 + (rect.size.x - 2 - wide) / 2.0), rect.position.y + rect.size.y - 6.0)
	if used:
		Fit.text(canvas, Palette.mono(), at, label, 16, Palette.PAPER_LINE)
	else:
		code(canvas, at, label, false)


## A piece of code on a little card, as Stu's notes show them.
static func tag(canvas: CanvasItem, rect: Rect2, words: String) -> void:
	canvas.draw_rect(rect, Palette.PAPER_LINE)
	canvas.draw_rect(rect.grow(-1), Palette.CREAM)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, 2, rect.size.y - 2), Palette.TEAL)
	code(canvas, Vector2(rect.position.x + 6, rect.end.y - 5), words, false)


static func tag_width(words: String) -> float:
	return Fit.width(Palette.mono(), words, 16) + 10.0


static func chip_width(cue: String) -> float:
	return maxf(18.0, Fit.width(Palette.mono(), Loop.cue_label(cue), 16) + 12.0)


## What a piece of JavaScript is, a token at a time: [text, kind], where kind
## is "keyword", "call", "string", "number" or "plain".
static func tokens(line: String) -> Array:
	var out: Array = []
	var i := 0
	while i < line.length():
		var c := line[i]
		if c == "\"":
			var j := line.find("\"", i + 1)
			j = line.length() - 1 if j < 0 else j
			out.append([line.substr(i, j - i + 1), "string"])
			i = j + 1
		elif _is_word(c):
			var j := i
			while j < line.length() and (_is_word(line[j]) or line[j].is_valid_int()):
				j += 1
			var word := line.substr(i, j - i)
			out.append([word, "keyword" if KEYWORDS.has(word) else ("call" if CALLS.has(word) else "plain")])
			i = j
		elif c.is_valid_int():
			var j := i
			while j < line.length() and line[j].is_valid_int():
				j += 1
			out.append([line.substr(i, j - i), "number"])
			i = j
		else:
			out.append([c, "plain"])
			i += 1
	return out


static func _is_word(c: String) -> bool:
	return c == "_" or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")


static func kind_color(kind: String, dark: bool) -> Color:
	match kind:
		"keyword":
			return Palette.MUSTARD_LIGHT if dark else Palette.BLUE
		"call":
			return Palette.TEAL_LIGHT if dark else Palette.TEAL
		"string":
			return Palette.BRICK_LIGHT if dark else Palette.BRICK
		"number":
			return Palette.MUSTARD if dark else Color(0.6, 0.38, 0.05)
	return Palette.GLASS_TEXT if dark else Palette.INK


## A line of JavaScript with its baseline starting at `at`, each word in the
## colour of what it is (on dark glass if `dark`). Returns its width.
## Drawn a word at a time, so it's measured as one piece of text.
static func code(canvas: CanvasItem, at: Vector2, line: String, dark: bool, tint: float = 1.0) -> float:
	var font := Palette.mono()
	var wide := Fit.width(font, line, 16)
	Fit.measure(canvas, Rect2(at.x, at.y - 16 * Fit.RISE, wide, 16 * (Fit.RISE + Fit.DROP)), line)
	var x := at.x
	for token: Array in tokens(line):
		var piece := str(token[0])
		var color := kind_color(str(token[1]), dark)
		color.a *= tint
		canvas.draw_string(font, Vector2(x, at.y), piece, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
		x += Fit.width(font, piece, 16)
	return wide


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


## A panel's name on a strip along its top.
static func head(canvas: CanvasItem, rect: Rect2, words: String, fill: Color, right: String = "") -> void:
	var strip := Rect2(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, 12)
	canvas.draw_rect(strip, fill)
	Fit.text(canvas, Palette.pixel(), Vector2(strip.position.x + 4, strip.end.y - 3), words, 10, Palette.CREAM)
	if right != "":
		Fit.text(canvas, Palette.pixel(), Vector2(strip.end.x - 4 - Fit.width(Palette.pixel(), right, 10), strip.end.y - 3), right, 10, Palette.CREAM)


## The line along the foot of a screen that says what to press.
static func prompt(canvas: CanvasItem, words: String) -> void:
	var font := Palette.pixel()
	var wide := Fit.width(font, words, 10)
	var rect := Rect2(472.0 - wide - 8.0, 257.0, wide + 8.0, 12.0)
	canvas.draw_rect(rect, Color(Palette.PLUM_DARK, 0.88))
	Fit.cover(rect)
	Fit.text(canvas, font, Vector2(rect.position.x + 4.0, 266.0), words, 10, Palette.MUSTARD_LIGHT)
