extends CanvasLayer

## "Turn your phone sideways": covers everything while the window is taller
## than it is wide, since the game is laid out landscape.

var _cover: Control


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cover = Control.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.draw.connect(_draw_cover)
	_cover.visible = false
	add_child(_cover)
	get_window().size_changed.connect(_check)
	_check()


func _exit_tree() -> void:
	Palette.release()


func upright() -> bool:
	var s := DisplayServer.window_get_size()
	return s.y > s.x


## Whether the card is up (the bot checks it with the window upright).
func covered() -> bool:
	return _cover.visible


func _check() -> void:
	var up := upright()
	# Upright, the game's landscape screen would sit in a thin band between
	# black bars, so the card fills the whole screen instead; turned back,
	# the screen keeps its shape again.
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND if up else Window.CONTENT_SCALE_ASPECT_KEEP
	_cover.visible = up
	_cover.queue_redraw()


## How much bigger than the game's own pixels the card draws: upright, a
## 480-pixel-wide screen is shown at under one screen pixel per game pixel
## (0.81 on a 390-wide phone), and the card's text must stay readable.
const CARD_SCALE := 1.6


func _draw_cover() -> void:
	var r := _cover.get_rect()
	_cover.draw_rect(r, Palette.SLATE)
	_cover.draw_set_transform(r.get_center(), 0.0, Vector2(CARD_SCALE, CARD_SCALE))
	# A phone, tipped on its side, with an arrow.
	_cover.draw_rect(Rect2(Vector2(-30, -60), Vector2(60, 34)), Palette.GREEN, false, 3.0)
	_cover.draw_rect(Rect2(Vector2(-26, -56), Vector2(52, 26)), Palette.GREEN_DARK)
	_cover.draw_arc(Vector2(0, -43), 44, PI * 0.15, PI * 0.85, 16, Palette.WHITE, 2.0)
	var font := Palette.titles()
	var text := "TURN YOUR PHONE SIDEWAYS"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_cover.draw_string(font, Vector2(-w / 2.0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.WHITE)
	var small := "Mission Silicon plays in landscape."
	var w2 := Palette.body().get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.LABEL).x
	_cover.draw_string(Palette.body(), Vector2(-w2 / 2.0, 40), small, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.LABEL, Palette.SLATE_LIGHT)
	_cover.draw_set_transform(Vector2.ZERO)
