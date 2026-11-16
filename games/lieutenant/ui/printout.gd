class_name Printout
extends RefCounted

## A result table, set out the way Records' line printer would: fixed-width
## columns on green-bar paper. Used by the notebook (what a query returned)
## and by lesson cards.


## Sets a result out in at most `max_rows` rows and `width` room pixels.
## Returns {lines: [{kind, cells}], widths: [chars], more}. Cells too wide
## for their column are cut with "..".
static func layout(result: Dictionary, max_rows: int, width: float) -> Dictionary:
	var columns: Array = result.columns
	var rows: Array = result.rows
	var shown: Array = rows.slice(0, max_rows)
	var widths: Array = []
	for i in columns.size():
		var w := str(columns[i]).length()
		for row: Array in shown:
			w = maxi(w, Sql.show(row[i]).length())
		widths.append(w)
	# Trim the widest columns until the row fits.
	var cell := SqlDraw.width("0")
	var room := int(width / cell) - 2
	while _total(widths) > room:
		var widest := 0
		for i in widths.size():
			if int(widths[i]) > int(widths[widest]):
				widest = i
		if int(widths[widest]) <= 4:
			break
		widths[widest] = int(widths[widest]) - 1
	var lines: Array = [{"kind": "head", "cells": columns}]
	for row: Array in shown:
		var cells: Array = []
		for v: Variant in row:
			cells.append(Sql.show(v))
		lines.append({"kind": "row", "cells": cells, "nulls": row.map(func(v: Variant) -> bool: return v == null)})
	if rows.is_empty():
		lines.append({"kind": "note", "text": "(no rows)"})
	elif rows.size() > shown.size():
		lines.append({"kind": "note", "text": "... and %d more rows" % (rows.size() - shown.size())})
	return {"lines": lines, "widths": widths, "more": rows.size() - shown.size()}


static func _total(widths: Array) -> int:
	var total := 0
	for w: int in widths:
		total += w + 2
	return total


## Draws a laid-out table into `rect`, 11 room pixels to a line.
static func draw(c: CanvasItem, rect: Rect2, table: Dictionary) -> void:
	var font := Palette.mono()
	var cell := SqlDraw.width("0")
	c.draw_rect(rect, Palette.BAR_LIGHT)
	var y := rect.position.y + 2
	var index := 0
	for line: Dictionary in table.lines:
		if index % 2 == 1:
			c.draw_rect(Rect2(rect.position.x, y, rect.size.x, 11), Palette.BAR_GREEN)
		var x := rect.position.x + 6
		var base := y + 9
		if line.kind == "note":
			c.draw_string(font, Vector2(x, base), str(line.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.BAR_INK.lightened(0.35))
		else:
			var cells: Array = line.cells
			for i in cells.size():
				var w := int(table.widths[i])
				var text := str(cells[i])
				if text.length() > w:
					text = text.substr(0, maxi(w - 2, 1)) + ".."
				var color := Palette.BAR_INK
				if line.kind == "head":
					color = Palette.SYN_KEYWORD
				elif bool((line.nulls as Array)[i]):
					color = Palette.EMBER.darkened(0.25)
				c.draw_string(font, Vector2(roundf(x), base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
				x += (w + 2) * cell
			if line.kind == "head":
				c.draw_line(Vector2(rect.position.x + 4, y + 10.5), Vector2(rect.end.x - 4, y + 10.5), Color(Palette.BAR_INK, 0.45), 1.0)
		y += 11
		index += 1
