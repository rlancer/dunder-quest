class_name PlayerCamera
extends Camera2D

## Keeps the view on the player and clamps it to the stage bounds.
## Leads a little in the running direction and shakes on hits.

const LOOK_AHEAD := 28.0
const LOOK_RATE := 2.2

var _lead: float = 0.0
var _lead_target: float = 0.0
var _trauma: float = 0.0


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


func reset_lead() -> void:
	_lead = 0.0
	_lead_target = 0.0
	_trauma = 0.0
	offset = Vector2.ZERO


func _process(delta: float) -> void:
	var body := get_parent() as Node2D
	if body == null:
		return
	# Cancel the parent's fractional pixel so the view stays on the pixel grid.
	position = body.global_position.round() - body.global_position
	_lead = move_toward(_lead, _lead_target, LOOK_AHEAD * LOOK_RATE * delta)
	var jitter := Vector2.ZERO
	if _trauma > 0.0:
		jitter = Vector2(randf_range(-_trauma, _trauma), randf_range(-_trauma, _trauma))
		_trauma = maxf(_trauma - 18.0 * delta, 0.0)
	offset = (Vector2(_lead, 0.0) + jitter).round()
