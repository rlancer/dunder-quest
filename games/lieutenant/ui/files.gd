extends Control

## The case files: a drawer of manila folders, one per case. Up and down
## move between them, Enter (or a tap on the picked folder) opens it. A case
## opens when the one before it is closed.

const MUSIC := "res://assets/audio/music_title.ogg"
const ART := "res://assets/backgrounds/desk.png"
const TAB := Rect2(12, 36, 208, 37)
const STEP := 43.0
const SHEET := Rect2(230, 34, 232, 210)

var _selected: int = 1
var _time: float = 0.0
var _flash: String = ""
var _flash_time: float = 0.0
var _fade: ColorRect
var _leaving: bool = false
var _stamp: float = 0.0
var _faces: Dictionary = {}


func _ready() -> void:
	Progress.load_data()
	var art := Backdrop.sprite(ART)
	art.show_behind_parent = true
	add_child(art)
	for c: Dictionary in Story.cases():
		var path := "res://assets/sprites/%s.png" % c.killer
		if ResourceLoader.exists(path):
			_faces[int(c.id)] = load(path)
	_selected = clampi(Progress.current_case, 1, Progress.count())
	if not Progress.is_open(_selected):
		_selected = 1
	if Progress.just_cleared > 0:
		_stamp = 1.6
		Progress.just_cleared = 0
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.3)
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)


func _tab(id: int) -> Rect2:
	return Rect2(TAB.position + Vector2(0, (id - 1) * STEP), TAB.size)


func _process(delta: float) -> void:
	_time += delta
	_flash_time = maxf(_flash_time - delta, 0.0)
	_stamp = maxf(_stamp - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"confirm") or event.is_action_pressed(&"edit"):
		_go()
	elif event.is_action_pressed(&"pause"):
		_leave(Main.TITLE)


## Clicks and taps come here: this full-screen Control stops them before
## _unhandled_input. A tap arrives as an emulated click, so it isn't read twice.
func _gui_input(event: InputEvent) -> void:
	if not _leaving and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_tap(event.position)


func _tap(at: Vector2) -> void:
	for id in range(1, Progress.count() + 1):
		if _tab(id).has_point(at):
			if id == _selected:
				_go()
			elif Progress.is_open(id):
				_selected = id
				Progress.current_case = id
				StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
			else:
				_say("Close \"%s\" first." % Story.case(id - 1).get("title", ""))
			return
	if SHEET.has_point(at):
		_go()


func _move(step: int) -> void:
	var next := clampi(_selected + step, 1, Progress.count())
	if next == _selected:
		return
	if step > 0 and not Progress.is_open(next):
		_say("Close \"%s\" first." % Story.case(_selected).get("title", ""))
		StageAudio.play(get_tree(), preload("res://assets/audio/buzz.wav"))
		return
	_selected = next
	Progress.current_case = next
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))


func _go() -> void:
	if not Progress.is_open(_selected):
		_say("Not yet. Close the one before it.")
		return
	_leaving = true
	StageAudio.play(get_tree(), preload("res://assets/audio/page.wav"))
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: Main.play_case(get_tree(), _selected))


func _leave(path: String) -> void:
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))


func _say(text: String) -> void:
	_flash = text
	_flash_time = 2.5


func _draw() -> void:
	var mono := Palette.mono()
	var titles := Palette.titles()
	Fit.frame(self)
	draw_rect(Rect2(0, 0, 480, 24), Color(0, 0, 0, 0.82))
	Fit.begin(Rect2(0, 0, 480, 24), "the case files' top bar")
	Fit.text(self, titles, Vector2(10, 17), "Just One More JOIN", 14, Palette.CREAM)
	Fit.text(self, mono, Vector2(218, 16), "Five people who thought of everything.", 16, Color(0.8, 0.78, 0.72))
	Fit.end()
	# The folders.
	for id in range(1, Progress.count() + 1):
		var c := Story.case(id)
		var tab := _tab(id)
		var open := Progress.is_open(id)
		var picked := id == _selected
		if picked:
			tab.position.x += 6
		var paper := Color(0.86, 0.74, 0.5) if open else Color(0.5, 0.44, 0.34)
		draw_rect(Rect2(tab.position + Vector2(2, 2), tab.size), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(tab.position + Vector2(8, -4), Vector2(46, 4)), paper.darkened(0.1))
		draw_rect(tab, paper)
		draw_rect(Rect2(tab.position, Vector2(tab.size.x, 1)), paper.lightened(0.25))
		if picked:
			draw_rect(tab.grow(1), Palette.EMBER, false, 2.0)
		Fit.begin(tab, "a case folder")
		# Top right: the case's number, or the stamp once it's closed.
		if Progress.is_cleared(id):
			_draw_stamp(tab.position + Vector2(tab.size.x - 52, 3), 1.0 if not (picked and _stamp > 0.0) else clampf((1.6 - _stamp) * 4.0, 0.0, 1.0))
		else:
			Fit.text(self, mono, tab.position + Vector2(tab.size.x - 46, 13), "CASE %d" % id, 16, Palette.INK.lightened(0.3))
		Fit.text(self, titles, tab.position + Vector2(8, 17), str(c.get("title", "")) if open else "Sealed", 14, Palette.INK if open else Palette.INK.lightened(0.3))
		Fit.text(self, mono, tab.position + Vector2(8, 31), str(c.get("lesson", "")), 16, Palette.SYN_KEYWORD if open else Palette.INK.lightened(0.3))
		Fit.end()
	# The open file: a sheet of paper with tonight's suspect clipped to it.
	var c := Story.case(_selected)
	draw_rect(Rect2(SHEET.position + Vector2(3, 3), SHEET.size), Color(0, 0, 0, 0.4))
	draw_rect(SHEET, Palette.NOTE)
	draw_rect(Rect2(SHEET.position, Vector2(SHEET.size.x, 16)), Palette.NOTE_COVER)
	Fit.begin(SHEET, "the open case file")
	Fit.text(self, mono, SHEET.position + Vector2(8, 12), "L.A.P.D. HOMICIDE  ·  CASE %d" % _selected, 16, Palette.CREAM)
	var x := SHEET.position.x + 10
	var y := SHEET.position.y + 38
	Fit.text(self, titles, Vector2(x, y), str(c.get("title", "")), 20, Palette.NOTE_INK)
	y += 16
	Fit.text(self, mono, Vector2(x, y), str(c.get("place", "")), 16, Palette.NOTE_INK.lightened(0.2))
	y += 16
	# The photograph.
	var photo := Rect2(SHEET.end.x - 62, y - 4, 48, 60)
	draw_rect(photo.grow(3), Color.WHITE)
	draw_rect(photo, Palette.NIGHT.lightened(0.25))
	var sheet: Texture2D = _faces.get(_selected)
	if sheet != null:
		draw_texture_rect_region(sheet, Rect2(photo.position + Vector2(-8, 2), Vector2(64, 60)), Rect2(0, 10, 64, 60))
	draw_rect(Rect2(photo.position.x + 18, photo.position.y - 8, 12, 8), Palette.STEEL)
	var killer := str(c.get("killer", ""))
	# Beside the photograph, not under it.
	Fit.begin(Rect2(x, y - 8, photo.position.x - 5 - x, 74), "the case file, beside the photograph")
	Fit.text(self, mono, Vector2(x, y + 4), "TONIGHT'S SUSPECT", 16, Palette.EMBER.darkened(0.3))
	Fit.text(self, mono, Vector2(x, y + 16), Story.full_name(killer), 16, Palette.NOTE_INK)
	var role_y := y + 28
	for line in SqlDraw.wrap(str((Story.data().cast as Dictionary).get(killer, {}).get("role", "")), 144):
		Fit.text(self, mono, Vector2(x, role_y), line, 16, Palette.NOTE_INK.lightened(0.25))
		role_y += 11
	Fit.end()
	y += 74
	Fit.text(self, mono, Vector2(x, y), "TONIGHT'S SQL", 16, Palette.EMBER.darkened(0.3))
	y += 12
	for line in SqlDraw.wrap(str(c.get("lesson", "")), SHEET.size.x - 20):
		Fit.text(self, mono, Vector2(x, y), line, 16, Palette.SYN_KEYWORD)
		y += 11
	y += 8
	var status := "Closed in %d calls to Records" % Progress.best_tries(_selected) if Progress.is_cleared(_selected) else ("Open" if Progress.is_open(_selected) else "Sealed until the case before it is closed")
	for line in SqlDraw.wrap(status, SHEET.size.x - 20):
		Fit.text(self, mono, Vector2(x, y), line, 16, Palette.GREEN.darkened(0.3) if Progress.is_cleared(_selected) else Palette.NOTE_INK.lightened(0.2))
		y += 11
	var go := "Tap this sheet to open the case" if TouchControls.active else "Enter: open the file   Esc: title"
	Fit.text(self, mono, Vector2(x, SHEET.end.y - 8), go, 16, Palette.STEEL_DARK)
	Fit.end()
	if _flash_time > 0.0:
		var w := mono.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(mono, Vector2(240 - w * 0.5, 262), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
		Fit.text(self, mono, Vector2(240 - w * 0.5, 262), _flash, 16, Palette.CREAM)


func _draw_stamp(at: Vector2, amount: float) -> void:
	var color := Color(Palette.RED.darkened(0.1), 0.85 * amount)
	var box := Rect2(at, Vector2(46, 14)).grow(2.0 * (1.0 - amount))
	draw_rect(box, color, false, 1.5)
	Fit.text(self, Palette.mono(), box.position + Vector2(5, 11), "CLOSED", 16, color)
