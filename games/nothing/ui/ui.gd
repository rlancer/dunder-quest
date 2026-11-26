class_name Ui
extends RefCounted

## The pieces every screen is drawn from: plum panels, slip paper, cards
## coloured by what they are, a monitor's glass, stars, ticks.

const PORTRAITS := "res://assets/sprites/%s.png"
## A row of code or of a list.
const ROW := 12.0


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


## A sheet of paper: a request slip, a lesson card.
static func paper(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PAPER_LINE)
	canvas.draw_rect(rect.grow(-1), Palette.PAPER)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 3, rect.size.x - 2, 2), Palette.PAPER_DARK)
	canvas.draw_rect(Rect2(rect.end.x - 3, rect.position.y + 1, 2, rect.size.y - 2), Palette.PAPER_DARK)
	Fit.cover(rect)


## Two brass brads down the left of a sheet.
static func brads(canvas: CanvasItem, rect: Rect2) -> void:
	for y: float in [rect.position.y + 24.0, rect.end.y - 24.0]:
		canvas.draw_rect(Rect2(rect.position.x + 3, y - 2, 4, 4), Palette.MUSTARD)
		canvas.draw_rect(Rect2(rect.position.x + 3, y - 2, 4, 1), Palette.MUSTARD_LIGHT)


## A studio monitor's dark glass.
static func glass(canvas: CanvasItem, rect: Rect2) -> void:
	canvas.draw_rect(rect, Palette.PLUM_DARK)
	canvas.draw_rect(rect.grow(-1), Palette.GLASS)
	Fit.cover(rect)


## A card: a little white card with a stripe the colour of what it is
## (a method, a path, a header or a body) and its words on it.
static func chip(canvas: CanvasItem, rect: Rect2, card: String, lit: bool, used: bool = false) -> void:
	var face := Palette.PAPER_DARK if used else Palette.CREAM
	canvas.draw_rect(rect, Palette.MUSTARD_LIGHT if lit else Palette.PLUM_DARK)
	canvas.draw_rect(rect.grow(-1), face.lightened(0.25) if lit and not used else face)
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.position.y + 1, 3, rect.size.y - 2), kind_color(Http.kind(card), false))
	canvas.draw_rect(Rect2(rect.position.x + 1, rect.end.y - 2, rect.size.x - 2, 1), face.darkened(0.15))
	var wide := Fit.width(Palette.mono(), card, 16)
	var at := Vector2(roundf(rect.position.x + 3 + (rect.size.x - 3 - wide) / 2.0), rect.position.y + rect.size.y - 5.0)
	Fit.text(canvas, Palette.mono(), at, card, 16, Palette.PAPER_LINE if used else Palette.INK)


static func chip_width(card: String) -> float:
	return maxf(20.0, Fit.width(Palette.mono(), card, 16) + 12.0)


## The colour of a kind of card: a method, a path, a header, a body.
static func kind_color(kind: String, dark: bool) -> Color:
	match kind:
		"method":
			return Palette.BRICK_LIGHT if dark else Palette.BRICK
		"path":
			return Palette.TEAL_LIGHT if dark else Palette.TEAL
		"header":
			return Palette.MUSTARD_LIGHT if dark else Palette.BLUE
		"body":
			return Palette.MUSTARD if dark else Color(0.6, 0.38, 0.05)
	return Palette.GLASS_TEXT if dark else Palette.INK


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
