extends Stage

## Flat 5B, Hermes House. Lesson 1: calling methods.
##
## The kitchen door only opens while somebody stands on the doormat, and
## left alone Jazz drifts back to the sofa. So Clive scripts him onto the
## mat: jazz.walk(7). Jazz gets through himself over the counter and out of
## the serving hatch, which Clive can't jump up to.
##
## In the hall the floorboards are up: a hole five boards wide, too far for
## Clive. Folding boards span it while someone stands on the rug past it.
## Jazz's script walks him to the edge, jumps the hole and steps onto the
## rug: order matters, and jump() is a method too.

const MAT_X := 16
const SOFA_X := 9
const DOOR_X := 21
const HOLE := Vector2i(35, 39)
const RUG_X := 42


func _init() -> void:
	stage_id = 1
	width = 64
	starts_as = "clive"
	theme_row = 0
	sky_color = Color(0.2, 0.17, 0.2)
	backdrop = [
		["res://assets/backgrounds/flat_far.png", 0.1, Color(0.85, 0.85, 0.9)],
		["res://assets/backgrounds/flat_near.png", 0.4, Color(0.7, 0.7, 0.75)],
	]
	if ResourceLoader.exists("res://assets/audio/music_flat.ogg"):
		music = load("res://assets/audio/music_flat.ogg") as AudioStream


func _build() -> void:
	ground(0, HOLE.x - 1)
	ground(HOLE.y + 1, width - 1)
	block(0, 0, 0, 13)
	block(width - 1, width - 1, 0, 13)

	# The living room.
	place("clive", 3)
	place("jazz", SOFA_X)
	comfort("clive", 4)
	comfort("jazz", SOFA_X)
	for spot: Array in [["plant", 1], ["telly", 12], ["window", 6], ["poster", 15]]:
		furnish(spot[0], spot[1])
	card_at(1, "c1_heads")
	thought_at(5, "clive", "Saturday. Big plans: alphabetise the spice rack, then possibly a walk.")
	thought_at(11, "clive", "The kitchen door only opens while someone stands on the mat. My idea. Jazz called it fascist.")
	add_biscuit(6, 14)

	# The kitchen door, the wall it's in, and the serving hatch over it.
	# The counter is a step up for anyone; only Jazz can jump from it to the
	# hatch's sill.
	var door := add_slab("door", DOOR_X, 10, Vector2i(1, 4), Slab.Look.DOOR)
	block(DOOR_X, DOOR_X, 0, 5)
	shelf(DOOR_X, DOOR_X, 9)
	add_plate("mat", MAT_X, FLOOR_ROW, 1, [door])
	block(18, 19, 12, 13)
	furnish("fridge", 20)
	add_biscuit(18.5, 12)
	card_at(13, "c1_methods", "clive")
	add_laptop(14, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"comment": "Jazz, from the sofa: walk to the doormat."},
		{"call": ["jazz", "walk", [{"slot": "steps"}]]},
	], {"steps": [3, 5, 7, 9]}), SOFA_X, FLOOR_ROW, "Count the floorboards from the sofa to the mat. Floorboards don't lie. Unlike Jazz.")
	thought_at(17, "jazz", "The serving hatch. Technically a door if you believe in yourself.")

	# The hall.
	add_router(23)
	comfort("clive", 26)
	comfort("jazz", 30, FLOOR_ROW, "beanbag")
	add_biscuit(27, 14)
	thought_at(24, "clive", "The floorboards are up. Jazz 'did some plumbing'. Jazz found a sock in there from 2009.")
	card_at(29, "c1_order")
	var boards := add_slab("boards", HOLE.x, FLOOR_ROW, Vector2i(HOLE.y - HOLE.x + 1, 1), Slab.Look.PLANKS, false)
	add_plate("rug", RUG_X, FLOOR_ROW, 2, [boards])
	add_laptop(32, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"comment": "Get Jazz over the hole and onto the rug."},
		{"call": ["jazz", "walk", [3]]},
		{"call": ["jazz", {"slot": "verb"}, []]},
		{"call": ["jazz", "walk", [{"slot": "steps"}]]},
	], {"verb": ["strum", "press", "jump"], "steps": [-2, 1, 4]}), 31, FLOOR_ROW, "He can clear that hole. He'd clear a hole in his own argument if he had one.")
	add_biscuit(37, 11)

	# Past the hole: the way out.
	add_router(45)
	plank(48, 50, 11)
	add_biscuit(49, 11)
	thought_at(47, "clive", "The front door. Freedom. Or the corner shop, which is freedom with crisps.")
	add_biscuit(55, 14)
	furnish("plant", 61)
	add_exit(58, FLOOR_ROW, "Front door")


func _clear_line() -> String:
	return "Out of the flat by lunchtime. Clive put it in the calendar anyway."
