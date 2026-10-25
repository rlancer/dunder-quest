extends StaticBody2D

## Releases one pickup the first time it is bumped from below.

signal released(pickup: Node)

@export var spent_texture: Texture2D
@export var pickup_scene: PackedScene
@export var bump_sound: AudioStream

var spent: bool = false

var _rest_y: float = 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group(&"head_bump")
	add_to_group(&"cache_stone")
	_rest_y = position.y


func _process(_delta: float) -> void:
	# The rune breathes until the stone is spent, so it reads as "hit me".
	var sprite := %Sprite as Sprite2D
	if spent:
		sprite.modulate = Color.WHITE
		return
	var glow := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 260.0)
	sprite.modulate = Color(1.0 + glow * 0.18, 1.0 + glow * 0.1, 1.0)


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()


func receive_head_bump() -> void:
	_nudge()
	if spent:
		return
	spent = true
	var sprite := %Sprite as Sprite2D
	if spent_texture != null:
		sprite.texture = spent_texture
	StageAudio.play(get_tree(), bump_sound)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -8.0), Fx.SPARK, 8, 50.0)
	if pickup_scene == null:
		return
	var pickup := pickup_scene.instantiate() as Node2D
	var parent_node := get_parent()
	if parent_node == null:
		return
	parent_node.add_child(pickup)
	pickup.global_position = global_position + Vector2(0.0, -18.0)
	pickup.call(&"pop_up")
	released.emit(pickup)


func _nudge() -> void:
	if _tween != null:
		_tween.kill()
	position.y = _rest_y
	_tween = create_tween()
	_tween.tween_property(self, "position:y", _rest_y - 4.0, 0.05)
	_tween.tween_property(self, "position:y", _rest_y, 0.08)
