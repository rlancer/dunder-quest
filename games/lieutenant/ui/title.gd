extends Control

## The title: a street at night, a lamp, the Lieutenant and his dog under
## it, and the name in fat cream letters. The first press also unlocks web
## audio.

const ART := "res://assets/backgrounds/title.png"
const MUSIC := "res://assets/audio/music_title.ogg"
const SHARP := preload("res://world/sharp_pixels.gdshader")

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
	_figure("lt", 10, Vector2(380, 244))
	_figure("null", 5, Vector2(330, 246))
	var column := VBoxContainer.new()
	column.position = Vector2(40, 132)
	column.custom_minimum_size = Vector2(104, 0)
	column.add_theme_constant_override(&"separation", 4)
	add_child(column)
	_start = _button(column, "Carry on" if Progress.has_progress() else "Start", _on_start)
	_new = _button(column, "New game", _on_new)
	_new.visible = Progress.has_progress()
	_button(column, "Story", _on_story)
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
	_footer.text = "Cases closed %d/%d" % [Progress.cleared_count(), Progress.count()] if Progress.has_progress() else ("Tap to choose" if TouchControls.active else "Arrows to walk, E to talk, Enter to call Records")

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	_start.grab_focus()
	if not OS.has_feature("web") or StageAudio.web_audio_unlocked:
		_music()


## One frame of a sheet, standing on the street.
func _figure(who: String, frames: int, feet: Vector2) -> void:
	var path := "res://assets/sprites/%s.png" % who
	if not ResourceLoader.exists(path):
		return
	var sprite := Sprite2D.new()
	sprite.texture = load(path) as Texture2D
	sprite.hframes = frames
	sprite.frame = 0
	sprite.centered = false
	sprite.scale = Vector2(Person.SCALE, Person.SCALE)
	sprite.flip_h = true
	var size := sprite.texture.get_size() * Person.SCALE
	sprite.position = feet - Vector2(size.x / frames / 2.0, size.y)
	var sharp := ShaderMaterial.new()
	sharp.shader = SHARP
	sprite.material = sharp
	add_child(sprite)


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
	draw_string(titles, Vector2(38, 58), "Just One More", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.CREAM)
	draw_string(titles, Vector2(38, 96), "JOIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Palette.EMBER)
	var mono := Palette.mono()
	draw_string(mono, Vector2(40, 112), "He knows who did it. He needs a query that proves it. Learn SQL.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.86, 0.84, 0.78))
	draw_string(mono, Vector2(40, 124), "a __dunder_quest__ game", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.EMBER)


func _input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
			StageAudio.web_audio_unlocked = true
			_music()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()


## A first run opens on the prologue and goes straight into the first case.
## After that, Start goes to the case files.
func _on_start() -> void:
	if Progress.has_progress():
		_leave(func() -> void: get_tree().change_scene_to_file(Main.FILES))
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
