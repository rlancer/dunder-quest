extends Control

## The title: the palace at night, the name in sand-gold, and the rooms.
## The first press also unlocks web audio.

const ART := "res://assets/backgrounds/title.png"
const MUSIC := "res://assets/audio/music_title.ogg"
const PRINCE := preload("res://assets/sprites/prince.png")

var _start: Button
var _new: Button
var _rooms: HBoxContainer
var _confirm_reset: bool = false
var _clock: float = 0.0
var _fade: ColorRect
var _leaving: bool = false
## Held here: a texture only loaded inside _draw is freed before it's drawn.
var _art: Texture2D


func _ready() -> void:
	Progress.load_data()
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	var column := VBoxContainer.new()
	column.position = Vector2(36, 128)
	column.custom_minimum_size = Vector2(120, 0)
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	_start = _button(column, "Carry on" if Progress.has_progress() else "Start", func() -> void: _go(Progress.next_room()))
	_new = _button(column, "New game", _on_new)
	_new.visible = Progress.has_progress()
	_button(column, "Full screen", _toggle_fullscreen).visible = not OS.has_feature("web_ios")
	_button(column, "Quit", func() -> void: get_tree().quit()).visible = not OS.has_feature("web")

	# Every room you've reached, by number.
	_rooms = HBoxContainer.new()
	_rooms.position = Vector2(36, 236)
	_rooms.add_theme_constant_override(&"separation", 4)
	add_child(_rooms)
	for id in range(1, Story.count() + 1):
		var button := Button.new()
		button.text = str(id)
		button.custom_minimum_size = Vector2(22, 20)
		button.disabled = not Progress.is_open(id)
		button.tooltip_text = Story.level(id).title
		button.pressed.connect(_go.bind(id))
		_rooms.add_child(button)
	_rooms.visible = Progress.has_progress()

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	_start.grab_focus()
	if not OS.has_feature("web") or StageAudio.web_audio_unlocked:
		_music()


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	button.focus_entered.connect(func() -> void:
		if _confirm_reset and button != _new:
			_cancel_reset())
	parent.add_child(button)
	return button


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Palette.INK)
	if _art != null:
		draw_texture_rect(_art, Rect2(0, 0, 480, 270), false)
	# A dark wash on the left, where the name and the menu sit.
	for i in 24:
		draw_rect(Rect2(i * 12.0, 0, 12, 270), Color(Palette.INK, 0.78 * (1.0 - i / 24.0)))
	draw_string(Palette.pixel(), Vector2(36, 62), "Prince of", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.SAND_PALE)
	draw_string(Palette.pixel(), Vector2(36, 92), "Versions", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.SAND)
	draw_string(Palette.mono(), Vector2(37, 108), "Learn Git. Turn back the sands.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
	draw_string(Palette.mono(), Vector2(37, 120), "a __dunder_quest__ game", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.TEAL.lightened(0.3))
	if _rooms.visible:
		draw_string(Palette.pixel(), Vector2(36, 232), "Rooms cleared %d/%d" % [Progress.cleared_count(), Story.count()], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Palette.PAPER, 0.8))
	var frame := 10 if fmod(_clock, 5.0) > 3.6 else 0
	draw_texture_rect_region(PRINCE, Rect2(196, 180, 48, 64), Rect2(24 * frame, 0, 24, 32))


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
			StageAudio.web_audio_unlocked = true
			_music()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()


func _go(id: int) -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: Main.play(get_tree(), id))


func _on_new() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_new.text = "Wipe the save? Again"
		_new.add_theme_color_override(&"font_color", Palette.CRIMSON.lightened(0.3))
		return
	Progress.reset()
	_go(1)


func _cancel_reset() -> void:
	_confirm_reset = false
	_new.text = "New game"
	_new.remove_theme_color_override(&"font_color")


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _music() -> void:
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)
