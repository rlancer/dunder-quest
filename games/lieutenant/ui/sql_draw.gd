class_name SqlDraw
extends RefCounted

## SQL on the page: keywords, strings, numbers and functions in their own
## colors, and the measuring and wrapping the notebook and cards share.

const SIZE := 16
const LINE := 11
## What a clause's second line starts with.
const INDENT := "    "
const WORDS := ["SELECT", "DISTINCT", "FROM", "JOIN", "LEFT", "INNER", "OUTER", "ON", "WHERE", "GROUP", "BY", "HAVING", "ORDER", "ASC", "DESC", "LIMIT", "AND", "OR", "NOT", "IS", "NULL", "LIKE", "BETWEEN", "IN", "AS"]


## [[text, color], ...] for one line of SQL.
static func tokens(line: String, base: Color, dark: bool = false) -> Array:
	var keyword := Palette.DARK_KEYWORD if dark else Palette.SYN_KEYWORD
	var string := Palette.DARK_STRING if dark else Palette.SYN_STRING
	var number := Palette.DARK_NUMBER if dark else Palette.SYN_NUMBER
	var function := Palette.DARK_FUNC if dark else Palette.SYN_FUNC
	var out: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "'":
			var j := i + 1
			while j < n and line[j] != "'":
				j += 1
			out.append([line.substr(i, mini(j + 1, n) - i), string])
			i = mini(j + 1, n)
		elif c >= "0" and c <= "9":
			var j := i
			while j < n and ((line[j] >= "0" and line[j] <= "9") or line[j] == "."):
				j += 1
			out.append([line.substr(i, j - i), number])
			i = j
		elif _word(c):
			var j := i
			while j < n and (_word(line[j]) or (line[j] >= "0" and line[j] <= "9")):
				j += 1
			var word := line.substr(i, j - i)
			var color := base
			if WORDS.has(word):
				color = keyword
			elif j < n and line[j] == "(":
				color = function
			out.append([word, color])
			i = j
		else:
			out.append([c, base])
			i += 1
	return out


## Draws one line at `at` (baseline) and returns its width. Each word is
## placed by the width of everything before it, so a line comes out exactly
## as wide as `width` says however many colours it's drawn in.
static func draw_line(canvas: CanvasItem, at: Vector2, line: String, base: Color = Palette.NOTE_INK, dark: bool = false) -> float:
	var font := Palette.mono()
	var before := ""
	for token: Array in tokens(line, base, dark):
		Fit.text(canvas, font, at + Vector2(width(before), 0), str(token[0]), SIZE, token[1])
		before += str(token[0])
	return width(line)


static func width(text: String) -> float:
	return Palette.mono().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x


## How far one character of the code font moves along a line. (A single
## character measures a little more than that: its width is rounded up.)
static func cell() -> float:
	return width("0".repeat(40)) / 40.0


## Breaks `text` into lines no wider than `limit`.
static func wrap(text: String, limit: float, font: Font = null, size: int = SIZE) -> PackedStringArray:
	if font == null:
		font = Palette.mono()
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > limit and line != "":
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return lines


## A query written a clause to a line, with any clause wider than `limit`
## carried on to further lines, indented.
static func wrap_clauses(clauses: PackedStringArray, limit: float) -> PackedStringArray:
	var out := PackedStringArray()
	for clause in clauses:
		if width(clause) <= limit:
			out.append(clause)
			continue
		# (SqlDraw.wrap, spelled out: a bare wrap() is GDScript's own, for numbers.)
		var rest := SqlDraw.wrap(clause, limit)
		out.append(rest[0])
		rest.remove_at(0)
		for line in SqlDraw.wrap(" ".join(rest), limit - width(INDENT)):
			out.append(INDENT + line)
	return out


static func _word(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
