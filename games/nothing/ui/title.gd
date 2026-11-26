extends Control

## The title: a corner coffee shop on the Upper West Side at dusk, and the
## name in rounded capitals the colour of its neon. The first press also
## unlocks web audio.

const ART := "res://assets/backgrounds/title.png"

var _start: Button
var _new: Button
var _footer: Label
var _confirm_reset: bool = false
var _clock: float = 0.0
var _fade: ColorRect
var _leaving: bool = false


func _ready() -> void:
	Progress.load_data()
	var art := Backdrop.sprite(ART)
	art.show_behind_parent = true
	add_child(art)
	var column := VBoxContainer.new()
	column.position = Vector2(298, 152)
	column.custom_minimum_size = Vector2(112, 0)
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	_start = _button(column, "Carry on" if Progress.has_progress() else "Start", _on_start)
	_new = _button(column, "New game", _on_new)
	_new.visible = Progress.has_progress()
	_button(column, "Story", _on_story)
	_button(column, "Full screen", _toggle_fullscreen).visible = not OS.has_feature("web_ios")
	_button(column, "Quit", func() -> void: get_tree().quit()).visible = not OS.has_feature("web")

	_footer = Label.new()
	_footer.position = Vector2(8, 254)
	_footer.size = Vector2(464, 14)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_footer.add_theme_font_size_override(&"font_size", 11)
	_footer.add_theme_color_override(&"font_color", Palette.CREAM)
	_footer.add_theme_color_override(&"font_outline_color", Palette.INK)
	_footer.add_theme_constant_override(&"outline_size", 3)
	add_child(_footer)
	_footer.text = footer_text()

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	_start.grab_focus()
	if not OS.has_feature("web") or StageAudio.web_audio_unlocked:
		Sfx.music("title")


static func footer_text() -> String:
	if Progress.has_progress():
		return "Episodes aired %d/%d" % [Progress.cleared_count(), Progress.count()]
	return "Tap to choose" if TouchControls.active else "Arrows and Enter, or the mouse"


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
	var titles := Palette.titles()
	var mono := Palette.mono()
	Fit.frame(self)
	Fit.text(self, titles, Vector2(268, 38), "A GAME ABOUT", 22, Palette.CREAM)
	# The name, with a drop shadow, as on a title card.
	Fit.text(self, titles, Vector2(268, 78), "NOTHING", 44, Palette.BRICK)
	Fit.text(self, titles, Vector2(266, 76), "NOTHING", 44, Palette.MUSTARD)
	Fit.text(self, mono, Vector2(268, 98), "Make the slip. Send it.", 16, Palette.CREAM)
	Fit.text(self, mono, Vector2(268, 110), "Learn HTTP and REST APIs.", 16, Palette.CREAM)
	Fit.text(self, mono, Vector2(268, 130), "a __dunder_quest__ game", 16, Palette.MUSTARD_LIGHT)


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
			StageAudio.web_audio_unlocked = true
			Sfx.music("title")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()


## A first run opens on the prologue and goes straight into the first
## episode. After that, Start goes to the TV guide.
func _on_start() -> void:
	if Progress.has_progress():
		_leave(func() -> void: get_tree().change_scene_to_file(Main.BOARD))
	else:
		_leave(func() -> void: Main.play_intro(get_tree(), 1))


func _on_story() -> void:
	_leave(func() -> void: Main.play_intro(get_tree(), 0))


func _leave(then: Callable) -> void:
	if _leaving:
		return
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	tween.tween_callback(then)


func _on_new() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		_new.text = "Wipe it? Again"
		_new.add_theme_color_override(&"font_color", Palette.BRICK_LIGHT)
		return
	Progress.reset()
	_on_start()


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
