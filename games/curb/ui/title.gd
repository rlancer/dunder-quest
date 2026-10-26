extends Control

## The title: yellow serif on black, like the top of an episode, over a strip
## of a Westside street at dusk with Barry in it, squinting at you. The first
## press also unlocks web audio.

const ART := "res://assets/backgrounds/title.png"
const MUSIC := "res://assets/audio/music_title.ogg"

var _start: Button
var _new: Button
var _footer: Label
var _confirm_reset: bool = false
var _clock: float = 0.0
var _fade: ColorRect
var _leaving: bool = false
var _barry: Texture2D
## Held here: a texture only loaded inside _draw is freed before it's drawn.
var _art: Texture2D


func _ready() -> void:
	Progress.load_data()
	_barry = load("res://assets/sprites/barry.png") as Texture2D
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	var column := VBoxContainer.new()
	column.position = Vector2(190, 120)
	column.custom_minimum_size = Vector2(100, 0)
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	_start = _button(column, "Carry on" if Progress.has_progress() else "Start", _on_start)
	_new = _button(column, "New game", _on_new)
	_new.visible = Progress.has_progress()
	_button(column, "Full screen", _toggle_fullscreen).visible = not OS.has_feature("web_ios")
	_button(column, "Quit", func() -> void: get_tree().quit()).visible = not OS.has_feature("web")

	_footer = Label.new()
	_footer.position = Vector2(0, 254)
	_footer.size = Vector2(472, 14)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.add_theme_font_size_override(&"font_size", 11)
	_footer.add_theme_color_override(&"font_outline_color", Palette.INK)
	_footer.add_theme_constant_override(&"outline_size", 3)
	add_child(_footer)
	_footer.text = "Scenes cleared %d/%d" % [Progress.cleared_count(), Progress.count()] if Progress.has_progress() else ("Tap to choose" if TouchControls.active else "Arrows to walk, E to talk, Enter to run a plan")

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
	draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	if _art != null:
		# A letterboxed strip of the street.
		draw_texture_rect_region(_art, Rect2(0, 196, 480, 74), Rect2(0, 186, 480, 74))
		draw_rect(Rect2(0, 196, 480, 74), Color(0, 0, 0, 0.25))
	if _barry != null:
		var frame := 4 if fmod(_clock, 6.0) > 3.5 else 0
		draw_texture_rect_region(_barry, Rect2(372, 208, 24, 48), Rect2(24 * frame, 0, 24, 48))
	var serif := Palette.serif()
	var title := "Curb Your Oxidation"
	var w := serif.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	draw_string(serif, Vector2(roundf(240 - w / 2), 70), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.YELLOW)
	var mono := Palette.mono()
	var tag := "The borrow checker is the unwritten social contract. Learn Rust."
	var tw := mono.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(mono, Vector2(roundf(240 - tw / 2), 94), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))
	var brand := "a __dunder_quest__ game"
	var bw := mono.get_string_size(brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string(mono, Vector2(roundf(240 - bw / 2), 108), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RUST)


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
			StageAudio.web_audio_unlocked = true
			_music()


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
		_new.text = "Wipe the save? Again"
		_new.add_theme_color_override(&"font_color", Palette.RED.lightened(0.2))
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


func _music() -> void:
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)
