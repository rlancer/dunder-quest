extends Area2D

## Checkpoint lantern. Lights once when the player walks past and becomes
## the stage's respawn point.

signal lit(at: Vector2)

const UNLIT := preload("res://assets/sprites/lantern_unlit.png")
const LIT := preload("res://assets/sprites/lantern_lit.png")

@export var light_sound: AudioStream

var is_lit: bool = false


func _ready() -> void:
	add_to_group(&"checkpoint")
	body_entered.connect(_on_body_entered)
	var sprite := %Sprite as Sprite2D
	sprite.texture = UNLIT
	sprite.position.y = -float(UNLIT.get_height()) * 0.5


func _process(_delta: float) -> void:
	if not is_lit:
		return
	var glow := %Glow as Sprite2D
	glow.modulate.a = 0.35 + 0.12 * sin(float(Time.get_ticks_msec()) / 160.0)


func _on_body_entered(body: Node2D) -> void:
	if is_lit or not body.is_in_group(&"player"):
		return
	is_lit = true
	(%Sprite as Sprite2D).texture = LIT
	(%Glow as Sprite2D).visible = true
	StageAudio.play(get_tree(), light_sound)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -22.0), Fx.SPARK, 12, 60.0)
	Fx.float_text(get_parent(), global_position + Vector2(-14.0, -14.0), "Checkpoint", Color(1.0, 0.86, 0.5))
	lit.emit(global_position + Vector2(0.0, -10.0))
