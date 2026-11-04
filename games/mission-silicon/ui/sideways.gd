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


func _check() -> void:
	_cover.visible = upright()
	_cover.queue_redraw()


func _draw_cover() -> void:
	var r := _cover.get_rect()
	_cover.draw_rect(r, Palette.SLATE)
	var c := r.get_center()
	# A phone, tipped on its side, with an arrow.
	_cover.draw_rect(Rect2(c + Vector2(-30, -60), Vector2(60, 34)), Palette.GREEN, false, 3.0)
	_cover.draw_rect(Rect2(c + Vector2(-26, -56), Vector2(52, 26)), Palette.GREEN_DARK)
	_cover.draw_arc(c + Vector2(0, -43), 44, PI * 0.15, PI * 0.85, 16, Palette.WHITE, 2.0)
	var font := Palette.titles()
	var text := "TURN YOUR PHONE SIDEWAYS"
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	_cover.draw_string(font, Vector2(c.x - w / 2.0, c.y + 20), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.WHITE)
	var small := "Mission Silicon plays in landscape."
	var w2 := Palette.body().get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.LABEL).x
	_cover.draw_string(Palette.body(), Vector2(c.x - w2 / 2.0, c.y + 40), small, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.LABEL, Palette.SLATE_LIGHT)
