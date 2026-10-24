class_name StageLevel
extends Node2D

## Shared stage flow: tiles, spawn, deaths, checkpoints, the run clock,
## audio unlock, the pause menu, the wizard's arena, and the waygate exit.
##
## Each stage is also a Python lesson (see `Lessons`). Lore scrolls on the
## route teach it, and the stage's gadget is the way forward: code the player
## reads and then runs by bumping blocks, where only the right answer builds
## the path. At the end the wizard duels the player in a sealed arena (see
## `WizardDuel`): his questions come from the scrolls they read, they answer
## by bumping lettered blocks while dodging his spells, and each right answer
## breaks one of his wards.

const TILE := 16
## How long the results card waits for a press before moving on by itself.
const PASSAGE_TIMEOUT := 4.0
const DEATH_HOLD := 0.55
const ASH_SHELF := preload("res://entities/platforms/ash_shelf.tscn")
const LANTERN := preload("res://entities/checkpoint/lantern.tscn")
const WIZARD_DUEL := preload("res://entities/wizard/wizard_duel.gd")
## The arena, in tiles: the duel's floor, the run-up with its lantern, and
## the stretch past the wizard's barrier where the waygate stands.
const ARENA_TILES := 28
const ARENA_RUN_UP := 5
const ARENA_RUN_OUT := 8
const SCROLL_TINT := Color(1.0, 0.84, 0.46)
const LORE_SCROLL := preload("res://entities/lesson/lore_scroll.gd")
const RUNE_BLOCK := preload("res://entities/lesson/rune_block.gd")
const RUNE_KEY := preload("res://entities/lesson/rune_key.gd")
const LESSON_SIGN := preload("res://entities/lesson/lesson_sign.gd")

@export var tileset_texture: Texture2D
@export var music_stream: AudioStream
@export var copperling_scene: PackedScene
@export var cache_stone_scene: PackedScene
@export var clay_brick_scene: PackedScene
@export var emberseed_scene: PackedScene
@export var waygate_scene: PackedScene
@export var next_stage: PackedScene

@onready var player: PlayerBody = %Player
@onready var spawn: Marker2D = %Spawn
@onready var fall_zone: Area2D = %FallZone
@onready var fall_shape: CollisionShape2D = %FallShape
@onready var tiles: TileMapLayer = %Tiles
@onready var hud: StageHud = %Hud
@onready var audio: StageAudio = %StageAudio

var _cleared: bool = false
var _departing: bool = false
var _dying: bool = false
## Bumped by every death and respawn, so a death still waiting out its
## animation knows when something else already put the player back.
var _death_serial: int = 0
## Falls this attempt at the stage, for the stats.
var _deaths: int = 0
var _web_audio_locked: bool = false
var _elapsed: float = 0.0
var _clock_running: bool = false
var _duel: WizardDuel


func _ready() -> void:
	add_to_group(&"stage")
	# Ember checks read the player after it moves this frame.
	process_physics_priority = 20
	if not _prepare_tiles():
		return
	_paint_stage()
	hud.set_stage_name(_stage_name())
	hud.set_lesson(Lessons.topic(stage_index()))
	_refresh_scrolls()
	_configure_stage()
	_add_abyss()
	var spawn_position := _spawn_position()
	spawn.position = spawn_position
	player.position = spawn_position
	player.velocity = Vector2.ZERO
	player.set_camera_bounds(Rect2i(0, 0, _stage_width() * TILE, _stage_height() * TILE))
	_fit_fall_zone()
	_spawn_actors()
	hud.set_seed_total(_count_seeds())
	fall_zone.body_entered.connect(_on_fall_zone_body_entered)
	player.connect(&"respawn_requested", _kill_player)
	hud.map_requested.connect(return_to_map)
	hud.restart_requested.connect(_restart_stage)
	Telemetry.track("stage_start", stage_index())
	if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
		_web_audio_locked = true
		hud.show_press_to_start()
	else:
		_start_music()
		_clock_running = true


func _unhandled_input(event: InputEvent) -> void:
	if not _web_audio_locked or not event.is_pressed() or event.is_echo():
		return
	_web_audio_locked = false
	StageAudio.web_audio_unlocked = true
	hud.hide_press_to_start()
	_start_music()
	_clock_running = true


func _process(delta: float) -> void:
	# The clock waits while the wizard duels, so reading his code costs nothing.
	if not _clock_running or _cleared or _departing or (_duel != null and _duel.is_engaged()):
		return
	_elapsed += delta
	hud.set_time(_elapsed)


func _physics_process(_delta: float) -> void:
	if _cleared or _departing or _dying or player == null:
		return
	if _touching_ember():
		_kill_player()


func stage_index() -> int:
	return 1


func _stage_name() -> String:
	return str(GameProgression.get_stage_data(stage_index()).get("name", "Stage"))


func _stage_width() -> int:
	return 84


func _stage_height() -> int:
	return 17


func _spawn_position() -> Vector2:
	return Vector2(56, 214)


func _configure_stage() -> void:
	pass


func _paint_stage() -> void:
	push_error("Stage is missing its layout")


func _spawn_actors() -> void:
	pass


func _passage_detail() -> String:
	return "The span continues"


func _prepare_tiles() -> bool:
	if tileset_texture == null:
		push_error("Level is missing its tileset texture")
		return false
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tiles.tile_set = StageTileset.build(tileset_texture)
	return true


func _paint_solid(from_x: int, to_x: int, surface_row: int) -> void:
	for x in range(from_x, to_x + 1):
		tiles.set_cell(Vector2i(x, surface_row), StageTileset.SOURCE, StageTileset.GROUND)
		for y in range(surface_row + 1, _stage_height()):
			tiles.set_cell(Vector2i(x, y), StageTileset.SOURCE, StageTileset.FILL)


func _paint_row(from_x: int, to_x: int, row: int, atlas: Vector2i) -> void:
	for x in range(from_x, to_x + 1):
		tiles.set_cell(Vector2i(x, row), StageTileset.SOURCE, atlas)


## Ember on the floor row. Supported ember sits on fill; open ember floats over a pit.
func _paint_ember(from_x: int, to_x: int, supported: bool) -> void:
	_paint_row(from_x, to_x, 14, StageTileset.EMBER)
	if supported:
		for y in range(15, _stage_height()):
			_paint_row(from_x, to_x, y, StageTileset.FILL)


## A low ceiling: fill from the top of the stage down to a slab underside.
func _paint_roof(from_x: int, to_x: int, bottom_row: int) -> void:
	for y in range(0, bottom_row):
		_paint_row(from_x, to_x, y, StageTileset.FILL)
	_paint_row(from_x, to_x, bottom_row, StageTileset.SLAB)


## Lays tiles one at a time, `beat` seconds apart, with a puff of dust on
## each: a gadget building a bridge or a stair. Returns false if the stage
## left the tree partway.
func _raise_tiles(cells: Array[Vector2i], atlas: Vector2i, beat: float) -> bool:
	for cell in cells:
		tiles.set_cell(cell, StageTileset.SOURCE, atlas)
		Fx.dust(self, tiles.map_to_local(cell) + Vector2(0.0, -8.0), 3)
		if beat > 0.0:
			await get_tree().create_timer(beat, false).timeout
			if not is_inside_tree():
				return false
	return true


## Takes back tiles a gadget laid, crumbling each into dust.
func _crumble_tiles(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if tiles.get_cell_source_id(cell) != -1:
			Fx.dust(self, tiles.map_to_local(cell), 4)
		tiles.erase_cell(cell)


func _spawn_shelf(at: Vector2, span: float, shake: float, drop: float) -> void:
	var shelf := ASH_SHELF.instantiate() as AnimatableBody2D
	shelf.set(&"span", span)
	shelf.set(&"shake_time", shake)
	shelf.set(&"crumble_drop", drop)
	shelf.position = at
	add_child(shelf)


func _spawn_crawler(at: Vector2, speed: float) -> void:
	var crawler := _spawn(copperling_scene, at)
	if crawler == null:
		return
	crawler.set(&"speed", speed)
	crawler.set(&"direction", -1.0)


func _spawn_cache(at: Vector2) -> void:
	var cache := _spawn(cache_stone_scene, at)
	if cache != null:
		cache.connect(&"released", _on_cache_released)


func _spawn_gate(at: Vector2) -> void:
	var gate := _spawn(waygate_scene, at)
	if gate != null:
		gate.connect(&"reached", _on_waygate_reached)


## A lantern on the floor at `at`. Walking past it moves the respawn point there.
func _spawn_checkpoint(at: Vector2) -> void:
	var lantern := LANTERN.instantiate() as Node2D
	lantern.position = at
	add_child(lantern)
	lantern.connect(&"lit", _on_checkpoint_lit)


## A lore scroll on the floor at `at`, holding one scroll of this stage's lesson.
## A dormant scroll can't be read until it wakes (see `LoreScroll.pop_to`).
func _spawn_scroll(at: Vector2, scroll_id: String, dormant: bool = false) -> LoreScroll:
	if Lessons.scroll(scroll_id).is_empty():
		push_error("Unknown lore scroll %s" % scroll_id)
	var scroll := LORE_SCROLL.new() as LoreScroll
	scroll.scroll_id = scroll_id
	scroll.monitoring = not dormant
	scroll.position = at
	add_child(scroll)
	scroll.read.connect(_on_scroll_read)
	return scroll


## A carved slate centered over `at`, growing upward, with code on it.
func _spawn_sign(at: Vector2, text: String, tint: Color) -> LessonSign:
	var sign := LESSON_SIGN.new() as LessonSign
	sign.text = text
	sign.tint = tint
	sign.position = at
	add_child(sign)
	return sign


## A bumpable stone with a label; the caller handles `bumped`.
func _spawn_rune_block(at: Vector2, index: int, label: String, tint: Color) -> RuneBlock:
	var block := RUNE_BLOCK.new() as RuneBlock
	block.index = index
	block.label_text = label
	block.tint = tint
	block.position = at
	add_child(block)
	return block


func _spawn_key(at: Vector2, key_name: String) -> RuneKey:
	var key := RUNE_KEY.new() as RuneKey
	key.key_name = key_name
	key.position = at
	add_child(key)
	return key


## Holds the stage on a lesson card until the player reads it.
func _show_card(card: Dictionary) -> void:
	hud.open_card(card)


## A scroll the player has never read opens its card. One known from an
## earlier run is picked up without stopping play; the Spellbook has it.
func _on_scroll_read(scroll: LoreScroll) -> void:
	if _dying or scroll.taken:
		return
	var data := Lessons.scroll(scroll.scroll_id)
	var known := GameProgression.knows_scroll(scroll.scroll_id)
	scroll.take()
	GameProgression.learn_scroll(scroll.scroll_id)
	Telemetry.track("scroll_read", stage_index(), {"scroll": scroll.scroll_id, "known": known})
	_refresh_scrolls()
	if known:
		Fx.float_text(self, scroll.global_position + Vector2(-20.0, -8.0), str(data.get("title", "")), SCROLL_TINT)
		return
	_show_card({
		"kicker": "Lore scroll  -  %s" % Lessons.topic(stage_index()),
		"title": data.get("title", ""),
		"code": data.get("code", ""),
		"body": data.get("insight", ""),
		"tint": SCROLL_TINT,
	})


func _refresh_scrolls() -> void:
	hud.set_scrolls(GameProgression.known_scrolls(stage_index()).size(), Lessons.scroll_ids(stage_index()).size())


## The wizard's arena, starting at tile column `left` on `floor_row`: a flat
## run-up with a lantern, the duel's floor, and the run-out where the waygate
## stands past his barrier. Stages must be at least `arena_end(left)` wide.
func _build_arena(left: int, title: String, tint: Color, floor_row: int = 14) -> WizardDuel:
	_paint_solid(left - ARENA_RUN_UP, arena_end(left) - 1, floor_row)
	var floor_y := float(floor_row * TILE)
	_spawn_checkpoint(Vector2(float((left - 3) * TILE + 8), floor_y))
	var duel := WIZARD_DUEL.new() as WizardDuel
	duel.stage_id = stage_index()
	duel.title = title
	duel.tint = tint
	duel.taunt = str(Lessons.stage(stage_index()).get("taunt", ""))
	duel.hud = hud
	duel.player = player
	duel.stage_bounds = Rect2i(0, 0, _stage_width() * TILE, _stage_height() * TILE)
	duel.position = Vector2(float(left * TILE), floor_y)
	add_child(duel)
	duel.downed.connect(_kill_player)
	_duel = duel
	_spawn_gate(Vector2(float(left * TILE) + WizardDuel.WIZARD_X + 64.0, floor_y))
	return duel


## The first tile column past an arena that starts at `left`.
static func arena_end(left: int) -> int:
	return left + ARENA_TILES + ARENA_RUN_OUT


func duel() -> WizardDuel:
	return _duel


func _add_parallax(node_name: String, texture: Texture2D, scroll: Vector2, z: int, scale_factor: float = 4.0, tint: Color = Color.WHITE) -> void:
	var layer := Parallax2D.new()
	layer.name = node_name
	layer.scroll_scale = scroll
	layer.repeat_size = Vector2(float(texture.get_width()) * scale_factor, 0.0)
	layer.repeat_times = 4
	layer.z_index = z
	layer.follow_viewport = true
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.modulate = tint
	layer.add_child(sprite)
	add_child(layer)


## Darkens the bottom of the stage behind the tiles so every pit reads as a drop,
## whatever the backdrop paints at floor height.
func _add_abyss() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.01, 0.04, 0.0))
	gradient.set_color(1, Color(0.03, 0.01, 0.04, 0.96))
	gradient.add_point(0.45, Color(0.03, 0.01, 0.04, 0.7))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var abyss := Sprite2D.new()
	abyss.name = "Abyss"
	abyss.texture = texture
	abyss.centered = false
	abyss.z_index = -10
	abyss.position = Vector2(0.0, float(_stage_height() * TILE) - 56.0)
	abyss.scale = Vector2(float(_stage_width() * TILE) / 4.0, 1.0)
	add_child(abyss)


func _fit_fall_zone() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(_stage_width() * TILE) + 480.0, 80.0)
	fall_shape.shape = shape
	fall_zone.position = Vector2(float(_stage_width() * TILE) * 0.5, float(_stage_height() * TILE) + 64.0)


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


## Loose seeds plus one inside every unspent cache stone. Only this stage's
## own nodes count, since a stage being replaced can still be in the tree.
func _count_seeds() -> int:
	var total := 0
	for seed in get_tree().get_nodes_in_group(&"emberseed"):
		if is_ancestor_of(seed):
			total += 1
	for cache in get_tree().get_nodes_in_group(&"cache_stone"):
		if is_ancestor_of(cache) and not bool(cache.get(&"spent")):
			total += 1
	return total + _gadget_seeds()


## Seeds a stage's lesson gadget will hand out later, counted in the total.
func _gadget_seeds() -> int:
	return 0


func _touching_ember() -> bool:
	var origin := player.global_position
	for lift in [10.0, 6.0, 2.0]:
		var cell := tiles.local_to_map(tiles.to_local(origin + Vector2(0.0, lift)))
		if tiles.get_cell_source_id(cell) == StageTileset.SOURCE and tiles.get_cell_atlas_coords(cell) == StageTileset.EMBER:
			return true
	return false


func _on_cache_released(pickup: Node) -> void:
	_bind_seed(pickup)


func _on_seed_collected() -> void:
	hud.note_seed()


func _on_checkpoint_lit(at: Vector2) -> void:
	spawn.global_position = at


func _on_waygate_reached() -> void:
	if _departing or _cleared or _dying:
		return
	player.set_controls_enabled(false)
	player.velocity = Vector2.ZERO
	_clock_running = false
	hud.set_time(_elapsed)
	var new_best := GameProgression.mark_cleared(stage_index(), hud.seed_count, _elapsed)
	Telemetry.track("stage_clear", stage_index(), {
		"time": snappedf(_elapsed, 0.1),
		"seeds": hud.seed_count,
		"deaths": _deaths,
		"best": new_best,
	})
	Telemetry.flush()
	if next_stage == null:
		_cleared = true
		hud.show_clear(_elapsed, new_best)
		return
	_departing = true
	hud.show_passage(_passage_detail(), _elapsed, new_best)
	get_tree().create_timer(PASSAGE_TIMEOUT).timeout.connect(hud.request_continue)
	await hud.continue_requested
	if not is_inside_tree():
		return
	await hud.fade_to(1.0, 0.3).finished
	if GameProgression.came_from_map:
		get_tree().change_scene_to_file("res://levels/world_map.tscn")
	else:
		_open_next_stage()


func return_to_map() -> void:
	if not _cleared and not _departing:
		Telemetry.track("stage_quit", stage_index(), {
			"x": roundi(player.global_position.x),
			"elapsed": snappedf(_elapsed, 0.1),
			"deaths": _deaths,
		})
	GameProgression.came_from_map = true
	GameProgression.current_stage_id = stage_index()
	await hud.fade_to(1.0, 0.25).finished
	get_tree().change_scene_to_file("res://levels/world_map.tscn")


func _restart_stage() -> void:
	await hud.fade_to(1.0, 0.2).finished
	if get_tree().current_scene == self and scene_file_path != "":
		get_tree().change_scene_to_file(scene_file_path)
		return
	_respawn_player()


func _open_next_stage() -> void:
	if next_stage == null or not is_inside_tree():
		return
	if get_tree().current_scene == self:
		get_tree().change_scene_to_packed(next_stage)
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var next := next_stage.instantiate()
	parent_node.add_child(next)
	queue_free()


func _on_fall_zone_body_entered(body: Node2D) -> void:
	if body != player:
		return
	_kill_player()


## Knock-out hop, a short fade, then back to the last lantern.
func _kill_player() -> void:
	if _cleared or _departing:
		player.release_respawn_lock()
		return
	if _dying:
		return
	_dying = true
	Telemetry.track("death", stage_index(), {
		"x": roundi(player.global_position.x),
		"y": roundi(player.global_position.y),
		"duel": _duel != null and _duel.is_engaged(),
	})
	if _duel != null:
		_duel.call_off()
	_deaths += 1
	_death_serial += 1
	var serial := _death_serial
	hud.note_fall()
	GameProgression.note_death()
	player.play_death()
	await get_tree().create_timer(DEATH_HOLD).timeout
	if serial != _death_serial or not is_inside_tree():
		return
	await hud.fade_to(1.0, 0.15).finished
	if serial != _death_serial or not is_inside_tree():
		return
	_respawn_player()


func _respawn_player() -> void:
	if _cleared or _departing:
		player.release_respawn_lock()
		return
	_death_serial += 1
	_dying = false
	if _duel != null:
		# The wizard keeps his post, and the wards already broken stay broken.
		_duel.call_off()
	player.global_position = spawn.global_position
	player.revive()
	player.reset_camera()
	player.release_respawn_lock()
	if _deaths == Eggs.GOT_BETTER_FALLS:
		Fx.float_text(self, spawn.global_position + Vector2(-16.0, -8.0), Eggs.GOT_BETTER, Fx.SPARK, 0.8)
	get_tree().call_group(&"ash_shelf", &"reset_piece")
	get_tree().call_group(&"kiln_lift", &"reset_piece")
	hud.fade_to(0.0, 0.25)


func _start_music() -> void:
	audio.play_music(music_stream)
