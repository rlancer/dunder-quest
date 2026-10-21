class_name HexStrike
extends Area2D

## A bolt the wizard calls down from above. A sigil marks the spot first and
## a thin guide line shows where it will fall, then the bolt drops straight
## to the floor and hurts only for that instant. Step aside while it warns.

signal hit(spell: Node2D, body: Node2D)

const WARN := 0.9
const STRIKE := 0.18
const FADE := 0.25
const HALF_WIDTH := 6.0

var tint: Color = Color(0.55, 0.85, 1.0)
## How far below the sigil the floor is.
var drop: float = 88.0
var zap_sound: AudioStream = preload("res://assets/audio/break.wav")

var _clock: float = 0.0
var _struck: bool = false


func _ready() -> void:
	add_to_group(&"duel_spell")
	z_index = 6
	collision_layer = 0
	collision_mask = 2
	monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_WIDTH * 2.0 - 2.0, drop)
	shape.shape = rect
	shape.position = Vector2(0.0, drop * 0.5)
	add_child(shape)
	body_entered.connect(func(body: Node2D) -> void: hit.emit(self, body))


func _physics_process(delta: float) -> void:
	_clock += delta
	if not _struck and _clock >= WARN:
		_struck = true
		monitoring = true
		StageAudio.play(get_tree(), zap_sound)
		Fx.sparks(get_parent(), global_position + Vector2(0.0, drop - 2.0), tint, 10, 70.0)
		Fx.dust(get_parent(), global_position + Vector2(0.0, drop), 5)
	elif _struck and monitoring and _clock >= WARN + STRIKE:
		set_deferred(&"monitoring", false)
	elif _clock >= WARN + STRIKE + FADE:
		queue_free()
	if _struck and monitoring:
		for body in get_overlapping_bodies():
			hit.emit(self, body)


func is_striking() -> bool:
	return _struck and _clock < WARN + STRIKE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _struck:
		# The sigil spins up faster as the strike nears; the guide line pulses.
		var urgency := clampf(_clock / WARN, 0.0, 1.0)
		var blink := 0.5 + 0.5 * sin(_clock * (10.0 + 30.0 * urgency))
		var ring := tint
		ring.a = 0.4 + 0.5 * blink
		var spin := _clock * (4.0 + 10.0 * urgency)
		for arm in 4:
			var angle := spin + float(arm) * PI * 0.5
			var tip := Vector2(cos(angle), sin(angle)) * 5.0
			draw_rect(Rect2(tip.round() - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), ring)
		draw_rect(Rect2(-1.0, -1.0, 2.0, 2.0), tint.lightened(0.5))
		var guide := tint
		guide.a = 0.12 + 0.22 * urgency * blink
		var dash := 0.0
		while dash < drop:
			draw_rect(Rect2(-0.5, dash + 4.0, 1.0, 3.0), guide)
			dash += 7.0
		draw_rect(Rect2(-HALF_WIDTH, drop - 1.0, HALF_WIDTH * 2.0, 1.0), guide)
		return
	var fade := 1.0 - clampf((_clock - WARN - STRIKE) / FADE, 0.0, 1.0)
	var bolt := tint
	bolt.a = fade
	draw_rect(Rect2(-HALF_WIDTH + 2.0, 0.0, HALF_WIDTH * 2.0 - 4.0, drop), bolt)
	draw_rect(Rect2(-1.0, 0.0, 2.0, drop), Color(1.0, 1.0, 1.0, fade))
	draw_rect(Rect2(-HALF_WIDTH - 2.0, drop - 2.0, HALF_WIDTH * 2.0 + 4.0, 2.0), Color(1.0, 1.0, 1.0, 0.8 * fade))
