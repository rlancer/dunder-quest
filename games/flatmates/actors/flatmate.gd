class_name Flatmate
extends CharacterBody2D

## One of the two flatmates. While the player is in his head he runs and
## jumps on the controls (with the first game's feel: coyote time, a jump
## buffer, a hang at the apex and a cut on release). The rest of the time he
## works through his to-do list, one step at a time, which is what the
## scripts fill: every method call adds a step and hands back a promise that
## settles when the step is done. Taking over pauses the list; it carries on
## from the same step when the player swaps out again.
##
## Clive jumps low and can't carry a tune. Jazz jumps high and has a guitar.

signal fell

const TILE := 16.0
## Inner-voice lines and speech last this long on screen, plus a beat per word.
const SAY_TIME := 1.2
## A walk that makes no headway for this long gives up (he hit a wall).
const STUCK_TIME := 0.35
## How close counts as "at" something, for reach() and press().
const NEAR := 14.0

@export var who: String = "clive"
@export var speed: float = 150.0
@export var jump_velocity: float = -330.0
@export var acceleration: float = 1300.0
@export var friction: float = 1600.0
@export var air_resistance: float = 420.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15
@export var jump_cut_multiplier: float = 0.45
@export var fall_gravity_multiplier: float = 1.3
@export var apex_gravity_multiplier: float = 0.5
@export var apex_threshold: float = 60.0
@export var max_fall_speed: float = 440.0
@export var corner_correction: int = 5
@export var sheet: Texture2D
@export var jump_sound: AudioStream
@export var strum_sound: AudioStream

## True while the player is in this flatmate's head.
var active: bool = false
## The stage, for press() and strum() and for looking things up by name.
var stage: Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote: float = 0.0
var _buffer: float = 0.0
var _facing: float = 1.0
var _was_on_floor: bool = false
var _bob_time: float = 0.0
var _visual: Node2D
var _sprite: Sprite2D
var _squash: Tween
## The to-do list: {kind, arg, promise}. The head is the step in progress.
var _steps: Array[Dictionary] = []
var _step_started: bool = false
var _step_time: float = 0.0
var _walk_target: float = 0.0
var _last_x: float = 0.0
var _stuck: float = 0.0
var _left_floor: bool = false
var _pose_time: float = 0.0
var _pose: int = -1
var _frozen: bool = false
## reach() calls waiting for him to get somewhere: {target, promise}.
var _reaching: Array[Dictionary] = []

const FRAME_IDLE := 0
const FRAME_WALK := 1
const FRAME_JUMP := 3
const FRAME_STRUM := 4
const FRAME_PRESS := 5
const FRAMES := 6


func _ready() -> void:
	motion_mode = MOTION_MODE_GROUNDED
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50.0)
	collision_layer = 2
	collision_mask = 1
	add_to_group(&"flatmate")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10.0, 20.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -2.0)
	add_child(shape)
	_visual = Node2D.new()
	add_child(_visual)
	_sprite = Sprite2D.new()
	_sprite.texture = sheet
	_sprite.hframes = FRAMES
	_sprite.position = Vector2(0.0, -4.0)
	_visual.add_child(_sprite)
	z_index = 5


func set_active(on: bool) -> void:
	active = on
	_buffer = 0.0
	_step_started = false


## Puts him down at `at`, standing still, his list emptied.
func place(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	_frozen = false
	_sprite.modulate = Color.WHITE
	clear_steps()


func clear_steps() -> void:
	for step in _steps:
		(step["promise"] as JsPromise).resolve()
	_steps.clear()
	for wait in _reaching:
		(wait["promise"] as JsPromise).resolve()
	_reaching.clear()
	_step_started = false
	_pose = -1


func is_busy() -> bool:
	return not _steps.is_empty()


func freeze(on: bool) -> void:
	_frozen = on
	if on:
		velocity = Vector2.ZERO


func facing() -> float:
	return _facing


# --- The script side --------------------------------------------------------

func js_label() -> String:
	return who.capitalize()


func js_methods() -> PackedStringArray:
	var methods := PackedStringArray(["walk", "jump", "press", "say", "wait", "reach"])
	if who == "jazz":
		methods.append("strum")
	return methods


func js_call(method: String, args: Array) -> Variant:
	match method:
		"walk":
			if args.is_empty() or not (args[0] is int or args[0] is float):
				return JsError.make("TypeError", "%s.walk() needs a number of steps" % who)
			return _add_step("walk", args[0])
		"wait":
			return _add_step("wait", float(args[0]) if not args.is_empty() else 0.0)
		"say":
			return _add_step("say", JsRunner.text_of(args[0]) if not args.is_empty() else "")
		"reach":
			if args.is_empty() or not args[0] is Node2D:
				return JsError.make("TypeError", "%s.reach() needs somewhere to go" % who)
			return _reach(args[0])
		_:
			return _add_step(method, args[0] if not args.is_empty() else null)


func js_get(prop: String) -> Variant:
	match prop:
		"name":
			return who.capitalize()
		"x":
			return int(floor(global_position.x / TILE))
	return null


func _add_step(kind: String, arg: Variant) -> JsPromise:
	var promise := JsPromise.new()
	_steps.append({"kind": kind, "arg": arg, "promise": promise})
	return promise


## Settles once he stands at `target`. Played by the player, he waits for
## them to walk him there; otherwise it's a step on his list: walk to it.
func _reach(target: Node2D) -> JsPromise:
	if active:
		var promise := JsPromise.new()
		_reaching.append({"target": target, "promise": promise})
		return promise
	return _add_step("reach", target)


# --- Movement ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _frozen:
		return
	if is_on_floor():
		_coyote = coyote_time
		if velocity.y > 0.0:
			velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + _gravity_now() * delta, max_fall_speed)
		_coyote = maxf(_coyote - delta, 0.0)

	var direction := 0.0
	var jump_now := false
	if active:
		if Input.is_action_just_pressed(&"jump"):
			_buffer = jump_buffer_time
		else:
			_buffer = maxf(_buffer - delta, 0.0)
		jump_now = _buffer > 0.0 and _coyote > 0.0
		direction = Input.get_axis(&"move_left", &"move_right")
		if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
			velocity.y *= jump_cut_multiplier
	else:
		var drive := _run_step(delta)
		direction = drive.x
		jump_now = drive.y > 0.0 and _coyote > 0.0

	if jump_now:
		velocity.y = jump_velocity
		_buffer = 0.0
		_coyote = 0.0
		StageAudio.play(get_tree(), jump_sound)
		_play_squash(0.82, 1.16)
		Fx.dust(get_parent(), global_position + Vector2(0.0, 8.0), 5)

	var rate := acceleration if direction != 0.0 else (friction if is_on_floor() else air_resistance)
	velocity.x = move_toward(velocity.x, direction * speed, rate * delta)
	if direction != 0.0:
		_facing = signf(direction)
	var fall_speed := velocity.y
	if velocity.y < 0.0:
		_slip_past_corner(delta)
	move_and_slide()
	if is_on_floor() and not _was_on_floor and fall_speed > 160.0:
		_play_squash(1.14, 0.84)
		Fx.dust(get_parent(), global_position + Vector2(0.0, 8.0), 6)
	_was_on_floor = is_on_floor()
	_check_reaching()


## Works on the step at the head of the list. Returns (direction, jump).
func _run_step(delta: float) -> Vector2:
	if _steps.is_empty():
		return Vector2.ZERO
	var step: Dictionary = _steps[0]
	var kind := str(step["kind"])
	if not _step_started:
		_step_started = true
		_step_time = 0.0
		_stuck = 0.0
		_last_x = global_position.x
		_left_floor = false
		_begin(step)
	_step_time += delta
	match kind:
		"walk", "reach":
			var gap := _walk_target - global_position.x
			if absf(gap) <= 2.0:
				velocity.x = 0.0
				global_position.x = _walk_target
				_finish()
				return Vector2.ZERO
			if absf(global_position.x - _last_x) < 0.4:
				_stuck += delta
			else:
				_stuck = 0.0
			_last_x = global_position.x
			if _stuck >= STUCK_TIME and is_on_floor():
				_finish()
				return Vector2.ZERO
			# Ease in over the last few pixels so he stops on the tile.
			return Vector2(signf(gap) * clampf(absf(gap) / 10.0, 0.35, 1.0), 0.0)
		"jump":
			if not is_on_floor():
				_left_floor = true
			if _left_floor and is_on_floor():
				# Landed: settle onto the middle of the tile underfoot.
				step["kind"] = "walk"
				_walk_target = floorf(global_position.x / TILE) * TILE + TILE * 0.5
				_stuck = 0.0
				return Vector2.ZERO
			if _step_time > 2.0:
				_finish()
				return Vector2.ZERO
			return Vector2(_facing, 1.0 if not _left_floor else 0.0)
		"wait":
			if _step_time * 1000.0 >= float(step["arg"]):
				_finish()
		"say", "press", "strum":
			if _step_time >= float(step.get("hold", 0.35)):
				_finish()
		_:
			_finish()
	return Vector2.ZERO


func _begin(step: Dictionary) -> void:
	var kind := str(step["kind"])
	match kind:
		"walk":
			var tiles := int(step["arg"])
			var from := floorf(global_position.x / TILE) * TILE + TILE * 0.5
			_walk_target = from + float(tiles) * TILE
			if tiles != 0:
				_facing = signf(float(tiles))
		"reach":
			var target := step["arg"] as Node2D
			_walk_target = target.global_position.x if is_instance_valid(target) else global_position.x
		"say":
			var text := str(step["arg"])
			step["hold"] = SAY_TIME + 0.15 * text.split(" ").size()
			if stage != null:
				stage.call(&"speech", self, text)
		"press":
			_pose = FRAME_PRESS
			_pose_time = 0.3
			step["hold"] = 0.35
			if stage != null:
				stage.call(&"press_at", self)
		"strum":
			_pose = FRAME_STRUM
			_pose_time = 0.45
			step["hold"] = 0.5
			StageAudio.play(get_tree(), strum_sound)
			if stage != null:
				stage.call(&"strum_at", self)


func _finish() -> void:
	if _steps.is_empty():
		return
	var step: Dictionary = _steps.pop_front()
	_step_started = false
	(step["promise"] as JsPromise).resolve()


func _check_reaching() -> void:
	# Collect first: settling a promise can run a script that changes the list.
	var arrived: Array[JsPromise] = []
	for index in range(_reaching.size() - 1, -1, -1):
		var wait: Dictionary = _reaching[index]
		var target := wait["target"] as Node2D
		if not is_instance_valid(target) or is_at(target):
			_reaching.remove_at(index)
			arrived.append(wait["promise"])
	for promise in arrived:
		promise.resolve()


## Played by the player, a step waits; this counts it as done the moment he
## gets there himself.
func is_at(target: Node2D) -> bool:
	return absf(target.global_position.x - global_position.x) <= NEAR and absf(target.global_position.y - global_position.y) <= 24.0


func _gravity_now() -> float:
	var held := (active and Input.is_action_pressed(&"jump")) or (not active and not _steps.is_empty() and str(_steps[0]["kind"]) == "jump")
	if held and absf(velocity.y) < apex_threshold:
		return gravity * apex_gravity_multiplier
	if velocity.y > 0.0 and not held:
		return gravity * fall_gravity_multiplier
	return gravity


func _slip_past_corner(delta: float) -> void:
	var rise := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, rise):
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


# --- Looks ------------------------------------------------------------------

func _process(delta: float) -> void:
	if _sprite == null or _frozen:
		return
	var frame := FRAME_IDLE
	var bob := 0.0
	if not is_on_floor():
		frame = FRAME_JUMP
	elif absf(velocity.x) > 20.0:
		_bob_time += delta
		frame = FRAME_WALK + int(_bob_time / 0.14) % 2
		bob = -1.0 if frame == FRAME_WALK else 0.0
	else:
		_bob_time = 0.0
	if _pose >= 0:
		_pose_time -= delta
		frame = _pose
		if _pose_time <= 0.0:
			_pose = -1
	_sprite.frame = frame
	_sprite.flip_h = _facing < 0.0
	_sprite.position = Vector2(0.0, -4.0 + bob)
	_visual.position = global_position.round() - global_position


func _play_squash(wide: float, tall: float) -> void:
	if _squash != null:
		_squash.kill()
	_squash = create_tween()
	_squash.tween_property(_visual, "scale", Vector2(wide, tall), 0.06)
	_squash.tween_property(_visual, "scale", Vector2.ONE, 0.1)


## The fall: a hop and a drop off the bottom, then the stage puts him back.
func play_fall() -> void:
	freeze(true)
	clear_steps()
	_sprite.modulate = Color(1.0, 0.75, 0.7)
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", -26.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", 150.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	fell.emit()
