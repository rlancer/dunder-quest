class_name Wizard
extends Area2D

## A dark wizard who blocks the route behind a magic barrier. Walking into his
## zone challenges the player to his trial: the stage runs the quiz, and each
## right answer breaks one of his wards (the pips over his name) while a wrong
## one gets the player zapped. With the last ward broken he is banished and
## his barrier dissolves. As the player draws near he taunts them with a line
## that gives away the lesson's theme.

signal challenged(wizard: Wizard)

const FRAME_TIME := 0.45
const ORB := Vector2(-6.0, -22.0)
## How close (in x) the player must come before the taunt shows.
const TAUNT_RANGE := 150.0
const PIP_Y := -49.0
const PIP_GAP := 7.0

@export var title: String = "Dark Wizard"
@export var tint: Color = Color(0.55, 0.85, 1.0)
@export var taunt: String = ""
@export var zap_sound: AudioStream
@export var banish_sound: AudioStream

var banished: bool = false
## How many right answers the trial takes, and how many are still owed.
var ward_total: int = 1
var wards_left: int = 1

@onready var _sprite: Sprite2D = %Sprite
@onready var _glow: Sprite2D = %Glow
@onready var _barrier: ArcaneBarrier = %Barrier
@onready var _nameplate: Label = %Nameplate

var _clock: float = 0.0
var _bubble: Label


func _ready() -> void:
	add_to_group(&"wizard")
	body_entered.connect(_on_body_entered)
	_glow.modulate = Color(tint.r, tint.g, tint.b, 0.5)
	_barrier.tint = tint
	_nameplate.text = title
	_nameplate.add_theme_color_override(&"font_color", tint.lerp(Color.WHITE, 0.55))
	_build_bubble()


## Arms the trial: `count` wards, one per question to be answered right.
func set_wards(count: int) -> void:
	ward_total = maxi(count, 1)
	wards_left = ward_total
	queue_redraw()


## One right answer: a ward shatters and the barrier thins. Returns how many
## are left; at zero the stage banishes him.
func break_ward() -> int:
	if wards_left <= 0:
		return 0
	wards_left -= 1
	var pip := global_position + Vector2(_pip_x(wards_left), PIP_Y)
	Fx.sparks(get_parent(), pip, tint, 8, 40.0)
	_barrier.weaken(float(wards_left) / float(ward_total))
	queue_redraw()
	return wards_left


func _pip_x(ward: int) -> float:
	return (float(ward) - float(ward_total - 1) * 0.5) * PIP_GAP


func _build_bubble() -> void:
	_bubble = Label.new()
	_bubble.text = taunt
	_bubble.add_theme_font_size_override(&"font_size", 10)
	_bubble.add_theme_color_override(&"font_color", tint.lerp(Color.WHITE, 0.7))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.06, 0.03, 0.09, 0.88)
	box.border_color = tint
	box.set_border_width_all(1)
	box.set_corner_radius_all(2)
	box.content_margin_left = 4.0
	box.content_margin_right = 4.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	box.anti_aliasing = false
	_bubble.add_theme_stylebox_override(&"normal", box)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.z_index = 8
	_bubble.modulate.a = 0.0
	add_child(_bubble)
	_bubble.reset_size()
	_bubble.position = Vector2(-_bubble.size.x * 0.5 - 6.0, -62.0).round()


func _process(delta: float) -> void:
	if banished:
		return
	_clock += delta
	_update_bubble(delta)
	if ward_total > 1:
		queue_redraw()
	_sprite.frame = int(_clock / FRAME_TIME) % 2
	# A one-pixel hover every other beat, offset from the frame swap.
	_sprite.position.y = -14.0 - (1.0 if int(_clock / FRAME_TIME + 0.5) % 2 == 0 else 0.0)
	_glow.position = ORB + Vector2(0.0, _sprite.position.y + 14.0)
	_glow.modulate.a = 0.34 + 0.12 * sin(_clock * 4.0)


func _update_bubble(delta: float) -> void:
	if taunt == "":
		return
	var near := false
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null:
		var gap := player.global_position - global_position
		near = absf(gap.x) < TAUNT_RANGE and absf(gap.y) < 80.0
	_bubble.modulate.a = move_toward(_bubble.modulate.a, 1.0 if near else 0.0, delta * 4.0)


## Small diamonds over the nameplate: bright for wards still standing,
## hollow for the ones already broken. A one-question trial shows none.
func _draw() -> void:
	if banished or ward_total <= 1:
		return
	var pulse := 0.75 + 0.25 * sin(_clock * 4.0)
	for ward in ward_total:
		var at := Vector2(_pip_x(ward), PIP_Y).round()
		var standing := ward < wards_left
		var color := tint.lightened(0.35) if standing else Color(0.3, 0.26, 0.36)
		color.a = pulse if standing else 0.9
		draw_rect(Rect2(at + Vector2(-1.0, -2.0), Vector2(3.0, 5.0)), Color(0.06, 0.03, 0.09, 0.9))
		draw_rect(Rect2(at + Vector2(-2.0, -1.0), Vector2(5.0, 3.0)), Color(0.06, 0.03, 0.09, 0.9))
		draw_rect(Rect2(at + Vector2(0.0, -1.0), Vector2(1.0, 3.0)), color)
		draw_rect(Rect2(at + Vector2(-1.0, 0.0), Vector2(3.0, 1.0)), color)


func is_taunting() -> bool:
	return _bubble != null and _bubble.modulate.a > 0.5


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
	wards_left = 0
	queue_redraw()
	set_deferred(&"monitoring", false)
	StageAudio.play(get_tree(), banish_sound)
	var center := global_position + Vector2(0.0, -14.0)
	Fx.sparks(get_parent(), center, tint, 18, 70.0)
	Fx.dust(get_parent(), global_position + Vector2(0.0, -2.0), 10)
	Fx.float_text(get_parent(), global_position + Vector2(-16.0, -18.0), "Banished!", tint.lightened(0.4))
	_nameplate.hide()
	_bubble.hide()
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
	if _bubble != null:
		_bubble.hide()


func _on_body_entered(body: Node2D) -> void:
	if banished or not body.is_in_group(&"player"):
		return
	challenged.emit(self)
