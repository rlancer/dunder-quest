class_name Fit
extends RefCounted

## Every piece of text in the game is drawn through here, inside the panel
## it belongs to: `Fit.begin(rect, "the lineup")`, the text, `Fit.end()`.
## In play that's all it is. With `audit` on (tests/layout.tscn and the
## bot), any text that reaches past its panel's edge is written down in
## `breaks`, so a line that's grown too long for its box fails a test
## instead of being found by a player. Long text is wrapped (`para`), never
## cut. (The same idea as Just One More JOIN's ui/fit.gd.)

const SCREEN := Rect2(0, 0, 480, 270)
## How far a glyph reaches above and below its baseline, as a share of the
## font size (capitals and descenders; the font's own line box is taller).
const RISE := 0.6
const DROP := 0.14

static var audit: bool = false
## "panel: text" -> how it broke out, for every break seen.
static var breaks: Dictionary = {}
static var _stack: Array = []
## The text drawn so far this frame, canvas by canvas, to catch one piece
## of text drawn over another.
static var _drawn: Dictionary = {}
static var _canvas: int = 0


## Call at the top of a canvas's draw: a new frame's worth of text.
static func frame(canvas: CanvasItem) -> void:
	_canvas = canvas.get_instance_id()
	_drawn[_canvas] = []
	_stack.clear()


## An opaque panel drawn over part of the canvas: what's under it no longer
## counts as text to collide with.
static func cover(rect: Rect2) -> void:
	if audit:
		_drawn[_canvas] = (_drawn.get(_canvas, []) as Array).filter(func(seen: Array) -> bool: return not rect.intersects(seen[0]))


## Blinking marks are drawn every frame while auditing, so none is missed.
static func blink(on: bool) -> bool:
	return on or audit


static func begin(rect: Rect2, what: String) -> void:
	_stack.append({"rect": rect, "what": what})


static func end() -> void:
	_stack.pop_back()


static func width(font: Font, words: String, size: int) -> float:
	return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Draws `text` with its baseline starting at `at`, and returns its width.
static func text(canvas: CanvasItem, font: Font, at: Vector2, words: String, size: int, color: Color) -> float:
	canvas.draw_string(font, at, words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	var wide := width(font, words, size)
	if audit and words.strip_edges() != "":
		var box := Rect2(at.x, at.y - size * RISE, wide, size * (RISE + DROP))
		check(box, words)
		# Text over other text. Words of one line are drawn one after another
		# and may touch, so the test is on boxes a pixel smaller all round.
		var mine := box.grow(-1.0)
		var seen: Array = _drawn.get(_canvas, [])
		for other: Array in seen:
			if mine.intersects(other[0]) and str(other[1]) != words:
				breaks["\"%s\" is drawn over \"%s\"" % [words, other[1]]] = "overlap"
		seen.append([mine, words])
		_drawn[_canvas] = seen
	return wide


## Records `box` (some text's, or anything else's) if it isn't inside the
## panel being drawn.
static func check(box: Rect2, words: String) -> void:
	if not audit:
		return
	var panel: Rect2 = _stack[-1].rect if not _stack.is_empty() else SCREEN
	var what: String = _stack[-1].what if not _stack.is_empty() else "the screen"
	var over := PackedStringArray()
	if box.position.x < panel.position.x - 0.5:
		over.append("%d px past the left" % ceili(panel.position.x - box.position.x))
	if box.end.x > panel.end.x + 0.5:
		over.append("%d px past the right" % ceili(box.end.x - panel.end.x))
	if box.position.y < panel.position.y - 0.5:
		over.append("%d px past the top" % ceili(panel.position.y - box.position.y))
	if box.end.y > panel.end.y + 0.5:
		over.append("%d px past the bottom" % ceili(box.end.y - panel.end.y))
	if not over.is_empty():
		breaks["%s: \"%s\"" % [what, words]] = ", ".join(over)


## `words` broken into lines no wider than `wide`, at spaces.
static func wrap_text(font: Font, words: String, size: int, wide: float) -> PackedStringArray:
	var lines := PackedStringArray()
	for paragraph: String in words.split("\n"):
		var line := ""
		for word: String in paragraph.split(" "):
			var trial := word if line == "" else line + " " + word
			if line != "" and width(font, trial, size) > wide:
				lines.append(line)
				line = word
			else:
				line = trial
		lines.append(line)
	return lines


## Draws `words` wrapped to `wide` from the baseline `at`, `leading` pixels
## a line, showing only the first `shown` characters (-1 for all of them),
## and returns how many lines the whole text takes.
static func para(canvas: CanvasItem, font: Font, at: Vector2, words: String, size: int, color: Color, wide: float, leading: float, shown: int = -1) -> int:
	var lines := wrap_text(font, words, size, wide)
	var left := shown
	for i in lines.size():
		var line := lines[i]
		# While auditing, the whole text is measured however little shows.
		if shown >= 0 and not audit:
			if left <= 0:
				break
			line = line.left(left)
			left -= lines[i].length() + 1
		text(canvas, font, at + Vector2(0, i * leading), line, size, color)
	return lines.size()


## Draws `words` centred on `x`.
static func centred(canvas: CanvasItem, font: Font, x: float, y: float, words: String, size: int, color: Color) -> void:
	text(canvas, font, Vector2(roundf(x - width(font, words, size) / 2.0), y), words, size, color)
