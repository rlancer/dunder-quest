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
	Fx.dust(get_parent(), global_position, 8)
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
	for index in 4:
		# Quarter-brick chunks that pop up, then tumble down under gravity.
		var bit := Sprite2D.new()
		bit.texture = sprite.texture
		bit.region_enabled = true
		bit.region_rect = Rect2((index % 2) * 8, (index / 2) * 8, 8, 8)
		bit.global_position = global_position + Vector2(float(index % 2) * 8.0 - 4.0, float(index / 2) * 8.0 - 4.0)
		bit.z_index = 4
		parent_node.add_child(bit)
		var side := -1.0 if index % 2 == 0 else 1.0
		var rise := -22.0 if index < 2 else -12.0
		var start := bit.global_position
		var tween := bit.create_tween()
		tween.tween_method(
			func(t: float) -> void:
				bit.global_position = start + Vector2(side * 26.0 * t, rise * 4.0 * t + 120.0 * t * t)
				bit.rotation = side * t * 6.0,
			0.0, 1.0, 0.55)
		tween.parallel().tween_property(bit, "modulate:a", 0.0, 0.2).set_delay(0.35)
		tween.tween_callback(bit.queue_free)
