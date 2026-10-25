extends Stage

## Croydon Credit. Lesson 2: variables and strings.
##
## Jazz has come in to ask Clive for a loan, which Clive is not allowed to
## give him. The staff door's keypad wants the desk number then the
## extension, and the building's laptop builds the code from two consts in a
## template literal: `${desk}${ext}` is "127", while "desk" in quotes is just
## the word. Past it, the lift goes where `floor` says, but only for a number:
## "2" in quotes is a string and the lift refuses it. Big Ron's office is on
## floor 2. Each flatmate rides up on his own run; an empty lift comes back.

const DOOR_X := 16
const SHAFT_X := 22
const UPPER := 8


func _init() -> void:
	stage_id = 2
	width = 60
	starts_as = "jazz"
	theme_row = 1
	sky_color = Color(0.16, 0.17, 0.22)
	backdrop = [
		["res://assets/backgrounds/office_far.png", 0.1, Color(0.85, 0.85, 0.9)],
		["res://assets/backgrounds/office_near.png", 0.4, Color(0.7, 0.7, 0.75)],
	]
	if ResourceLoader.exists("res://assets/audio/music_office.ogg"):
		music = load("res://assets/audio/music_office.ogg") as AudioStream


func _build() -> void:
	ground(0, SHAFT_X - 1)
	ground(SHAFT_X + 2, 30)
	block(0, 0, 0, 13)
	# The ground-floor corridor past the lift is a dead end; the way on is up.
	block(31, 31, 9, 13)
	shelf(SHAFT_X + 2, width - 1, UPPER)
	block(width - 1, width - 1, 0, UPPER - 1)

	# Reception.
	place("jazz", 3)
	place("clive", 7)
	comfort("jazz", 4, FLOOR_ROW, "sofa")
	comfort("clive", 8, FLOOR_ROW, "desk")
	furnish("plant", 1)
	furnish("watercooler", 11)
	furnish("clock", 6)
	card_at(2, "c2_vars")
	thought_at(5, "jazz", "Clive works here. Clive has access to money. Clive is my friend. This is basically a cash machine with feelings.")
	add_biscuit(5, 14)
	plank(8, 10, 11)
	add_biscuit(9, 11)

	# The staff door and its keypad.
	var door := add_slab("door", DOOR_X, 11, Vector2i(1, 3), Slab.Look.DOOR)
	block(DOOR_X, DOOR_X, 0, 10)
	var keypad := Keypad.new()
	keypad.js_name = "keypad"
	keypad.code = "127"
	keypad.holds = [door]
	add_gadget(keypad, tile(14, FLOOR_ROW))
	card_at(10, "c2_template")
	thought_at(13, "clive", "Staff door: desk number, then extension. Desk 12, extension 7. I chose neither. I treasure both.")
	add_laptop(12, FLOOR_ROW, JsProgram.make("door.js", "", [
		{"const": "desk", "value": 12},
		{"const": "ext", "value": 7},
		{"const": "code", "value": {"tpl": [{"slot": "first"}, {"slot": "second"}]}},
		{"call": ["keypad", "enter", [{"id": "code"}]]},
	], {
		"first": ["desk", {"id": "ext"}, {"id": "desk"}],
		"second": ["ext", {"id": "desk"}, {"id": "ext"}],
	}), 0, FLOOR_ROW, "The keypad wants 127. Not the word desk. Nobody's code is the word desk. Except Big Ron's.")

	# The lift.
	add_router(18)
	add_biscuit(19, 14)
	var lift := add_lift("lift", SHAFT_X, FLOOR_ROW, 2, 3, 3)
	lift.depart_delay = 1.2
	lift.return_after = 2.5
	card_at(19, "c2_numbers")
	add_laptop(20, FLOOR_ROW, JsProgram.make("lift.js", "", [
		{"const": "boss", "value": "Big Ron"},
		{"const": "floor", "value": {"slot": "floor"}},
		{"call": ["lift", "goTo", [{"id": "floor"}]]},
	], {"floor": [{"id": "boss"}, "2", 3, 2]}), 0, FLOOR_ROW, "Big Ron is on floor 2. Run it, then step in before the doors close.")
	furnish("plant", 27)
	thought_at(25, "jazz", "A corridor of beige. This is where dreams come to fill in forms.")

	# The roof, one floor too far.
	shelf(SHAFT_X + 2, SHAFT_X + 4, 5)
	add_biscuit(25, 5)

	# Big Ron's floor.
	comfort("jazz", 30, UPPER, "beanbag")
	comfort("clive", 35, UPPER, "armchair")
	add_router(33, UPPER)
	furnish("desk", 40, UPPER)
	furnish("desk", 46, UPPER)
	furnish("watercooler", 43, UPPER)
	add_biscuit(41, 7)
	add_biscuit(52, UPPER)
	thought_at(38, "clive", "Big Ron's floor. He calls it the penthouse. It's the second floor.")
	add_exit(55, UPPER, "Big Ron")


func _clear_line() -> String:
	return "Big Ron said no to the loan. Then yes. Then 'who are you?'. Jazz is calling it a win."
