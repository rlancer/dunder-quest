class_name Person
extends Node2D

## Somebody standing in a scene: Barry (who the player walks) or anyone he
## is bickering with. Drawn from a sheet of six 24x48 frames painted by
## tools/paint.py: idle, two walk frames, talk, squint (arms folded, eyes
## narrowed) and yell. The node sits at the feet.

const FRAME := Vector2i(24, 48)
enum Pose { IDLE, WALK_A, WALK_B, TALK, SQUINT, YELL }

var who: String = ""
var display_name: String = ""
var speed: float = 74.0
## Where the player is pushing Barry: -1, 0 or 1. Ignored for everyone else.
var walk_dir: float = 0.0
var min_x: float = 16.0
var max_x: float = 464.0
var pose: int = Pose.IDLE
## Holds a pose (talk, squint, yell) for this many seconds.
var pose_time: float = 0.0
var facing: int = 1
## A "!" over the head when there's a plan to sort out with them, a tick
## once it's sorted.
var marker: String = ""

var _sprite: Sprite2D
var _clock: float = 0.0
var _step: float = 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/sprites/%s.png" % who) as Texture2D
	_sprite.hframes = 6
	_sprite.centered = false
	_sprite.offset = Vector2(-FRAME.x / 2.0, -FRAME.y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_clock = randf() * 3.0


func _process(delta: float) -> void:
	_clock += delta
	if pose_time > 0.0:
		pose_time -= delta
		if pose_time <= 0.0:
			pose = Pose.IDLE
	if walk_dir != 0.0:
		position.x = clampf(position.x + walk_dir * speed * delta, min_x, max_x)
		facing = 1 if walk_dir > 0.0 else -1
		_step += delta
		pose_time = 0.0
		pose = Pose.WALK_A if int(_step * 7.0) % 2 == 0 else Pose.WALK_B
	elif pose == Pose.WALK_A or pose == Pose.WALK_B:
		pose = Pose.IDLE
	_sprite.frame = pose
	_sprite.flip_h = facing < 0
	# A small breath on idle, so nobody looks like a cardboard cutout.
	_sprite.position.y = -1.0 if pose == Pose.IDLE and fmod(_clock, 2.6) < 1.3 else 0.0
	queue_redraw()


func strike(new_pose: int, seconds: float = 1.2) -> void:
	pose = new_pose
	pose_time = seconds


func face(x: float) -> void:
	if absf(x - position.x) > 2.0:
		facing = 1 if x > position.x else -1


func head() -> Vector2:
	return global_position + Vector2(0, -FRAME.y - 2)


func _draw() -> void:
	if marker == "":
		return
	var bob := roundf(sin(_clock * 4.0) * 1.5)
	var at := Vector2(0, -FRAME.y - 10 + bob)
	if marker == "!":
		draw_rect(Rect2(at + Vector2(-5, -9), Vector2(10, 13)), Palette.INK)
		draw_rect(Rect2(at + Vector2(-4, -8), Vector2(8, 11)), Palette.PAD)
		draw_rect(Rect2(at + Vector2(-1, -7), Vector2(2, 6)), Palette.RUST)
		draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 2)), Palette.RUST)
	elif marker == "ok":
		draw_line(at + Vector2(-4, -3), at + Vector2(-1, 0), Palette.GREEN, 2.0)
		draw_line(at + Vector2(-1, 0), at + Vector2(5, -7), Palette.GREEN, 2.0)
