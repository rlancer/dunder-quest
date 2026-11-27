extends Control

## The TV guide on Stu's coffee table: a listing for every episode, locked
## until the one before it has aired. One that's aired shows the fewest
## takes it took and a star for every scene played at par.

const ART := "res://assets/backgrounds/apartment.png"
const FIRST := Vector2(12, 46)
const SHEET := Vector2(88, 176)
const STEP := 92.0

var _selected: int = 1
var _clock: float = 0.0
var _said: String = ""
var _said_for: float = 0.0
var _fade: ColorRect
var _leaving: bool = false
var _flash: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	var art := Backdrop.sprite(ART)
	art.show_behind_parent = true
	art.modulate = Color(0.42, 0.38, 0.48)
	add_child(art)
	_selected = clampi(Progress.current_episode, 1, maxi(Story.count(), 1))
	if Progress.just_cleared > 0:
		_flash = 1.6
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.35)
	Sfx.music("title")


func _process(delta: float) -> void:
	_clock += delta
	_said_for = maxf(_said_for - delta, 0.0)
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _sheet(id: int) -> Rect2:
	return Rect2(FIRST + Vector2((id - 1) * STEP, 0), SHEET)


func _say(words: String) -> void:
	_said = words
	_said_for = 3.0
	Sfx.play(self, "buzz")


func _take(id: int) -> void:
	if _leaving:
		return
	if not Progress.is_open(id):
		_say("Not yet, kid. \"%s\" airs first." % Story.episode(id - 1).get("title", ""))
		return
	_leaving = true
	Progress.just_cleared = 0
	Sfx.play(self, "page")
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: Main.play_episode(get_tree(), id))


func _back() -> void:
	if _leaving:
		return
	_leaving = true
	Progress.just_cleared = 0
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(Main.TITLE))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if Rect2(8, 4, 44, 16).has_point(event.position):
			_back()
			return
		for id in range(1, Story.count() + 1):
			if _sheet(id).has_point(event.position):
				# The first tap picks a notice; a tap on the picked one takes it.
				if id == _selected or TouchControls.active:
					_selected = id
					_take(id)
				else:
					_selected = id
					Sfx.play(self, "tick")
				return


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_right", true):
		_selected = mini(_selected + 1, Story.count())
		Sfx.play(self, "tick")
	elif event.is_action_pressed(&"move_left", true):
		_selected = maxi(_selected - 1, 1)
		Sfx.play(self, "tick")
	elif event.is_action_pressed(&"confirm"):
		_take(_selected)
	elif event.is_action_pressed(&"pause"):
		_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	Fit.frame(self)
	var titles := Palette.titles()
	var mono := Palette.mono()
	var pixel := Palette.pixel()
	Fit.centred(self, titles, 240, 30, "THIS WEEK ON TV", 24, Palette.MUSTARD_LIGHT)
	var back := Rect2(8, 4, 44, 16)
	draw_rect(back, Palette.PLUM_DARK)
	draw_rect(back.grow(-1), Palette.PLUM)
	Fit.begin(back, "the board's Title button")
	Fit.centred(self, pixel, back.position.x + 22, back.end.y - 4, "< Title", 10, Palette.CREAM)
	Fit.end()
	for id in range(1, Story.count() + 1):
		var episode := Story.episode(id)
		var sheet := _sheet(id)
		var picked := id == _selected
		var open := Progress.is_open(id)
		var done := Progress.is_cleared(id)
		if picked:
			sheet.position.y -= 4
			draw_rect(sheet.grow(2), Palette.MUSTARD_LIGHT)
		Ui.paper(self, sheet)
		draw_rect(Rect2(sheet.position.x + 1, sheet.position.y + 1, sheet.size.x - 4, 3), Palette.TEAL if open else Palette.PAPER_LINE)
		if not open:
			draw_rect(sheet.grow(-1), Color(Palette.PLUM_DARK, 0.45))
		Fit.begin(sheet, "the listing for episode %d" % id)
		var ink := Palette.INK if open else Palette.DIM
		Fit.centred(self, pixel, sheet.position.x + 44, sheet.position.y + 18, "EPISODE %d" % id, 10, Palette.BRICK if open else Palette.DIM)
		var y := sheet.position.y + 36
		for line: String in Fit.wrap_text(titles, str(episode.title), 14, SHEET.x - 12):
			Fit.centred(self, titles, sheet.position.x + 44, y, line, 14, ink)
			y += 15
		draw_rect(Rect2(sheet.position.x + 10, y - 6, SHEET.x - 20, 1), Palette.PAPER_LINE)
		y += 8
		for line: String in Fit.wrap_text(mono, str(episode.lesson), 16, SHEET.x - 12):
			Fit.centred(self, mono, sheet.position.x + 44, y, line, 16, ink)
			y += 12
		# The foot of the listing: how it went, or whether it can air yet.
		var foot := sheet.end.y - 12
		if done:
			var scenes := (episode.scenes as Array).size()
			var x := sheet.position.x + 44 - scenes * 6.0 + 6.0
			for i in scenes:
				Ui.star(self, Vector2(x + i * 12.0, foot - 30), 5, Palette.MUSTARD if i < Progress.stars(id) else Palette.PAPER_DARK)
			var tries := Progress.best_tries(id)
			Fit.centred(self, mono, sheet.position.x + 44, foot - 12, "%d %s" % [tries, "take" if tries == 1 else "takes"], 16, Palette.INK)
			var flash := _flash > 0.0 and Progress.just_cleared == id and fmod(_clock, 0.4) < 0.2
			Ui.tab(self, Rect2(sheet.position.x + 22, foot - 6, 44, 12), "AIRED", Palette.MUSTARD if flash else Palette.BRICK, Palette.CREAM)
		elif open:
			Ui.tab(self, Rect2(sheet.position.x + 18, foot - 6, 52, 12), "TONIGHT", Palette.TEAL, Palette.CREAM)
		else:
			Ui.tab(self, Rect2(sheet.position.x + 18, foot - 6, 52, 12), "LOCKED", Palette.PLUM, Palette.PAPER_DARK)
		Fit.end()
	var foot_rect := Rect2(8, 238, 464, 16)
	if _said_for > 0.0:
		draw_rect(foot_rect, Color(Palette.PLUM_DARK, 0.9))
		Fit.cover(foot_rect)
		Fit.begin(foot_rect, "what the board says")
		Fit.centred(self, mono, 240, 250, _said, 16, Palette.MUSTARD_LIGHT)
		Fit.end()
	Ui.prompt(self, "Tap a listing to watch it" if TouchControls.active else "Arrows pick, Enter starts the episode, Esc for the title")
