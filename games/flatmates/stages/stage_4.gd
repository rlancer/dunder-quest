extends Stage

## The stag do, at Wet Bottom Farm (a converted barn, three stars).
## Lesson 4: events and callbacks.
##
## Two farm gates, one behind the other, and two plates up in the hay loft:
## standing on the first opens the first gate, the second opens the second.
## Clive needs Jazz on the first plate until he's between the gates, then on
## the second. A plain list of steps can't wait for that; a listener can.
## When Clive rings the bell in the pen, the callback walks Jazz along the
## loft. Only "ring" is the bell's event: listen for "click" and you wait
## forever. Jazz just jumps the gates.

const LOFT := 11
const GATE_1 := 20
const GATE_2 := 28


func _init() -> void:
	stage_id = 4
	width = 58
	starts_as = "clive"
	theme_row = 3
	sky_color = Color(0.42, 0.5, 0.56)
	backdrop = [
		["res://assets/backgrounds/farm_far.png", 0.1, Color(0.95, 0.95, 0.95)],
		["res://assets/backgrounds/farm_near.png", 0.4, Color(0.8, 0.8, 0.8)],
	]
	if ResourceLoader.exists("res://assets/audio/music_farm.ogg"):
		music = load("res://assets/audio/music_farm.ogg") as AudioStream


func _build() -> void:
	ground(0, 40)
	ground(44, width - 1)
	block(0, 0, 0, 13)
	block(width - 1, width - 1, 0, 13)

	# The farmyard, and the hay loft over it.
	place("clive", 3)
	place("jazz", 10, LOFT)
	comfort("clive", 5, FLOOR_ROW, "haybale")
	comfort("jazz", 9, LOFT, "")
	furnish("haybale", 13)
	card_at(2, "c4_events")
	thought_at(4, "clive", "A stag do. On a farm. Gary from Sales organised it, so naturally it's raining and the barn smells of regret.")
	add_biscuit(6, 14)
	shelf(8, 18, LOFT)
	add_biscuit(17, 10)

	# Two gates, each with its plate in the loft.
	var gate_1 := add_slab("gate1", GATE_1, 11, Vector2i(1, 3), Slab.Look.GATE)
	var gate_2 := add_slab("gate2", GATE_2, 11, Vector2i(1, 3), Slab.Look.GATE)
	add_plate("plate1", 12, LOFT, 1, [gate_1])
	add_plate("plate2", 16, LOFT, 1, [gate_2])
	add_switch("bell", 24, FLOOR_ROW, Switch.Look.BELL, "ring")
	furnish("sheep", 22)
	add_biscuit(25, 12)
	thought_at(21, "clive", "The pen. Me and a sheep. It's looking at me like I owe it money.")
	card_at(22, "c4_callbacks", "clive")
	add_laptop(7, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"call": ["jazz", "walk", [2]]},
		{"on": ["bell", {"slot": "event"}], "body": [
			{"call": ["jazz", "walk", [{"slot": "steps"}]]},
		]},
	], {"event": ["click", "ding", "ring"], "steps": [2, 4, 6]}), 10, LOFT, "Jazz holds the first gate until I'm in the pen. Then I ring the bell, and he moves to the second plate.")

	# The field past the gates, and the duck pond.
	comfort("clive", 32, FLOOR_ROW, "haybale")
	comfort("jazz", 34, FLOOR_ROW, "")
	add_router(31)
	thought_at(30, "jazz", "Jumped a gate. Literally a farm gate. Who's the alpha now, Gary?")
	furnish("haybale", 37)
	add_biscuit(42, 11)
	thought_at(39, "clive", "A pond. Ducks. I can jump that. I have jumped things before. Mostly to conclusions.")
	plank(47, 49, 11)
	add_biscuit(48, 11)
	add_biscuit(53, 14)
	add_exit(53, FLOOR_ROW, "The barn")


func _clear_line() -> String:
	return "The stag do ended at nine. Gary cried. The sheep was the best man."
