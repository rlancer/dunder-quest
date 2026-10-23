class_name Fx
extends RefCounted

## One-shot pixel effects. CPU particles keep them working on the web renderer.
## Every `at` is a global position, whatever the parent's own offset.

const DUST := Color(0.94, 0.82, 0.62, 0.9)
const SPARK := Color(1.0, 0.78, 0.3, 1.0)
const EMBER := Color(1.0, 0.45, 0.16, 1.0)

static var _hitstop_serial: int = 0


## Puffs of dust at the feet. `side` pushes the puff away from the motion.
static func dust(parent: Node, at: Vector2, amount: int = 6, side: float = 0.0) -> void:
	var puff := _burst(parent, at, amount, 0.35)
	puff.direction = Vector2(side, -1.0) if side != 0.0 else Vector2.UP
	puff.spread = 70.0
	puff.initial_velocity_min = 14.0
	puff.initial_velocity_max = 36.0
	puff.gravity = Vector2(0.0, 40.0)
	puff.damping_min = 30.0
	puff.damping_max = 60.0
	puff.scale_amount_min = 1.0
	puff.scale_amount_max = 2.0
	puff.color_ramp = _fade(DUST)
	puff.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	puff.emission_rect_extents = Vector2(4.0, 1.0)


## Radial sparks, for pickups, stomps and the waygate.
static func sparks(parent: Node, at: Vector2, color: Color = SPARK, amount: int = 10, speed: float = 70.0) -> void:
	var burst := _burst(parent, at, amount, 0.45)
	burst.spread = 180.0
	burst.initial_velocity_min = speed * 0.4
	burst.initial_velocity_max = speed
	burst.gravity = Vector2(0.0, 120.0)
	burst.damping_min = 40.0
	burst.damping_max = 80.0
	burst.scale_amount_min = 1.0
	burst.scale_amount_max = 2.0
	burst.color_ramp = _fade(color)


## A short label that drifts up and fades, e.g. "+1". `hold` keeps it fully
## visible that much longer, and `outline` thickens its edge, for payoffs.
static func float_text(parent: Node, at: Vector2, text: String, color: Color = SPARK, hold: float = 0.0, outline: int = 3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var label := Label.new()
	label.text = text
	label.z_index = 20
	label.add_theme_font_size_override(&"font_size", 13)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"outline_size", outline)
	parent.add_child(label)
	label.global_position = (at + Vector2(-8.0, -20.0)).round()
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 14.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.25).set_delay(0.3 + hold)
	tween.tween_callback(label.queue_free)


static func _burst(parent: Node, at: Vector2, amount: int, lifetime: float) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = maxi(amount, 1)
	particles.lifetime = lifetime
	particles.lifetime_randomness = 0.4
	particles.local_coords = false
	particles.z_index = 6
	if parent != null and parent.is_inside_tree():
		parent.add_child(particles)
		particles.global_position = at
		particles.emitting = true
		particles.finished.connect(particles.queue_free)
	return particles


static func _fade(color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color)
	gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	return gradient


## Freezes the action for a beat so a hit lands with weight. Real time, so the
## slowed clock can't stretch it; a newer stop simply extends the freeze.
static func hitstop(tree: SceneTree, seconds: float, slow: float = 0.05) -> void:
	if tree == null:
		return
	_hitstop_serial += 1
	var serial := _hitstop_serial
	Engine.time_scale = slow
	await tree.create_timer(seconds, true, false, true).timeout
	if serial == _hitstop_serial:
		Engine.time_scale = 1.0
