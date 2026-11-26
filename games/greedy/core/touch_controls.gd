extends CanvasLayer

## Phones and tablets. The whole game is tapped (chips, buttons, pages), so
## there is no on-screen pad: this only notices that the player is using
## touch, so prompts say "tap", scales the picture smoothly to fill the
## screen, and asks for landscape when a phone is held upright.

const FONT := preload("res://assets/fonts/PixelifySans.ttf")

## True while the player is playing by touch.
var active: bool = OS.has_feature("web_android") or OS.has_feature("web_ios")

var _banner: Node2D


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = Node2D.new()
	_banner.draw.connect(_draw_banner)
	add_child(_banner)
	get_window().size_changed.connect(_banner.queue_redraw)


func _process(_delta: float) -> void:
	# Keys and gamepads keep the crisp whole-number scale. By touch the
	# picture scales smoothly to fill the screen; it stays 16:9 either way.
	var window := get_window()
	var stretch := Window.CONTENT_SCALE_STRETCH_FRACTIONAL if active else Window.CONTENT_SCALE_STRETCH_INTEGER
	if window.content_scale_stretch != stretch:
		window.content_scale_stretch = stretch
		_banner.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if not active:
			active = true
			_banner.queue_redraw()
	elif event is InputEventKey or event is InputEventJoypadButton:
		if event.is_pressed() and active:
			active = false
			_banner.queue_redraw()


## Held upright, a phone shows the game as a thin strip; ask for landscape.
func _draw_banner() -> void:
	var size := get_window().size
	if not active or size.y <= size.x:
		return
	var view := _banner.get_viewport_rect().size
	_banner.draw_rect(Rect2(0, 0, view.x, 18), Color(0.16, 0.09, 0.06, 0.9))
	_banner.draw_string(FONT, Vector2(0, 13), "Turn your phone sideways to play", HORIZONTAL_ALIGNMENT_CENTER, view.x, 11, Color(0.91, 0.63, 0.23))
