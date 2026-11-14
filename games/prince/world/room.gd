class_name Room
extends Node2D

## One room of the palace, built from its entry in data/levels.json. The room
## is a Git working tree you can walk through: every torch, gate, bridge and
## spike field is drawn from (and collides by) its one-line file in `repo`.
## Touching a lever writes the file; the Dagger of HEAD (ui/console.gd) runs
## git on it. The Prince's place is kept per commit, so a reset or a switch
## carries him back to where he stood when that commit was last made.

const T := 16
const COLS := 30
const ROWS := 17
const VIEW := Vector2(480, 270)
const TILES := preload("res://assets/sprites/tiles.png")
const DOOR := preload("res://assets/sprites/door.png")
const VIZIER := preload("res://assets/sprites/vizier.png")
const TILE: Dictionary = {
	"stone": 0, "floor": 1, "spikes": 2, "plank": 3, "gate": 4, "holes": 5, "plate_up": 6, "plate_down": 7,
	"lever_off": 8, "lever_on": 9, "torch_dark": 10, "torch_a": 11, "torch_b": 12, "scroll": 13, "bar": 14, "gate_tip": 15,
}

## Tests set these: no waiting on cards, speeches or the rewind.
static var test_fast: bool = false

var level_id: int = 1
var level: Dictionary = {}
var repo: GitRepo
var prince: Prince
var hud: Hud
var console: Console
## opening, play, dagger, dead, rewind, cutscene, clear, timeout
var state: String = "opening"
var pad_wanted: bool:
	get: return state == "play"
var time_left: float = 0.0
var elapsed: float = 0.0
var deaths: int = 0
var commands_run: int = 0
## Commit id -> where the Prince last stood in it.
var spots: Dictionary = {}
var start: Vector2 = Vector2.ZERO

var _grid: PackedStringArray = []
var _legend: Dictionary = {}
var _fired: Dictionary = {}
var _touching: Dictionary = {}
var _clock: float = 0.0
var _backdrop: Texture2D
var _vizier_at: Vector2 = Vector2.ZERO
var _vizier_shown: bool = false
var _vizier_casting: bool = false
var _door_at: Vector2i = Vector2i(-1, -1)
var _audio: StageAudio


func _ready() -> void:
	add_to_group(&"room")
	# The tiles, the door and the Vizier are painted at two texels to a room
	# pixel; this keeps them sharp at any window scale.
	var sharp := ShaderMaterial.new()
	sharp.shader = Prince.SHARP
	material = sharp
	level = Story.level(level_id)
	repo = Steps.open_room(level)
	_grid = PackedStringArray(level.map)
	_legend = level.get("legend", {})
	time_left = float(level.get("time", 180))
	for row in ROWS:
		for col in COLS:
			var ch := _grid[row][col]
			if ch == "P":
				start = Vector2(col * T + T / 2.0, (row + 1) * T)
			elif ch == "V":
				_vizier_at = Vector2(col * T + T / 2.0, (row + 1) * T)
			elif ch == "E":
				_door_at = Vector2i(col, row)
	for sha: String in repo.commits:
		spots[sha] = start
	var art := "res://assets/backgrounds/%s.png" % level.get("backdrop", "hall")
	if ResourceLoader.exists(art):
		_backdrop = load(art) as Texture2D
	_vizier_shown = bool(level.get("boss", false))

	Sfx.warm()
	_audio = StageAudio.new()
	add_child(_audio)
	prince = Prince.new()
	prince.room = self
	prince.z_index = 2
	add_child(prince)
	prince.place(start)
	hud = Hud.new()
	hud.room = self
	add_child(hud)
	console = Console.new()
	console.room = self
	hud.add_child(console)
	console.hide()
	Sfx.music(self, "music_%s" % level.get("music", "room"))
	_open.call_deferred()


func _open() -> void:
	await hud.title_card()
	if state == "opening":
		state = "play"


# --- the room as files -------------------------------------------------------

func value(file: String) -> String:
	return repo.value(file)


func thing(col: int, row: int) -> Dictionary:
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return {}
	return _legend.get(_grid[row][col], {})


func is_solid(col: int, row: int) -> bool:
	if col < 0 or col >= COLS or row < 0:
		return true
	if row >= ROWS:
		return false
	var ch := _grid[row][col]
	if ch == "#":
		return true
	var what: Dictionary = _legend.get(ch, {})
	match String(what.get("type", "")):
		"bridge":
			return value(what.file) == "down"
		"gate":
			return value(what.file) != "open"
		"spikes":
			return true
	return false


## Whether a lever or plate has already done all it does.
func _is_set(what: Dictionary) -> bool:
	var sets: Dictionary = what.get("sets", {})
	for file: String in sets:
		if value(file) != String(sets[file]):
			return false
	return true


func _write(file: String, text: String) -> void:
	Steps.run(repo, level, ["set", file, text])


## Why the door is shut, in the room's words ("" when it's open).
func door_says() -> String:
	if Steps.exit_open(repo, level):
		return ""
	if level.files.has("door") and value("door") == "barred":
		return "Barred from the other side."
	var want: Dictionary = level.get("exit_when", {})
	for file: String in want:
		if value(file) != String(want[file]):
			return "Shut. It wants the %s %s." % [file.replace("_", " "), want[file]]
	if not repo.merging.is_empty():
		return "The door won't open in the middle of a merge."
	if repo.head != "main":
		return "The door opens only for main. This is %s." % repo.head
	return "The door opens only for sealed history. Commit first."


func door_frame() -> int:
	if Steps.exit_open(repo, level):
		return 1
	return 2 if level.files.has("door") and value("door") == "barred" else 0


# --- play --------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	position.x = floorf((get_viewport_rect().size.x - VIEW.x) / 2.0)
	queue_redraw()
	if state == "play":
		elapsed += delta
		time_left -= delta
		var dir := Input.get_axis(&"move_left", &"move_right")
		prince.step(delta, signf(dir) if absf(dir) > 0.3 else 0.0, Input.is_action_just_pressed(&"jump"), Input.is_action_pressed(&"jump"))
		if prince.jumped:
			Sfx.play(self, "jump")
		if prince.landed:
			Sfx.play(self, "land")
		_touch()
		if state != "play":
			return
		if time_left <= 0.0:
			_timeout()
		elif Input.is_action_just_pressed(&"dagger") and prince.on_floor:
			draw_dagger()
	elif state == "dead" or state == "cutscene":
		# He still falls, and lies where he lands.
		prince.step(delta, 0.0, false, false)
	elif state == "dagger":
		if not prince.alive:
			return
		if Input.is_action_just_pressed(&"dagger") or Input.is_action_just_pressed(&"pause"):
			sheathe()


## Everything the Prince's box is over: hazards first, then mechanisms.
func _touch() -> void:
	var rect := prince.box()
	if rect.position.y > ROWS * T:
		_die()
		return
	var now := {}
	var sign_text := ""
	for row in range(floori(rect.position.y / T), floori((rect.end.y - 0.001) / T) + 1):
		for col in range(floori(rect.position.x / T), floori((rect.end.x - 0.001) / T) + 1):
			if row < 0 or row >= ROWS or col < 0 or col >= COLS:
				continue
			var ch := _grid[row][col]
			# Spikes fill the lower part of their tile.
			var deep := rect.end.y > row * T + 6.0
			if ch == "^" and deep:
				_die()
				return
			var below: Dictionary = thing(col, row + 1)
			if String(below.get("type", "")) == "spikes" and value(below.file) == "armed" and deep:
				_die()
				return
			if level.get("signs", {}).has(ch):
				sign_text = level.signs[ch]
			if ch == "E":
				if Steps.exit_open(repo, level):
					_clear()
					return
				sign_text = door_says()
			var what: Dictionary = _legend.get(ch, {})
			if what.is_empty():
				continue
			var key := Vector2i(col, row)
			now[key] = true
			if _touching.has(key):
				continue
			match String(what.type):
				"torch":
					if value(what.file) != "lit":
						_write(what.file, "lit")
						Sfx.play(self, "torch")
				"plate", "lever":
					if not _is_set(what):
						for file: String in what.sets:
							_write(file, what.sets[file])
						Sfx.play(self, "lever")
						if "gate" in what.sets or "portcullis" in what.sets or "bridge" in what.sets:
							Sfx.play(self, "gate")
	_touching = now
	hud.sign_text = sign_text
	var triggers: Array = level.get("triggers", [])
	for index in triggers.size():
		if not _fired.has(index) and prince.on_floor and prince.pos.x >= float(triggers[index].col) * T:
			_fired[index] = true
			_cutscene(triggers[index])
			return


func _die() -> void:
	if state != "play":
		return
	state = "dead"
	deaths += 1
	prince.die()
	hud.sign_text = ""
	Sfx.play(self, "death")
	MusicDirector.duck(true)
	if not test_fast:
		await get_tree().create_timer(0.9).timeout
	if state == "dead":
		draw_dagger()


func _timeout() -> void:
	state = "timeout"
	Sfx.play(self, "death")
	await hud.card("The sands ran out", "The Vizier's hourglass is empty. The room starts over.", 2.4)
	Main.play(get_tree(), level_id)


## The Vizier (or anyone) steps in, speaks, and runs their steps.
func _cutscene(trigger: Dictionary) -> void:
	state = "cutscene"
	hud.sign_text = ""
	_vizier_shown = true
	_vizier_casting = true
	Sfx.play(self, "vizier")
	var lines: Array = trigger.get("say", [])
	var who: String = Story.data().cast[trigger.get("who", "vizier")].full
	if not lines.is_empty():
		await hud.say(who, lines[0])
	for step: Array in trigger.get("steps", []):
		var result := Steps.run(repo, level, step)
		if not result.is_empty():
			spots[repo.head_sha()] = prince.pos
			hud.toast(result)
			Sfx.play(self, "gate")
	for index in range(1, lines.size()):
		await hud.say(who, lines[index])
	_vizier_casting = false
	if trigger.get("flee", false):
		_vizier_shown = false
		Sfx.play(self, "rewind")
	state = "play"


func _clear() -> void:
	state = "clear"
	hud.sign_text = ""
	Progress.clear(level_id, elapsed)
	Sfx.play(self, "clear")
	hud.clear_card()


# --- the dagger --------------------------------------------------------------

func draw_dagger() -> void:
	if state != "play" and state != "dead":
		return
	state = "dagger"
	prince.dagger_up = prince.alive
	prince.queue_redraw()
	Sfx.play(self, "draw")
	console.open()


func sheathe() -> void:
	if state != "dagger" or not prince.alive:
		return
	console.hide()
	prince.dagger_up = false
	prince.queue_redraw()
	# Jump may be the key that closed it; don't leap on the way out.
	Input.action_release(&"jump")
	state = "play"


## Runs one of the dagger's steps (see git/steps.gd) and plays what it did to
## the room. Returns git's result.
func run_git(step: Array) -> Dictionary:
	var before := repo.head_sha()
	var result := Steps.run(repo, level, step)
	if result.is_empty():
		return result
	commands_run += 1
	var ok := int(result.exit) == 0
	hud.toast(result)
	match String(step[0]):
		"commit", "revert", "commit_merge":
			if ok:
				spots[repo.head_sha()] = prince.pos
				Sfx.play(self, "commit")
			else:
				Sfx.play(self, "error")
		"merge":
			if ok:
				spots[repo.head_sha()] = prince.pos
				Sfx.play(self, "commit")
			else:
				Sfx.play(self, "conflict" if not repo.merging.is_empty() else "error")
		"reset", "switch":
			if ok and (String(step[0]) == "reset" or repo.head_sha() != before or not prince.alive):
				_rewind()
			elif ok:
				Sfx.play(self, "draw")
			else:
				Sfx.play(self, "error")
		"switch_c", "resolve", "merge_abort":
			Sfx.play(self, "draw" if ok else "error")
	return result


## The sands run backward: the Prince is carried to where he stood in HEAD.
func _rewind() -> void:
	state = "rewind"
	console.hide()
	Sfx.play(self, "rewind")
	MusicDirector.duck(false)
	hud.rewind()
	if not test_fast:
		await get_tree().create_timer(0.35).timeout
	prince.place(spots.get(repo.head_sha(), start))
	prince.dagger_up = false
	_touching = {}
	_mark_touching()
	if not test_fast:
		await get_tree().create_timer(0.35).timeout
	state = "play"


## After a rewind, whatever he lands on doesn't fire until he steps off it.
func _mark_touching() -> void:
	var rect := prince.box()
	for row in range(floori(rect.position.y / T), floori((rect.end.y - 0.001) / T) + 1):
		for col in range(floori(rect.position.x / T), floori((rect.end.x - 0.001) / T) + 1):
			if not thing(col, row).is_empty():
				_touching[Vector2i(col, row)] = true


# --- drawing -----------------------------------------------------------------

func _tile(name: String, col: int, row: int, tint: Color = Color.WHITE, lift: float = 0.0) -> void:
	# The sheet is painted at two texels to a room pixel, each 32-texel tile
	# in a 34-texel cell with its edges repeated (tools/paint.py).
	draw_texture_rect_region(TILES, Rect2(col * T, row * T - lift, T, T), Rect2(TILE[name] * 34 + 1, 1, 32, 32), tint)


func _draw() -> void:
	var margin := position.x
	draw_rect(Rect2(-margin, 0, VIEW.x + margin * 2.0, VIEW.y + 2.0), Palette.NIGHT)
	if _backdrop != null:
		draw_texture_rect(_backdrop, Rect2(Vector2.ZERO, VIEW), false, Color(0.62, 0.64, 0.78))
	var flick := int(_clock * 8.0) % 2 == 0
	var dirty := repo.modified()
	# The palace carries on past the room's edges when the view is wider.
	for col in range(-ceili(margin / T), COLS + ceili(margin / T)):
		if col >= 0 and col < COLS:
			continue
		for row in ROWS:
			_tile("stone", col, row, Color(0.7, 0.7, 0.8))
	for row in ROWS:
		for col in COLS:
			var ch := _grid[row][col]
			if ch == "#":
				_tile("stone" if row == 0 or _grid[row - 1][col] == "#" else "floor", col, row)
				continue
			if ch == "^":
				_tile("spikes", col, row)
				continue
			if level.get("signs", {}).has(ch):
				_tile("scroll", col, row)
				continue
			var what: Dictionary = _legend.get(ch, {})
			if what.is_empty():
				continue
			var changed := false
			match String(what.type):
				"torch":
					var lit := value(what.file) == "lit"
					if lit:
						draw_circle(Vector2(col * T + 8, row * T + 4), 22.0 + (1.0 if flick else 0.0), Color(1.0, 0.7, 0.25, 0.1))
						draw_circle(Vector2(col * T + 8, row * T + 4), 11.0, Color(1.0, 0.8, 0.4, 0.12))
					_tile(("torch_a" if flick else "torch_b") if lit else "torch_dark", col, row)
					changed = what.file in dirty
				"plate":
					_tile("plate_down" if _is_set(what) else "plate_up", col, row)
				"lever":
					_tile("lever_on" if _is_set(what) else "lever_off", col, row)
				"bridge":
					_tile("plank", col, row, Color.WHITE if value(what.file) == "down" else Color(1, 1, 1, 0.16))
					changed = what.file in dirty and (col == 0 or _grid[row][col - 1] != ch)
				"spikes":
					_tile("holes", col, row)
					if value(what.file) == "armed":
						_tile("spikes", col, row - 1)
					changed = what.file in dirty and (col == 0 or _grid[row][col - 1] != ch)
				"gate":
					var state_now := value(what.file)
					var top := row == 0 or _grid[row - 1][col] != ch
					if state_now == "open":
						if top:
							_tile("gate_tip", col, row)
					elif state_now == "conflict":
						# Two timelines in one gate: it flickers between them.
						_tile("gate", col, row, Color(0.5, 1.0, 0.95, 0.9) if flick else Color(1.0, 0.45, 0.5, 0.55))
					else:
						_tile("gate", col, row)
						if state_now == "barred" and not top:
							_tile("bar", col, row)
					changed = what.file in dirty and top
			if changed:
				_draw_changed(col, row)
	if _door_at.x >= 0:
		draw_texture_rect_region(DOOR, Rect2(_door_at.x * T - 4, (_door_at.y - 1) * T, 24, 32), Rect2(door_frame() * 48, 0, 48, 64))
	if _vizier_shown:
		var frame := 1 if _vizier_casting else 0
		var bob := sin(_clock * 2.0) * 1.0
		draw_texture_rect_region(VIZIER, Rect2(_vizier_at.x - 12, _vizier_at.y - 40 + bob, 24, 40), Rect2(frame * 48, 0, 48, 80))


## A grain of loose sand over anything changed since the last commit.
func _draw_changed(col: int, row: int) -> void:
	var at := Vector2(col * T + 8, row * T - 5 + sin(_clock * 5.0) * 1.5)
	draw_colored_polygon(PackedVector2Array([at + Vector2(0, -3), at + Vector2(3, 0), at + Vector2(0, 3), at + Vector2(-3, 0)]), Palette.SAND)
	draw_rect(Rect2(at - Vector2(0.5, 0.5), Vector2(1, 1)), Palette.INK)
