class_name Dog
extends Node2D

## Null, the Lieutenant's basset hound. He follows a few steps behind, sits
## when the Lieutenant stops, and takes no interest in the case. Five frames
## from tools/paint.py: sitting, then four of an unhurried walk.

const SHARP := preload("res://world/sharp_pixels.gdshader")
const SCALE := 0.75
const TRAIL := 38.0

var master: Person
var _sprite: Sprite2D
var _walked: float = 0.0
var _facing: int = 1
var _moving: bool = false


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/null.png") as Texture2D
	_sprite.hframes = 5
	_sprite.centered = false
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.offset = Vector2(-40, -48)
	var sharp := ShaderMaterial.new()
	sharp.shader = SHARP
	_sprite.material = sharp
	add_child(_sprite)


func _process(delta: float) -> void:
	if master == null or not is_instance_valid(master):
		return
	var gap := master.position.x - position.x
	# He sets off late and stops late.
	if absf(gap) > TRAIL + (0.0 if _moving else 14.0):
		_moving = true
	elif absf(gap) <= TRAIL:
		_moving = false
	if _moving:
		var step := signf(gap) * 62.0 * delta
		position.x += step
		_walked += absf(step)
		_facing = 1 if gap > 0.0 else -1
	_sprite.frame = 1 + int(_walked / 8.0) % 4 if _moving else 0
	_sprite.flip_h = _facing < 0
