class_name Biscuit
extends Node2D

## A custard cream, dropped by somebody, somewhere, some time ago. Either
## flatmate can pick it up.

signal taken

var _time: float = 0.0
var _gone: bool = false


func _ready() -> void:
	_time = randf() * TAU


func _physics_process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _gone:
		return
	for body in get_tree().get_nodes_in_group(&"flatmate"):
		var mate := body as Flatmate
		if (mate.global_position + Vector2(0, -2)).distance_to(global_position) < 11.0:
			_gone = true
			StageAudio.play(get_tree(), preload("res://assets/audio/pickup.wav"))
			Fx.sparks(get_parent(), global_position, Palette.AMBER, 8, 50.0)
			taken.emit()
			queue_free()
			return


func _draw() -> void:
	var y := roundf(sin(_time * 3.0) * 1.5)
	draw_rect(Rect2(Vector2(-5, -3 + y), Vector2(10, 6)), Color(0.93, 0.8, 0.5))
	draw_rect(Rect2(Vector2(-4, -1 + y), Vector2(8, 2)), Color(0.98, 0.95, 0.85))
	draw_rect(Rect2(Vector2(-5, -3 + y), Vector2(10, 1)), Color(0.8, 0.62, 0.34))
	draw_rect(Rect2(Vector2(-5, 2 + y), Vector2(10, 1)), Color(0.8, 0.62, 0.34))
