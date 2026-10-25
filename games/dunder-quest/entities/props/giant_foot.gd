class_name GiantFoot
extends Node2D

## The giant foot that stomps down beside the squire when a stage is cleared,
## a nod to the show's cut-out animation. It drops from above the screen,
## lands with a shake and a puff of dust, holds a beat, and lifts away.
## The node sits on the ground where the foot lands.

signal landed

const TEXTURE := preload("res://assets/sprites/giant_foot.png")
const STOMP := preload("res://assets/audio/stomp.wav")
## How far above its landing spot the foot starts: well off the top of the screen.
const DROP := 320.0
const FALL_TIME := 0.18
const HOLD := 0.55
const LIFT_TIME := 0.4

var _sprite: Sprite2D


func _ready() -> void:
	z_index = 5
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_sprite.position = _rest() + Vector2(0.0, -DROP)
	_stomp()


## Where the sprite's corner sits once the sole is on the ground.
func _rest() -> Vector2:
	return Vector2(-float(TEXTURE.get_width()) * 0.5, -float(TEXTURE.get_height()))


func _stomp() -> void:
	var fall := create_tween()
	fall.tween_property(_sprite, "position:y", _rest().y, FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if not is_inside_tree():
		return
	StageAudio.play(get_tree(), STOMP)
	Fx.dust(get_parent(), global_position + Vector2(-32.0, 0.0), 10, -1.0)
	Fx.dust(get_parent(), global_position + Vector2(32.0, 0.0), 10, 1.0)
	var player := get_tree().get_first_node_in_group(&"player") as PlayerBody
	if player != null:
		player.camera.shake(6.0)
	landed.emit()
	await get_tree().create_timer(HOLD).timeout
	if not is_inside_tree():
		return
	var lift := create_tween()
	lift.tween_property(_sprite, "position:y", _rest().y - DROP, LIFT_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	lift.tween_callback(queue_free)
