extends Area2D

signal reached

@export var goal_sound: AudioStream

var opened: bool = false


func _ready() -> void:
	add_to_group(&"waygate")
	body_entered.connect(_on_body_entered)
	var sprite := %Sprite as Sprite2D
	if sprite.texture != null:
		sprite.position.y = -float(sprite.texture.get_height()) * 0.5


func _process(_delta: float) -> void:
	var sprite := %Sprite as Sprite2D
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) / 220.0))


func _on_body_entered(body: Node2D) -> void:
	if opened or not body.is_in_group(&"player"):
		return
	opened = true
	StageAudio.play(get_tree(), goal_sound)
	reached.emit()
