class_name Dialogue
extends Control

## Lines of dialogue in a bubble along the bottom, with the speaker's
## close-up: `await dialogue.play(lines, place)`. A tap anywhere (or Enter,
## Space) moves on. Tests set `test_auto_frames` so lines move on by
## themselves.

signal advanced

static var test_auto_frames: int = 0

var _portrait: Portrait
var _name: Label
var _text: Label
var _place: Label
var _waiting: bool = false
var _frames: int = 0
var _shown_at: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bubble := UI.place(UI.panel(Palette.WHITE, Palette.SLATE, 1), Rect2(8, 200, 464, 64))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	_portrait = UI.place(Portrait.new(), Rect2(16, 208, 48, 48)) as Portrait
	add_child(_portrait)
	_name = UI.place(UI.label("", Palette.LABEL, Palette.GREEN_DARK), Rect2(74, 204, 380, 14)) as Label
	add_child(_name)
	_text = UI.place(UI.label("", Palette.LABEL, Palette.SLATE, true), Rect2(74, 218, 390, 44)) as Label
	add_child(_text)
	_place = UI.place(UI.label("", Palette.LABEL, Palette.WHITE), Rect2(8, 6, 300, 18)) as Label
	# A slate tag, so the place reads on a bright backdrop too.
	var tag := StyleBoxFlat.new()
	tag.bg_color = Color(Palette.SLATE, 0.85)
	tag.set_content_margin_all(3)
	_place.add_theme_stylebox_override("normal", tag)
	add_child(_place)
	var hint := UI.place(UI.label("tap", Palette.BODY, Palette.SLATE_LIGHT), Rect2(446, 250, 24, 12))
	add_child(hint)


func play(lines: Array, place: String = "") -> void:
	visible = true
	_place.text = place
	_place.size = Vector2.ZERO
	_place.visible = place != ""
	for line in lines:
		var who: String = line["who"]
		_portrait.who = who
		# "as" is a documentary lower third (the finale's flash-forward).
		_name.text = line.get("as", Season.person(who).get("full", who))
		_text.text = line["say"]
		await _wait()
	visible = false


func _wait() -> void:
	_waiting = true
	_frames = 0
	_shown_at = Engine.get_process_frames()
	await advanced


func _process(_delta: float) -> void:
	if _waiting and test_auto_frames > 0:
		_frames += 1
		if _frames >= test_auto_frames:
			_advance()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.pressed and (event.is_action("ui_accept") or event.is_action("ui_select")):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	# A tap that arrives on the frame a line appears belongs to the last one.
	if not _waiting or Engine.get_process_frames() == _shown_at:
		return
	_waiting = false
	advanced.emit()
