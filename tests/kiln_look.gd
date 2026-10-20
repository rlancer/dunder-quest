extends Node

## Opens Kiln Mouth and saves one settled view of each lane.

const _NAMES: PackedStringArray = [
	"mouth",
	"arch",
	"maw",
	"span",
	"hall",
	"gate",
]
const _POINTS: Array[Vector2] = [
	Vector2(200, 216),
	Vector2(480, 216),
	Vector2(560, 216),
	Vector2(930, 216),
	Vector2(1240, 216),
	Vector2(1400, 216),
]

var _player: CharacterBody2D
var _spot := 0
var _hold := 0
var _capture := ""


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
	var packed := load("res://levels/level_03.tscn") as PackedScene
	var level := packed.instantiate()
	add_child(level)
	_player = level.get_node(^"Player") as CharacterBody2D
	_player.set(&"controls_enabled", false)
	_player.set_physics_process(false)
	_pin()


func _physics_process(_delta: float) -> void:
	_pin()
	_hold += 1
	if _hold == 20:
		_capture = _NAMES[_spot]
	elif _hold > 24:
		_spot += 1
		_hold = 0
		if _spot >= _NAMES.size():
			print("LOOK done")
			get_tree().quit(0)


func _process(_delta: float) -> void:
	if _capture == "":
		return
	var tag := _capture
	_capture = ""
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		print("LOOK empty ", tag)
		return
	var path := ProjectSettings.globalize_path("res://tests/shots/kiln_%s.png" % tag)
	image.save_png(path)
	print("LOOK shot ", tag)


func _pin() -> void:
	_player.global_position = _POINTS[_spot]
	_player.velocity = Vector2.ZERO
	_player.reset_camera()
