extends Control

## Title screen. The first press also unlocks web audio for the whole session.

const MAP_SCENE := "res://levels/world_map.tscn"
const MUSIC := preload("res://assets/audio/music_calm.ogg")
const CONFIRM_SOUND := preload("res://assets/audio/goal.wav")
const MOVE_SOUND := preload("res://assets/audio/bump.wav")

@onready var stage_audio: StageAudio = %StageAudio
@onready var start_button: Button = %StartButton
@onready var new_button: Button = %NewButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var stats_button: Button = %StatsButton
@onready var quit_button: Button = %QuitButton
@onready var logo: Control = %Logo
@onready var fade: ColorRect = %Fade
@onready var footer: Label = %Footer

var _leaving: bool = false
var _confirm_reset: bool = false
var _clock: float = 0.0


func _ready() -> void:
	GameProgression.load_data()
	start_button.text = "Continue" if GameProgression.has_progress() else "Start"
	new_button.visible = GameProgression.has_progress()
	var desktop := not OS.has_feature("web")
	quit_button.visible = desktop
	# iPhone browsers can't take the page fullscreen.
	fullscreen_button.visible = not OS.has_feature("web_ios")
	start_button.pressed.connect(_on_start)
	new_button.pressed.connect(_on_new_game)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	stats_button.pressed.connect(_toggle_stats)
	_update_stats_button()
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	for button in [start_button, new_button, fullscreen_button, stats_button, quit_button]:
		button.focus_entered.connect(_on_focus_moved)
	_update_footer()
	start_button.grab_focus()
	if not OS.has_feature("web") or StageAudio.web_audio_unlocked:
		_start_music()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.5)


func _process(delta: float) -> void:
	_clock += delta
	logo.position.y = roundf(sin(_clock * 1.6) * 2.0)


func _input(event: InputEvent) -> void:
	if StageAudio.web_audio_unlocked or not OS.has_feature("web"):
		return
	if event.is_pressed() and not event.is_echo():
		StageAudio.web_audio_unlocked = true
		_start_music()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
	elif event.is_action_pressed(&"pause") and _confirm_reset:
		_cancel_reset()


func _on_start() -> void:
	if _leaving:
		return
	_leaving = true
	stage_audio.play_sfx(CONFIRM_SOUND)
	GameProgression.came_from_map = true
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.4)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(MAP_SCENE))


func _on_new_game() -> void:
	if not _confirm_reset:
		_confirm_reset = true
		new_button.text = "Erase save? Press again"
		new_button.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45))
		new_button.add_theme_color_override(&"font_focus_color", Color(1.0, 0.55, 0.45))
		return
	GameProgression.reset_progress()
	_on_start()


func _cancel_reset() -> void:
	_confirm_reset = false
	new_button.text = "New game"
	new_button.remove_theme_color_override(&"font_color")
	new_button.remove_theme_color_override(&"font_focus_color")


func _on_focus_moved() -> void:
	if _confirm_reset and not new_button.has_focus():
		_cancel_reset()
	stage_audio.play_sfx(MOVE_SOUND)


func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


## Players can opt out of the anonymous play stats; the choice is remembered.
func _toggle_stats() -> void:
	Telemetry.set_enabled(not Telemetry.enabled)
	_update_stats_button()


func _update_stats_button() -> void:
	stats_button.text = "Anonymous stats: %s" % ("On" if Telemetry.enabled else "Off")


func _update_footer() -> void:
	if not GameProgression.has_progress():
		footer.text = "Tap to choose" if TouchControls.active else "Arrows / WASD / gamepad   Jump: Space or A"
		return
	footer.text = "Seeds %d/%d   Stages cleared %d/%d" % [
		GameProgression.get_total_seeds_collected(),
		GameProgression.get_total_max_seeds(),
		_cleared_count(),
		GameProgression.get_stage_count(),
	]


func _cleared_count() -> int:
	var count := 0
	for stage in GameProgression.STAGES:
		if GameProgression.is_cleared(int(stage.id)):
			count += 1
	return count


func _start_music() -> void:
	stage_audio.play_music(MUSIC)
