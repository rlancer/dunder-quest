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
	_add_motes()


func _process(_delta: float) -> void:
	var sprite := %Sprite as Sprite2D
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.82 + 0.18 * sin(float(Time.get_ticks_msec()) / 220.0))


## Teal motes drifting up through the arch so the exit reads from a distance.
func _add_motes() -> void:
	var motes := CPUParticles2D.new()
	motes.position = Vector2(0.0, -6.0)
	motes.amount = 10
	motes.lifetime = 1.6
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(6.0, 2.0)
	motes.direction = Vector2.UP
	motes.spread = 12.0
	motes.gravity = Vector2.ZERO
	motes.initial_velocity_min = 10.0
	motes.initial_velocity_max = 20.0
	var fade := Gradient.new()
	fade.set_color(0, Color(0.55, 1.0, 0.9, 0.9))
	fade.set_color(1, Color(0.55, 1.0, 0.9, 0.0))
	motes.color_ramp = fade
	add_child(motes)


func _on_body_entered(body: Node2D) -> void:
	if opened or not body.is_in_group(&"player"):
		return
	opened = true
	StageAudio.play(get_tree(), goal_sound)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -20.0), Color(0.5, 1.0, 0.9), 24, 110.0)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -20.0), Fx.SPARK, 16, 80.0)
	reached.emit()
