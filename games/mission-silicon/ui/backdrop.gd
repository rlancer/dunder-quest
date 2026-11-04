class_name Backdrop
extends TextureRect

## The scenery behind the dialogue: assets/backgrounds/<place>.png, pixel art
## made by tools/art.py (the garage with Aleister, the house's kitchen).

var place: String = "garage":
	set(v):
		place = v
		texture = load("res://assets/backgrounds/%s.png" % v) as Texture2D


func _ready() -> void:
	UI.place(self, Rect2(0, 0, 480, 270))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if texture == null:
		place = place
