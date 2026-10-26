class_name CodeDraw
extends RefCounted

## Rust syntax coloring for the legal pad, the code strip and lesson cards:
## keywords, types, macros, strings, numbers, lifetimes, comments and calls.

const SIZE := 16
const LINE := 11
const KEYWORDS := ["fn", "let", "mut", "if", "else", "match", "for", "in", "return", "struct", "enum", "impl", "self", "Self", "true", "false", "pub", "use", "loop", "while"]
const TYPES := ["i32", "i64", "u32", "u8", "usize", "f64", "bool", "char", "str", "String", "Vec", "Option", "Result"]


## [[text, color], ...] for one line.
static func tokens(line: String, base: Color = Palette.PAD_INK) -> Array:
	var out: Array = []
	var i := 0
	var n := line.length()
	while i < n:
		var c := line[i]
		if c == "/" and i + 1 < n and line[i + 1] == "/":
			out.append([line.substr(i), Palette.SYN_COMMENT])
			break
		if c == "\"":
			var j := i + 1
			while j < n and line[j] != "\"":
				if line[j] == "\\":
					j += 1
				j += 1
			out.append([line.substr(i, mini(j + 1, n) - i), Palette.SYN_STRING])
			i = mini(j + 1, n)
			continue
		if c == "'" and i + 1 < n and _is_word(line[i + 1]):
			var j := i + 1
			while j < n and (_is_word(line[j]) or _is_digit(line[j])):
				j += 1
			out.append([line.substr(i, j - i), Palette.SYN_KEYWORD])
			i = j
			continue
		if _is_digit(c):
			var j := i
			while j < n and (_is_digit(line[j]) or line[j] == "." or line[j] == "_"):
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
			elif j < n and line[j] == "!":
				color = Palette.SYN_MACRO
				word += "!"
				j += 1
			elif TYPES.has(word) or word[0] == word[0].to_upper() and word[0] != "_":
				color = Palette.SYN_TYPE
			elif j < n and line[j] == "(":
				color = Palette.SYN_CALL
			out.append([word, color])
			i = j
			continue
		out.append([c, base])
		i += 1
	return out


## Draws one line at `at` (baseline) and returns its width.
static func draw_line(canvas: CanvasItem, at: Vector2, line: String, base: Color = Palette.PAD_INK, tint: float = 0.0) -> float:
	var font := Palette.mono()
	var x := 0.0
	for token: Array in tokens(line, base):
		var color: Color = token[1]
		if tint > 0.0:
			color = color.lerp(Palette.SEPIA.darkened(0.5), tint)
		canvas.draw_string(font, (at + Vector2(x, 0)).round(), str(token[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, color)
		x += font.get_string_size(str(token[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	return x


static func width(text: String) -> float:
	return Palette.mono().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x


## Breaks `text` into lines no wider than `limit` in `font` at `size`.
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


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_word(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"
