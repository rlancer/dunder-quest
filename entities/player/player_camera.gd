class_name PlayerCamera
extends Camera2D

## Keeps the view on the player and clamps it to the stage bounds.


func set_room_limits(bounds: Rect2i) -> void:
	limit_left = bounds.position.x
	limit_top = bounds.position.y
	limit_right = bounds.end.x
	limit_bottom = bounds.end.y
	limit_smoothed = true
	limit_enabled = true


func _process(_delta: float) -> void:
	var body := get_parent() as Node2D
	if body == null:
		return
	# Cancel the parent's fractional pixel so the view stays on the pixel grid.
	position = body.global_position.round() - body.global_position
