class_name Stage
extends Node2D

## What every stage shares: the two flatmates and whose head you're in, the
## camera, the tiles, falls and Wi-Fi routers, biscuits, the laptops and the
## script runner, the inner voice, and the way out. Both flatmates have to
## reach the way out to clear a stage.
##
## A stage script overrides `_build()` to paint its rooms and place its
## gadgets, using the helpers below. Positions are in tiles unless a name
## says otherwise: `tile(x, row)` is the bottom-center of a tile, where a
## gadget or a flatmate's feet stand.

const TILE := 16
const ROWS := 17
const FLOOR_ROW := 14
## A flatmate this close to a laptop or a switch can use it.
const REACH := 18.0
## How far below the stage counts as a fall.
const FALL_MARGIN := 24.0
const FLATMATE := preload("res://actors/flatmate.gd")
const HUD := preload("res://ui/hud.gd")
const EDITOR := preload("res://ui/editor.gd")

## Set by the stage script.
var stage_id: int = 1
var width: int = 80
## "clive" or "jazz": whose head you start in.
var starts_as: String = "clive"
var theme_row: int = 0
var music: AudioStream
## Parallax layers, far to near: [texture path, scroll, tint].
var backdrop: Array = []
var sky_color: Color = Color(0.11, 0.1, 0.13)

var clive: Flatmate
var jazz: Flatmate
var active: Flatmate
var runner: JsRunner
var hud: Hud
var editor: LaptopScreen
var tiles: TileMapLayer
var camera: Camera2D

var _names: Dictionary = {}
var _laptops: Array[Laptop] = []
var _switches: Array[Switch] = []
var _gadgets: Array[Gadget] = []
var _routers: Array[Marker] = []
var _exit: Marker
var _respawn: Dictionary = {}
## Where each flatmate drifts when you leave his head: {who: [Vector2...]}.
var _comforts: Dictionary = {"clive": [], "jazz": []}
## Inner-voice triggers: {x, who, card or line, done}.
var _thoughts: Array[Dictionary] = []
var _biscuits: int = 0
var _biscuit_total: int = 0
var _runs: int = 0
var _falls: int = 0
var _elapsed: float = 0.0
var _clock_on: bool = false
var _cleared: bool = false
var _audio_locked: bool = false
var _swap_count: int = 0


func _ready() -> void:
	add_to_group(&"stage")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_make_world()
	_build()
	_after_build()


# --- Overrides --------------------------------------------------------------

func _build() -> void:
	push_error("Stage is missing its layout")


## Per-frame stage logic (a train that leaves, a tannoy that listens).
func _tick(_delta: float) -> void:
	pass


## A stage can answer a console line (the tannoy reads them out).
func _heard_log(_text: String) -> void:
	pass


## The line on the results card under "Stage clear".
func _clear_line() -> String:
	return "Both of you made it out."


# --- Setup ------------------------------------------------------------------

func _make_world() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	var fill := ColorRect.new()
	fill.color = sky_color
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(fill)
	tiles = TileMapLayer.new()
	tiles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sheet := load("res://assets/sprites/tiles.png") as Texture2D
	tiles.tile_set = Tiles.build(sheet, sheet.get_height() / TILE)
	add_child(tiles)
	runner = JsRunner.new()
	runner.world = self
	add_child(runner)
	runner.logged.connect(_on_logged)
	clive = _make_flatmate("clive", 150.0, -330.0)
	jazz = _make_flatmate("jazz", 165.0, -440.0)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	hud = HUD.new() as Hud
	add_child(hud)
	editor = EDITOR.new() as LaptopScreen
	add_child(editor)
	editor.run_requested.connect(_run_laptop)


func _make_flatmate(who: String, run_speed: float, jump: float) -> Flatmate:
	var mate := FLATMATE.new() as Flatmate
	mate.who = who
	mate.name = who.capitalize()
	mate.speed = run_speed
	mate.jump_velocity = jump
	mate.sheet = load("res://assets/sprites/%s.png" % who) as Texture2D
	mate.jump_sound = preload("res://assets/audio/jump.wav")
	mate.strum_sound = preload("res://assets/audio/strum.wav") if ResourceLoader.exists("res://assets/audio/strum.wav") else preload("res://assets/audio/pickup.wav")
	mate.stage = self
	add_child(mate)
	mate.fell.connect(_on_fell.bind(mate))
	_names[who] = mate
	return mate


func _after_build() -> void:
	for layer_index in backdrop.size():
		var layer: Array = backdrop[layer_index]
		if ResourceLoader.exists(str(layer[0])):
			_add_parallax(load(str(layer[0])) as Texture2D, float(layer[1]), -40 + layer_index * 10, layer[2] if layer.size() > 2 else Color.WHITE)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = width * TILE
	camera.limit_bottom = ROWS * TILE
	active = clive if starts_as == "clive" else jazz
	clive.set_active(active == clive)
	jazz.set_active(active == jazz)
	_respawn = {"clive": clive.global_position, "jazz": jazz.global_position}
	camera.global_position = active.global_position
	camera.reset_smoothing()
	hud.set_stage(Progress.stage(stage_id).get("name", ""), Lessons.lesson(stage_id))
	hud.set_biscuits(0, _biscuit_total)
	hud.set_pov(active.who)
	hud.paused_changed.connect(_on_pause_changed)
	hud.map_requested.connect(_to_map)
	hud.restart_requested.connect(_restart)
	if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
		_audio_locked = true
		hud.show_press_to_start()
		get_tree().paused = true
	else:
		_begin()


func _begin() -> void:
	_clock_on = true
	if music != null:
		MusicDirector.play(music)


func _unhandled_input(event: InputEvent) -> void:
	if _audio_locked and event.is_pressed() and not event.is_echo():
		_audio_locked = false
		StageAudio.web_audio_unlocked = true
		get_tree().paused = false
		hud.hide_press_to_start()
		_begin()
		get_viewport().set_input_as_handled()


# --- Play -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _cleared:
		return
	if _clock_on:
		_elapsed += delta
		hud.set_time(_elapsed)
	if Input.is_action_just_pressed(&"swap"):
		swap()
	if Input.is_action_just_pressed(&"edit"):
		use()
	for mate: Flatmate in [clive, jazz]:
		if mate.global_position.y > ROWS * TILE + FALL_MARGIN and not mate._frozen:
			_fall(mate)
	_watch_routers()
	_watch_thoughts()
	_watch_exit()
	_update_prompt()
	_tick(delta)


func _process(_delta: float) -> void:
	if active != null:
		var lead := Vector2(active.facing() * 20.0, -12.0)
		camera.global_position = active.global_position + lead
	hud.track_other(_other(), camera)


func _other() -> Flatmate:
	return jazz if active == clive else clive


## Into the other flatmate's head.
func swap() -> void:
	if _cleared or get_tree().paused:
		return
	var left := active
	active.set_active(false)
	active = _other()
	active.set_active(true)
	_swap_count += 1
	_drift(left)
	camera.position_smoothing_speed = 4.0
	get_tree().create_timer(0.6).timeout.connect(func() -> void: camera.position_smoothing_speed = 7.0)
	hud.set_pov(active.who)
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
	if _swap_count <= 1 or randf() < 0.35:
		think(active.who, Voice.swap_line(active.who))


## Left to himself, with nothing on his to-do list, a flatmate wanders
## back to the nearest comfort spot he can walk to without a jump: Jazz to
## a sofa, Clive to an armchair. So nobody stays on a plate unless a script
## put him there.
func _drift(mate: Flatmate) -> void:
	# Busy with a script, or already at the way out: he stays put.
	if mate.is_busy() or (_exit != null and _exit.holds(mate)):
		return
	var best := Vector2.INF
	for spot: Vector2 in _comforts.get(mate.who, []):
		if absf(spot.x - mate.global_position.x) < absf(best.x - mate.global_position.x) and _walkable(mate.global_position, spot):
			best = spot
	if best == Vector2.INF or absf(best.x - mate.global_position.x) < 6.0:
		return
	var marker := Node2D.new()
	add_child(marker)
	marker.global_position = best
	mate.js_call("reach", [marker])
	speech(mate, Voice.drift_line(mate.who))
	get_tree().create_timer(8.0).timeout.connect(marker.queue_free)


## True when the floor runs unbroken from `from` to `to` at the feet's level
## (no gap, no step up), so a plain walk gets there.
func _walkable(from: Vector2, to: Vector2) -> bool:
	if absf(from.y - to.y) > 4.0:
		return false
	var row := int(floor((from.y + 8.0 + 2.0) / TILE))
	var a := int(floor(minf(from.x, to.x) / TILE))
	var b := int(floor(maxf(from.x, to.x) / TILE))
	for x in range(a, b + 1):
		if tiles.get_cell_source_id(Vector2i(x, row)) == -1:
			return false
		if tiles.get_cell_source_id(Vector2i(x, row - 1)) != -1:
			return false
	return true


## Use: open a laptop, pull a lever, ring a bell. Whatever is closest.
func use() -> void:
	if _cleared or get_tree().paused or editor.just_closed():
		return
	var laptop := _nearest(_laptops, active) as Laptop
	if laptop != null:
		editor.open(laptop, active.who)
		return
	var switch := _nearest(_switches, active) as Switch
	if switch != null:
		active._pose = Flatmate.FRAME_PRESS
		active._pose_time = 0.3
		switch.use(active)


func _nearest(list: Array, mate: Flatmate) -> Node2D:
	var best: Node2D = null
	var best_d := REACH
	for node: Node2D in list:
		var d := absf(node.global_position.x - mate.global_position.x)
		if d <= best_d and absf(node.global_position.y - (mate.global_position.y + 8.0)) <= 20.0:
			best = node
			best_d = d
	return best


func _update_prompt() -> void:
	var laptop := _nearest(_laptops, active) as Laptop
	if laptop != null:
		hud.prompt("%s: open %s" % [Controls.label(&"edit"), laptop.program.file_name])
		return
	var switch := _nearest(_switches, active) as Switch
	if switch != null:
		hud.prompt("%s: %s" % [Controls.label(&"edit"), {Switch.Look.LEVER: "pull the lever", Switch.Look.BELL: "ring the bell", Switch.Look.BUTTON: "press the button"}[switch.look]])
		return
	hud.prompt("")


## A script's run button. The script is for the flatmate it names, so if
## the player is in his head they swap out first. He goes back to the
## laptop's home spot, the things the laptop resets go back, and it runs.
func _run_laptop(laptop: Laptop) -> void:
	var program := laptop.program
	var mate := _names.get(program.runs_on) as Flatmate
	runner.stop()
	if mate == active:
		swap()
	for node in laptop.resets:
		if is_instance_valid(node) and node.has_method(&"reset_piece"):
			node.call(&"reset_piece")
	if mate != null:
		mate.clear_steps()
		if laptop.home != Vector2.INF and mate.global_position.distance_to(laptop.home) > 4.0:
			Fx.dust(self, mate.global_position, 6)
			mate.place(laptop.home)
			Fx.dust(self, laptop.home, 6)
	_runs += 1
	laptop.runs += 1
	hud.clear_console()
	hud.console("> node %s" % program.file_name, &"cmd")
	_on_run(laptop)
	runner.run(program)


## A stage can get ready for a run, just before its first line.
func _on_run(_laptop: Laptop) -> void:
	pass


func _on_logged(text: String, kind: StringName) -> void:
	hud.console(text, kind)
	if kind == &"error":
		StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
		think(active.who, Voice.error_line(active.who))
	_heard_log(text)


# --- Called by flatmates ----------------------------------------------------

## press(): uses the switch he is standing at, if any.
func press_at(mate: Flatmate) -> void:
	var switch := _nearest(_switches, mate) as Switch
	if switch != null:
		switch.use(mate)
	else:
		speech(mate, "Nothing to press here.")


## strum(): every gadget in earshot hears it.
func strum_at(mate: Flatmate) -> void:
	Fx.sparks(self, mate.global_position + Vector2(mate.facing() * 6.0, -6.0), Palette.JS, 6, 40.0)
	for gadget in _gadgets:
		if is_instance_valid(gadget) and gadget.global_position.distance_to(mate.global_position) <= 72.0:
			gadget.hear_strum(mate)


func speech(mate: Flatmate, text: String) -> void:
	hud.speech(mate, text)


func speech_at(at: Vector2, text: String) -> void:
	Fx.float_text(self, at + Vector2(-text.length() * 2.5, 0.0), text, Palette.PAPER, 1.4)


## The inner voice: what `who` is thinking, shown only from inside his head.
func think(who: String, line: String) -> void:
	if line == "":
		return
	if who == active.who:
		hud.inner_voice(who, line)


func js_lookup(name: String) -> Variant:
	return _names.get(name, null)


## Lets scripts name something that isn't a gadget, like an array of amps.
func define(name: String, value: Variant) -> void:
	_names[name] = value


# --- Falls, routers, thoughts, the exit --------------------------------------

func _fall(mate: Flatmate) -> void:
	_falls += 1
	Progress.note_fall()
	if mate != active:
		runner.stop()
	mate.play_fall()
	if mate == active:
		think(mate.who, Voice.fall_line(mate.who, _falls))


func _on_fell(mate: Flatmate) -> void:
	mate.place(_respawn.get(mate.who, Vector2(48, 200)))
	Fx.dust(self, mate.global_position, 6)


func _watch_routers() -> void:
	for router in _routers:
		if router.lit:
			continue
		for mate: Flatmate in [clive, jazz]:
			if absf(mate.global_position.x - router.global_position.x) < 12.0 and absf(mate.global_position.y + 8.0 - router.global_position.y) < 24.0:
				router.lit = true
				_respawn["clive"] = router.global_position + Vector2(-10, -8)
				_respawn["jazz"] = router.global_position + Vector2(10, -8)
				Fx.float_text(self, router.global_position + Vector2(-20, -14), "Wi-Fi: connected", Palette.GREEN)
				break


func _watch_thoughts() -> void:
	for entry in _thoughts:
		if entry["done"] or active.global_position.x < float(entry["x"]):
			continue
		if entry["who"] != "" and entry["who"] != active.who:
			continue
		entry["done"] = true
		if entry.has("card"):
			var card := Lessons.card(str(entry["card"]))
			if not card.is_empty():
				Progress.hear_thought(str(entry["card"]))
				hud.open_card(card)
		else:
			think(active.who, str(entry["line"]))


func _watch_exit() -> void:
	if _exit == null:
		return
	var inside := _exit.count_inside()
	_exit.lit = inside > 0
	if inside >= 2:
		_clear()


## Clears the stage: both flatmates made it.
func _clear() -> void:
	_cleared = true
	_clock_on = false
	runner.stop()
	for mate: Flatmate in [clive, jazz]:
		mate.clear_steps()
		mate.set_active(false)
	StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
	var at := _exit.global_position if _exit != null else active.global_position
	Fx.sparks(self, at + Vector2(0, -20), Palette.JS, 18, 90.0)
	var best := Progress.mark_cleared(stage_id, _biscuits, _elapsed)
	await get_tree().create_timer(0.6).timeout
	hud.show_results(_clear_line(), [
		["Time", Progress.format_time(_elapsed) + ("  best!" if best else "")],
		["Custard creams", "%d / %d" % [_biscuits, _biscuit_total]],
		["Scripts run", str(_runs)],
		["Falls", str(_falls)],
	], stage_id == Progress.count())
	await hud.continue_requested
	_to_map()


func _to_map() -> void:
	runner.stop()
	get_tree().paused = false
	await hud.fade(1.0, 0.3)
	get_tree().change_scene_to_file("res://ui/line_map.tscn")


func _restart() -> void:
	runner.stop()
	get_tree().paused = false
	await hud.fade(1.0, 0.2)
	Main.play_stage(get_tree(), stage_id)


func _on_pause_changed(paused: bool) -> void:
	get_tree().paused = paused


# --- Building helpers -------------------------------------------------------

## Bottom-center of tile (x, row), in pixels: where feet and gadgets stand.
static func tile(x: float, row: float) -> Vector2:
	return Vector2(x * TILE + TILE * 0.5, row * TILE)


## Top-left corner of tile (x, row), in pixels.
static func corner(x: float, row: float) -> Vector2:
	return Vector2(x * TILE, row * TILE)


## Solid ground from column `from` to `to` with its top at `top`.
func ground(from: int, to: int, top: int = FLOOR_ROW) -> void:
	for x in range(from, to + 1):
		tiles.set_cell(Vector2i(x, top), Tiles.SOURCE, Vector2i(Tiles.FLOOR, theme_row))
		for y in range(top + 1, ROWS):
			tiles.set_cell(Vector2i(x, y), Tiles.SOURCE, Vector2i(Tiles.FILL, theme_row))


## A wall or block, columns from..to, rows top..bottom, all solid.
func block(from: int, to: int, top: int, bottom: int) -> void:
	for x in range(from, to + 1):
		for y in range(top, bottom + 1):
			tiles.set_cell(Vector2i(x, y), Tiles.SOURCE, Vector2i(Tiles.FLOOR if y == top else Tiles.FILL, theme_row))


## A shelf you stand on, one tile thick.
func shelf(from: int, to: int, row: int) -> void:
	for x in range(from, to + 1):
		tiles.set_cell(Vector2i(x, row), Tiles.SOURCE, Vector2i(Tiles.SHELF, theme_row))


## A plank you can jump up through.
func plank(from: int, to: int, row: int) -> void:
	for x in range(from, to + 1):
		tiles.set_cell(Vector2i(x, row), Tiles.SOURCE, Vector2i(Tiles.PLANK, theme_row))


## A ceiling: fill from the top of the stage down to `bottom`.
func roof(from: int, to: int, bottom: int) -> void:
	for x in range(from, to + 1):
		for y in range(0, bottom + 1):
			tiles.set_cell(Vector2i(x, y), Tiles.SOURCE, Vector2i(Tiles.FILL if y < bottom else Tiles.SHELF, theme_row))


func place(who: String, x: float, row: float = FLOOR_ROW) -> void:
	var mate := _names[who] as Flatmate
	mate.global_position = tile(x, row) + Vector2(0, -8)


func add_gadget(gadget: Gadget, at: Vector2) -> Gadget:
	gadget.position = at
	gadget.stage = self
	add_child(gadget)
	_gadgets.append(gadget)
	if gadget.js_name != "":
		_names[gadget.js_name] = gadget
	if gadget is Switch:
		_switches.append(gadget as Switch)
	return gadget


func add_slab(name: String, x: int, row: int, size: Vector2i, look: Slab.Look, on: bool = true) -> Slab:
	var slab := Slab.new()
	slab.js_name = name
	slab.size_tiles = size
	slab.look = look
	slab.on = on
	return add_gadget(slab, corner(x, row)) as Slab


func add_plate(name: String, x: int, row: int = FLOOR_ROW, wide: int = 1, holds: Array[Slab] = []) -> Plate:
	var plate := Plate.new()
	plate.js_name = name
	plate.width_tiles = wide
	plate.holds = holds
	return add_gadget(plate, corner(x, row)) as Plate


func add_switch(name: String, x: int, row: int, look: Switch.Look, event: String, holds: Array[Slab] = []) -> Switch:
	var switch := Switch.new()
	switch.js_name = name
	switch.look = look
	switch.event = event
	switch.holds = holds
	return add_gadget(switch, tile(x, row)) as Switch


func add_lift(name: String, x: int, row: int, wide: int, step: int, top: int, look: Lift.Look = Lift.Look.LIFT) -> Lift:
	var lift := Lift.new()
	lift.js_name = name
	lift.width_tiles = wide
	lift.step_tiles = step
	lift.top_floor = top
	lift.look = look
	return add_gadget(lift, corner(x, row)) as Lift


func add_spot(name: String, x: float, row: int, look: Spot.Look = Spot.Look.NONE, caption: String = "") -> Spot:
	var spot := Spot.new()
	spot.js_name = name
	spot.look = look
	spot.caption = caption
	return add_gadget(spot, tile(x, row)) as Spot


## A laptop at column x running `program`; its flatmate starts runs at home_x.
func add_laptop(x: float, row: int, program: JsProgram, home_x: float, home_row: int, hint: String) -> Laptop:
	var laptop := Laptop.new()
	laptop.program = program
	laptop.home = tile(home_x, home_row) + Vector2(0, -8)
	laptop.hint = hint
	laptop.position = tile(x, row)
	laptop.stage = self
	add_child(laptop)
	_laptops.append(laptop)
	return laptop


func add_biscuit(x: float, row: float) -> void:
	var biscuit := Biscuit.new()
	biscuit.position = tile(x, row) + Vector2(0, -6)
	add_child(biscuit)
	_biscuit_total += 1
	biscuit.taken.connect(func() -> void:
		_biscuits += 1
		hud.set_biscuits(_biscuits, _biscuit_total))


func add_router(x: float, row: int = FLOOR_ROW) -> void:
	var router := Marker.new()
	router.kind = Marker.Kind.ROUTER
	router.position = tile(x, row)
	add_child(router)
	_routers.append(router)


func add_exit(x: float, row: int, caption: String) -> void:
	_exit = Marker.new()
	_exit.kind = Marker.Kind.EXIT
	_exit.caption = caption
	_exit.position = tile(x, row)
	add_child(_exit)


## A lesson card when `who` (or either, for "") first walks past column x.
func card_at(x: float, card: String, who: String = "") -> void:
	_thoughts.append({"x": x * TILE, "who": who, "card": card, "done": Progress.knows_thought(card)})


## A one-line inner-voice thought when `who` walks past column x.
func thought_at(x: float, who: String, line: String) -> void:
	_thoughts.append({"x": x * TILE, "who": who, "line": line, "done": false})


## A comfort spot for `who`: where he drifts when left alone. Drawn as a
## sofa (Jazz) or an armchair (Clive), or nothing if `look` is "".
func comfort(who: String, x: float, row: int = FLOOR_ROW, look: String = "auto") -> void:
	_comforts[who].append(tile(x, row) + Vector2(0, -8))
	if look == "auto":
		look = "sofa" if who == "jazz" else "armchair"
	if look != "":
		var seat := Furniture.new()
		seat.kind = look
		seat.position = tile(x, row)
		add_child(seat)


## Set dressing: a piece of `Furniture` standing on tile (x, row).
func furnish(kind: String, x: float, row: int = FLOOR_ROW) -> void:
	var piece := Furniture.new()
	piece.kind = kind
	piece.position = tile(x, row)
	add_child(piece)


## A painted prop behind the action, bottom-center at (x, row).
func prop(texture_path: String, x: float, row: float, z: int = -3) -> Sprite2D:
	if not ResourceLoader.exists(texture_path):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5)
	sprite.position = tile(x, row)
	sprite.z_index = z
	add_child(sprite)
	return sprite


func _add_parallax(texture: Texture2D, scroll: float, z: int, tint: Color) -> void:
	var layer := Parallax2D.new()
	layer.scroll_scale = Vector2(scroll, scroll * 0.3)
	layer.repeat_size = Vector2(float(texture.get_width()) * 2.0, 0.0)
	layer.repeat_times = 4
	layer.z_index = z
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(2.0, 2.0)
	sprite.modulate = tint
	sprite.position = Vector2(0, float(ROWS * TILE) - texture.get_height() * 2.0)
	layer.add_child(sprite)
	add_child(layer)
