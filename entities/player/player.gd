class_name PlayerBody
extends CharacterBody2D

## Side-view platformer controller.
## Coyote time, jump buffering, variable jump height, and pixel snapping.
## A held jump hangs a moment at its apex; let go and the fall pulls harder,
## so holding always carries at least as far as a plain arc and releasing
## drops quickly. Falls top out at a terminal speed, and a rise that clips a
## ledge corner slides around it (never around a block made to be bumped).

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
## A stomp with jump held springs this high instead.
@export var stomp_bounce_held_velocity: float = -400.0
@export var fall_gravity_multiplier: float = 1.3
@export var apex_gravity_multiplier: float = 0.5
## Below this vertical speed, with jump held, the body is at its apex.
@export var apex_threshold: float = 60.0
@export var max_fall_speed: float = 440.0
## How far a rise may slide sideways to clear a ledge corner, in pixels.
@export var corner_correction: int = 5
## How long a knock from a spell or a wizard takes the controls away.
@export var knock_time: float = 0.3
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
var _knock_timer: float = 0.0
## Game time spent running on the ground, for the run bob.
var _bob_time: float = 0.0
## Easter eggs (see `Eggs`): quick turns on the ground for the silly walk,
## and whether a copperling has sent the pebble running yet.
var _silly_turns: int = 0
var _silly_window: float = 0.0
var _silly_last: float = 0.0
var _silly_done: bool = false
var _ran_away: bool = false


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
		velocity.y = minf(velocity.y + _gravity_now() * delta, max_fall_speed)
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	_knock_timer = maxf(_knock_timer - delta, 0.0)

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
	if controls_enabled and _knock_timer <= 0.0:
		direction = Input.get_axis(&"move_left", &"move_right")
	var target_speed := direction * speed
	var rate := acceleration if direction != 0.0 else (friction if is_on_floor() else air_resistance)
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)
	if direction > 0.0:
		_facing = 1.0
	elif direction < 0.0:
		_facing = -1.0
	_watch_silly_walk(delta, direction)

	var fall_speed := velocity.y
	if velocity.y < 0.0:
		_slip_past_corner(delta)
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


func _process(delta: float) -> void:
	if _dead:
		return
	var bob := 0.0
	if is_on_floor() and absf(velocity.x) > 20.0:
		if int(_bob_time / 0.14) % 2 == 0:
			bob = -1.0
		_bob_time += delta
	else:
		_bob_time = 0.0
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


## Knocked back by a spell or a wizard: a shove, and a beat without controls.
func knock(push: Vector2) -> void:
	if _dead:
		return
	velocity = push
	_knock_timer = knock_time
	jump_buffer_timer = 0.0
	camera.shake(3.0)


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
			velocity.y = stomp_bounce_held_velocity if Input.is_action_pressed(&"jump") and controls_enabled else stomp_bounce_velocity
			StageAudio.play(get_tree(), stomp_sound)
			_play_squash(1.2, 0.78)
			camera.shake(2.0)
			Fx.hitstop(get_tree(), 0.05)
	if not controls_enabled:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var collider := collision.get_collider() as Node
		if collider == null or collider in stomped:
			continue
		if collider.is_in_group(&"stompable"):
			if collider.is_in_group(&"copperling") and not _ran_away and not _respawn_locked:
				_ran_away = true
				Fx.float_text(get_parent(), global_position + Vector2(-30.0, -8.0), Eggs.RUN_AWAY)
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


## A held jump floats for a moment at the top of its arc and falls at the
## plain rate; without jump held, a fall pulls harder.
func _gravity_now() -> float:
	var held := controls_enabled and Input.is_action_pressed(&"jump")
	if held and absf(velocity.y) < apex_threshold:
		return gravity * apex_gravity_multiplier
	if velocity.y > 0.0 and not held:
		return gravity * fall_gravity_multiplier
	return gravity


## A rise that would clip the corner of a ledge by a few pixels slides around
## it instead of stopping dead. Blocks that answer a head bump are left alone,
## so a bump always lands on the block the player aimed at.
func _slip_past_corner(delta: float) -> void:
	var rise := Vector2(0.0, velocity.y * delta)
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, rise, hit):
		return
	var collider := hit.get_collider() as Node
	if collider != null and collider.is_in_group(&"head_bump"):
		return
	var lean := signf(velocity.x)
	for nudge in range(1, corner_correction + 1):
		for side: float in [lean if lean != 0.0 else -1.0, -lean if lean != 0.0 else 1.0]:
			var shift := Vector2(side * float(nudge), 0.0)
			if test_move(global_transform, shift):
				continue
			if not test_move(global_transform.translated(shift), rise):
				global_position += shift
				return


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


## Six turns on the ground, each within 0.6 s of the last, is a silly walk.
## Once a stage.
func _watch_silly_walk(delta: float, direction: float) -> void:
	if _silly_done:
		return
	_silly_window = maxf(_silly_window - delta, 0.0)
	if _silly_window <= 0.0:
		_silly_turns = 0
	if direction == 0.0 or not is_on_floor():
		return
	var side := signf(direction)
	if _silly_last != 0.0 and side != _silly_last:
		_silly_turns += 1
		_silly_window = 0.6
		if _silly_turns >= 6:
			_silly_done = true
			Fx.float_text(get_parent(), global_position + Vector2(-28.0, -8.0), Eggs.SILLY_WALK)
	_silly_last = side


func _play_squash(wide: float, tall: float) -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(visual, "scale", Vector2(wide, tall), 0.06)
	_squash_tween.tween_property(visual, "scale", Vector2.ONE, 0.1)
