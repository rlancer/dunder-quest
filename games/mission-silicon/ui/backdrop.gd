class_name Backdrop
extends Control

## Placeholder scenery behind the dialogue: the garage with Aleister roaring
## under a desk fan, or the house's kitchen. Drawn in flat pixels until the
## backdrops are generated like the other games'.

var place: String = "garage":
	set(v):
		place = v
		queue_redraw()
var _clock: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_clock += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	if place == "garage":
		draw_rect(Rect2(0, 0, 480, 270), Color("#3b3f47"))
		draw_rect(Rect2(0, 170, 480, 100), Color("#2a2d33"))
		for x in range(0, 480, 40):
			draw_line(Vector2(x, 0), Vector2(x, 170), Color("#34383f"))
		# The rack.
		draw_rect(Rect2(200, 70, 80, 110), Color("#1a1c20"))
		for i in 6:
			var y := 78 + i * 16
			draw_rect(Rect2(206, y, 68, 12), Color("#26292e"))
			for j in 4:
				var on := fposmod(_clock * 3.0 + i * 0.7 + j * 1.3, 2.0) < 1.2
				draw_rect(Rect2(212 + j * 8, y + 4, 3, 3), Palette.GREEN if on else Color("#e04848"))
		# Heat.
		var glow := 0.15 + 0.08 * sin(_clock * 4.0)
		draw_rect(Rect2(196, 66, 88, 118), Color(1.0, 0.35, 0.2, glow))
		# The desk fan.
		draw_rect(Rect2(310, 150, 6, 30), Color("#888c94"))
		draw_circle(Vector2(313, 140), 16, Color("#9aa0a8"))
		var a := _clock * 20.0
		for k in 3:
			var ang := a + k * TAU / 3.0
			draw_line(Vector2(313, 140), Vector2(313, 140) + Vector2(cos(ang), sin(ang)) * 13, Color("#5b6675"), 3.0)
	else:
		draw_rect(Rect2(0, 0, 480, 270), Color("#e9e4da"))
		draw_rect(Rect2(0, 150, 480, 120), Color("#c9b79c"))
		draw_rect(Rect2(60, 40, 120, 80), Color("#bcd8e8"))
		draw_rect(Rect2(60, 40, 120, 80), Color("#8a7a66"), false, 3.0)
		draw_rect(Rect2(260, 110, 180, 40), Color("#7a6a56"))
