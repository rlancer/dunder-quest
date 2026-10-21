class_name WardWave
extends Area2D

## A crackling wave of the wizard's ward rolling along the arena floor toward
## the player. It stands only a tile high, so a hop clears it, and it burns
## out when it reaches the arena's seal.

signal hit(spell: Node2D, body: Node2D)

const HEIGHT := 11.0

var speed: float = 90.0
var direction: float = -1.0
var tint: Color = Color(0.55, 0.85, 1.0)
## Global x where the wave burns out.
var stop_x: float = 0.0

var _clock: float = 0.0
var _spent: bool = false


func _ready() -> void:
	add_to_group(&"duel_spell")
	z_index = 4
	collision_layer = 0
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(9.0, HEIGHT - 2.0)
	shape.shape = rect
	shape.position = Vector2(0.0, -HEIGHT * 0.5)
	add_child(shape)
	body_entered.connect(func(body: Node2D) -> void: hit.emit(self, body))


func _physics_process(delta: float) -> void:
	if _spent:
		return
	position.x += direction * speed * delta
	if (direction < 0.0 and global_position.x <= stop_x) or (direction > 0.0 and global_position.x >= stop_x):
		burn_out()


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func burn_out() -> void:
	if _spent:
		return
	_spent = true
	set_deferred(&"monitoring", false)
	Fx.sparks(get_parent(), global_position + Vector2(0.0, -4.0), tint, 6, 40.0)
	queue_free()


## Tongues of light that flicker at different heights, brightest at the core,
## with a trail of embers left behind.
func _draw() -> void:
	var core := tint.lightened(0.45)
	for column in 5:
		var x := float(column - 2) * 2.0
		var lick := 0.5 + 0.5 * sin(_clock * 22.0 + float(column) * 1.7)
		var tall := roundf(HEIGHT * (0.45 + 0.55 * lick) * (1.0 - absf(float(column - 2)) * 0.18))
		var color := tint if absf(float(column - 2)) > 0.5 else core
		color.a = 0.85
		draw_rect(Rect2(x - 1.0, -tall, 2.0, tall), color)
	draw_rect(Rect2(-1.0, -HEIGHT + 3.0, 2.0, HEIGHT - 3.0), Color(1.0, 1.0, 1.0, 0.6))
	for ember in 3:
		var trail := float(ember + 1) * 5.0 * -direction
		var rise := fmod(_clock * 20.0 + float(ember) * 3.0, 6.0)
		var mote := tint
		mote.a = 0.6 - float(ember) * 0.18
		draw_rect(Rect2(trail, -2.0 - rise, 1.0, 1.0), mote)
	draw_rect(Rect2(-6.0, -1.0, 12.0, 1.0), Color(tint.r, tint.g, tint.b, 0.5))
