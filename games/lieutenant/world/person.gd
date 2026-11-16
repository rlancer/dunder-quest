class_name Person
extends Node2D

## Somebody standing in a case: the Lieutenant (who the player walks) or
## tonight's suspect. Drawn from a sheet painted by tools/paint.py at two
## texels to a room pixel: idle, talk, two poses of their own (the
## Lieutenant thinks with a hand to his brow and raises a finger; a suspect
## folds their arms and, later, sweats), then the walk cycle if they have
## one. The node sits at the feet.

const SHARP := preload("res://world/sharp_pixels.gdshader")
## A frame of the sheet is 64x128 texels, drawn this many room pixels to a
## texel: the cast stands in front of the furniture, so they're drawn larger.
const SCALE := 0.75
const FRAME := Vector2(64, 128) * SCALE
enum Pose { IDLE, TALK, ONE, TWO, WALK }
const MOODS := {"think": Pose.ONE, "smug": Pose.ONE, "point": Pose.TWO, "sweat": Pose.TWO}
## Room pixels walked per frame of the cycle, so feet keep up with the floor.
const STRIDE := 9.0

var who: String = ""
var display_name: String = ""
var speed: float = 78.0
## Where the player is pushing the Lieutenant: -1, 0 or 1.
var walk_dir: float = 0.0
var min_x: float = 18.0
var max_x: float = 462.0
var pose: int = Pose.IDLE
## Holds a pose for this many seconds.
var pose_time: float = 0.0
var facing: int = 1
## "!" when there's something to put to them, "ok" once it's settled.
var marker: String = ""

var _sprite: Sprite2D
var _frames: int = 4
var _clock: float = 0.0
var _walked: float = 0.0
var _goal: float = NAN


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/%s.png" % who) as Texture2D
	_frames = maxi(int(_sprite.texture.get_width() / 64.0), 1) if _sprite.texture != null else 4
	_sprite.hframes = _frames
	_sprite.centered = false
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.offset = Vector2(-32, -128)
	var sharp := ShaderMaterial.new()
	sharp.shader = SHARP
	_sprite.material = sharp
	add_child(_sprite)
	_clock = randf() * 3.0


func _process(delta: float) -> void:
	_clock += delta
	if pose_time > 0.0:
		pose_time -= delta
		if pose_time <= 0.0 and pose != Pose.WALK:
			pose = Pose.IDLE
	var dir := walk_dir
	if not is_nan(_goal):
		dir = signf(_goal - position.x)
		if absf(_goal - position.x) <= speed * delta:
			position.x = _goal
			_goal = NAN
			dir = 0.0
	if dir != 0.0:
		var before := position.x
		position.x = clampf(position.x + dir * speed * delta, min_x, max_x)
		facing = 1 if dir > 0.0 else -1
		_walked += absf(position.x - before)
		pose_time = 0.0
		pose = Pose.WALK
	elif pose == Pose.WALK:
		pose = Pose.IDLE
	var frame := pose
	if pose == Pose.WALK:
		var cycle := _frames - Pose.WALK
		frame = Pose.WALK + int(_walked / STRIDE) % cycle if cycle > 0 else Pose.IDLE
	_sprite.frame = mini(frame, _frames - 1)
	_sprite.flip_h = facing < 0
	# A small breath on idle, so nobody looks like a cardboard cutout.
	_sprite.position.y = -0.5 if pose == Pose.IDLE and fmod(_clock, 2.8) < 1.4 else 0.0
	queue_redraw()


func strike(new_pose: int, seconds: float = 1.2) -> void:
	pose = new_pose
	pose_time = seconds


## Strikes the pose a line's mood asks for ("think", "smug", "point",
## "sweat"), or talks.
func strike_mood(mood: String, seconds: float) -> void:
	strike(int(MOODS.get(mood, Pose.TALK)), seconds)


func face(x: float) -> void:
	if absf(x - position.x) > 2.0:
		facing = 1 if x > position.x else -1


## Walks to x by himself (cutscenes); `is_walking` says when he's there.
func walk_to(x: float) -> void:
	_goal = clampf(x, min_x, max_x)


func is_walking() -> bool:
	return not is_nan(_goal)


func head() -> Vector2:
	return global_position + Vector2(0, -FRAME.y + 8)


func _draw() -> void:
	if marker == "":
		return
	var bob := roundf(sin(_clock * 4.0) * 1.5)
	Marker.draw(self, Vector2(0, -FRAME.y - 2 + bob), marker)
