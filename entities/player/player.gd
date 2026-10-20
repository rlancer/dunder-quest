class_name PlayerBody
extends CharacterBody2D

## Side-view platformer controller.
## Coyote time, jump buffering, variable jump height, and pixel snapping.

signal respawn_requested

@export var speed: float = 180.0
@export var jump_velocity: float = -460.0
@export var acceleration: float = 1400.0
@export var friction: float = 1600.0
@export var air_resistance: float = 400.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15
@export var jump_cut_multiplier: float = 0.45
@export var stomp_bounce_velocity: float = -260.0
@export var jump_sound: AudioStream
@export var stomp_sound: AudioStream

@onready var visual: Node2D = %Visual
@onready var sprite: Sprite2D = %Sprite
@onready var camera: PlayerCamera = %Camera

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var controls_enabled: bool = true

var _sprite_base_y: float = -4.0
var _was_on_floor: bool = false
var _respawn_locked: bool = false
var _squash_tween: Tween
var _death_tween: Tween
var _facing: float = 1.0
var _step_timer: float = 0.0
var _dead: bool = false


func _ready() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 8.0
	floor_max_angle = deg_to_rad(50.0)
	floor_block_on_wall = false
	add_to_group(&"player")
	if sprite.texture != null:
		_sprite_base_y = 8.0 - float(sprite.texture.get_height()) * 0.5
	sprite.position.y = _sprite_base_y


func _exit_tree() -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	if _death_tween != null:
		_death_tween.kill()


func _physics_process(delta: float) -> void:
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0

	if is_on_floor():
		coyote_timer = coyote_time
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		velocity.y += gravity * delta
		coyote_timer = maxf(coyote_timer - delta, 0.0)

	if controls_enabled and Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)

	var jumped := false
	if controls_enabled and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		jumped = true
		StageAudio.play(get_tree(), jump_sound)
		_play_squash(0.82, 1.16)
		Fx.dust(get_parent(), global_position + Vector2(0.0, 8.0), 5)

	if controls_enabled and Input.is_action_just_released(&"jump") and not Input.is_action_just_pressed(&"jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var direction := 0.0
	if controls_enabled:
		direction = Input.get_axis(&"move_left", &"move_right")
	var target_speed := direction * speed
	var rate := acceleration if direction != 0.0 else (friction if is_on_floor() else air_resistance)
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if direction > 0.0:
		_facing = 1.0
	elif direction < 0.0:
		_facing = -1.0

	var fall_speed := velocity.y
	var collided := move_and_slide()
	if is_on_floor() and not _was_on_floor and not jumped:
		if fall_speed > 220.0:
			_play_squash(1.16, 0.82)
		if fall_speed > 120.0:
			Fx.dust(get_parent(), global_position + Vector2(0.0, 8.0), 7)
	_kick_up_steps(delta, direction)
	_was_on_floor = is_on_floor()
	if is_on_ceiling() and velocity.y < 0.0:
		velocity.y = 0.0
	if collided:
		_handle_contacts()


func _process(_delta: float) -> void:
	if _dead:
		return
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 20.0 and int(Time.get_ticks_msec() / 140) % 2 == 0:
		bob = -1.0
	sprite.position = Vector2(0.0, _sprite_base_y + bob)
	# Stretch along the fall or rise so airtime reads at a glance.
	var stretch := 0.0
	if not is_on_floor():
		stretch = clampf(absf(velocity.y) / 900.0, 0.0, 0.14)
	sprite.scale = Vector2(_facing * (1.0 - stretch * 0.6), 1.0 + stretch)
	visual.position = global_position.round() - global_position
	camera.look_toward(_facing, absf(velocity.x) > 40.0)


## Freezes the body and plays the knocked-out hop. The stage moves it home after.
func play_death() -> void:
	_dead = true
	controls_enabled = false
	jump_buffer_timer = 0.0
	velocity = Vector2.ZERO
	# Physics stops, but the collision layer stays: toggling it makes the fall
	# zone report a fresh entry once the body is already back at the spawn.
	set_physics_process(false)
	camera.shake(5.0)
	if _squash_tween != null:
		_squash_tween.kill()
	visual.scale = Vector2.ONE
	sprite.scale = Vector2(_facing, -1.0)
	sprite.modulate = Color(1.0, 0.7, 0.6)
	if _death_tween != null:
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(sprite, "position:y", _sprite_base_y - 22.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_death_tween.tween_property(sprite, "position:y", _sprite_base_y + 160.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func revive() -> void:
	if _death_tween != null:
		_death_tween.kill()
	_dead = false
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2(_facing, 1.0)
	sprite.position = Vector2(0.0, _sprite_base_y)
	velocity = Vector2.ZERO
	set_physics_process(true)
	controls_enabled = true
	_was_on_floor = false


func is_dead() -> bool:
	return _dead


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		jump_buffer_timer = 0.0


func set_camera_bounds(bounds: Rect2i) -> void:
	camera.set_room_limits(bounds)


func reset_camera() -> void:
	camera.reset_lead()
	camera.reset_smoothing()
	camera.force_update_scroll()


func release_respawn_lock() -> void:
	_respawn_locked = false


func _handle_contacts() -> void:
	var stomped: Array[Node] = []
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		if collider.is_in_group(&"head_bump") and collision.get_normal().y > 0.5:
			collider.call(&"receive_head_bump")
		if collider.is_in_group(&"stompable") and _is_stomp(collision, collider):
			collider.call(&"receive_stomp")
			stomped.append(collider)
			velocity.y = stomp_bounce_velocity
			StageAudio.play(get_tree(), stomp_sound)
			_play_squash(1.2, 0.78)
			camera.shake(2.0)
	if not controls_enabled:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider == null or collider in stomped:
			continue
		if collider.is_in_group(&"stompable"):
			_ask_respawn()
			return


func _is_stomp(collision: KinematicCollision2D, collider: Node) -> bool:
	var enemy := collider as Node2D
	if enemy == null:
		return false
	if absf(global_position.x - enemy.global_position.x) > 28.0:
		return false
	var feet := global_position.y + 8.0
	var above_enemy := feet < enemy.global_position.y - 2.0
	if velocity.y > 20.0 or above_enemy:
		if collision.get_normal().y < -0.15 or above_enemy or velocity.y > 20.0:
			return true
	return false


func _ask_respawn() -> void:
	if _respawn_locked or not controls_enabled:
		return
	_respawn_locked = true
	respawn_requested.emit()


func _kick_up_steps(delta: float, direction: float) -> void:
	if not is_on_floor() or absf(velocity.x) < 120.0:
		_step_timer = 0.0
		return
	_step_timer -= delta
	# A skid puff when reversing, otherwise a light footfall every few steps.
	var skidding := direction != 0.0 and signf(direction) != signf(velocity.x)
	if _step_timer <= 0.0 or skidding:
		_step_timer = 0.09 if skidding else 0.28
		Fx.dust(get_parent(), global_position + Vector2(-signf(velocity.x) * 4.0, 8.0), 2 if not skidding else 4, -signf(velocity.x))


func _play_squash(wide: float, tall: float) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(wide, tall), 0.06)
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.1)
