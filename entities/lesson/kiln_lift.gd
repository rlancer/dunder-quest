class_name KilnLift
extends AnimatableBody2D

## Kiln Mouth's lift: an iron plate at the foot of the kiln wall that runs a
## for loop. A forge block loads it with a range; stepping on the plate runs
## the loop, and every lap raises it one notch with the value of i floating
## off it. At the top it holds while it is ridden, then sinks back to the
## floor once left alone, waiting if anyone stands in the pit beneath it.
## Loading a new loop sinks it first.
## Resets when the stage puts the player back at a lantern.

signal ran(laps: int)

const WIDTH := 32.0
const THICK := 16.0
const LAP_RISE := 24.0
const LAP_TIME := 0.32
const LAP_PAUSE := 0.14
const SINK_SPEED := 160.0
## How long the plate waits, unridden at the top, before it sinks.
const IDLE_SINK := 0.9
const IRON := Color(0.32, 0.27, 0.3)
const IRON_LIGHT := Color(0.52, 0.45, 0.46)
const IRON_DARK := Color(0.14, 0.1, 0.13)
const CHAIN := Color(0.4, 0.36, 0.4)

enum State { REST, RUNNING, TOP, SINKING }

var tint: Color = Color(0.5, 1.0, 0.65)
## The values the loaded loop hands to i, in order. Empty when nothing is loaded.
var values: Array[int] = []
var state: State = State.REST

var _origin: Vector2 = Vector2.ZERO
var _rise: float = 0.0
var _target: float = 0.0
var _lap: int = 0
var _beat: float = 0.0
var _idle: float = 0.0
var _hinted: bool = false
var _clank: AudioStream = preload("res://assets/audio/bump.wav")


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"kiln_lift")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	process_physics_priority = -1
	z_index = 1
	_origin = global_position
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, THICK)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, THICK * 0.5)
	add_child(collision)


## Loads a loop. A raised plate sinks first; the next ride runs it.
func load_loop(loop_values: Array[int]) -> void:
	values = loop_values.duplicate()
	_hinted = false
	if state != State.REST:
		state = State.SINKING


func laps() -> int:
	return values.size()


func height() -> float:
	return _rise


func is_topped() -> bool:
	return state == State.TOP


func reset_piece() -> void:
	state = State.REST
	_rise = 0.0
	_lap = 0
	global_position = _origin


func _physics_process(delta: float) -> void:
	match state:
		State.REST:
			if _ridden():
				if values.is_empty():
					if not _hinted:
						_hinted = true
						Fx.float_text(get_parent(), global_position + Vector2(-44.0, -20.0), "Load a loop at a forge", tint.lightened(0.3))
				else:
					state = State.RUNNING
					_lap = 0
					_beat = LAP_PAUSE
					_target = 0.0
		State.RUNNING:
			if _rise < _target:
				_rise = minf(_rise + LAP_RISE / LAP_TIME * delta, _target)
			else:
				_beat -= delta
				if _beat <= 0.0:
					if _lap >= values.size():
						state = State.TOP
						_idle = 0.0
						ran.emit(values.size())
					else:
						_start_lap()
		State.TOP:
			_idle = 0.0 if _ridden() else _idle + delta
			if _idle >= IDLE_SINK:
				state = State.SINKING
		State.SINKING:
			if not _blocked_below():
				_rise = maxf(_rise - SINK_SPEED * delta, 0.0)
			if _rise <= 0.0:
				state = State.REST
	global_position = _origin + Vector2(0.0, -_rise)


func _start_lap() -> void:
	_target = LAP_RISE * float(_lap + 1)
	_beat = LAP_PAUSE
	StageAudio.play(get_tree(), _clank)
	Fx.float_text(get_parent(), global_position + Vector2(18.0, -6.0), "i=%d" % values[_lap], tint.lightened(0.4))
	Fx.dust(get_parent(), global_position + Vector2(0.0, THICK), 3)
	_lap += 1


## Someone standing under the raised plate, in the pit it sinks into.
func _blocked_below() -> bool:
	var body := get_tree().get_first_node_in_group(&"player") as Node2D
	if body == null:
		return false
	var under := body.global_position.y - 10.0 > global_position.y + THICK - 2.0
	return under and absf(body.global_position.x - global_position.x) < WIDTH * 0.5 + 6.0


func _ridden() -> bool:
	var body := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if body == null or not body.is_on_floor():
		return false
	var feet := body.global_position.y + 8.0
	if absf(feet - global_position.y) > 4.0:
		return false
	return absf(body.global_position.x - global_position.x) <= WIDTH * 0.5 + 4.0


func _process(_delta: float) -> void:
	queue_redraw()


## An iron plate with rivets and a glowing lap counter, on two chains that
## run up out of sight.
func _draw() -> void:
	var half := WIDTH * 0.5
	for side: float in [-half + 4.0, half - 5.0]:
		var link := -_rise - 64.0
		while link < 0.0:
			draw_rect(Rect2(side, link, 1.0, 3.0), CHAIN)
			draw_rect(Rect2(side - 1.0, link + 3.0, 3.0, 1.0), CHAIN.darkened(0.3))
			link += 5.0
	draw_rect(Rect2(-half, 0.0, WIDTH, THICK), IRON_DARK)
	draw_rect(Rect2(-half + 1.0, 1.0, WIDTH - 2.0, THICK - 2.0), IRON)
	draw_rect(Rect2(-half + 1.0, 1.0, WIDTH - 2.0, 1.0), IRON_LIGHT)
	for x: float in [-half + 3.0, half - 4.0]:
		for y: float in [4.0, THICK - 4.0]:
			draw_rect(Rect2(x, y, 1.0, 1.0), IRON_LIGHT)
	# One lamp per lap of the loaded loop, lit as the laps run.
	var count := values.size()
	for index in count:
		var lit := state != State.REST and index < _lap
		var lamp := tint if lit else Color(0.24, 0.2, 0.24)
		draw_rect(Rect2(-float(count) * 2.5 + float(index) * 5.0 + 1.0, 7.0, 3.0, 3.0), lamp)
