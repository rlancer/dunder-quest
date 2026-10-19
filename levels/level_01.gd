extends Node2D

const TILE := 16
const WIDTH := 84
const HEIGHT := 17
const SURFACE_ROW := 14
const SPAWN_POSITION := Vector2(56, 214)

@export var tileset_texture: Texture2D
@export var music_stream: AudioStream
@export var copperling_scene: PackedScene
@export var cache_stone_scene: PackedScene
@export var clay_brick_scene: PackedScene
@export var emberseed_scene: PackedScene
@export var waygate_scene: PackedScene

@onready var player: PlayerBody = %Player
@onready var spawn: Marker2D = %Spawn
@onready var fall_zone: Area2D = %FallZone
@onready var tiles: TileMapLayer = %Tiles
@onready var hud: StageHud = %Hud
@onready var music: AudioStreamPlayer = %Music

var _cleared: bool = false


func _ready() -> void:
	_paint_stage()
	spawn.position = SPAWN_POSITION
	player.position = SPAWN_POSITION
	player.velocity = Vector2.ZERO
	player.set_camera_bounds(Rect2i(0, 0, WIDTH * TILE, HEIGHT * TILE))
	_fit_fall_zone()
	_spawn_actors()
	fall_zone.body_entered.connect(_on_fall_zone_body_entered)
	player.connect(&"respawn_requested", _respawn_player)
	_start_music()


func _paint_stage() -> void:
	if tileset_texture == null:
		push_error("Level is missing its tileset texture")
		return
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.tile_set = StageTileset.build(tileset_texture)
	var spans: Array[Vector2i] = [
		Vector2i(0, 11),
		Vector2i(15, 20),
		Vector2i(31, 47),
		Vector2i(52, WIDTH - 1),
	]
	for span in spans:
		for x in range(span.x, span.y + 1):
			tiles.set_cell(Vector2i(x, SURFACE_ROW), StageTileset.SOURCE, StageTileset.GROUND)
			for y in range(SURFACE_ROW + 1, HEIGHT):
				tiles.set_cell(Vector2i(x, y), StageTileset.SOURCE, StageTileset.FILL)
	for x in range(21, 31):
		tiles.set_cell(Vector2i(x, 12), StageTileset.SOURCE, StageTileset.SLAB)
	for x in range(56, 61):
		tiles.set_cell(Vector2i(x, 12), StageTileset.SOURCE, StageTileset.ONE_WAY)
	for x in range(64, 71):
		tiles.set_cell(Vector2i(x, 10), StageTileset.SOURCE, StageTileset.SLAB)


func _fit_fall_zone() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(WIDTH * TILE) + 480.0, 80.0)
	var collision := fall_zone.get_node(^"CollisionShape2D") as CollisionShape2D
	collision.shape = shape
	fall_zone.position = Vector2(float(WIDTH * TILE) * 0.5, float(HEIGHT * TILE) + 64.0)


func _spawn_actors() -> void:
	_spawn(copperling_scene, Vector2(416, 188))
	var cache := _spawn(cache_stone_scene, Vector2(552, 136))
	if cache != null:
		cache.connect(&"released", _on_cache_released)
	_spawn(clay_brick_scene, Vector2(616, 136))
	var seed_xs: Array[int] = [680, 696, 712, 728, 744]
	for seed_x in seed_xs:
		_bind_seed(_spawn(emberseed_scene, Vector2(float(seed_x), 210.0)))
	var gate := _spawn(waygate_scene, Vector2(1224, 224))
	if gate != null:
		gate.connect(&"reached", _on_waygate_reached)


func _spawn(packed: PackedScene, at: Vector2) -> Node2D:
	if packed == null:
		push_error("Level is missing a packed scene")
		return null
	var node := packed.instantiate() as Node2D
	node.position = at
	add_child(node)
	return node


func _bind_seed(seed: Node) -> void:
	if seed == null:
		return
	if not seed.is_connected(&"collected", _on_seed_collected):
		seed.connect(&"collected", _on_seed_collected)


func _on_cache_released(pickup: Node) -> void:
	_bind_seed(pickup)


func _on_seed_collected() -> void:
	hud.note_seed()


func _on_waygate_reached() -> void:
	if _cleared:
		return
	_cleared = true
	player.set_controls_enabled(false)
	hud.show_clear()


func _on_fall_zone_body_entered(body: Node2D) -> void:
	if body != player:
		return
	_respawn_player()


func _respawn_player() -> void:
	if _cleared:
		player.release_respawn_lock()
		return
	player.global_position = spawn.global_position
	player.velocity = Vector2.ZERO
	player.reset_camera()
	player.release_respawn_lock()


func _start_music() -> void:
	if music_stream == null:
		return
	var duplicated: Resource = music_stream.duplicate()
	if duplicated is AudioStreamWAV:
		var wav := duplicated as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		var bytes_per_sample := 2
		if wav.format == AudioStreamWAV.FORMAT_8_BITS:
			bytes_per_sample = 1
		elif wav.format == AudioStreamWAV.FORMAT_IMA_ADPCM:
			bytes_per_sample = 1
		var channels := 2 if wav.stereo else 1
		var frame_count := wav.data.size() / maxi(bytes_per_sample * channels, 1)
		if frame_count > wav.loop_begin:
			wav.loop_end = frame_count
	elif duplicated is AudioStreamMP3:
		(duplicated as AudioStreamMP3).loop = true
	elif duplicated is AudioStreamOggVorbis:
		(duplicated as AudioStreamOggVorbis).loop = true
	music.stream = duplicated as AudioStream
	music.bus = &"Music"
	music.volume_db = -8.0
	music.play()
