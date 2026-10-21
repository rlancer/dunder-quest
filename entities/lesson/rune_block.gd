class_name RuneBlock
extends StaticBody2D

## A stone block that answers a head bump with a lesson. It carries a short
## label (an index, a bucket number, a keyword, an answer letter) and leaves
## the reply to the stage, which listens for `bumped`. A cracked block is a
## spent choice: it goes dark and the stage ignores it.

signal bumped(block: RuneBlock)

const STONE := Color(0.2, 0.15, 0.27)
const STONE_LIGHT := Color(0.32, 0.25, 0.42)
const STONE_DARK := Color(0.1, 0.07, 0.14)

var index: int = 0
var label_text: String = "?"
var tint: Color = Color(0.6, 0.85, 1.0)
## Lit blocks glow steadily, e.g. a vault bucket that holds its key.
var lit: bool = false
var cracked: bool = false
## How wide the label may run; a long label spills past the stone's edges.
var label_width: float = 24.0

var _label: Label
var _rest_y: float = 0.0
var _flash: Color = Color(0, 0, 0, 0)
var _clock: float = 0.0
var _tween: Tween
var _bump_sound: AudioStream = preload("res://assets/audio/bump.wav")


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"head_bump")
	add_to_group(&"rune_block")
	z_index = 2
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16.0, 16.0)
	shape.shape = rect
	add_child(shape)
	_rest_y = position.y
	_label = Label.new()
	_label.add_theme_font_override(&"font", preload("res://assets/fonts/VT323.ttf"))
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.add_theme_constant_override(&"outline_size", 2)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(label_width, 16.0)
	_label.position = Vector2(-label_width * 0.5, -9.0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	set_label(label_text)


func _process(delta: float) -> void:
	_clock += delta
	if _flash.a > 0.0:
		_flash.a = maxf(_flash.a - delta * 2.5, 0.0)
	queue_redraw()


func set_label(text: String) -> void:
	label_text = text
	if _label != null:
		_label.text = text
		var color := tint.lightened(0.5) if not lit else Color(1.0, 0.97, 0.85)
		if cracked:
			color = Color(0.42, 0.38, 0.48)
		_label.add_theme_color_override(&"font_color", color)


func set_lit(on: bool) -> void:
	lit = on
	set_label(label_text)


func set_cracked(on: bool) -> void:
	if on and not cracked:
		Fx.dust(get_parent(), global_position + Vector2(0.0, 6.0), 5)
	cracked = on
	set_label(label_text)


## A short colored pulse: green for right, red for wrong.
func flash(color: Color) -> void:
	_flash = Color(color.r, color.g, color.b, 0.9)


func receive_head_bump() -> void:
	_nudge()
	StageAudio.play(get_tree(), _bump_sound)
	bumped.emit(self)


func dismiss() -> void:
	collision_layer = 0
	hide()


func _nudge() -> void:
	if _tween != null:
		_tween.kill()
	position.y = _rest_y
	_tween = create_tween()
	_tween.tween_property(self, "position:y", _rest_y - 4.0, 0.05)
	_tween.tween_property(self, "position:y", _rest_y, 0.08)


func _draw() -> void:
	var body := Rect2(-8.0, -8.0, 16.0, 16.0)
	draw_rect(body, STONE_DARK)
	draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), STONE)
	draw_rect(Rect2(-7.0, -7.0, 14.0, 1.0), STONE_LIGHT)
	draw_rect(Rect2(-7.0, -7.0, 1.0, 14.0), STONE_LIGHT)
	# The rune border breathes until the block is lit, then holds bright.
	var glow := 0.5 + 0.5 * sin(_clock * 3.2 + float(index))
	var edge := tint
	edge.a = 1.0 if lit else 0.35 + 0.35 * glow
	if cracked:
		edge = Color(0.3, 0.26, 0.34, 0.8)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 1.0), edge)
	draw_rect(Rect2(-8.0, 7.0, 16.0, 1.0), edge)
	draw_rect(Rect2(-8.0, -8.0, 1.0, 16.0), edge)
	draw_rect(Rect2(7.0, -8.0, 1.0, 16.0), edge)
	if lit:
		draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), Color(tint.r, tint.g, tint.b, 0.28))
	if cracked:
		draw_rect(Rect2(-7.0, -7.0, 14.0, 14.0), Color(0.0, 0.0, 0.0, 0.35))
		for crack: Rect2 in [Rect2(-4.0, -6.0, 1.0, 4.0), Rect2(-3.0, -2.0, 3.0, 1.0), Rect2(0.0, -1.0, 1.0, 5.0), Rect2(1.0, 3.0, 3.0, 1.0)]:
			draw_rect(crack, STONE_DARK)
	if _flash.a > 0.0:
		draw_rect(body, _flash)
