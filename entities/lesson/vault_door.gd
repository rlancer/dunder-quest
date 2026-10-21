class_name VaultDoor
extends StaticBody2D

## The Cinder Span vault door: a wall of gold bars too tall to jump, with one
## lock per key. Each key stored in its bucket lights a lock; with every lock
## lit the bars slide away.

const HEIGHT := 64.0
const BAR := Color(1.0, 0.78, 0.32)
const BAR_DARK := Color(0.6, 0.4, 0.14)
const LOCK_OFF := Color(0.3, 0.2, 0.26)
const LOCK_ON := Color(0.55, 1.0, 0.7)

var locks: int = 2

var _lit: int = 0
var _open: bool = false
var _slide: float = 0.0
var _shape: CollisionShape2D
var _open_sound: AudioStream = preload("res://assets/audio/goal.wav")


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"vault_door")
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


func is_open() -> bool:
	return _open


func lit_locks() -> int:
	return _lit


func light_lock() -> void:
	_lit = mini(_lit + 1, locks)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -_lock_y(_lit - 1)), LOCK_ON, 10, 50.0)
	queue_redraw()
	if _lit >= locks:
		open()


func open() -> void:
	if _open:
		return
	_open = true
	_shape.set_deferred(&"disabled", true)
	StageAudio.play(get_tree(), _open_sound)
	Fx.float_text(get_parent(), global_position + Vector2(-22.0, -HEIGHT), "Vault open!", BAR.lightened(0.3))
	var tween := create_tween()
	tween.tween_method(_set_slide, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func open_now() -> void:
	_open = true
	_lit = locks
	_shape.set_deferred(&"disabled", true)
	hide()


func dismiss() -> void:
	open_now()


func _set_slide(value: float) -> void:
	_slide = value
	queue_redraw()


func _lock_y(lock: int) -> float:
	return 18.0 + float(lock) * 14.0


func _draw() -> void:
	# The bars sink into the floor as the door opens.
	var sink := _slide * HEIGHT
	for bar in 3:
		var x := -5.0 + float(bar) * 4.0
		var top := -HEIGHT + sink
		draw_rect(Rect2(x, top, 2.0, HEIGHT - sink), BAR)
		draw_rect(Rect2(x + 1.0, top, 1.0, HEIGHT - sink), BAR_DARK)
	if _slide > 0.0:
		return
	draw_rect(Rect2(-7.0, -HEIGHT - 2.0, 14.0, 3.0), BAR_DARK)
	draw_rect(Rect2(-7.0, -HEIGHT - 2.0, 14.0, 1.0), BAR)
	for lock in locks:
		var y := -_lock_y(lock)
		var color := LOCK_ON if lock < _lit else LOCK_OFF
		draw_rect(Rect2(-5.0, y - 4.0, 10.0, 8.0), BAR_DARK)
		draw_rect(Rect2(-4.0, y - 3.0, 8.0, 6.0), color)
		draw_rect(Rect2(-1.0, y - 1.0, 2.0, 3.0), BAR_DARK)
