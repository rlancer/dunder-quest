class_name StageHud
extends CanvasLayer

## Stage overlay: name and lesson, seeds, clock, falls, the pause menu and its
## Spellbook, the results card, lesson cards (scrolls, keys), the wizard's quiz
## panel with its hints, and the full-screen fade used for deaths and scene changes.
## Runs while the tree is paused so the pause menu and cards can answer.

signal map_requested
signal restart_requested
signal continue_requested
## The player picked option `index` on the open quiz question.
signal quiz_answered(index: int)
## The verdict has been read (timed out or skipped); the stage moves on.
signal quiz_feedback_done
## The player asked the wizard for a hint on the open question.
signal quiz_hint_requested
## The last queued lesson card was dismissed and play resumes.
signal card_closed

const CONTINUE_LOCK := 0.6
const QUIZ_LETTERS: Array[String] = ["A", "B", "C", "D"]
## How long a verdict stays up before moving on by itself.
const QUIZ_RIGHT_HOLD := 2.6
const QUIZ_WRONG_HOLD := 4.2
## A press this soon after answering is the same press, not a skip.
const QUIZ_SKIP_LOCK := 0.45
const QUIZ_GOOD := Color(0.5, 0.92, 0.6)
const QUIZ_BAD := Color(1.0, 0.46, 0.4)
const QUIZ_WHISPER := Color(0.78, 0.66, 1.0)
const QUIZ_DIMMED := Color(0.42, 0.4, 0.48)
## A press this soon after a card opens is the press that was already held.
const CARD_LOCK := 0.35

enum QuizState { CLOSED, ASKING, FEEDBACK, DONE }

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
var _quiz_state: QuizState = QuizState.CLOSED
var _quiz_question: Dictionary = {}
var _quiz_selected: int = 0
var _quiz_hold: float = 0.0
var _quiz_lock: float = 0.0
var _quiz_buttons: Array[Button] = []
## Options the wizard's hint ruled out: index -> true. Selection skips them.
var _quiz_dimmed: Dictionary = {}
var _hint_button: Button
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

	%MapButton.pressed.connect(open_pause)
	%ResumeButton.pressed.connect(close_pause)
	%RestartButton.pressed.connect(_on_restart_pressed)
	%QuitButton.pressed.connect(_on_map_pressed)
	%ClearMapButton.pressed.connect(_on_map_pressed)
	for child in %Options.get_children():
		var button := child as Button
		var index := _quiz_buttons.size()
		_quiz_buttons.append(button)
		button.pressed.connect(_on_quiz_option_pressed.bind(index))
		button.mouse_entered.connect(_on_quiz_option_hovered.bind(index))
	%Falls.text = ""
	_build_lesson_ui()
	_update_seed_label()
	fade_to(0.0, 0.35)


## The pieces the lessons add to the scene's layout: the lesson topic beside
## the stage name, the quiz's hint button, the Spellbook entry, and the card.
func _build_lesson_ui() -> void:
	_lesson_label = Label.new()
	_lesson_label.add_theme_font_size_override(&"font_size", 10)
	_lesson_label.add_theme_color_override(&"font_color", Color(1.0, 0.84, 0.5, 0.9))
	_lesson_label.add_theme_constant_override(&"outline_size", 3)
	_lesson_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lesson_label)
	move_child(_lesson_label, %Title.get_index() + 1)

	_hint_button = Button.new()
	_hint_button.text = "Hint"
	_hint_button.focus_mode = Control.FOCUS_NONE
	_hint_button.add_theme_font_size_override(&"font_size", 10)
	_hint_button.pressed.connect(_on_hint_pressed)
	%WizardName.get_parent().add_child(_hint_button)

	_spellbook_button = Button.new()
	_spellbook_button.text = "Spellbook"
	_spellbook_button.pressed.connect(_open_spellbook)
	%ResumeButton.add_sibling(_spellbook_button)

	_card = LessonCard.new()
	_card.hide()
	add_child(_card)
	move_child(_card, %Fade.get_index())


## The quiz reads input before the GUI so arrows/WASD, the d-pad and confirm
## all drive the same selection, and focus navigation never double-steps.
func _input(event: InputEvent) -> void:
	if _card != null and _card.visible:
		_card_input(event)
		return
	if _quiz_state == QuizState.CLOSED or _paused:
		return
	var confirm := event.is_action_pressed(&"confirm") or event.is_action_pressed(&"ui_accept")
	if _quiz_state == QuizState.ASKING:
		if event.is_action_pressed(&"hint"):
			get_viewport().set_input_as_handled()
			quiz_hint_requested.emit()
			return
		var step := 0
		if event.is_action_pressed(&"move_up"):
			step = -2
		elif event.is_action_pressed(&"move_down"):
			step = 2
		elif event.is_action_pressed(&"move_left"):
			step = -1
		elif event.is_action_pressed(&"move_right"):
			step = 1
		if step != 0:
			get_viewport().set_input_as_handled()
			_step_quiz_selection(step)
		elif confirm:
			get_viewport().set_input_as_handled()
			_submit_quiz(_quiz_selected)
		return
	if _quiz_state == QuizState.FEEDBACK:
		var mouse := event as InputEventMouseButton
		var click := mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
		if (confirm or click) and _quiz_lock <= 0.0:
			get_viewport().set_input_as_handled()
			_finish_quiz_feedback()


func _process(delta: float) -> void:
	_card_lock -= delta
	if _quiz_state != QuizState.FEEDBACK or _paused:
		return
	_quiz_lock -= delta
	_quiz_hold -= delta
	if _quiz_hold <= 0.0:
		_finish_quiz_feedback()


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
	%PauseStats.text = "%s   Seeds %d/%d   Scrolls %d/%d" % [%Clock.text, seed_count, seed_total, scroll_found, scroll_total]
	%PausePanel.show()
	%ResumeButton.grab_focus()


func close_pause() -> void:
	if not _paused:
		return
	_paused = false
	%PausePanel.hide()
	get_tree().paused = false
	if _quiz_state == QuizState.ASKING:
		_select_quiz_option(_quiz_selected)


func show_press_to_start() -> void:
	waiting_for_start = true
	%Hint.text = "Press any key to play"
	%Hint.show()


func hide_press_to_start() -> void:
	waiting_for_start = false
	_refresh_hint()
	if not cleared:
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
	%ContinueHint.text = "Press Jump to continue"
	%ClearMapButton.hide()
	_show_card()


## Final card after the last stage.
func show_clear(time: float = 0.0, new_best: bool = false) -> void:
	cleared = true
	passage_shown = false
	waiting_for_start = false
	_continue_at = Time.get_ticks_msec() / 1000.0 + CONTINUE_LOCK * 2.0
	%Headline.text = "The kiln is lit!"
	%Subhead.text = "%s cleared. Thanks for playing!" % %Title.text
	_fill_stats(time)
	%Best.visible = new_best
	%ContinueHint.text = "Press Jump for the map"
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


## Opens the quiz panel on a question from `WizardQuiz`.
func open_quiz(wizard_title: String, question: Dictionary, tint: Color) -> void:
	_quiz_question = question
	%WizardName.text = wizard_title
	%WizardName.add_theme_color_override(&"font_color", tint.lightened(0.5))
	%Prompt.text = str(question.get("prompt", "What does this print?"))
	%Code.text = str(question.get("code", ""))
	var options: PackedStringArray = question.get("options", PackedStringArray())
	for index in _quiz_buttons.size():
		var button := _quiz_buttons[index]
		button.text = "%s  %s" % [QUIZ_LETTERS[index], options[index] if index < options.size() else ""]
		button.disabled = false
		button.remove_theme_stylebox_override(&"disabled")
		button.remove_theme_color_override(&"font_disabled_color")
	_quiz_dimmed = {}
	_hint_button.disabled = false
	%Verdict.text = "%s bars the way. Answer to pass." % wizard_title
	%Verdict.add_theme_color_override(&"font_color", Color(0.8, 0.78, 0.9))
	%Explanation.text = _quiz_controls_hint()
	_quiz_state = QuizState.ASKING
	var was_open: bool = %QuizPanel.visible
	%QuizPanel.show()
	_select_quiz_option(0)
	if not was_open:
		var box := %QuizBox as Control
		box.pivot_offset = box.size * 0.5
		box.scale = Vector2(0.9, 0.9)
		box.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(box, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(box, "modulate:a", 1.0, 0.12)


## Marks the chosen option, reveals the right one and its explanation, then
## emits `quiz_feedback_done` after a hold or a skip press.
func show_quiz_feedback(chosen: int, correct: bool) -> void:
	_quiz_state = QuizState.FEEDBACK
	_hint_button.disabled = true
	_quiz_hold = QUIZ_RIGHT_HOLD if correct else QUIZ_WRONG_HOLD
	_quiz_lock = QUIZ_SKIP_LOCK
	var answer := int(_quiz_question.get("answer", 0))
	for index in _quiz_buttons.size():
		var button := _quiz_buttons[index]
		button.disabled = true
		if index == answer:
			_paint_quiz_option(button, QUIZ_GOOD)
		elif index == chosen:
			_paint_quiz_option(button, QUIZ_BAD)
	var options: PackedStringArray = _quiz_question.get("options", PackedStringArray())
	if correct:
		%Verdict.text = "Correct! The barrier fades."
		%Verdict.add_theme_color_override(&"font_color", QUIZ_GOOD)
	else:
		%Verdict.text = "Zapped! It prints  %s" % (options[answer] if answer < options.size() else "?")
		%Verdict.add_theme_color_override(&"font_color", QUIZ_BAD)
		_shake_quiz()
	%Explanation.text = str(_quiz_question.get("explanation", ""))


## The wizard's hint: a whisper in the verdict line, a detail under it, and
## optionally one wrong option he refuses to look at, which dims out.
func show_quiz_hint(whisper: String, detail: String, dim_index: int = -1, more: bool = true) -> void:
	if _quiz_state != QuizState.ASKING:
		return
	%Verdict.text = whisper
	%Verdict.add_theme_color_override(&"font_color", QUIZ_WHISPER)
	%Explanation.text = detail
	if dim_index >= 0 and dim_index < _quiz_buttons.size():
		_quiz_dimmed[dim_index] = true
		var button := _quiz_buttons[dim_index]
		button.disabled = true
		_paint_quiz_option(button, QUIZ_DIMMED)
		if _quiz_selected == dim_index:
			_step_quiz_selection(1)
	_hint_button.disabled = not more


func quiz_dimmed() -> Array:
	return _quiz_dimmed.keys()


func close_quiz() -> void:
	_quiz_state = QuizState.CLOSED
	_quiz_question = {}
	%QuizPanel.hide()
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null and %QuizPanel.is_ancestor_of(focused):
		focused.release_focus()


func is_quiz_open() -> bool:
	return _quiz_state != QuizState.CLOSED


func is_quiz_asking() -> bool:
	return _quiz_state == QuizState.ASKING


func quiz_selected_index() -> int:
	return _quiz_selected


## Test hook: the marked answer of the open question, so bots can steer the
## real selection to it (or away from it) and press confirm.
func quiz_answer_index() -> int:
	return int(_quiz_question.get("answer", -1))


func quiz_question() -> Dictionary:
	return _quiz_question


## Moves the selection by `step`, passing over options a hint dimmed out.
func _step_quiz_selection(step: int) -> void:
	var count := _quiz_buttons.size()
	var target := _quiz_selected
	for _attempt in count:
		target = posmod(target + step, count)
		if not _quiz_dimmed.has(target):
			break
		# Vertical steps that land on a dimmed option slide sideways instead.
		step = signi(step)
	_select_quiz_option(target)


func _select_quiz_option(index: int) -> void:
	if _quiz_buttons.is_empty():
		return
	_quiz_selected = clampi(index, 0, _quiz_buttons.size() - 1)
	_quiz_buttons[_quiz_selected].grab_focus()


func _submit_quiz(index: int) -> void:
	if _quiz_state != QuizState.ASKING:
		return
	_select_quiz_option(index)
	# The stage replies with show_quiz_feedback; until then nothing else may pick.
	_quiz_state = QuizState.DONE
	quiz_answered.emit(index)


func _finish_quiz_feedback() -> void:
	if _quiz_state != QuizState.FEEDBACK:
		return
	_quiz_state = QuizState.DONE
	quiz_feedback_done.emit()


func _paint_quiz_option(button: Button, color: Color) -> void:
	var base := button.get_theme_stylebox(&"normal") as StyleBoxFlat
	if base != null:
		var box := base.duplicate() as StyleBoxFlat
		box.border_color = color
		box.bg_color = Color(color.r * 0.22, color.g * 0.22, color.b * 0.22, 0.96)
		button.add_theme_stylebox_override(&"disabled", box)
	button.add_theme_color_override(&"font_disabled_color", color.lightened(0.3))


func _shake_quiz() -> void:
	var center := %QuizPanel.get_node(^"Center") as Control
	var tween := create_tween()
	for offset: float in [-5.0, 4.0, -3.0, 2.0, 0.0]:
		tween.tween_property(center, "position:x", offset, 0.04)


func _quiz_controls_hint() -> String:
	if Input.get_connected_joypads().is_empty():
		return "Arrows or WASD to choose, Space or Enter to answer. H asks for a hint."
	return "D-pad to choose, A to answer. Y asks for a hint."


func _on_quiz_option_pressed(index: int) -> void:
	if _paused or _quiz_dimmed.has(index):
		return
	_submit_quiz(index)


func _on_quiz_option_hovered(index: int) -> void:
	if _quiz_state == QuizState.ASKING and not _paused and not _quiz_dimmed.has(index):
		_select_quiz_option(index)


func _on_hint_pressed() -> void:
	if _quiz_state == QuizState.ASKING and not _paused:
		quiz_hint_requested.emit()


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
			"body": "Lore scrolls lie along the trail. Each one you read is kept here, and the wizards only ask about what you have read.",
		})
	_book_open = true
	%PausePanel.hide()
	_show_book_page(maxi(start, 0))


func _show_book_page(index: int) -> void:
	_book_index = clampi(index, 0, _book_pages.size() - 1)
	var page := _book_pages[_book_index].duplicate()
	var arrows := "<  %d / %d  >     " % [_book_index + 1, _book_pages.size()] if _book_pages.size() > 1 else ""
	page["footer"] = "%sEsc to close" % arrows
	page["tint"] = QUIZ_WHISPER
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
		["Emberseeds", "%d / %d" % [seed_count, seed_total]],
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
