extends CharacterBody2D

## Walks a platform, turns at ledges and walls, and dies when stomped.

@export var speed: float = 22.0
@export var ledge_reach: float = 9.0

var direction: float = -1.0
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

var _dead: bool = false
var _tween: Tween
var _sprite_base_y: float = 0.0
var _walk_clock: float = 0.0


func _ready() -> void:
	add_to_group(&"stompable")
	add_to_group(&"copperling")
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50.0)
	var sprite := %Sprite as Sprite2D
	if sprite.texture != null:
		sprite.position.y = -float(sprite.texture.get_height()) * 0.5
	_sprite_base_y = sprite.position.y
	_walk_clock = randf() * 1.0


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		return
	if is_on_floor():
		velocity.y = 0.0
		if _should_turn():
			direction *= -1.0
	else:
		velocity.y += gravity * delta
	velocity.x = direction * speed
	var sprite := %Sprite as Sprite2D
	sprite.scale.x = -1.0 if direction < 0.0 else 1.0
	# Two-step waddle so the beetle reads as walking, not sliding.
	_walk_clock += delta * maxf(speed, 10.0) / 10.0
	sprite.position.y = _sprite_base_y - (1.0 if int(_walk_clock) % 2 == 0 else 0.0)
	move_and_slide()


func receive_stomp() -> void:
	if _dead:
		return
	_dead = true
	remove_from_group(&"stompable")
	set_deferred(&"collision_layer", 0)
	set_deferred(&"collision_mask", 0)
	velocity = Vector2.ZERO
	var sprite := %Sprite as CanvasItem
	var face := signf(sprite.scale.x)
	if is_zero_approx(face):
		face = 1.0
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -5.0), Color(0.95, 0.6, 0.3), 8, 60.0)
	Fx.dust(get_parent(), global_position, 6)
	_tween = create_tween()
	_tween.tween_property(sprite, "scale", Vector2(face * 1.35, 0.35), 0.1)
	_tween.tween_property(sprite, "modulate:a", 0.0, 0.2).set_delay(0.15)
	_tween.tween_callback(queue_free)


func _should_turn() -> bool:
	return _wall_ahead() or not _floor_ahead()


func _floor_ahead() -> bool:
	var from := global_position + Vector2(direction * ledge_reach, -4.0)
	return _ray_hits(from, from + Vector2(0.0, 22.0))


func _wall_ahead() -> bool:
	var from := global_position + Vector2(0.0, -8.0)
	return _ray_hits(from, from + Vector2(direction * 12.0, 0.0))


func _ray_hits(from: Vector2, to: Vector2) -> bool:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()
