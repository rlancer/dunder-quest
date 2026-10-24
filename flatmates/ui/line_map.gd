extends Control

## Stage select, drawn as a tram line through Croydon: one stop per stage,
## left to right. Left and right move along the line, Jump or Enter gets on.
## A stop opens when the one before it is cleared.

const LINE_Y := 120.0
const FIRST_X := 52.0
const GAP := 75.0
const TRAM := Color(0.38, 0.76, 0.32)
const MUSIC := "res://assets/audio/music_title.ogg"
const ART := "res://assets/backgrounds/map.png"

var _selected: int = 1
var _tram_x: float = FIRST_X
var _time: float = 0.0
var _flash: String = ""
var _flash_time: float = 0.0
var _typed: String = ""
var _fade: ColorRect
var _leaving: bool = false
var _celebrate: float = 0.0


func _ready() -> void:
	Progress.load_data()
	_selected = clampi(Progress.current_stage, 1, Progress.count())
	if not Progress.is_open(_selected):
		_selected = 1
	_tram_x = _stop_x(_selected)
	if Progress.just_cleared > 0:
		_tram_x = _stop_x(Progress.just_cleared)
		_celebrate = 1.6
		Progress.just_cleared = 0
	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.06, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.3)
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)


func _stop_x(id: int) -> float:
	return FIRST_X + GAP * float(id - 1)


func _process(delta: float) -> void:
	_time += delta
	_tram_x = move_toward(_tram_x, _stop_x(_selected), 240.0 * delta)
	_flash_time = maxf(_flash_time - delta, 0.0)
	_celebrate = maxf(_celebrate - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	_typed = Eggs.spell(_typed, event, Eggs.TOWN_WORD)
	if _typed == Eggs.TOWN_WORD:
		_typed = ""
		_say(Eggs.TOWN)
	if event.is_action_pressed(&"move_left"):
		_move(-1)
	elif event.is_action_pressed(&"move_right"):
		_move(1)
	elif event.is_action_pressed(&"confirm") or event.is_action_pressed(&"jump"):
		_board()
	elif event.is_action_pressed(&"pause"):
		_leave(Main.TITLE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_tap(event.position)


func _tap(at: Vector2) -> void:
	for id in range(1, Progress.count() + 1):
		if at.distance_to(Vector2(_stop_x(id), LINE_Y)) < 22.0:
			if id == _selected:
				_board()
			else:
				_selected = id
				StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
			return
	if Rect2(150, 200, 180, 40).has_point(at):
		_board()


func _move(step: int) -> void:
	var next := clampi(_selected + step, 1, Progress.count())
	if next == _selected:
		return
	if step > 0 and not Progress.is_open(next):
		_say("Clear %s first." % Progress.stage(_selected).get("stop", ""))
		StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
		return
	_selected = next
	Progress.current_stage = next
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))


func _board() -> void:
	if not Progress.is_open(_selected):
		_say("That stop's closed. Clear the one before it.")
		return
	_leaving = true
	StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: Main.play_stage(get_tree(), _selected))


func _leave(path: String) -> void:
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))


func _say(text: String) -> void:
	_flash = text
	_flash_time = 2.5


func _draw() -> void:
	var font := load("res://assets/fonts/PixelifySans.ttf") as Font
	var mono := Palette.mono()
	draw_rect(Rect2(0, 0, 480, 270), Color(0.13, 0.12, 0.16))
	if ResourceLoader.exists(ART):
		draw_texture_rect(load(ART) as Texture2D, Rect2(0, 0, 480, 270), false)
		draw_rect(Rect2(0, 0, 480, 270), Color(0.06, 0.05, 0.09, 0.45))
	# A route map's header strip.
	draw_rect(Rect2(0, 0, 480, 30), TRAM.darkened(0.45))
	draw_string(font, Vector2(12, 20), "Croydon line", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
	draw_string(mono, Vector2(150, 19), "Towards: the rest of your life", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER.darkened(0.15))

	# The line, solid up to the last open stop, dashed past it.
	for id in range(1, Progress.count()):
		var from := Vector2(_stop_x(id), LINE_Y)
		var to := Vector2(_stop_x(id + 1), LINE_Y)
		if Progress.is_open(id + 1):
			draw_rect(Rect2(from + Vector2(0, -3), Vector2(to.x - from.x, 6)), TRAM)
		else:
			var x := from.x
			while x < to.x:
				draw_rect(Rect2(Vector2(x, LINE_Y - 2), Vector2(minf(6, to.x - x), 4)), TRAM.darkened(0.55))
				x += 10
	for id in range(1, Progress.count() + 1):
		var at := Vector2(_stop_x(id), LINE_Y)
		var open := Progress.is_open(id)
		var done := Progress.is_cleared(id)
		draw_circle(at, 8.0, Palette.INK)
		draw_circle(at, 6.0, Palette.PAPER if open else Palette.STEEL_DARK)
		if done:
			draw_circle(at, 3.0, TRAM)
		var stop := str(Progress.stage(id).get("stop", ""))
		var width := mono.get_string_size(stop, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var label_y := LINE_Y - 16 if id % 2 == 1 else LINE_Y + 24
		var label_x := clampf(at.x - width * 0.5, 4, 476 - width)
		draw_string_outline(mono, Vector2(label_x, label_y), stop, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
		draw_string(mono, Vector2(label_x, label_y), stop, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER if open else Palette.STEEL)

	# The tram: a little green box with two windows, bobbing.
	var bob := roundf(sin(_time * 5.0) * 1.0)
	var tram := Vector2(roundf(_tram_x) - 11, LINE_Y - 16 + bob)
	draw_rect(Rect2(tram, Vector2(22, 10)), TRAM.lightened(0.15))
	draw_rect(Rect2(tram + Vector2(3, 2), Vector2(6, 4)), Palette.CODE)
	draw_rect(Rect2(tram + Vector2(13, 2), Vector2(6, 4)), Palette.CODE)
	draw_rect(Rect2(tram + Vector2(0, 9), Vector2(22, 1)), Palette.INK)
	if _celebrate > 0.0:
		draw_string(mono, tram + Vector2(-10, -6), "Next stop!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.JS)

	# The selected stop's card.
	var data := Progress.stage(_selected)
	var card := Rect2(110, 168, 260, 76)
	draw_rect(card, Color(0.06, 0.05, 0.09, 0.92))
	draw_rect(Rect2(card.position, Vector2(3, card.size.y)), Palette.JS)
	draw_string(font, card.position + Vector2(12, 18), "%d. %s" % [_selected, data.get("name", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
	draw_string(mono, card.position + Vector2(12, 34), "Lesson: %s" % data.get("lesson", ""), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.JS)
	var status := "Cleared" if Progress.is_cleared(_selected) else ("Open" if Progress.is_open(_selected) else "Closed")
	draw_string(mono, card.position + Vector2(12, 50), "%s   Best %s   Custard creams %d/%d" % [status, Progress.format_time(Progress.best_time(_selected)), Progress.best_biscuits(_selected), int(data.get("biscuits", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.STEEL)
	var go := "Tap the stop to get on" if TouchControls.active else "Space or Enter: get on    Esc: title"
	draw_string(mono, card.position + Vector2(12, 67), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER.darkened(0.2))
	if _flash_time > 0.0:
		var w := mono.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(mono, Vector2(240 - w * 0.5, 156), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
		draw_string(mono, Vector2(240 - w * 0.5, 156), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
