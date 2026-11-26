class_name Ui
extends RefCounted

## The pieces every screen is drawn from: boards, parchment, chips, a line
## of the lineup with what the pattern caught lit up on it, stars, ticks.

const PORTRAITS := "res://assets/sprites/%s.png"

static var _portraits: Dictionary = {}


static func portrait(who: String) -> Texture2D:
	if not _portraits.has(who):
		var path := PORTRAITS % who
		_portraits[who] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _portraits[who]


## A panel of weathered boards.
static func wood(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.WOOD_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.WOOD)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, rect.size.x - 2, 1), Palette.WOOD_LIGHT)
	var y := rect.position.y + 14.0
	while y < rect.end.y - 4.0:
		canvas.draw_rect(Rect2(rect.position.x + 1, y, rect.size.x - 2, 1), Color(Palette.WOOD_DARK, 0.45))
		y += 14.0
	Fit.cover(rect)


## A sheet of wanted-poster parchment.
static func paper(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PAPER_LINE)
	canvas.draw_rect(rect.grow(-1), Palette.PAPER)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Palette.PAPER_DARK)
	canvas.draw_rect(Rect2(rect.end.x - 3, rect.position.y + 1, 2, rect.size.y - 2), Palette.PAPER_DARK)
	Fit.cover(rect)


## A nail in each top corner of a poster.
static func nails(canvas: CanvasItem, rect: Rect2) -> void:
	for x: float in [rect.position.x + 5.0, rect.end.x - 6.0]:
		canvas.draw_rect(Rect2(x - 1, rect.position.y + 3, 3, 3), Palette.WOOD_DARK)
		canvas.draw_rect(Rect2(x, rect.position.y + 4, 1, 1), Palette.PAPER_DARK)


## A chip: a piece of pattern on a little tile. Returns nothing; its width
## is `chip_width`.
static func chip(canvas: CanvasItem, rect: Rect2, token: String, lit: bool, on_paper: bool = false) -> void:
	var face := Palette.PAPER_DARK if on_paper else Palette.CREAM
	canvas.draw_rect(rect, Palette.GOLD_LIGHT if lit else Palette.WOOD_DARK)
	canvas.draw_rect(rect.grow(-1), face.lightened(0.25) if lit else face)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), face.darkened(0.18))
	var wide := Fit.width(Palette.mono(), token, 16)
	regex(canvas, Vector2(roundf(rect.position.x + (rect.size.x - wide) / 2.0), rect.position.y + rect.size.y - 6.0), token, kind_color(token))


static func chip_width(token: String) -> float:
	return maxf(18.0, Fit.width(Palette.mono(), token, 16) + 10.0)


## Ink for plain letters, red for the pieces with a special meaning.
static func kind_color(token: String) -> Color:
	var kind := Rx.kind(token)
	if kind != "atom":
		return Palette.RED
	if token == "." or token.begins_with("\\") or token.begins_with("["):
		return Palette.RED
	return Palette.INK


## Regex text, with every space shown as a small tray so it can be seen.
static func regex(canvas: CanvasItem, at: Vector2, words: String, color: Color, size: int = 16) -> float:
	var font := Palette.mono()
	var wide := Fit.text(canvas, font, at, words, size, color)
	for i in words.length():
		if words[i] == " ":
			var x := at.x + Fit.width(font, words.left(i), size)
			var w := Fit.width(font, " ", size)
			var tray := Color(color, 0.55)
			canvas.draw_rect(Rect2(x + 1, at.y, w - 2, 1), tray)
			canvas.draw_rect(Rect2(x + 1, at.y - 2, 1, 2), tray)
			canvas.draw_rect(Rect2(x + w - 2, at.y - 2, 1, 2), tray)
	return wide


## One line of a lineup: its text at the baseline `at`, with what the
## pattern matched lit behind it (`r` is a Judge row, or {} for none), the
## part a group rounded up lit brighter, and the part the judge wants
## (`take`) underlined in red.
static func lineup_text(canvas: CanvasItem, at: Vector2, words: String, r: Dictionary, take: String, color: Color, glow: float = 1.0) -> void:
	var font := Palette.mono()
	if not r.is_empty() and bool(r.get("found", false)):
		_band(canvas, at, words, int(r.start), int(r.end), Color(Palette.MATCH, Palette.MATCH.a * glow))
		var ts := int(r.get("take_start", -1))
		var te := int(r.get("take_end", -1))
		if ts >= 0 and (ts != int(r.start) or te != int(r.end)):
			_band(canvas, at, words, ts, te, Color(Palette.TAKE, Palette.TAKE.a * glow))
	if take != "":
		var from := words.find(take)
		if from >= 0:
			var x0 := at.x + Fit.width(font, words.left(from), 16)
			var x1 := at.x + Fit.width(font, words.left(from + take.length()), 16)
			var x := x0
			while x < x1:
				canvas.draw_rect(Rect2(x, at.y + 2, minf(3.0, x1 - x), 1), Palette.RED)
				x += 5.0
	Fit.text(canvas, font, at, words, 16, color)


static func _band(canvas: CanvasItem, at: Vector2, words: String, from: int, to: int, color: Color) -> void:
	var font := Palette.mono()
	var x0 := at.x + Fit.width(font, words.left(from), 16)
	var x1 := at.x + Fit.width(font, words.left(to), 16)
	# A match of nothing (an empty pattern, a bare ^) still shows, as a sliver.
	canvas.draw_rect(Rect2(x0 - 1, at.y - 10, maxf(x1 - x0, 1.0) + 2, 13), color)


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
	canvas.draw_rect(rect, Color(Palette.WOOD_DARK, 0.85))
	Fit.cover(rect)
	Fit.text(canvas, font, Vector2(rect.position.x + 4.0, 266.0), words, 10, Palette.GOLD_LIGHT)
