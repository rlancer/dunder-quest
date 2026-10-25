extends Control

## The title: the two flatmates on the landing outside Flat 5B, the name,
## and a short menu. The first press also unlocks web audio.

const ART := "res://assets/backgrounds/title.png"
const MUSIC := "res://assets/audio/music_title.ogg"
const EGG_HOLD := 4.0

var _buttons: Array[Button] = []
var _start: Button
var _new: Button
var _footer: Label
var _logo: Control
var _confirm_reset: bool = false
var _typed: String = ""
var _idle: float = 0.0
var _egg_time: float = 0.0
var _clock: float = 0.0
var _fade: ColorRect
var _leaving: bool = false


func _ready() -> void:
	Progress.load_data()
	var sky := ColorRect.new()
	sky.color = Color(0.1, 0.09, 0.13)
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	if ResourceLoader.exists(ART):
		var art := TextureRect.new()
		art.texture = load(ART) as Texture2D
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	_logo = Control.new()
	_logo.position = Vector2(24, 26)
	_logo.draw.connect(_draw_logo)
	add_child(_logo)

	var column := VBoxContainer.new()
	column.position = Vector2(28, 128)
	column.custom_minimum_size = Vector2(130, 0)
	column.add_theme_constant_override(&"separation", 5)
	add_child(column)
	_start = _button(column, "Carry on" if Progress.has_progress() else "Start", _on_start)
	_new = _button(column, "New game", _on_new)
	_new.visible = Progress.has_progress()
	_button(column, "Full screen", _toggle_fullscreen).visible = not OS.has_feature("web_ios")
	_button(column, "Quit", func() -> void: get_tree().quit()).visible = not OS.has_feature("web")

	_footer = Label.new()
	_footer.position = Vector2(0, 252)
	_footer.size = Vector2(472, 14)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.add_theme_font_size_override(&"font_size", 11)
	_footer.add_theme_color_override(&"font_color", Palette.PAPER.darkened(0.1))
	_footer.add_theme_color_override(&"font_outline_color", Palette.INK)
	_footer.add_theme_constant_override(&"outline_size", 3)
	add_child(_footer)
	_update_footer()

	_fade = ColorRect.new()
	_fade.color = Color(0.04, 0.03, 0.06, 1.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.5)
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
	_buttons.append(button)
	return button


func _draw_logo() -> void:
	var font := load("res://assets/fonts/PixelifySans.ttf") as Font
	var bob := roundf(sin(_clock * 1.6) * 1.5)
	# flatmates.js, with the .js in JavaScript yellow, like a file name.
	var x := 0.0
	for part: Array in [["flatmates", Palette.PAPER], [".js", Palette.JS]]:
		_logo.draw_string_outline(font, Vector2(x, 40 + bob), str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 6, Palette.INK)
		_logo.draw_string(font, Vector2(x, 40 + bob), str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, part[1])
		x += font.get_string_size(str(part[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var mono := Palette.mono()
	var tag := "Two flatmates. Two points of view. One of them runs your JavaScript."
	_logo.draw_string_outline(mono, Vector2(2, 62), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
	_logo.draw_string(mono, Vector2(2, 62), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER)
	var brand := "a __dunder_quest__ game"
	_logo.draw_string_outline(mono, Vector2(2, 78), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
	_logo.draw_string(mono, Vector2(2, 78), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)


func _process(delta: float) -> void:
	_clock += delta
	_logo.queue_redraw()
	_idle += delta
	if _idle >= 60.0 and _egg_time <= 0.0 and _footer.text != Eggs.IDLE:
		_footer.text = Eggs.IDLE
	if _egg_time > 0.0:
		_egg_time -= delta
		if _egg_time <= 0.0:
			_update_footer()


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if _footer.text == Eggs.IDLE:
			_update_footer()
		_idle = 0.0
		if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
			StageAudio.web_audio_unlocked = true
			_music()
	_typed = Eggs.spell(_typed, event, Eggs.BAND_WORD)
	if _typed == Eggs.BAND_WORD:
		_typed = ""
		_footer.text = Eggs.BAND
		_egg_time = EGG_HOLD
		StageAudio.play(get_tree(), preload("res://assets/audio/pickup.wav"))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()


func _on_start() -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(Main.MAP))


func _on_new() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_new.text = "Wipe the save? Press again"
		_new.add_theme_color_override(&"font_color", Palette.RED.lightened(0.2))
		_new.add_theme_color_override(&"font_focus_color", Palette.RED.lightened(0.2))
		return
	Progress.reset()
	_on_start()


func _cancel_reset() -> void:
	_confirm_reset = false
	_new.text = "New game"
	_new.remove_theme_color_override(&"font_color")
	_new.remove_theme_color_override(&"font_focus_color")


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _update_footer() -> void:
	if not Progress.has_progress():
		_footer.text = "Tap to choose" if TouchControls.active else "Arrows or WASD, Space to jump, Tab to swap heads"
		return
	_footer.text = "Custard creams %d/%d   Stops cleared %d/%d" % [Progress.total_biscuits(), Progress.max_biscuits(), Progress.cleared_count(), Progress.count()]


func _music() -> void:
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)
