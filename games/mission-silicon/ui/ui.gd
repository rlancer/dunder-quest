class_name UI
extends RefCounted

## Small builders for the game's controls, so every label and button gets
## the same fonts, sizes and startup-green styling, and every button is at
## least a tap target tall.


static func label(text: String, size: int = Palette.BODY, color: Color = Palette.SLATE, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Palette.body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func title(text: String, size: int, color: Color) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", Palette.titles())
	return l


static func box(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0, radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


## kind: "normal", "primary" (green), "quiet" (no border) or "dark".
static func button(text: String, kind: String = "normal", min_size: Vector2 = Vector2(0, Palette.TAP)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(maxf(min_size.x, Palette.TAP), maxf(min_size.y, Palette.TAP))
	b.add_theme_font_override("font", Palette.body())
	b.add_theme_font_size_override("font_size", Palette.LABEL)
	style(b, kind)
	return b


static func style(b: Button, kind: String) -> void:
	var bg := Palette.WHITE
	var fg := Palette.SLATE
	var border := Palette.SLATE_LIGHT
	match kind:
		"primary":
			bg = Palette.GREEN
			fg = Palette.WHITE
			border = Palette.GREEN_DARK
		"quiet":
			bg = Color(1, 1, 1, 0)
			border = Color(1, 1, 1, 0)
		"dark":
			bg = Palette.SLATE
			fg = Palette.WHITE
			border = Palette.BLACK
		"cut":
			bg = Palette.RULE
			fg = Palette.SLATE_MID
			border = Palette.SLATE_LIGHT
	b.add_theme_stylebox_override("normal", box(bg, border, 1))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.08) if bg.a > 0 else Color(0, 0, 0, 0.05), border, 1))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.12) if bg.a > 0 else Color(0, 0, 0, 0.1), border, 1))
	b.add_theme_stylebox_override("disabled", box(Palette.RULE, Palette.RULE, 1))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, fg)
	b.add_theme_color_override("font_disabled_color", Palette.SLATE_LIGHT)


static func panel(bg: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", box(bg, border, width))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func place(c: Control, rect: Rect2) -> Control:
	c.position = rect.position
	c.size = rect.size
	return c


static func vbox(sep: int = 2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep: int = 2) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()
