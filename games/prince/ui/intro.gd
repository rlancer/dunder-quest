class_name Intro
extends Control

## The prologue, before the first room: who keeps the palace ledger, who
## hates it, and what the dagger does. It is also the game's answer to "what
## is Git?": every beat pairs a line of the story with the Git word for it.
##
## The ledger on screen is a real GitRepo (git/repo.gd), so the grains, the
## ids and the output lines are the ones the real git would give; the last
## beats seal a torch and fall on the spikes with the same model the rooms
## use. Any key or tap moves on; Skip (or Esc) goes straight to the room.

const VIEW := Vector2(480, 270)
## Where the cast stands, and where the text panel starts.
const FLOOR := 190.0
const PANEL := 196.0
const BAR := 22.0
## Letters a second.
const TYPE := 46.0
const VIZIER := preload("res://assets/sprites/vizier.png")
const PRINCESS := preload("res://assets/sprites/princess.png")

## The hall beat's clock: light a torch, seal it, light another, fall, reset.
const HALL_FLOOR := 172.0
const HALL_START := 20.0
const HALL_TORCH_1 := 140.0
const HALL_TORCH_2 := 262.0
const HALL_PIT := 376.0
const T_TORCH_1 := 1.2
const T_SEAL := 2.3
const T_RUN := 3.6
const T_DIE := 5.0
const T_RESET := 6.6
const T_TORCH_2 := T_RUN + (T_DIE - T_RUN) * (HALL_TORCH_2 - HALL_TORCH_1) / (HALL_PIT - HALL_TORCH_1)

## The room to open afterwards; 0 goes back to the title.
static var then: int = 1

## The bot sets this and turns the pages itself.
var driven: bool = false
var ledger: GitRepo
var hall: GitRepo

var _beats: Array = []
var _index: int = -1
var _t: float = 0.0
var _clock: float = 0.0
var _fired: int = 0
var _quiet: bool = false
var _art: Dictionary = {}
var _leaving: bool = false
var _pressed_at: float = -1.0
var _shake: float = 0.0
var _rewind: float = 0.0
var _black: float = 1.0
var _who: Label
var _body: Label
var _git: Label
var _skip: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(StageAudio.new())
	for name in ["title", "hall", "gate", "dungeon"]:
		var path := "res://assets/backgrounds/%s.png" % name
		if ResourceLoader.exists(path):
			_art[name] = load(path)
	ledger = GitRepo.new()
	ledger.init({"east_torch": "dark", "garden_gate": "shut", "bridge": "up", "spikes": "safe", "tower_door": "open"},
		"The palace as it stood", "palace")
	hall = GitRepo.new()
	hall.init({"torch_1": "dark", "torch_2": "dark"}, "The hall as it stood", "palace")
	_beats = _script()
	_who = _label(11, Palette.pixel(), Palette.GREEN)
	_body = _label(11, Palette.pixel(), Palette.PAPER)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_git = _label(14, Palette.mono(), Palette.TEAL.lightened(0.4))
	_git.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip = Button.new()
	_skip.text = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override(&"font_size", 9)
	_skip.pressed.connect(finish)
	add_child(_skip)
	Sfx.warm()
	Sfx.music(self, "music_title")
	_show(0)


func _label(size: int, font: Font, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_constant_override(&"line_spacing", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


# --- the story ---------------------------------------------------------------

## One beat: a backdrop, who is on stage, a line (spoken, if `who`), the Git
## word for it, and what happens when (`events`: seconds, then a call).
## `poster` is the moment the screenshots take.
func _script() -> Array:
	var rooms := ["No", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten"]
	var count: String = rooms[Story.count()] if Story.count() < rooms.size() else str(Story.count())
	return [
		{"stage": "palace", "bg": "title",
			"text": "In the palace of the Sultan of Main, nothing was ever forgotten."},
		{"stage": "ledger", "bg": "hall", "trail": true, "poster": 4.6,
			"text": "Princess Shirin kept the palace ledger. Each time something changed, she sealed the moment in a grain of sand.",
			"git": "a sealed moment is a commit: a snapshot of every file",
			"events": [
				[1.2, _seal.bind(ledger, {"east_torch": "lit"}, "Light the east torch", "princess")],
				[2.6, _seal.bind(ledger, {"garden_gate": "open"}, "Open the garden gate", "princess")],
				[4.0, _seal.bind(ledger, {"bridge": "down"}, "Lower the bridge", "princess")],
			]},
		{"stage": "ledger", "bg": "hall", "trail": true,
			"text": "Grain by grain, the sand kept the whole story: what changed, who changed it, and the way back. Out in the world, people who write code keep the same ledger.",
			"git": "they call it Git: it remembers every version of your work"},
		{"stage": "vizier", "bg": "gate", "trail": true, "music": "music_boss", "shake": 0.5, "sound": "vizier",
			"text": "Grand Vizier Rebasir hated the ledger. Nobody can lie about a history that anyone can read."},
		{"stage": "vizier", "bg": "gate", "trail": true, "casting": true, "who": "vizier", "poster": 3.4,
			"text": "\"Then I shall write some history of my own. Guards! The Princess, to the tower!\"",
			"git": "anyone can commit, and the log shows who did",
			"events": [
				[1.4, _seal.bind(ledger, {"spikes": "armed"}, "Arm the spikes", "vizier")],
				[2.8, _seal.bind(ledger, {"tower_door": "barred"}, "Bar the tower door", "vizier")],
			]},
		{"stage": "tower", "bg": "dungeon", "who": "princess", "sound": "draw", "give": true,
			"text": "\"Take the Dagger of HEAD. It turns the palace back to any moment that was sealed.\"",
			"git": "HEAD is Git's name for the commit you are on"},
		{"stage": "tower", "bg": "dungeon", "who": "princess",
			"text": "\"But only to a sealed one. What nobody sealed, the sand never knew.\"",
			"git": "work you never committed can't be brought back"},
		{"stage": "hall", "bg": "hall", "trail": true, "hold": T_RESET + 2.6, "poster": T_RESET + 1.2,
			"text": "So seal your work as you go. Then a fall only costs you what you hadn't sealed.",
			"git": "git commit seals it · git reset --hard goes back to it",
			"events": [
				[T_TORCH_1, _write.bind(hall, "torch_1", "lit", "torch")],
				[T_SEAL, _seal.bind(hall, {}, "Light the first torch", "prince")],
				[T_TORCH_2, _write.bind(hall, "torch_2", "lit", "torch")],
				[T_DIE, _sound.bind("death")],
				[T_RESET, _turn_back],
			]},
		{"stage": "hourglass", "bg": "dungeon",
			"text": "The Vizier has turned his hourglass. %s rooms stand between you and the tower." % count,
			"git": "seal often · turn back the sands"},
	]


func _sound(name: String) -> void:
	if not _quiet and not Room.test_fast:
		Sfx.play(self, name)


func _write(repo: GitRepo, file: String, text: String, sound: String) -> void:
	repo.set_file(file, text)
	_sound(sound)


## Writes the files (if any) and commits them, as the rooms' levers and the
## dagger do.
func _seal(repo: GitRepo, files: Dictionary, message: String, author: String) -> void:
	for file: String in files:
		repo.set_file(file, files[file])
	repo.commit_all(message, author)
	_sound("commit")


func _turn_back() -> void:
	hall.reset_hard("HEAD")
	_rewind = 0.7
	_sound("rewind")


# --- turning the pages -------------------------------------------------------

func beat_count() -> int:
	return _beats.size()


func beat() -> int:
	return _index


func _show(index: int) -> void:
	_index = index
	_t = 0.0
	_fired = 0
	_black = 1.0
	var now: Dictionary = _beats[index]
	_shake = float(now.get("shake", 0.0))
	if now.has("music"):
		Sfx.music(self, now.music)
	if now.has("sound"):
		_sound(now.sound)
	var who: String = now.get("who", "")
	_who.text = Story.data().cast[who].full if who != "" else ""
	_who.add_theme_color_override(&"font_color", Palette.VIOLET.lightened(0.3) if who == "vizier" else Palette.GREEN)
	_body.text = now.text
	_body.visible_characters = 0
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if who != "" else HORIZONTAL_ALIGNMENT_CENTER
	_git.text = now.get("git", "")
	_git.modulate.a = 0.0


## Everything this beat has due by `_t`.
func _run_events() -> void:
	var events: Array = _beats[_index].get("events", [])
	while _fired < events.size() and float(events[_fired][0]) <= _t:
		(events[_fired][1] as Callable).call()
		_fired += 1


func _typed() -> bool:
	return _body.visible_characters < 0 or _body.visible_characters >= _body.text.length()


## How long the beat holds once it's on screen, if nobody presses anything.
func _hold() -> float:
	var now: Dictionary = _beats[_index]
	var text: String = now.text
	var read := text.length() / TYPE + 3.2 + text.length() * 0.05
	return maxf(read, float(now.get("hold", 0.0)))


## The beat as its screenshot wants it: everything due has happened, quietly.
func pose() -> void:
	_t = float(_beats[_index].get("poster", 60.0))
	_quiet = true
	_run_events()
	_quiet = false
	_rewind = 0.0
	_shake = 0.0
	_black = 0.0
	_body.visible_characters = -1
	_git.modulate.a = 1.0
	_place()
	queue_redraw()


## On to the next beat. Whatever this one still had to do is done first, so
## the ledger is the same however fast the pages are turned.
func advance() -> void:
	if _leaving:
		return
	_t = 600.0
	_quiet = true
	_run_events()
	_quiet = false
	_rewind = 0.0
	if _index + 1 >= _beats.size():
		finish()
	else:
		_show(_index + 1)


func finish() -> void:
	if _leaving:
		return
	_leaving = true
	_skip.hide()
	var tween := create_tween()
	tween.tween_property(self, "_black", 1.0, 0.35)
	tween.tween_callback(func() -> void:
		if then > 0:
			Main.play(get_tree(), then)
		else:
			Main.title(get_tree()))


func _unhandled_input(event: InputEvent) -> void:
	if _leaving or driven or event.is_echo() or not event.is_pressed():
		return
	if not (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton or event is InputEventScreenTouch):
		return
	if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
		StageAudio.web_audio_unlocked = true
		Sfx.music(self, _beats[_index].get("music", "music_title"))
	if event.is_action(&"pause"):
		finish()
		return
	# A tap arrives twice, as a touch and as the mouse click made from it.
	if _clock - _pressed_at < 0.2:
		return
	_pressed_at = _clock
	if _typed():
		advance()
	else:
		_body.visible_characters = -1


func _process(delta: float) -> void:
	_clock += delta
	_shake = maxf(0.0, _shake - delta)
	_rewind = maxf(0.0, _rewind - delta)
	if not _leaving:
		_black = maxf(0.0, _black - delta * 3.0)
	if not driven and not _leaving:
		_t += delta
		_run_events()
		if not _typed():
			_body.visible_characters = mini(_body.text.length(), int(_t * TYPE))
		else:
			_git.modulate.a = minf(1.0, _git.modulate.a + delta * 3.0)
		if _t > _hold():
			advance()
	_place()
	queue_redraw()


## The whole view: wider than VIEW on a screen wider than 16:9.
func _full() -> Vector2:
	return get_viewport_rect().size


func _margin() -> float:
	return floorf((_full().x - VIEW.x) / 2.0)


func _place() -> void:
	var left := _margin()
	var spoken := _who.text != ""
	_who.position = Vector2(left + 60, PANEL + 4)
	_who.size = Vector2(360, 12)
	_body.position = Vector2(left + 60, PANEL + (17 if spoken else 7))
	_body.size = Vector2(360, 40)
	_git.position = Vector2(left, 247)
	_git.size = Vector2(VIEW.x, 16)
	_skip.position = Vector2(left + VIEW.x - 40, 3)
	_skip.size = Vector2(36, 16)


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, _full()), Palette.INK)
	var now: Dictionary = _beats[_index]
	var jolt := Vector2(randf_range(-3, 3), randf_range(-2, 2)) * (_shake / 0.5) if _shake > 0.0 else Vector2.ZERO
	draw_set_transform(Vector2(_margin(), 0) + jolt.round())
	var art: Texture2D = _art.get(now.bg)
	if art != null:
		draw_texture_rect(art, Rect2(Vector2.ZERO, VIEW), false)
	call("_stage_%s" % now.stage, now)
	_motes()
	draw_set_transform(Vector2(_margin(), 0))
	if now.stage == "hall":
		_hall_wash()
	# The letterbox: a bar on top, the story underneath.
	draw_rect(Rect2(-_margin(), 0, _full().x, BAR), Palette.INK)
	draw_rect(Rect2(-_margin(), PANEL, _full().x, VIEW.y - PANEL), Color(Palette.INK, 0.94))
	draw_rect(Rect2(-_margin(), PANEL, _full().x, 1), Color(Palette.SAND, 0.5))
	draw_string(Palette.pixel(), Vector2(8, 15), "THE STORY SO FAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(Palette.SAND, 0.8))
	for i in _beats.size():
		draw_rect(Rect2(240 - _beats.size() * 4 + i * 8, 10, 4, 4), Palette.SAND if i <= _index else Color(Palette.STEEL, 0.4))
	if now.get("trail", false):
		_paint_ledger(hall if now.stage == "hall" else ledger)
	if _typed() and not driven and int(_clock * 2.0) % 2 == 0:
		draw_string(Palette.pixel(), Vector2(0, 266), "tap" if TouchControls.active else "press any key", HORIZONTAL_ALIGNMENT_RIGHT, 472, 8, Color(Palette.PAPER, 0.5))
	draw_set_transform(Vector2.ZERO)
	if _black > 0.0:
		draw_rect(Rect2(Vector2.ZERO, _full()), Color(0, 0, 0, _black))


## The sand trail and the last git command, as the rooms show them.
func _paint_ledger(repo: GitRepo) -> void:
	draw_rect(Rect2(-_margin(), BAR, _full().x, 50), Color(Palette.INK, 0.82))
	draw_rect(Rect2(-_margin(), BAR + 50, _full().x, 1), Color(Palette.SAND, 0.4))
	Trail.paint(self, repo, Rect2(40, BAR + 6, 400, 16), Palette.pixel(), true, _clock)
	for index in range(repo.log.size() - 1, -1, -1):
		var entry: Dictionary = repo.log[index]
		if not entry.has("cmd"):
			continue
		var ok := int(entry.exit) == 0
		draw_string(Palette.mono(), Vector2(40, BAR + 31), "$ git " + Console.shown(entry.cmd), HORIZONTAL_ALIGNMENT_LEFT, 400, 13, Palette.SAND_PALE)
		if not (entry.out as Array).is_empty():
			draw_string(Palette.mono(), Vector2(40, BAR + 44), String(entry.out[0]).strip_edges(), HORIZONTAL_ALIGNMENT_LEFT, 400, 13,
				Palette.PAPER if ok else Palette.CRIMSON.lightened(0.4))
		return


## Sand on the air, in every beat.
func _motes() -> void:
	for i in 28:
		var x := fmod(i * 53.7 + _clock * (5.0 + (i % 5) * 3.0), VIEW.x + 20.0) - 10.0
		var y := fmod(i * 29.3 + sin(_clock * 0.6 + i) * 7.0 + 400.0, PANEL - BAR) + BAR
		var glow := 0.25 + 0.35 * (0.5 + 0.5 * sin(_clock * 1.7 + i * 2.1))
		draw_rect(Rect2(roundf(x), roundf(y), 1, 1), Color(Palette.SAND_PALE, glow))


## A figure off its sheet, one texel to a pixel, standing at `feet`.
func _figure(sheet: Texture2D, cell: Vector2, frame: int, feet: Vector2, flip: bool = false, tint: Color = Color.WHITE) -> void:
	var box := Rect2(roundf(feet.x - cell.x / 2.0), roundf(feet.y - cell.y), cell.x, cell.y)
	if flip:
		box = Rect2(box.end.x, box.position.y, -cell.x, cell.y)
	draw_texture_rect_region(sheet, box, Rect2(cell.x * frame, 0, cell.x, cell.y), tint)


## A room tile at twice its room size, which is one texel to a pixel.
func _tile(name: String, x: float, y: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect_region(Room.TILES, Rect2(x, y, 32, 32), Rect2(Room.TILE[name] * 34 + 1, 1, 32, 32), tint)


func _glow(at: Vector2, radius: float, color: Color) -> void:
	for ring in 4:
		draw_circle(at, radius * (1.0 - ring * 0.22), Color(color, 0.07 + ring * 0.03))


func _stage_palace(_now: Dictionary) -> void:
	# The lamp in the tower where the ledger is kept.
	_glow(Vector2(433, 62), 9.0 + sin(_clock * 3.0), Palette.SAND)


func _stage_ledger(now: Dictionary) -> void:
	draw_rect(Rect2(0, BAR, VIEW.x, PANEL - BAR), Color(Palette.INK, 0.3))
	_glow(Vector2(240, 150), 46.0, Palette.GREEN)
	_figure(PRINCESS, Vector2(48, 72), 0, Vector2(240, FLOOR + sin(_clock * 1.6)))
	# A grain leaves her hand each time she seals.
	var events: Array = now.get("events", [])
	for event: Array in events:
		var since := _t - float(event[0])
		if since >= 0.0 and since < 0.6:
			var p := Vector2(240, 150).lerp(Vector2(240, BAR + 50), since / 0.6)
			_glow(p, 7.0, Palette.SAND)
			draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Palette.SAND_PALE)


func _stage_vizier(now: Dictionary) -> void:
	var casting: bool = now.get("casting", false)
	draw_rect(Rect2(0, BAR, VIEW.x, PANEL - BAR), Color(Palette.INK, 0.25))
	_glow(Vector2(240, 146), (58.0 if casting else 44.0) + sin(_clock * 4.0) * 3.0, Palette.VIOLET)
	_figure(VIZIER, Vector2(48, 80), 1 if casting else 0, Vector2(240, FLOOR + sin(_clock * 2.0)))
	if casting:
		# What he seals flies up to the ledger in his own colour.
		for event: Array in now.get("events", []):
			var since := _t - float(event[0])
			if since >= 0.0 and since < 0.6:
				var p := Vector2(240, 120).lerp(Vector2(240, BAR + 50), since / 0.6)
				_glow(p, 8.0, Palette.VIOLET)
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(3, 3)), Palette.VIOLET.lightened(0.4))


func _stage_tower(now: Dictionary) -> void:
	draw_rect(Rect2(0, BAR, VIEW.x, PANEL - BAR), Color(Palette.INK, 0.2))
	# The Princess behind the bars of her cell.
	_glow(Vector2(170, 150), 44.0, Palette.GREEN)
	_figure(PRINCESS, Vector2(48, 72), 0, Vector2(170, FLOOR))
	for row in 3:
		for col in 3:
			_tile("gate", 122 + col * 32, FLOOR - 96 + row * 32, Color(1, 1, 1, 0.8))
	# The dagger passes through them to the Prince.
	var reach := clampf(_t / 1.2, 0.0, 1.0) if now.get("give", false) else 1.0
	var grain := Vector2(196, 150).lerp(Vector2(296, 140), reach)
	if reach < 1.0:
		_glow(grain, 8.0, Palette.SAND)
		draw_rect(Rect2(grain - Vector2(1, 1), Vector2(3, 3)), Palette.SAND_PALE)
	else:
		_glow(Vector2(296, 136), 16.0 + sin(_clock * 5.0) * 2.0, Palette.SAND)
	_figure(Prince.SHEET, Prince.TEXELS, Prince.F_DAGGER if reach >= 1.0 else Prince.F_IDLE + int(_clock * 1.2) % 2, Vector2(310, FLOOR), true)


## The hall: the first room's lesson, played once. What it draws comes from
## `hall`'s working tree, as a room's does.
func _stage_hall(_now: Dictionary) -> void:
	draw_rect(Rect2(0, BAR, VIEW.x, PANEL - BAR), Color(Palette.INK, 0.25))
	var flick := int(_clock * 8.0) % 2 == 0
	for col in 15:
		var pit := col == 11 or col == 12
		_tile("holes" if pit else "floor", col * 32, HALL_FLOOR)
		if pit:
			_tile("spikes", col * 32, HALL_FLOOR - 32)
	var dirty := hall.modified()
	for torch: Array in [["torch_1", HALL_TORCH_1], ["torch_2", HALL_TORCH_2]]:
		# Each hangs a step past where he stops to light it.
		var at := Vector2(float(torch[1]) + 28.0, HALL_FLOOR - 64)
		var lit := hall.value(torch[0]) == "lit"
		if lit:
			_glow(at + Vector2(0, -8), 40.0 + (2.0 if flick else 0.0), Color(1.0, 0.72, 0.3))
		_tile(("torch_a" if flick else "torch_b") if lit else "torch_dark", at.x - 16, at.y - 16)
		if torch[0] in dirty:
			# Loose sand over what isn't sealed yet, as in the rooms.
			var p := at + Vector2(0, -30 + sin(_clock * 5.0) * 2.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(5, 0), p + Vector2(0, 5), p + Vector2(-5, 0)]), Palette.SAND)
	var x := HALL_TORCH_1
	var frame := Prince.F_IDLE + int(_clock * 1.2) % 2
	var feet := HALL_FLOOR
	if _t < T_TORCH_1:
		x = lerpf(HALL_START, HALL_TORCH_1, _t / T_TORCH_1)
		frame = _stride(x - HALL_START)
	elif _t < T_RUN:
		if _t >= T_SEAL and _t < T_SEAL + 0.9:
			frame = Prince.F_DAGGER
	elif _t < T_DIE:
		x = lerpf(HALL_TORCH_1, HALL_PIT, (_t - T_RUN) / (T_DIE - T_RUN))
		frame = _stride(x - HALL_TORCH_1) if x < HALL_PIT - 30.0 else Prince.F_FALL
	elif _t < T_RESET:
		x = HALL_PIT
		frame = Prince.F_DEAD
		feet = HALL_FLOOR - 6.0
	elif _t < T_RESET + 1.0:
		frame = Prince.F_DAGGER
	_figure(Prince.SHEET, Prince.TEXELS, frame, Vector2(x, feet))


func _stride(run: float) -> int:
	return Prince.F_RUN + int(run / (Prince.STRIDE * 2.0) * Prince.RUN_FRAMES) % Prince.RUN_FRAMES


## The sepia of a death and the sands running back, as the rooms show them.
func _hall_wash() -> void:
	var field := Rect2(-_margin(), 0, _full().x, VIEW.y)
	if _t >= T_DIE and _t < T_RESET:
		draw_rect(field, Color(0.45, 0.3, 0.12, 0.38))
	if _rewind > 0.0:
		var t := _rewind / 0.7
		draw_rect(field, Color(0.93, 0.78, 0.42, 0.55 * sin(t * PI)))
		for i in 14:
			var y := fmod(i * 37.0 + _clock * 90.0, VIEW.y)
			var x := fmod(i * 91.0 - _clock * 900.0, VIEW.x + 120.0)
			draw_rect(Rect2(x, y, 60.0 + (i % 3) * 30.0, 1.0), Color(1.0, 0.95, 0.75, 0.5 * t))


func _stage_hourglass(_now: Dictionary) -> void:
	draw_rect(Rect2(0, BAR, VIEW.x, PANEL - BAR), Color(Palette.INK, 0.55))
	var c := Vector2(240, 108)
	var w := 34.0
	var h := 52.0
	# It has only just been turned: the top is nearly full.
	var fill := clampf(1.0 - _t * 0.012, 0.6, 1.0)
	_glow(c, 70.0, Palette.SAND)
	var top := PackedVector2Array([c + Vector2(-w * fill, -h * fill), c + Vector2(w * fill, -h * fill), c])
	draw_colored_polygon(top, Palette.SAND)
	var heap := (1.0 - fill) + 0.12
	draw_colored_polygon(PackedVector2Array([c + Vector2(-w * heap * 2.0, h), c + Vector2(w * heap * 2.0, h), c + Vector2(0, h - h * heap * 1.6)]), Palette.SAND)
	draw_rect(Rect2(c.x - 0.5, c.y, 1, h), Color(Palette.SAND_PALE, 0.5 + 0.5 * sin(_clock * 20.0)))
	draw_polyline(PackedVector2Array([c + Vector2(-w, -h), c + Vector2(w, -h), c + Vector2(-w, h), c + Vector2(w, h), c + Vector2(-w, -h)]), Palette.SAND_PALE, 2.0)
	draw_rect(Rect2(c.x - w - 5, c.y - h - 5, w * 2 + 10, 5), Palette.SAND_PALE)
	draw_rect(Rect2(c.x - w - 5, c.y + h, w * 2 + 10, 5), Palette.SAND_PALE)
