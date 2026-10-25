class_name PlayerCamera
extends Camera2D

## Keeps the view on the player and clamps it to the stage bounds.
## Leads a little in the running direction and shakes on hits.
## A focus (a duel question) eases the view onto a box and zooms in on it.

const LOOK_AHEAD := 28.0
const LOOK_RATE := 2.2
const FOCUS_ZOOM := 1.25
const FOCUS_IN := 0.5
const FOCUS_OUT := 0.6
## How fast the focus zoom follows a box that grows or shrinks, per second.
const FIT_RATE := 1.0

var _lead: float = 0.0
var _lead_target: float = 0.0
var _trauma: float = 0.0
## 0 is the plain follow view, 1 is fully on the focus box.
var _focus: float = 0.0
var _focused: bool = false
var _focus_tween: Tween
var _focus_center: Vector2 = Vector2.ZERO
var _focus_zoom: float = 1.0


func set_room_limits(bounds: Rect2i) -> void:
	limit_left = bounds.position.x
	limit_top = bounds.position.y
	limit_right = bounds.end.x
	limit_bottom = bounds.end.y
	limit_smoothed = true
	limit_enabled = true


## Called by the player each frame. The lead only moves while running,
## so turning on the spot does not swing the view.
func look_toward(facing: float, running: bool) -> void:
	if running:
		_lead_target = facing * LOOK_AHEAD


func shake(strength: float) -> void:
	_trauma = maxf(_trauma, strength)


## Eases onto `box` (world space) and zooms in, up to FOCUS_ZOOM, as far as
## the box still fits inside `clear`, the part of the screen nothing covers.
## Call it every frame to follow a moving box.
func focus_on(box: Rect2, clear: Rect2) -> void:
	var view := get_viewport_rect().size
	var fit := minf(clear.size.x / maxf(box.size.x, 1.0), clear.size.y / maxf(box.size.y, 1.0))
	var target := clampf(fit, 1.0, FOCUS_ZOOM)
	_focus_zoom = target if not _focused else move_toward(_focus_zoom, target, FIT_RATE * get_process_delta_time())
	# Put the box's middle on the clear part's middle, not the screen's.
	_focus_center = box.get_center() - (clear.get_center() - view * 0.5) / _focus_zoom
	if not _focused:
		_focused = true
		_tween_focus(1.0, FOCUS_IN, Tween.EASE_OUT)


## Eases back to the plain follow view; `snap` drops the focus at once.
func release_focus(snap: bool = false) -> void:
	if snap:
		if _focus_tween != null:
			_focus_tween.kill()
		_focused = false
		_focus = 0.0
		zoom = Vector2.ONE
		return
	if _focused:
		_focused = false
		_tween_focus(0.0, FOCUS_OUT, Tween.EASE_IN_OUT)


func reset_lead() -> void:
	_lead = 0.0
	_lead_target = 0.0
	_trauma = 0.0
	offset = Vector2.ZERO
	release_focus(true)


func _tween_focus(to: float, seconds: float, ease_type: Tween.EaseType) -> void:
	if _focus_tween != null:
		_focus_tween.kill()
	_focus_tween = create_tween()
	_focus_tween.tween_property(self, "_focus", to, seconds).set_trans(Tween.TRANS_SINE).set_ease(ease_type)


func _process(delta: float) -> void:
	var body := get_parent() as Node2D
	if body == null:
		return
	# Cancel the parent's fractional pixel so the view stays on the pixel grid.
	position = body.global_position.round() - body.global_position
	if _focus > 0.0:
		position += (_focus_center - body.global_position.round()) * _focus
	zoom = Vector2.ONE * lerpf(1.0, _focus_zoom, _focus)
	_lead = move_toward(_lead, _lead_target, LOOK_AHEAD * LOOK_RATE * delta)
	var jitter := Vector2.ZERO
	if _trauma > 0.0:
		jitter = Vector2(randf_range(-_trauma, _trauma), randf_range(-_trauma, _trauma))
		_trauma = maxf(_trauma - 18.0 * delta, 0.0)
	offset = (Vector2(_lead * (1.0 - _focus), 0.0) + jitter).round()
