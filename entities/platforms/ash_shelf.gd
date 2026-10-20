extends AnimatableBody2D

## Cracks, then falls. Taught over a trench, then used over a pit.
## Resets when the stage puts the player back at the spawn.

@export var span: float = 48.0
@export var shake_time: float = 0.7
@export var crumble_drop: float = 16.0

const _FALL_SPEED := 140.0

var _origin: Vector2 = Vector2.ZERO
var _elapsed: float = 0.0
var _drop: float = 0.0
var _state: int = 0


func _ready() -> void:
	add_to_group(&"ash_shelf")
	sync_to_physics = true
	collision_layer = 1
	collision_mask = 0
	process_physics_priority = -1
	_origin = global_position
	_build_body()


func reset_piece() -> void:
	_state = 0
	_elapsed = 0.0
	_drop = 0.0
	visible = true
	collision_layer = 1
	global_position = _origin


func _physics_process(delta: float) -> void:
	if _state == 0:
		global_position = _origin
		if _rider():
			_state = 1
			_elapsed = 0.0
		return
	if _state == 1:
		_elapsed += delta
		global_position = _origin + Vector2(sin(_elapsed * 46.0), 0.0)
		if _elapsed >= shake_time:
			_state = 2
			_drop = 0.0
		return
	if _state == 2:
		_drop += _FALL_SPEED * delta
		global_position = _origin + Vector2(0.0, _drop)
		if _drop >= crumble_drop:
			_state = 3
			collision_layer = 0
			visible = false
			global_position = _origin + Vector2(0.0, 900.0)


func _rider() -> bool:
	var body := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if body == null or not body.is_on_floor():
		return false
	var feet := body.global_position.y + 8.0
	if absf(feet - global_position.y) > 6.0:
		return false
	var half := span * 0.5
	return body.global_position.x >= global_position.x - half and body.global_position.x <= global_position.x + half


func _build_body() -> void:
	var texture := load("res://assets/sprites/tile_ash.png") as Texture2D
	var count := maxi(int(round(span / 16.0)), 1)
	for index in count:
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(-span * 0.5 + float(index) * 16.0, 0.0)
		add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(span, 16.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, 8.0)
	add_child(collision)
