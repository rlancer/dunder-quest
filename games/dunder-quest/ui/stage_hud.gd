class_name StageHud
extends CanvasLayer

## Stage overlay: name and lesson, seeds, clock, falls, the pause menu and its
## Spellbook, the results card, lesson cards (scrolls, keys), the wizard duel's
## question strips, and the full-screen fade used for deaths and scene changes.
## Runs while the tree is paused so the pause menu and cards can answer.

signal map_requested
signal restart_requested
signal continue_requested
## The player asked the wizard for a hint mid-duel.
signal duel_hint_requested
## The last queued lesson card was dismissed and play resumes.
signal card_closed

const CONTINUE_LOCK := 0.6
## A press this soon after a card opens is the press that was already held.
const CARD_LOCK := 0.35
const WHISPER := Color(0.78, 0.66, 1.0)

var seed_count: int = 0
var seed_total: int = 0
var falls: int = 0
var cleared: bool = false
var passage_shown: bool = false
var waiting_for_start: bool = false
var hints_used: int = 0
var scroll_found: int = 0
var scroll_total: int = 0

var _paused: bool = false
var _continue_sent: bool = false
var _continue_at: float = 0.0
var _fade_tween: Tween
var _lesson_label: Label
var _card: LessonCard
var _card_queue: Array[Dictionary] = []
var _card_lock: float = 0.0
## True when the open card paused the tree itself and must unpause it.
var _card_paused_tree: bool = false
var _book_open: bool = false
var _book_pages: Array[Dictionary] = []
var _book_index: int = 0
var _spellbook_button: Button
var _duel: DuelPanel
## Whether the labels currently read for touch (no key names).
var _touch_labels: bool = false
## The top-bar pieces the duel's question strip covers while it is up.
var _bar: Array[CanvasItem] = []
## How long the pause menu has been open, for the resting easter egg.
var _pause_time: float = 0.0


func _ready() -> void:
	add_to_group(&"stage_hud")
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(_hide_hint)
	add_child(timer)
	timer.start()
	_refresh_hint()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool) -> void: _refresh_hint())
	if TouchControls.active:
		%Hint.hide()

	%MapButton.pressed.connect(open_pause)
	%ResumeButton.pressed.connect(close_pause)
	%RestartButton.pressed.connect(_on_restart_pressed)
	%QuitButton.pressed.connect(_on_map_pressed)
	%ClearMapButton.pressed.connect(_on_map_pressed)
	%Falls.text = ""
	_build_lesson_ui()
	_update_seed_label()
	fade_to(0.0, 0.35)


## The pieces the lessons add to the scene's layout: the lesson topic beside
## the stage name, the Spellbook entry, the duel strips, and the card.
func _build_lesson_ui() -> void:
	_lesson_label = Label.new()
	_lesson_label.add_theme_font_size_override(&"font_size", 10)
	_lesson_label.add_theme_color_override(&"font_color", Color(1.0, 0.84, 0.5, 0.9))
	_lesson_label.add_theme_constant_override(&"outline_size", 3)
	_lesson_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lesson_label)
	move_child(_lesson_label, %Title.get_index() + 1)

	_spellbook_button = Button.new()
	_spellbook_button.text = "Spellbook"
	_spellbook_button.pressed.connect(_open_spellbook)
	%ResumeButton.add_sibling(_spellbook_button)

	_duel = DuelPanel.new()
	_duel.hide()
	add_child(_duel)
	move_child(_duel, %PausePanel.get_index())
	_bar = [%Title, _lesson_label, $SeedChip, %Clock, %Falls, %MapButton]

	_card = LessonCard.new()
	_card.hide()
	add_child(_card)
	move_child(_card, %Fade.get_index())


## Lesson cards and the Spellbook read input before the GUI. Mid-duel, the
## hint key goes to the wizard.
func _input(event: InputEvent) -> void:
	if _card != null and _card.visible:
		_card_input(event)
		return
	if is_duel_open() and not _paused and event.is_action_pressed(&"hint"):
		get_viewport().set_input_as_handled()
		duel_hint_requested.emit()


func _process(delta: float) -> void:
	_card_lock -= delta
	if _paused:
		_pause_time += delta
		if _pause_time >= Eggs.RESTING_AFTER:
			_pause_title().text = Eggs.RESTING
	if TouchControls.active != _touch_labels:
		_touch_labels = TouchControls.active
		%MapButton.text = "Pause" if _touch_labels else "Pause [Esc]"
		if _touch_labels and not waiting_for_start and not cleared:
			%Hint.hide()


func _unhandled_input(event: InputEvent) -> void:
	if waiting_for_start or is_card_open():
		return
	if passage_shown or cleared:
		if _accepts_continue(event):
			get_viewport().set_input_as_handled()
			if cleared:
				_on_map_pressed()
			else:
				request_continue()
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		if _paused:
			close_pause()
		else:
			open_pause()


func _accepts_continue(event: InputEvent) -> bool:
	if Time.get_ticks_msec() / 1000.0 < _continue_at:
		return false
	if event is InputEventScreenTouch and event.pressed:
		return true
	return event.is_action_pressed(&"jump") or event.is_action_pressed(&"confirm")


func set_stage_name(stage_name: String) -> void:
	%Title.text = stage_name


## The lesson topic, set just after the stage name on the same line.
func set_lesson(text: String) -> void:
	_lesson_label.text = text
	var title := %Title as Label
	var font := title.get_theme_font(&"font")
	var width := font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size(&"font_size")).x
	_lesson_label.position = Vector2(title.position.x + width + 8.0, title.position.y + 3.0).round()


func set_scrolls(found: int, total: int) -> void:
	scroll_found = found
	scroll_total = total


func note_hint() -> void:
	hints_used += 1


func set_seed_total(total: int) -> void:
	seed_total = total
	_update_seed_label()


func set_time(seconds: float) -> void:
	%Clock.text = GameProgression.format_time(seconds) if seconds > 0.0 else "0:00.0"


func note_seed() -> void:
	seed_count += 1
	_update_seed_label()
	var icon := %SeedIcon as Control
	icon.pivot_offset = icon.size * 0.5
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2(1.5, 1.5), 0.06)
	tween.tween_property(icon, "scale", Vector2.ONE, 0.12)


func note_fall() -> void:
	falls += 1
	%Falls.text = "Falls %d" % falls


func is_paused() -> bool:
	return _paused


func open_pause() -> void:
	if _paused or cleared or passage_shown or waiting_for_start or is_card_open():
		return
	_paused = true
	get_tree().paused = true
	_pause_time = 0.0
	_pause_title().text = "Paused"
	%PauseStats.text = "%s   Tins %d/%d   Scrolls %d/%d" % [%Clock.text, seed_count, seed_total, scroll_found, scroll_total]
	%PausePanel.show()
	%ResumeButton.grab_focus()


func _pause_title() -> Label:
	return $PausePanel/Center/Box/Items/PauseTitle as Label


func close_pause() -> void:
	if not _paused:
		return
	_paused = false
	%PausePanel.hide()
	get_tree().paused = false


func show_press_to_start() -> void:
	waiting_for_start = true
	%Hint.text = "Tap to play" if TouchControls.active else "Press any key to play"
	%Hint.show()


func hide_press_to_start() -> void:
	waiting_for_start = false
	_refresh_hint()
	if not cleared and not TouchControls.active:
		%Hint.show()


## Results card between stages. Jump continues; the stage also sends a timed continue.
func show_passage(detail: String, time: float = 0.0, new_best: bool = false) -> void:
	passage_shown = true
	waiting_for_start = false
	_continue_sent = false
	_continue_at = Time.get_ticks_msec() / 1000.0 + CONTINUE_LOCK
	%Headline.text = "Stage clear!"
	%Subhead.text = detail
	_fill_stats(time)
	%Best.visible = new_best
	%ContinueHint.text = "Tap to continue" if TouchControls.active else "Press Jump to continue"
	%ClearMapButton.hide()
	_show_card()


## Final card after the last stage.
func show_clear(time: float = 0.0, new_best: bool = false) -> void:
	cleared = true
	passage_shown = false
	waiting_for_start = false
	_continue_at = Time.get_ticks_msec() / 1000.0 + CONTINUE_LOCK * 2.0
	%Headline.text = "The Grail is found!"
	%Subhead.text = "%s cleared. Thanks for playing!" % %Title.text
	if falls >= Eggs.BRIGHT_SIDE_FALLS:
		%Subhead.text = Eggs.BRIGHT_SIDE
	_fill_stats(time)
	%Best.visible = new_best
	%ContinueHint.text = "Tap for the map" if TouchControls.active else "Press Jump for the map"
	%ClearMapButton.show()
	_show_card()


func request_continue() -> void:
	if _continue_sent:
		return
	_continue_sent = true
	continue_requested.emit()


func is_cleared() -> bool:
	return cleared


## Tweens the full-screen fade. 1.0 is black.
func fade_to(alpha: float, duration: float) -> Tween:
	var fade := %Fade as ColorRect
	if _fade_tween != null:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade, "modulate:a", alpha, duration)
	return _fade_tween


## Opens the duel's strips over the arena and tucks the top bar away.
func open_duel(wizard_title: String, tint: Color, broken: int, total: int, sparks: int) -> void:
	%Hint.hide()
	for item in _bar:
		item.hide()
	_duel.open(wizard_title, tint, broken, total, sparks)


## The wizard's next question; `step` is the right answers so far plus one.
func duel_question(question: Dictionary, step: int, total: int) -> void:
	_duel.show_question(question, step, total)


## The verdict on a bumped answer. `remaining` is the wards still standing.
func duel_verdict(chosen: int, correct: bool, remaining: int) -> void:
	_duel.show_verdict(chosen, correct, remaining)


func duel_hint(whisper: String, detail: String, dim_index: int = -1, more: bool = true) -> void:
	_duel.show_hint(whisper, detail, dim_index, more)


func duel_say(text: String) -> void:
	_duel.say(text)


func duel_sparks(count: int) -> void:
	_duel.set_sparks(count)


func close_duel() -> void:
	_duel.hide()
	for item in _bar:
		item.show()


## The part of the screen the duel's strips and the touch buttons leave clear.
func duel_clear_rect() -> Rect2:
	var rows := _duel.clear_band()
	var sides := TouchControls.covered_sides()
	var width := get_viewport().get_visible_rect().size.x
	return Rect2(sides.x, rows.x, width - sides.x - sides.y, rows.y - rows.x)


func is_duel_open() -> bool:
	return _duel != null and _duel.visible


## Test hook: the answers a hint struck out on the open question.
func duel_dimmed() -> Array:
	return _duel.dimmed()


func duel_status() -> String:
	return _duel.status_text()


func duel_speech() -> String:
	return _duel.speech_text()


## Shows a lesson card and holds the stage until it is read. Cards that arrive
## while one is up wait their turn.
func open_card(card: Dictionary) -> void:
	if _card.visible and not _book_open:
		_card_queue.append(card)
		return
	if not get_tree().paused:
		_card_paused_tree = true
		get_tree().paused = true
	_card_lock = CARD_LOCK
	_card.show_card(_with_footer(card))


func is_card_open() -> bool:
	return _card != null and _card.visible


func is_spellbook_open() -> bool:
	return _book_open


func card_title() -> String:
	return _card.card_title() if is_card_open() else ""


func _card_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	get_viewport().set_input_as_handled()
	if _book_open:
		# By touch, the outer thirds of the screen turn pages; the middle closes.
		if mouse != null and _book_pages.size() > 1:
			var third := get_viewport().get_visible_rect().size.x / 3.0
			if mouse.position.x < third:
				_show_book_page(_book_index - 1)
				return
			if mouse.position.x > third * 2.0:
				_show_book_page(_book_index + 1)
				return
		if event.is_action_pressed(&"move_left"):
			_show_book_page(_book_index - 1)
		elif event.is_action_pressed(&"move_right"):
			_show_book_page(_book_index + 1)
		elif mouse != null or _is_close_press(event) or event.is_action_pressed(&"pause") or event.is_action_pressed(&"map") or event.is_action_pressed(&"ui_cancel"):
			_close_spellbook()
		return
	if _card_lock > 0.0:
		return
	if mouse != null or _is_close_press(event) or event.is_action_pressed(&"jump"):
		_close_card()


func _is_close_press(event: InputEvent) -> bool:
	return event.is_action_pressed(&"confirm") or event.is_action_pressed(&"ui_accept")


func _close_card() -> void:
	if not _card_queue.is_empty():
		_card_lock = CARD_LOCK
		_card.show_card(_with_footer(_card_queue.pop_front()))
		return
	_card.hide()
	if _card_paused_tree:
		_card_paused_tree = false
		get_tree().paused = false
	card_closed.emit()


func _with_footer(card: Dictionary) -> Dictionary:
	var shown := card.duplicate()
	if not shown.has("footer"):
		var joypad := not Input.get_connected_joypads().is_empty()
		if TouchControls.active:
			shown["footer"] = "Tap to continue"
		else:
			shown["footer"] = "Press A to continue" if joypad else "Press Space to continue"
	return shown


## Every scroll read so far, opened from the pause menu at this stage's lesson.
func _open_spellbook() -> void:
	if not _paused or _book_open:
		return
	_book_pages.clear()
	var start := -1
	var stage_id := _stage_id()
	for scroll_id in GameProgression.known_scrolls():
		var scroll := Lessons.scroll(scroll_id)
		var stage := int(scroll.get("stage", 0))
		if stage == stage_id and start < 0:
			start = _book_pages.size()
		_book_pages.append({
			"kicker": "Spellbook  -  Lesson %d: %s" % [stage, Lessons.topic(stage)],
			"title": scroll.get("title", ""),
			"code": scroll.get("code", ""),
			"body": scroll.get("insight", ""),
		})
	if _book_pages.is_empty():
		_book_pages.append({
			"kicker": "Spellbook",
			"title": "No scrolls yet",
			"code": "",
			"body": "Lore scrolls lie along the trail. Each one you read is kept here, and the wizards mostly ask about what you have read.",
		})
	_book_open = true
	%PausePanel.hide()
	_show_book_page(maxi(start, 0))


func _show_book_page(index: int) -> void:
	_book_index = clampi(index, 0, _book_pages.size() - 1)
	var page := _book_pages[_book_index].duplicate()
	var arrows := "<  %d / %d  >     " % [_book_index + 1, _book_pages.size()] if _book_pages.size() > 1 else ""
	page["footer"] = "%s%s" % [arrows, "Tap the middle to close" if TouchControls.active else "Esc to close"]
	page["tint"] = WHISPER
	_card.show_card(page)


func _close_spellbook() -> void:
	_book_open = false
	_card.hide()
	%PausePanel.show()
	_spellbook_button.grab_focus()


func _stage_id() -> int:
	var stage := get_parent()
	if stage != null and stage.has_method(&"stage_index"):
		return int(stage.call(&"stage_index"))
	return 0


func _show_card() -> void:
	%Hint.hide()
	%ClearPanel.show()
	var box := %Box as Control
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2(0.85, 0.85)
	box.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(box, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(box, "modulate:a", 1.0, 0.12)


func _fill_stats(time: float) -> void:
	var grid := %Stats as GridContainer
	for child in grid.get_children():
		child.queue_free()
	var rows: Array = [
		["Time", GameProgression.format_time(time)],
		["Tins of spam", "%d / %d" % [seed_count, seed_total]],
		["Scrolls", "%d / %d" % [scroll_found, scroll_total]],
		["Wizard hints", str(hints_used)],
		["Falls", str(falls)],
	]
	for row in rows:
		for index in 2:
			var label := Label.new()
			label.text = row[index]
			label.add_theme_font_size_override(&"font_size", 13)
			if index == 0:
				label.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.86))
			else:
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				label.add_theme_color_override(&"font_color", Color(1.0, 0.94, 0.8))
			grid.add_child(label)


func _update_seed_label() -> void:
	%SeedCount.text = "%d/%d" % [seed_count, seed_total] if seed_total > 0 else str(seed_count)


func _refresh_hint() -> void:
	if waiting_for_start:
		return
	if Input.get_connected_joypads().is_empty():
		%Hint.text = "Move A/D  Jump Space  Pause Esc"
	else:
		%Hint.text = "Move D-pad  Jump A  Pause Start"


func _on_restart_pressed() -> void:
	_paused = false
	%PausePanel.hide()
	get_tree().paused = false
	restart_requested.emit()


func _on_map_pressed() -> void:
	_paused = false
	%PausePanel.hide()
	get_tree().paused = false
	map_requested.emit()


func _hide_hint() -> void:
	if not cleared and not waiting_for_start:
		%Hint.hide()
