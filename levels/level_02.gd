extends StageLevel

## The Cheese Shoppe. Lesson 2: Dictionaries & Hashing.
## Short floors, a low-roofed pit, a stair of planks over the long drop.
## Ember tiles kill on touch. Ash shelves crack, then fall. Both reset on respawn.
## The longest stage, so two lanterns hold the respawn point.
##
## Two rune keys lie on the route. The vault near the end has four bucket
## blocks; bumping the bucket a key hashes to stores it and lights a lock on
## the door. With both stored the door opens, and the Cheesemonger duels in
## the arena past it.

const WIDTH := 212
const ARENA := 176
const VAULT_TINT := Color(1.0, 0.8, 0.36)
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
const BUCKETS_X := 2600.0
const BUCKETS_Y := 152.0
const DOOR_X := 2712.0
## Key name -> where it lies on the route.
const KEYS: Dictionary = {
	"brie": Vector2(1256, 222),
	"edam": Vector2(2400, 222),
}

var _door: VaultDoor
## Bucket -> key name, for keys carried and keys stored in the vault.
var _held: Dictionary = {}
var _stored: Dictionary = {}
const _FAR := preload("res://assets/backgrounds/shoppe_far.png")
const _MID := preload("res://assets/backgrounds/shoppe_mid.png")
const _NEAR := preload("res://assets/backgrounds/shoppe_near.png")


func stage_index() -> int:
	return 2


func _passage_detail() -> String:
	return "Cave of the Bunny awaits"


func _stage_width() -> int:
	return WIDTH


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	# The Cheese Shoppe: a village high street of empty cheese stalls. The busy layers sit back
	# behind darker tints so they never compete with the play lane.
	_add_parallax("FarStreet", _FAR, Vector2(0.08, 0.0), -40, 2.0, Color(0.85, 0.82, 0.85))
	_add_parallax("MidStalls", _MID, Vector2(0.3, 0.0), -30, 2.0, Color(0.62, 0.58, 0.62))
	_add_parallax("NearCobbles", _NEAR, Vector2(0.55, 0.0), -20, 2.0, Color(0.5, 0.45, 0.5))


func _paint_stage() -> void:
	var ground: Array[Vector2i] = [
		Vector2i(0, 7),
		Vector2i(10, 16),
		Vector2i(20, 23),
		Vector2i(27, 28),
		Vector2i(35, 42),
		Vector2i(46, 51),
		Vector2i(59, 62),
		Vector2i(73, 80),
		Vector2i(104, 109),
		Vector2i(113, 116),
		Vector2i(121, 125),
		Vector2i(132, 136),
		Vector2i(139, 142),
		Vector2i(148, 151),
		Vector2i(156, 184),
	]
	for span in ground:
		_paint_solid(span.x, span.y, 14)
	_paint_ember(8, 9, true)
	_paint_ember(127, 130, false)
	_paint_solid(52, 58, 15)
	_paint_roof(40, 46, 10)
	# Planks up and over the long drop, then down to the far ground.
	_paint_row(83, 86, 12, StageTileset.ONE_WAY)
	_paint_row(90, 93, 11, StageTileset.ONE_WAY)
	_paint_row(97, 100, 12, StageTileset.ONE_WAY)


func _spawn_actors() -> void:
	_spawn_shelf(Vector2(856, 224), 48.0, 0.20, 14.0)
	_spawn_shelf(Vector2(1104, 192), 64.0, 0.70, 48.0)
	_spawn_checkpoint(Vector2(1216, 224))
	_spawn_checkpoint(Vector2(1728, 224))
	_spawn_crawler(Vector2(1850, 224), 32.0)
	_spawn_crawler(Vector2(1988, 224), 26.0)
	_spawn_cache(Vector2(2248, 152))
	_spawn(clay_brick_scene, Vector2(2392, 152))
	var seed_points: Array[Vector2] = [
		Vector2(1456, 150),
		Vector2(1472, 150),
		Vector2(1488, 150),
	]
	for point in seed_points:
		_bind_seed(_spawn(emberseed_scene, point))
	_spawn_scroll(Vector2(104, 222), "dict_basics")
	_spawn_scroll(Vector2(600, 222), "dict_hash")
	_spawn_scroll(Vector2(1712, 222), "dict_overwrite")
	_spawn_scroll(Vector2(2128, 222), "dict_get")
	_spawn_scroll(Vector2(2176, 222), "dict_unhashable")
	_build_vault()
	_build_arena(ARENA, "The Cheesemonger", Color(0.95, 0.55, 1.0))


func _build_vault() -> void:
	for key_name: String in KEYS:
		_spawn_key(KEYS[key_name], key_name).collected.connect(_on_key_collected)
	_spawn_sign(Vector2(BUCKETS_X + 24.0, BUCKETS_Y - 10.0), "bucket = rune_hash(key) % 4", VAULT_TINT)
	for index in RuneKey.BUCKETS:
		var block := _spawn_rune_block(Vector2(BUCKETS_X + 16.0 * index, BUCKETS_Y), index, str(index), VAULT_TINT)
		block.bumped.connect(_on_bucket_bumped)
	_door = VaultDoor.new()
	_door.locks = KEYS.size()
	_door.position = Vector2(DOOR_X, 224)
	add_child(_door)


func _on_key_collected(key: RuneKey) -> void:
	key.take()
	var bucket := key.bucket()
	_held[bucket] = key.key_name
	var code := "key = \"%s\"\nrune_hash(key)      # %d\nrune_hash(key) %% 4  # %d" % [key.key_name, RuneKey.rune_hash(key.key_name), bucket]
	_show_card({
		"kicker": "Rune key  -  %d of %d" % [_held.size() + _stored.size(), KEYS.size()],
		"title": "The key \"%s\"" % key.key_name,
		"code": code,
		"body": "The vault ahead has 4 buckets. It hashes a key (here, by adding up its letter codes) and looks in that one bucket only. Bump bucket %d to store this key." % bucket,
		"tint": VAULT_TINT,
	})


func _on_bucket_bumped(block: RuneBlock) -> void:
	var bucket := block.index
	var above := block.global_position + Vector2(-30.0, -14.0)
	if _stored.has(bucket):
		Fx.float_text(self, above, "vault[%d] = \"%s\"" % [bucket, _stored[bucket]], VAULT_TINT.lightened(0.3))
		return
	if not _held.has(bucket):
		block.flash(BAD)
		var message := "KeyError: bucket %d" % bucket if not _held.is_empty() else "No key hashes here"
		Fx.float_text(self, above, message, BAD.lightened(0.3))
		return
	_stored[bucket] = _held[bucket]
	_held.erase(bucket)
	block.flash(GOOD)
	block.set_lit(true)
	Fx.float_text(self, above, "vault[%d] = \"%s\"" % [bucket, _stored[bucket]], GOOD.lightened(0.3))
	_door.light_lock()


## Test hook: the bucket each key belongs in, for bots that solve the vault.
func vault_buckets() -> Array[int]:
	var buckets: Array[int] = []
	for key_name: String in KEYS:
		buckets.append(RuneKey.rune_hash(key_name) % RuneKey.BUCKETS)
	return buckets
