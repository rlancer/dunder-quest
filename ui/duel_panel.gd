class_name DuelPanel
extends Control

## The wizard duel's two strips. Across the top, the question: the wizard's
## name, his wards, the player's sparks, then the code on the left and the
## four answers on the right, lettered like the blocks in the arena. Along
## the bottom, his words: taunts, verdicts and explanations, hints.
## It never takes input or stops play; the fight goes on underneath it.

const MONO := preload("res://assets/fonts/VT323.ttf")
const LETTERS: Array[String] = ["A", "B", "C", "D"]
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
const WHISPER := Color(0.78, 0.66, 1.0)
const DIMMED := Color(0.42, 0.4, 0.48)
const SPEECH := Color(0.92, 0.88, 0.96)
const WIDTH := 468.0

var _top: PanelContainer
var _frame: StyleBoxFlat
var _name: Label
var _wards: Label
var _sparks: _SparkMeter
var _status: Label
var _hint_chip: Label
var _code: Label
var _options: Array[Label] = []
var _option_styles: Array[StyleBoxFlat] = []
var _sub: PanelContainer
var _sub_label: Label
var _tint: Color = Color.WHITE
var _question: Dictionary = {}
var _dimmed: Dictionary = {}
var _broken: int = 0
var _total: int = 1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_sub()


func _build_top() -> void:
	_top = PanelContainer.new()
	_top.position = Vector2(6.0, 3.0)
	_top.custom_minimum_size = Vector2(WIDTH, 0.0)
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame = StyleBoxFlat.new()
	_frame.bg_color = Color(0.06, 0.03, 0.08, 0.9)
	_frame.set_border_width_all(1)
	_frame.border_width_top = 2
	_frame.set_corner_radius_all(2)
	_frame.content_margin_left = 6.0
	_frame.content_margin_right = 6.0
	_frame.content_margin_top = 2.0
	_frame.content_margin_bottom = 4.0
	_frame.anti_aliasing = false
	_top.add_theme_stylebox_override(&"panel", _frame)
	add_child(_top)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 2)
	_top.add_child(rows)

	var header := HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 8)
	rows.add_child(header)
	_name = _make_label(10, Color.WHITE)
	header.add_child(_name)
	_wards = _make_label(10, Color(0.8, 0.78, 0.9))
	header.add_child(_wards)
	_sparks = _SparkMeter.new()
	_sparks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_sparks)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_status = _make_label(10, Color(1.0, 0.86, 0.5))
	header.add_child(_status)
	_hint_chip = _make_label(10, Color(0.66, 0.6, 0.78))
	header.add_child(_hint_chip)

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 8)
	rows.add_child(body)
	var code_box := PanelContainer.new()
	var code_style := StyleBoxFlat.new()
	code_style.bg_color = Color(0.02, 0.015, 0.035, 1.0)
	code_style.border_width_left = 2
	code_style.border_color = Color(1.0, 0.84, 0.46, 0.5)
	code_style.content_margin_left = 6.0
	code_style.content_margin_right = 6.0
	code_style.content_margin_top = 1.0
	code_style.content_margin_bottom = 3.0
	code_style.anti_aliasing = false
	code_box.add_theme_stylebox_override(&"panel", code_style)
	body.add_child(code_box)
	_code = Label.new()
	_code.add_theme_font_override(&"font", MONO)
	_code.add_theme_font_size_override(&"font_size", 16)
	_code.add_theme_constant_override(&"line_spacing", -4)
	_code.add_theme_color_override(&"font_color", Color(0.86, 0.94, 0.88))
	code_box.add_child(_code)
	var options := VBoxContainer.new()
	options.add_theme_constant_override(&"separation", -3)
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(options)
	for index in LETTERS.size():
		var option := Label.new()
		option.add_theme_font_override(&"font", MONO)
		option.add_theme_font_size_override(&"font_size", 16)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.content_margin_left = 3.0
		style.content_margin_right = 3.0
		style.anti_aliasing = false
		option.add_theme_stylebox_override(&"normal", style)
		options.add_child(option)
		_options.append(option)
		_option_styles.append(style)


func _build_sub() -> void:
	_sub = PanelContainer.new()
	_sub.custom_minimum_size = Vector2(WIDTH, 0.0)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.02, 0.07, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, 0.12)
	style.set_corner_radius_all(2)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 2.0
	style.anti_aliasing = false
	_sub.add_theme_stylebox_override(&"panel", style)
	add_child(_sub)
	_sub_label = _make_label(10, SPEECH)
	_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_label.custom_minimum_size = Vector2(WIDTH - 12.0, 0.0)
	_sub.add_child(_sub_label)


## A fresh fight: the header fills in and the question strip waits.
func open(wizard_title: String, tint: Color, broken: int, total: int, sparks: int) -> void:
	_tint = tint
	_frame.border_color = tint
	_name.text = wizard_title
	_name.add_theme_color_override(&"font_color", tint.lightened(0.45))
	_broken = broken
	_total = total
	_refresh_wards()
	_sparks.count = sparks
	_sparks.tint = Color(1.0, 0.62, 0.3)
	_status.text = ""
	_hint_chip.text = ""
	_code.text = "..."
	for option in _options:
		option.text = ""
	_question = {}
	_top.modulate.a = 0.0
	show()
	_top.reset_size()
	create_tween().tween_property(_top, "modulate:a", 1.0, 0.2)


func show_question(question: Dictionary, step: int, total: int) -> void:
	_question = question
	_dimmed = {}
	_total = total
	_broken = step - 1
	_refresh_wards()
	_code.text = str(question.get("code", ""))
	var options: PackedStringArray = question.get("options", PackedStringArray())
	for index in _options.size():
		_options[index].text = "%s  %s" % [LETTERS[index], options[index] if index < options.size() else ""]
		_paint_option(index, Color(0.9, 0.92, 0.86), Color(0, 0, 0, 0))
	_status.text = str(question.get("prompt", "What does this print?"))
	_status.add_theme_color_override(&"font_color", Color(1.0, 0.86, 0.5))
	_hint_chip.text = _hint_key()
	_top.reset_size()
	say("Question %d of %d. Bump the block with the right answer." % [step, total] if step > 1 else "What does it print? Bump that block from below.", Color(0.8, 0.78, 0.9))


## Marks the bumped answer and the right one, and explains.
func show_verdict(chosen: int, correct: bool, remaining: int) -> void:
	var answer := int(_question.get("answer", 0))
	var options: PackedStringArray = _question.get("options", PackedStringArray())
	_paint_option(answer, GOOD.lightened(0.3), Color(GOOD.r * 0.25, GOOD.g * 0.25, GOOD.b * 0.25, 0.95))
	if not correct and chosen != answer:
		_paint_option(chosen, BAD.lightened(0.3), Color(BAD.r * 0.25, BAD.g * 0.25, BAD.b * 0.25, 0.95))
	_hint_chip.text = ""
	var explanation := str(_question.get("explanation", ""))
	if correct:
		_broken += 1
		_refresh_wards()
		_status.text = "A ward breaks!" if remaining > 0 else "The last ward breaks!"
		_status.add_theme_color_override(&"font_color", GOOD)
		say(explanation, GOOD.lightened(0.5))
	else:
		_status.text = "Zapped! It prints %s" % (options[answer] if answer < options.size() else "?")
		_status.add_theme_color_override(&"font_color", BAD)
		say(explanation, BAD.lightened(0.55))


## A whisper and its detail along the bottom, and maybe one answer struck out.
func show_hint(whisper: String, detail: String, dim_index: int, more: bool) -> void:
	say("%s\n%s" % [whisper, detail], WHISPER)
	if dim_index >= 0 and dim_index < _options.size():
		_dimmed[dim_index] = true
		_paint_option(dim_index, DIMMED, Color(0, 0, 0, 0))
	_hint_chip.text = _hint_key() if more else ""


func set_sparks(count: int) -> void:
	_sparks.count = count
	_sparks.flash()


## A line along the bottom strip. Empty text hides the strip.
func say(text: String, color: Color = SPEECH) -> void:
	_sub_label.text = text
	_sub_label.add_theme_color_override(&"font_color", color)
	_sub.visible = text != ""
	_sub.reset_size()
	_sub.position = Vector2(6.0, 268.0 - _sub.size.y).round()


func dimmed() -> Array:
	return _dimmed.keys()


func status_text() -> String:
	return _status.text


func speech_text() -> String:
	return _sub_label.text if _sub.visible else ""


func _refresh_wards() -> void:
	_wards.text = "Wards %d/%d" % [mini(_broken, _total), _total]


func _paint_option(index: int, text: Color, back: Color) -> void:
	_options[index].add_theme_color_override(&"font_color", text)
	_option_styles[index].bg_color = back


func _hint_key() -> String:
	if TouchControls.active:
		return "?: hint"
	return "Y: hint" if not Input.get_connected_joypads().is_empty() else "H: hint"


func _make_label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## The player's sparks: small flames, lit for each one left.
class _SparkMeter extends Control:
	var count: int = 3:
		set(value):
			count = value
			queue_redraw()
	var tint: Color = Color(1.0, 0.62, 0.3)
	var _flash: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(28.0, 8.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func flash() -> void:
		_flash = 1.0

	func _process(delta: float) -> void:
		if _flash > 0.0:
			_flash = maxf(_flash - delta * 3.0, 0.0)
			queue_redraw()

	func _draw() -> void:
		for index in WizardDuel.SPARKS:
			var x := float(index) * 9.0 + 1.0
			var lit := index < count
			var color := tint if lit else Color(0.28, 0.24, 0.32)
			if lit and _flash > 0.0:
				color = color.lerp(Color.WHITE, _flash)
			draw_rect(Rect2(x + 2.0, 0.0, 2.0, 2.0), color)
			draw_rect(Rect2(x + 1.0, 2.0, 4.0, 3.0), color)
			draw_rect(Rect2(x + 2.0, 5.0, 2.0, 2.0), color.darkened(0.3))
			if lit:
				draw_rect(Rect2(x + 2.0, 3.0, 2.0, 2.0), Color(1.0, 0.95, 0.7))
