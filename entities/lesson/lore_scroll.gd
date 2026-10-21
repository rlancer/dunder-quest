class_name LoreScroll
extends Area2D

## A lore scroll lying on the route. Touching it reads it: the stage shows its
## card and the Spellbook keeps it. The pickup zone is tall, so a hop over the
## scroll still catches it.

signal read(scroll: LoreScroll)

const PAPER := Color(0.96, 0.88, 0.68)
const PAPER_SHADE := Color(0.8, 0.66, 0.46)
const ROD := Color(0.55, 0.32, 0.2)
const INK := Color(0.42, 0.3, 0.38)
const GLOW := Color(1.0, 0.86, 0.5)

var scroll_id: String = ""
var taken: bool = false

var _clock: float = 0.0
var _sound: AudioStream = preload("res://assets/audio/pickup.wav")


func _ready() -> void:
	add_to_group(&"lesson")
	add_to_group(&"lore_scroll")
	z_index = 4
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(14.0, 96.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -40.0)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_clock = randf() * TAU


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Rises out of a bumped block, then floats down to rest on the floor, where
## it wakes. Spawn it dormant so it can't be read on the way.
func pop_to(rest: Vector2) -> void:
	var crest := global_position + Vector2(0.0, -14.0)
	var tween := create_tween()
	tween.tween_property(self, "global_position", crest, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", rest, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(set_deferred.bind(&"monitoring", true))


func take() -> void:
	if taken:
		return
	taken = true
	set_deferred(&"monitoring", false)
	StageAudio.play(get_tree(), _sound)
	Fx.sparks(get_parent(), global_position, GLOW, 14, 70.0)
	queue_free()


## Route verifiers measure the level alone, without cards stopping the run.
func dismiss() -> void:
	set_deferred(&"monitoring", false)
	hide()


func _draw() -> void:
	var bob := roundf(sin(_clock * 2.6) * 1.5)
	var top := -10.0 + bob
	# A soft halo so the scroll reads from across the screen.
	var halo := 0.18 + 0.08 * sin(_clock * 3.4)
	draw_circle(Vector2(0.0, top + 4.0), 9.0, Color(GLOW.r, GLOW.g, GLOW.b, halo * 0.5))
	draw_circle(Vector2(0.0, top + 4.0), 6.0, Color(GLOW.r, GLOW.g, GLOW.b, halo))
	# Paper, shaded at the bottom edge, with three lines of ink.
	draw_rect(Rect2(-5.0, top, 10.0, 9.0), PAPER)
	draw_rect(Rect2(-5.0, top + 8.0, 10.0, 1.0), PAPER_SHADE)
	for row in 3:
		var width := 6.0 if row != 1 else 4.0
		draw_rect(Rect2(-3.0, top + 2.0 + float(row) * 2.0, width, 1.0), INK)
	# Rolled ends.
	draw_rect(Rect2(-7.0, top - 1.0, 2.0, 11.0), ROD)
	draw_rect(Rect2(5.0, top - 1.0, 2.0, 11.0), ROD)
	draw_rect(Rect2(-7.0, top - 1.0, 2.0, 1.0), ROD.lightened(0.35))
	draw_rect(Rect2(5.0, top - 1.0, 2.0, 1.0), ROD.lightened(0.35))
	# A glint that sweeps across now and then.
	var sweep := fmod(_clock * 0.7, 3.0)
	if sweep < 1.0:
		draw_rect(Rect2(-5.0 + sweep * 9.0, top, 1.0, 8.0), Color(1.0, 1.0, 1.0, 0.7))


func _on_body_entered(body: Node2D) -> void:
	if taken or not body.is_in_group(&"player"):
		return
	read.emit(self)
