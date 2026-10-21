class_name ArcaneBarrier
extends StaticBody2D

## The wizard's wall. Solid on the world layer and tall enough that no jump
## clears it. Drawn as a shimmering band of light that thins as the wizard's
## wards break; dissolving fades it out and drops the collision. A duel's
## seal is the same wall, raised behind the player as the fight begins.

const VISIBLE_HEIGHT := 72.0
const BAND := 6.0

var tint: Color = Color(0.55, 0.85, 1.0)

var _open: bool = false
var _fade: float = 1.0
## How bright the band burns, from 1.0 (every ward up) down toward a faint glow.
var _power: float = 1.0
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(&"arcane_barrier")


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func is_open() -> bool:
	return _open


## Dims the band to match the share of wards still standing. It stays solid.
func weaken(share: float) -> void:
	var target := lerpf(0.35, 1.0, clampf(share, 0.0, 1.0))
	var center := global_position + Vector2(0.0, -VISIBLE_HEIGHT * 0.4)
	Fx.sparks(get_parent(), center, tint, 8, 40.0)
	create_tween().tween_property(self, "_power", target, 0.3)


## Raises an open wall again: it flares up out of the floor and turns solid.
func rise() -> void:
	if not _open:
		return
	_open = false
	_power = 1.0
	_wall().set_deferred(&"disabled", false)
	show()
	var center := global_position + Vector2(0.0, -VISIBLE_HEIGHT * 0.4)
	Fx.sparks(get_parent(), center, tint, 14, 60.0)
	var tween := create_tween()
	tween.tween_property(self, "_fade", 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func dissolve() -> void:
	if _open:
		return
	_open = true
	_wall().set_deferred(&"disabled", true)
	var center := global_position + Vector2(0.0, -VISIBLE_HEIGHT * 0.4)
	Fx.sparks(get_parent(), center, tint, 16, 50.0)
	var tween := create_tween()
	tween.tween_property(self, "_fade", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(hide)


func open_now() -> void:
	_open = true
	_fade = 0.0
	_wall().set_deferred(&"disabled", true)
	hide()


func _wall() -> CollisionShape2D:
	return get_node(^"Wall") as CollisionShape2D


func _draw() -> void:
	if _fade <= 0.0:
		return
	# Rows of light, brightest at the floor, with a slow wave running upward.
	var rows := int(VISIBLE_HEIGHT / 2.0)
	for row in rows:
		var y := -2.0 - float(row) * 2.0
		var height_fade := 1.0 - float(row) / float(rows)
		var wave := 0.5 + 0.5 * sin(_clock * 5.0 - float(row) * 0.55)
		var alpha := (0.18 + 0.5 * wave) * height_fade * _fade * _power
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
