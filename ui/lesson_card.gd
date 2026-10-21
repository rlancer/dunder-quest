class_name LessonCard
extends Control

## The full-screen card for a lore scroll, a rune key, or a Spellbook page:
## a kicker, a title, a code block, one line of insight, and a footer.
## Built in code so every lesson shares one layout. The HUD drives its input.

const MONO := preload("res://assets/fonts/VT323.ttf")
const GOLD := Color(1.0, 0.84, 0.46)

var _box: PanelContainer
var _frame: StyleBoxFlat
var _kicker: Label
var _title: Label
var _code: Label
var _code_box: PanelContainer
var _body: Label
var _footer: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.07, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = PanelContainer.new()
	_box.custom_minimum_size = Vector2(400.0, 0.0)
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.08, 0.05, 0.08, 0.97)
	_frame.border_color = GOLD
	_frame.set_border_width_all(1)
	_frame.border_width_top = 3
	_frame.set_corner_radius_all(3)
	_frame.content_margin_left = 10.0
	_frame.content_margin_right = 10.0
	_frame.content_margin_top = 6.0
	_frame.content_margin_bottom = 6.0
	_frame.anti_aliasing = false
	_box.add_theme_stylebox_override(&"panel", _frame)
	center.add_child(_box)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 4)
	_box.add_child(rows)
	_kicker = _make_label(10, GOLD.darkened(0.15))
	rows.add_child(_kicker)
	_title = _make_label(16, Color(1.0, 0.95, 0.84))
	_title.add_theme_constant_override(&"outline_size", 3)
	rows.add_child(_title)
	_code_box = PanelContainer.new()
	var code_style := StyleBoxFlat.new()
	code_style.bg_color = Color(0.02, 0.015, 0.035, 1.0)
	code_style.border_color = GOLD.darkened(0.4)
	code_style.border_width_left = 2
	code_style.content_margin_left = 7.0
	code_style.content_margin_right = 6.0
	code_style.content_margin_top = 3.0
	code_style.content_margin_bottom = 4.0
	code_style.anti_aliasing = false
	_code_box.add_theme_stylebox_override(&"panel", code_style)
	rows.add_child(_code_box)
	_code = Label.new()
	_code.add_theme_font_override(&"font", MONO)
	_code.add_theme_font_size_override(&"font_size", 16)
	_code.add_theme_constant_override(&"line_spacing", -3)
	_code.add_theme_color_override(&"font_color", Color(0.86, 0.94, 0.88))
	_code_box.add_child(_code)
	_body = _make_label(11, Color(0.92, 0.88, 0.96))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(380.0, 0.0)
	rows.add_child(_body)
	_footer = _make_label(10, Color(0.7, 0.66, 0.78))
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rows.add_child(_footer)


## card: {kicker, title, code, body, footer, tint}. Empty code hides the block.
func show_card(card: Dictionary) -> void:
	var tint: Color = card.get("tint", GOLD)
	_frame.border_color = tint
	_kicker.add_theme_color_override(&"font_color", tint)
	_kicker.text = str(card.get("kicker", "")).to_upper()
	_title.text = str(card.get("title", ""))
	_code.text = str(card.get("code", ""))
	_code_box.visible = _code.text != ""
	_body.text = str(card.get("body", ""))
	_body.visible = _body.text != ""
	_footer.text = str(card.get("footer", ""))
	var was_open := visible
	show()
	if not was_open:
		_box.pivot_offset = _box.size * 0.5
		_box.scale = Vector2(0.9, 0.9)
		_box.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_box, "modulate:a", 1.0, 0.12)


func card_title() -> String:
	return _title.text


func _make_label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label
