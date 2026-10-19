extends StaticBody2D

## Breaks when the player jumps into it from below.

@export var break_sound: AudioStream

var _broken: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group(&"head_bump")
	add_to_group(&"clay_brick")


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()


func receive_head_bump() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group(&"head_bump")
	remove_from_group(&"clay_brick")
	set_deferred(&"collision_layer", 0)
	StageAudio.play(get_tree(), break_sound)
	var sprite := %Sprite as Sprite2D
	_scatter(sprite)
	_tween = create_tween()
	_tween.tween_property(sprite, "scale", Vector2(1.25, 0.3), 0.08)
	_tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(queue_free)


func _scatter(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	for index in 3:
		var bit := Sprite2D.new()
		bit.texture = sprite.texture
		bit.scale = Vector2(0.45, 0.45)
		bit.global_position = global_position
		parent_node.add_child(bit)
		var tween := bit.create_tween()
		var hop := Vector2(float(index - 1) * 12.0, -16.0)
		tween.tween_property(bit, "global_position", bit.global_position + hop, 0.16)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, 0.2)
		tween.tween_callback(bit.queue_free)
