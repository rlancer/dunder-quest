class_name Plate
extends Gadget

## A creaky floorboard (or a doormat, or a pressure pad: it depends on the
## room). It fires "press" when a flatmate steps on and "release" when the
## last one steps off, and while anyone stands on it the slabs in `holds`
## flip: doors open, bridges fold out.

const TILE := 16.0

@export var width_tiles: int = 1
## Slabs held open (or shown) while somebody stands here.
var holds: Array[Slab] = []
var pressed: bool = false
## Who is standing on it, for scripts that ask.
var by: Flatmate


func _physics_process(_delta: float) -> void:
	var now: Flatmate = null
	for body in get_tree().get_nodes_in_group(&"flatmate"):
		var mate := body as Flatmate
		var feet := mate.global_position.y + 8.0
		if absf(feet - global_position.y) <= 3.0 and mate.global_position.x >= global_position.x - 2.0 and mate.global_position.x <= global_position.x + width_tiles * TILE + 2.0 and mate.is_on_floor():
			now = mate
			break
	if (now != null) == pressed:
		by = now if now != null else by
		return
	pressed = now != null
	by = now
	for slab in holds:
		if is_instance_valid(slab):
			slab.set_on(not slab.on)
	StageAudio.play(get_tree(), preload("res://assets/audio/bump.wav"))
	emit_event("press" if pressed else "release")
	queue_redraw()


func js_get(prop: String) -> Variant:
	if prop == "pressed":
		return pressed
	return null


func _draw() -> void:
	var w := width_tiles * TILE
	var sink := 2.0 if pressed else 0.0
	pixel_rect(Rect2(Vector2(0, -3 + sink), Vector2(w, 3 - sink)), Palette.JS if pressed else Palette.AMBER.darkened(0.2))
	pixel_rect(Rect2(Vector2(1, -3 + sink), Vector2(w - 2, 1)), Palette.PAPER.lerp(Palette.JS, 0.5))
	draw_name(Vector2(w * 0.5, -8.0))
