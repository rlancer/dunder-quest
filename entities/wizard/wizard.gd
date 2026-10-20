class_name Wizard
extends Area2D

## A dark wizard who blocks the route behind a magic barrier. Walking into his
## zone challenges the player; the stage runs the quiz and then either zaps the
## player or banishes him, which also dissolves the barrier.

signal challenged(wizard: Wizard)

const FRAME_TIME := 0.45
const ORB := Vector2(-6.0, -22.0)

@export var title: String = "Dark Wizard"
@export var tint: Color = Color(0.55, 0.85, 1.0)
@export var zap_sound: AudioStream
@export var banish_sound: AudioStream

var banished: bool = false

@onready var _sprite: Sprite2D = %Sprite
@onready var _glow: Sprite2D = %Glow
@onready var _barrier: ArcaneBarrier = %Barrier
@onready var _nameplate: Label = %Nameplate

var _clock: float = 0.0


func _ready() -> void:
	add_to_group(&"wizard")
	body_entered.connect(_on_body_entered)
	_glow.modulate = Color(tint.r, tint.g, tint.b, 0.5)
	_barrier.tint = tint
	_nameplate.text = title
	_nameplate.add_theme_color_override(&"font_color", tint.lerp(Color.WHITE, 0.55))


func _process(delta: float) -> void:
	if banished:
		return
	_clock += delta
	_sprite.frame = int(_clock / FRAME_TIME) % 2
	# A one-pixel hover every other beat, offset from the frame swap.
	_sprite.position.y = -14.0 - (1.0 if int(_clock / FRAME_TIME + 0.5) % 2 == 0 else 0.0)
	_glow.position = ORB + Vector2(0.0, _sprite.position.y + 14.0)
	_glow.modulate.a = 0.34 + 0.12 * sin(_clock * 4.0)


## Zone center in world space, for tests that need to walk into it.
func zone_position() -> Vector2:
	return global_position + (%Zone as CollisionShape2D).position


## World x from the zone's left edge to the barrier's right edge: the stretch
## of floor the encounter occupies. Verifiers check it sits on one flat run.
func blocked_span() -> Vector2:
	var zone := %Zone as CollisionShape2D
	var wall := %Wall as CollisionShape2D
	var zone_half := (zone.shape as RectangleShape2D).size.x * 0.5
	var wall_half := (wall.shape as RectangleShape2D).size.x * 0.5
	return Vector2(zone_position().x - zone_half, wall.global_position.x + wall_half)


func barrier_open() -> bool:
	return _barrier.is_open()


## A forked bolt from the staff to the target, plus sparks where it lands.
func zap(target: Node2D) -> void:
	if banished or target == null:
		return
	StageAudio.play(get_tree(), zap_sound)
	var from := global_position + ORB
	var to := target.global_position + Vector2(0.0, -4.0)
	var bolt := Line2D.new()
	bolt.width = 2.0
	bolt.default_color = Color(tint.r, tint.g, tint.b, 1.0).lightened(0.35)
	bolt.z_index = 7
	bolt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var steps := 6
	for index in steps + 1:
		var point := from.lerp(to, float(index) / float(steps))
		if index > 0 and index < steps:
			point += Vector2(0.0, randf_range(-5.0, 5.0))
		bolt.add_point(point.round())
	get_parent().add_child(bolt)
	var tween := bolt.create_tween()
	tween.tween_property(bolt, "modulate:a", 0.0, 0.35).set_delay(0.08)
	tween.tween_callback(bolt.queue_free)
	Fx.sparks(get_parent(), to, tint, 14, 80.0)
	var flash := create_tween()
	_glow.scale = Vector2(1.8, 1.8)
	flash.tween_property(_glow, "scale", Vector2.ONE, 0.3)


## Correct answer: a puff of smoke, the wizard fades, and the barrier dissolves.
func banish() -> void:
	if banished:
		return
	banished = true
	set_deferred(&"monitoring", false)
	StageAudio.play(get_tree(), banish_sound)
	var center := global_position + Vector2(0.0, -14.0)
	Fx.sparks(get_parent(), center, tint, 18, 70.0)
	Fx.dust(get_parent(), global_position + Vector2(0.0, -2.0), 10)
	Fx.float_text(get_parent(), global_position + Vector2(-16.0, -18.0), "Banished!", tint.lightened(0.4))
	_nameplate.hide()
	var tween := create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.3, 0.2), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_sprite, "modulate:a", 0.0, 0.22)
	tween.parallel().tween_property(_glow, "modulate:a", 0.0, 0.18)
	_barrier.dissolve()


## Removes the wizard and his barrier at once, with no effects.
## Route verifiers use this so their trials measure the level alone.
func dismiss() -> void:
	banished = true
	set_deferred(&"monitoring", false)
	_barrier.open_now()
	hide()


func _on_body_entered(body: Node2D) -> void:
	if banished or not body.is_in_group(&"player"):
		return
	challenged.emit(self)
