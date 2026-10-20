class_name ArcaneBarrier
extends StaticBody2D

## The wizard's wall. Solid on the world layer and tall enough that no jump
## clears it. Drawn as a shimmering band of light; dissolving fades it out and
## drops the collision.

const VISIBLE_HEIGHT := 72.0
const BAND := 6.0

var tint: Color = Color(0.55, 0.85, 1.0)

var _open: bool = false
var _fade: float = 1.0
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(&"arcane_barrier")


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func is_open() -> bool:
	return _open


func dissolve() -> void:
	if _open:
		return
	_open = true
	(%Wall as CollisionShape2D).set_deferred(&"disabled", true)
	var center := global_position + Vector2(0.0, -VISIBLE_HEIGHT * 0.4)
	Fx.sparks(get_parent().get_parent(), center, tint, 16, 50.0)
	var tween := create_tween()
	tween.tween_property(self, "_fade", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func open_now() -> void:
	_open = true
	_fade = 0.0
	(%Wall as CollisionShape2D).set_deferred(&"disabled", true)
	hide()


func _draw() -> void:
	if _fade <= 0.0:
		return
	# Rows of light, brightest at the floor, with a slow wave running upward.
	var rows := int(VISIBLE_HEIGHT / 2.0)
	for row in rows:
		var y := -2.0 - float(row) * 2.0
		var height_fade := 1.0 - float(row) / float(rows)
		var wave := 0.5 + 0.5 * sin(_clock * 5.0 - float(row) * 0.55)
		var alpha := (0.18 + 0.5 * wave) * height_fade * _fade
		var core := Color(tint.r, tint.g, tint.b, alpha)
		draw_rect(Rect2(-BAND * 0.5, y, BAND, 2.0), core)
		draw_rect(Rect2(-1.0, y, 2.0, 2.0), Color(1.0, 1.0, 1.0, alpha * 0.45))
		var edge := Color(tint.r, tint.g, tint.b, alpha * 0.35)
		draw_rect(Rect2(-BAND * 0.5 - 2.0, y, 2.0, 2.0), edge)
		draw_rect(Rect2(BAND * 0.5, y, 2.0, 2.0), edge)
	# Motes drifting up the band.
	for index in 5:
		var phase := fmod(_clock * 0.6 + float(index) * 0.21, 1.0)
		var mote_y := -phase * VISIBLE_HEIGHT
		var mote_x := float(index % 3) - 2.0
		var mote := Color.WHITE.lerp(tint, 0.3)
		mote.a = (1.0 - phase) * 0.85 * _fade
		draw_rect(Rect2(mote_x, round(mote_y), 1.0, 1.0), mote)
	# A bright seam where the wall meets the ground.
	draw_rect(Rect2(-BAND * 0.5 - 2.0, -1.0, BAND + 4.0, 1.0), Color(tint.r, tint.g, tint.b, 0.8 * _fade).lightened(0.3))
