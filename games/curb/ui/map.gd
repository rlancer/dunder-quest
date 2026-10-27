extends Control

## Scene select, drawn on a map of the Westside: one pin per scene. Left and
## right move between them, Enter (or a tap on the open pin) goes there. A
## scene opens when the one before it is cleared.

const ART := "res://assets/backgrounds/map.png"
const MUSIC := "res://assets/audio/music_title.ogg"
## Where each scene's pin sits on the map, in scene order.
const PINS := [
	Vector2(126, 66), Vector2(176, 92), Vector2(232, 70), Vector2(290, 96), Vector2(336, 64),
	Vector2(388, 92), Vector2(300, 140), Vector2(236, 120), Vector2(176, 144), Vector2(116, 112),
]

var _selected: int = 1
var _time: float = 0.0
var _flash: String = ""
var _flash_time: float = 0.0
var _fade: ColorRect
var _leaving: bool = false
var _celebrate: float = 0.0
## Held here: a texture only loaded inside _draw is freed before it's drawn.
var _art: Texture2D


func _ready() -> void:
	Progress.load_data()
	if ResourceLoader.exists(ART):
		_art = load(ART) as Texture2D
	_selected = clampi(Progress.current_scene, 1, Progress.count())
	if not Progress.is_open(_selected):
		_selected = 1
	if Progress.just_cleared > 0:
		_celebrate = 2.0
		Progress.just_cleared = 0
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.3)
	if ResourceLoader.exists(MUSIC):
		MusicDirector.play(load(MUSIC) as AudioStream)


func _pin(id: int) -> Vector2:
	return PINS[(id - 1) % PINS.size()]


func _process(delta: float) -> void:
	_time += delta
	_flash_time = maxf(_flash_time - delta, 0.0)
	_celebrate = maxf(_celebrate - delta, 0.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _leaving:
		return
	if event.is_action_pressed(&"move_left") or event.is_action_pressed(&"move_up"):
		_move(-1)
	elif event.is_action_pressed(&"move_right") or event.is_action_pressed(&"move_down"):
		_move(1)
	elif event.is_action_pressed(&"confirm") or event.is_action_pressed(&"edit"):
		_go()
	elif event.is_action_pressed(&"pause"):
		_leave(Main.TITLE)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap(event.position)
	elif event is InputEventScreenTouch and event.pressed:
		_tap(event.position)


func _tap(at: Vector2) -> void:
	for id in range(1, Progress.count() + 1):
		if at.distance_to(_pin(id)) < 16.0:
			if id == _selected:
				_go()
			elif Progress.is_open(id):
				_selected = id
				StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
			return
	if Rect2(60, 186, 360, 76).has_point(at):
		_go()


func _move(step: int) -> void:
	var next := clampi(_selected + step, 1, Progress.count())
	if next == _selected:
		return
	if step > 0 and not Progress.is_open(next):
		_say("Clear \"%s\" first." % Story.scene(_selected).get("title", ""))
		StageAudio.play(get_tree(), preload("res://assets/audio/break.wav"))
		return
	_selected = next
	Progress.current_scene = next
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))


func _go() -> void:
	if not Progress.is_open(_selected):
		_say("Not yet. Clear the one before it.")
		return
	_leaving = true
	StageAudio.play(get_tree(), preload("res://assets/audio/goal.wav"))
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.3)
	tween.tween_callback(func() -> void: Main.play_scene(get_tree(), _selected))


func _leave(path: String) -> void:
	_leaving = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.25)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(path))


func _say(text: String) -> void:
	_flash = text
	_flash_time = 2.5


func _draw() -> void:
	var mono := Palette.mono()
	var titles := Palette.titles()
	draw_rect(Rect2(0, 0, 480, 270), Color.BLACK)
	if _art != null:
		draw_texture_rect(_art, Rect2(0, 0, 480, 270), false)
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(0, 0, 480, 24), Color(0, 0, 0, 0.85))
	draw_string(titles, Vector2(10, 17), "Curb Your Oxidation", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.YELLOW)
	draw_string(mono, Vector2(186, 16), "The Westside. Ten scenes. One borrow checker.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.8, 0.8))
	for id in range(1, Progress.count()):
		var from := _pin(id)
		var to := _pin(id + 1)
		var color := Palette.RUST if Progress.is_open(id + 1) else Color(Palette.STEEL_DARK, 0.7)
		var steps := int(from.distance_to(to) / 6.0)
		for s in steps:
			if s % 2 == 0:
				draw_line(from.lerp(to, float(s) / steps), from.lerp(to, float(s + 1) / steps), color, 2.0)
	for id in range(1, Progress.count() + 1):
		var at := _pin(id)
		var open := Progress.is_open(id)
		var selected := id == _selected
		var r := 7.0 + (1.5 * sin(_time * 5.0) if selected else 0.0)
		draw_circle(at, r + 2, Palette.INK)
		draw_circle(at, r, Palette.PAPER if open else Palette.STEEL_DARK)
		if Progress.is_cleared(id):
			draw_circle(at, 3.5, Palette.GREEN)
		var label := str(id)
		var lw := mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string(mono, at + Vector2(-lw / 2, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK if open else Palette.STEEL)
		if selected and _celebrate > 0.0:
			draw_string(mono, at + Vector2(-24, -14), "Next up!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)

	var s := Story.scene(_selected)
	var card := Rect2(60, 186, 360, 76)
	draw_rect(card, Color(0, 0, 0, 0.92))
	draw_rect(Rect2(card.position, Vector2(3, card.size.y)), Palette.YELLOW)
	draw_string(titles, card.position + Vector2(14, 22), str(s.get("title", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(mono, card.position + Vector2(14, 38), "%d. %s   ·   Rust: %s" % [_selected, s.get("place", ""), s.get("lesson", "")], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
	var status := "Cleared in %d tries" % Progress.best_tries(_selected) if Progress.is_cleared(_selected) else ("Open" if Progress.is_open(_selected) else "Not yet")
	draw_string(mono, card.position + Vector2(14, 53), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.STEEL)
	var go := "Tap the card to go" if TouchControls.active else "Arrows: choose   Enter: go   Esc: title"
	draw_string(mono, card.position + Vector2(14, 68), go, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.PAPER.darkened(0.25))
	if _flash_time > 0.0:
		var w := mono.get_string_size(_flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(mono, Vector2(240 - w * 0.5, 176), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Palette.INK)
		draw_string(mono, Vector2(240 - w * 0.5, 176), _flash, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.AMBER)
