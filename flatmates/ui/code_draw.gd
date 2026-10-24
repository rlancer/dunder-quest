class_name CodeDraw
extends RefCounted

## Syntax coloring for code on a card or in the editor: keywords, strings
## (quotes and backticks), numbers, comments and method calls, the way a
## code editor would show them.

const SIZE := 16
const LINE := 11
const KEYWORDS := ["const", "let", "for", "of", "if", "else", "await", "async", "function", "return", "new", "true", "false", "null", "undefined"]


## [[text, color], ...] for one line.
static func tokens(line: String, base: Color = Palette.CODE) -> Array:
	var out: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "/" and i + 1 < n and line[i + 1] == "/":
			out.append([line.substr(i), Palette.SYN_COMMENT])
			break
		if c == "\"" or c == "'" or c == "`":
			var j := i + 1
			while j < n and line[j] != c:
				j += 1
			out.append([line.substr(i, mini(j + 1, n) - i), Palette.SYN_STRING])
			i = mini(j + 1, n)
			continue
		if _is_digit(c):
			var j := i
			while j < n and (_is_digit(line[j]) or line[j] == "."):
				j += 1
			out.append([line.substr(i, j - i), Palette.SYN_NUMBER])
			i = j
			continue
		if _is_word(c):
			var j := i
			while j < n and (_is_word(line[j]) or _is_digit(line[j])):
				j += 1
			var word := line.substr(i, j - i)
			var color := base
			if KEYWORDS.has(word):
				color = Palette.SYN_KEYWORD
			elif j < n and line[j] == "(":
				color = Palette.SYN_CALL
			elif word in ["clive", "jazz", "console", "Promise", "setTimeout"]:
				color = Palette.JS
			out.append([word, color])
			i = j
			continue
		out.append([c, base.darkened(0.15)])
		i += 1
	return out


## Draws one line at `at` (baseline) and returns its width.
static func draw_line(canvas: CanvasItem, at: Vector2, line: String, base: Color = Palette.CODE) -> float:
	var font := Palette.mono()
	var x := 0.0
	for token: Array in tokens(line, base):
		canvas.draw_string(font, (at + Vector2(x, 0)).round(), str(token[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, token[1])
		x += font.get_string_size(str(token[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	return x


static func width(text: String) -> float:
	return Palette.mono().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_word(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_" or c == "$"
