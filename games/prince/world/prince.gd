class_name Prince
extends Node2D

## The Prince: runs, jumps, dies. He moves on the room's tile grid with his
## own box collision (no physics engine), so every run plays out the same
## and the bot's jumps land where a player's would.

const SHEET := preload("res://assets/sprites/prince.png")
const FRAME := Vector2(24, 32)
const WIDTH := 10.0
const HEIGHT := 26.0
const RUN := 96.0
const ACCEL := 900.0
const GRAVITY := 980.0
const JUMP := 290.0
const MAX_FALL := 420.0
## A jump still counts this long after walking off a ledge, or before landing.
const COYOTE := 0.09
const BUFFER := 0.12

var room: Room
## His feet, centre.
var pos: Vector2 = Vector2.ZERO
var vel: Vector2 = Vector2.ZERO
var on_floor: bool = false
var alive: bool = true
var facing: float = 1.0
## Holding the dagger up (while its console is open, or the sands rewind).
var dagger_up: bool = false
var landed: bool = false
var jumped: bool = false

var _coyote: float = 0.0
var _buffer: float = 0.0
var _clock: float = 0.0


func place(at: Vector2) -> void:
	pos = at
	vel = Vector2.ZERO
	alive = true
	on_floor = true
	_coyote = 0.0
	_buffer = 0.0
	position = pos
	queue_redraw()


func die() -> void:
	alive = false
	vel.x = 0.0


func box() -> Rect2:
	return Rect2(pos.x - WIDTH / 2.0, pos.y - HEIGHT, WIDTH, HEIGHT)


## One step of play. `dir` is -1, 0 or 1.
func step(delta: float, dir: float, jump_pressed: bool, jump_held: bool) -> void:
	_clock += delta
	landed = false
	jumped = false
	if not alive:
		dir = 0.0
		jump_pressed = false
	vel.x = move_toward(vel.x, dir * RUN, ACCEL * delta)
	if dir != 0.0:
		facing = signf(dir)
	_coyote = COYOTE if on_floor else maxf(0.0, _coyote - delta)
	_buffer = BUFFER if jump_pressed else maxf(0.0, _buffer - delta)
	if _buffer > 0.0 and _coyote > 0.0:
		vel.y = -JUMP
		_buffer = 0.0
		_coyote = 0.0
		on_floor = false
		jumped = true
	elif vel.y < 0.0 and not jump_held:
		# A short hop for a tap.
		vel.y = maxf(vel.y, -JUMP * 0.45)
	vel.y = minf(vel.y + GRAVITY * delta, MAX_FALL)
	_move_x(vel.x * delta)
	var was_on_floor := on_floor
	_move_y(vel.y * delta)
	landed = on_floor and not was_on_floor
	position = pos.round()
	queue_redraw()


func _move_x(amount: float) -> void:
	if amount == 0.0:
		return
	pos.x += amount
	var rect := box()
	var edge := rect.end.x if amount > 0.0 else rect.position.x
	var col := floori((edge - (0.001 if amount > 0.0 else 0.0)) / Room.T)
	for row in range(floori(rect.position.y / Room.T), floori((rect.end.y - 0.001) / Room.T) + 1):
		if room.is_solid(col, row):
			pos.x = col * Room.T - WIDTH / 2.0 if amount > 0.0 else (col + 1) * Room.T + WIDTH / 2.0
			vel.x = 0.0
			return


func _move_y(amount: float) -> void:
	pos.y += amount
	on_floor = false
	var rect := box()
	var first := floori(rect.position.x / Room.T)
	var last := floori((rect.end.x - 0.001) / Room.T)
	if amount >= 0.0:
		var row := floori(rect.end.y / Room.T)
		for col in range(first, last + 1):
			# Only a floor he was above, so he never snaps up through a wall's side.
			if room.is_solid(col, row) and rect.end.y - amount <= row * Room.T + 0.01:
				pos.y = row * Room.T
				vel.y = 0.0
				on_floor = true
				return
	else:
		var row := floori(rect.position.y / Room.T)
		for col in range(first, last + 1):
			if room.is_solid(col, row):
				pos.y = (row + 1) * Room.T + HEIGHT
				vel.y = 0.0
				return


func _frame() -> int:
	if not alive:
		return 9
	if dagger_up:
		return 10
	if not on_floor:
		return 7 if vel.y < 0.0 else 8
	if absf(vel.x) > 8.0:
		return 1 + int(_clock * 12.0) % 6
	return 0


func _draw() -> void:
	var source := Rect2(_frame() * FRAME.x, 0, FRAME.x, FRAME.y)
	var dest := Rect2(-FRAME.x / 2.0, -FRAME.y, FRAME.x, FRAME.y)
	if facing < 0.0:
		dest = Rect2(FRAME.x / 2.0, -FRAME.y, -FRAME.x, FRAME.y)
	draw_texture_rect_region(SHEET, dest, source)
