class_name StageHud
extends CanvasLayer

## Stage overlay: name, seeds, clock, falls, the pause menu, the results card,
## and the full-screen fade used for deaths and scene changes.
## Runs while the tree is paused so the pause menu can answer.

signal map_requested
signal restart_requested
signal continue_requested

const CONTINUE_LOCK := 0.6

var seed_count: int = 0
var seed_total: int = 0
var falls: int = 0
var cleared: bool = false
var passage_shown: bool = false
var waiting_for_start: bool = false

var _paused: bool = false
var _continue_sent: bool = false
var _continue_at: float = 0.0
var _fade_tween: Tween


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
	%Falls.text = ""
	_update_seed_label()
	fade_to(0.0, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if waiting_for_start:
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
	if _paused or cleared or passage_shown or waiting_for_start:
		return
	_paused = true
	get_tree().paused = true
	%PauseStats.text = "%s   Seeds %d/%d" % [%Clock.text, seed_count, seed_total]
	%PausePanel.show()
	%ResumeButton.grab_focus()


func close_pause() -> void:
	if not _paused:
		return
	_paused = false
	%PausePanel.hide()
	get_tree().paused = false


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
