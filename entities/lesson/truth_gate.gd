class_name TruthGate
extends StaticBody2D

## A Smelter's Fork gate: a wall of glass bars too tall to jump, standing on
## an `if`. The stage re-checks the condition whenever its dial turns and
## calls `set_open`; while the condition is True the bars sink into the
## floor, and the moment it turns False they rise again.

const HEIGHT := 64.0
const BARS := 3
const OPEN_COLOR := Color(0.5, 0.92, 0.6)
const SHUT_COLOR := Color(1.0, 0.46, 0.4)
const FRAME := Color(0.16, 0.1, 0.18)

var tint: Color = Color(0.7, 0.8, 1.0)

var _open: bool = false
var _slide: float = 0.0
var _shape: CollisionShape2D
var _tween: Tween
var _clock: float = 0.0
var _open_sound: AudioStream = preload("res://assets/audio/goal.wav")
var _shut_sound: AudioStream = preload("res://assets/audio/bump.wav")


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"truth_gate")
	z_index = 1
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	# Taller than any jump, like the wizard's barrier.
	rect.size = Vector2(10.0, 256.0)
	_shape.shape = rect
	_shape.position = Vector2(0.0, -128.0)
	add_child(_shape)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func is_open() -> bool:
	return _open


func set_open(on: bool) -> void:
	if on == _open:
		return
	_open = on
	_shape.set_deferred(&"disabled", on)
	StageAudio.play(get_tree(), _open_sound if on else _shut_sound)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -HEIGHT * 0.5), OPEN_COLOR if on else SHUT_COLOR, 10, 50.0)
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "_slide", 1.0 if on else 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func open_now() -> void:
	_open = true
	_slide = 1.0
	_shape.set_deferred(&"disabled", true)


func dismiss() -> void:
	open_now()


func _draw() -> void:
	# The frame stays; the bars sink into the floor as the gate opens.
	var sink := _slide * HEIGHT
	var state := OPEN_COLOR if _open else SHUT_COLOR
	draw_rect(Rect2(-8.0, -HEIGHT - 4.0, 16.0, 4.0), FRAME)
	var lamp := state
	lamp.a = 0.7 + 0.3 * sin(_clock * 5.0)
	draw_rect(Rect2(-2.0, -HEIGHT - 3.0, 4.0, 2.0), lamp)
	if _slide >= 1.0:
		return
	for bar in BARS:
		var x := -5.0 + float(bar) * 4.0
		var top := -HEIGHT + sink
		var glass := tint
		glass.a = 0.55 + 0.25 * sin(_clock * 3.0 + float(bar))
		draw_rect(Rect2(x, top, 2.0, HEIGHT - sink), glass)
		draw_rect(Rect2(x, top, 1.0, HEIGHT - sink), Color(1.0, 1.0, 1.0, 0.35))
