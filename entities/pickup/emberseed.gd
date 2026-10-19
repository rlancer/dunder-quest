extends Area2D

signal collected

@export var collect_sound: AudioStream

var _taken: bool = false
var _tween: Tween


func _ready() -> void:
	add_to_group(&"emberseed")
	body_entered.connect(_on_body_entered)


func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()


func _process(_delta: float) -> void:
	var sprite := %Sprite as Sprite2D
	sprite.position.y = roundf(sin(float(Time.get_ticks_msec()) / 180.0))


func pop_up() -> void:
	var crest := global_position + Vector2(0.0, -20.0)
	var rest := global_position + Vector2(0.0, -8.0)
	_tween = create_tween()
	_tween.tween_property(self, "global_position", crest, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "global_position", rest, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group(&"player"):
		return
	_taken = true
	collected.emit()
	StageAudio.play(get_tree(), collect_sound)
	queue_free()
