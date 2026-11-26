class_name Dialogue
extends Control

## Somebody talking: their portrait, their name, and the line typed out in
## a box along the foot of the screen while their voice reads it
## (core/voice.gd). Enter, a click or a tap finishes the typing, then turns
## the page. The Chef stands on the right; everybody else on the left; the
## narrator has no face at all.

signal advanced

const BOX := Rect2(8, 198, 464, 64)
## Letters a second.
const TYPE := 44.0

var line: Dictionary = {}
var active: bool = false
## The bot sets this: the page turns by itself after so many frames.
var auto_frames: int = 0

var _shown: float = 0.0
var _clock: float = 0.0
var _frames: int = 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Says the line, and comes back when the player turns the page.
func say(l: Dictionary) -> void:
	line = l
	_shown = 0.0
	_frames = 0
	active = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Sfx.play(self, str(l.get("sound", "")))
	Voice.say(l)
	queue_redraw()
	await advanced
	active = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func typed() -> bool:
	return _shown >= str(line.get("text", "")).length()


func press() -> void:
	if not active:
		return
	if not typed():
		_shown = 1e6
		queue_redraw()
		return
	Voice.hush()
	advanced.emit()


func _process(delta: float) -> void:
	if not active:
		return
	_clock += delta
	_shown += delta * TYPE
	_frames += 1
	if auto_frames > 0 and _frames >= auto_frames:
		_shown = 1e6
		Voice.hush()
		advanced.emit()
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		press()


func _unhandled_input(event: InputEvent) -> void:
	if active and is_visible_in_tree() and event.is_action_pressed(&"confirm"):
		get_viewport().set_input_as_handled()
		press()


func _draw() -> void:
	if line.is_empty():
		return
	Fit.frame(self)
	var who := str(line.get("who", "narrator"))
	var narrator := who == "narrator"
	var right := who == "chef"
	var face := Ui.portrait(who) if not narrator else null
	if face != null:
		# A little bob while the words are still coming.
		var bob := roundf(sin(_clock * 9.0) * 1.5) if not typed() else 0.0
		var x := BOX.end.x - 102.0 if right else BOX.position.x + 6.0
		var at := Vector2(x, BOX.position.y - 94.0 + bob)
		draw_texture_rect(face, Rect2(at + Vector2(3, 3), Vector2(96, 96)), false, Color(0, 0, 0, 0.35))
		draw_texture_rect(face, Rect2(at, Vector2(96, 96)), false)
	if narrator:
		draw_rect(BOX, Color(Palette.STEEL_DARK, 0.92))
		draw_rect(Rect2(BOX.position.x, BOX.position.y, BOX.size.x, 1), Palette.LAMP)
		draw_rect(Rect2(BOX.position.x, BOX.end.y - 1, BOX.size.x, 1), Palette.LAMP)
		Fit.cover(BOX)
	else:
		Ui.steel(self, BOX)
		var name := Story.name_of(who)
		var font := Palette.pixel()
		var wide := Fit.width(font, name, 10) + 12.0
		var tab := Rect2(BOX.end.x - wide - 8.0 if right else BOX.position.x + 8.0, BOX.position.y - 6.0, wide, 13.0)
		draw_rect(tab, Palette.STEEL_DARK)
		draw_rect(tab.grow(-1), Palette.LAMP)
		Fit.cover(tab)
		Fit.begin(tab, "%s's name" % name)
		Fit.text(self, font, Vector2(tab.position.x + 6.0, tab.end.y - 3.0), name, 10, Palette.INK)
		Fit.end()
	Fit.begin(BOX, "the dialogue box")
	var text := str(line.get("text", ""))
	Fit.para(self, Palette.mono(), Vector2(BOX.position.x + 12, BOX.position.y + 20), text, 16, Palette.PAPER if narrator else Palette.CREAM, BOX.size.x - 26, 13, int(_shown))
	Fit.end()
	if typed() and Fit.blink(fmod(_clock, 0.8) < 0.5):
		var tip := BOX.end - Vector2(12, 6)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(-4, -5), tip + Vector2(4, -5), tip]), Palette.LAMP_LIGHT)
