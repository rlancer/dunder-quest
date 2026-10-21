class_name RuneKey
extends Area2D

## A key on the route, named by a string. The Cinder Span vault stores each
## key in the bucket its rune hash picks, so the player learns to read
## hash(key) % buckets before reaching the door.

signal collected(key: RuneKey)

const BUCKETS := 4
const METAL := Color(1.0, 0.8, 0.36)
const METAL_DARK := Color(0.72, 0.46, 0.16)

var key_name: String = "ash"
var taken: bool = false

var _clock: float = 0.0
var _tag: Label
var _sound: AudioStream = preload("res://assets/audio/goal.wav")


## The vault's hash: the sum of the letter codes. Python's own str hash is
## salted per run, but the bucket rule, hash % buckets, is the same.
static func rune_hash(text: String) -> int:
	var total := 0
	for index in text.length():
		total += text.unicode_at(index)
	return total


func bucket() -> int:
	return rune_hash(key_name) % BUCKETS


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"rune_key")
	z_index = 4
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14.0, 96.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -40.0)
	add_child(shape)
	_tag = Label.new()
	_tag.text = "\"%s\"" % key_name
	_tag.add_theme_font_size_override(&"font_size", 10)
	_tag.add_theme_color_override(&"font_color", METAL.lightened(0.4))
	_tag.add_theme_constant_override(&"outline_size", 3)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.size = Vector2(60.0, 12.0)
	_tag.position = Vector2(-30.0, -32.0)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tag)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func take() -> void:
	if taken:
		return
	taken = true
	set_deferred(&"monitoring", false)
	StageAudio.play(get_tree(), _sound)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -8.0), METAL, 16, 80.0)
	queue_free()


func dismiss() -> void:
	set_deferred(&"monitoring", false)
	hide()


func _draw() -> void:
	var bob := roundf(sin(_clock * 3.0) * 1.5)
	var o := Vector2(0.0, -10.0 + bob)
	draw_circle(o + Vector2(0.0, 0.0), 9.0, Color(METAL.r, METAL.g, METAL.b, 0.12 + 0.06 * sin(_clock * 4.0)))
	# Bow: a ring with a hole.
	draw_rect(Rect2(o.x - 7.0, o.y - 3.0, 6.0, 6.0), METAL)
	draw_rect(Rect2(o.x - 5.0, o.y - 1.0, 2.0, 2.0), Color(0.1, 0.06, 0.1))
	# Shaft and teeth.
	draw_rect(Rect2(o.x - 1.0, o.y - 1.0, 8.0, 2.0), METAL)
	draw_rect(Rect2(o.x + 3.0, o.y + 1.0, 1.0, 2.0), METAL_DARK)
	draw_rect(Rect2(o.x + 6.0, o.y + 1.0, 1.0, 3.0), METAL_DARK)
	draw_rect(Rect2(o.x - 7.0, o.y - 3.0, 6.0, 1.0), METAL.lightened(0.4))


func _on_body_entered(body: Node2D) -> void:
	if taken or not body.is_in_group(&"player"):
		return
	collected.emit(self)
