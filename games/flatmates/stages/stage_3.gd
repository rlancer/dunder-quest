extends Stage

## Band practice in the cellar of the Crown and Anchor. Lesson 3: loops.
##
## The band's stage is five tiles up. Every strum lifts the speaker stack
## one notch, so a for loop strumming four times carries Clive up to where
## he can climb off; five is too loud and the landlord pulls the plug, so
## `i < 4` works and `i <= 4` doesn't. Up there, three amps each raise a
## riser into a stair: for...of over the whole array switches on all three,
## amps.slice(1) misses the first step, and amps[0] isn't a list at all.

const STACK_X := 13
const RAISED := 9


func _init() -> void:
	stage_id = 3
	width = 52
	starts_as = "jazz"
	theme_row = 2
	sky_color = Color(0.14, 0.1, 0.12)
	backdrop = [
		["res://assets/backgrounds/cellar_far.png", 0.1, Color(0.8, 0.78, 0.82)],
		["res://assets/backgrounds/cellar_near.png", 0.4, Color(0.65, 0.62, 0.68)],
	]
	if ResourceLoader.exists("res://assets/audio/music_cellar.ogg"):
		music = load("res://assets/audio/music_cellar.ogg") as AudioStream


func _build() -> void:
	ground(0, width - 1)
	block(0, 0, 0, 13)
	block(width - 1, width - 1, 0, 13)

	# The bar end.
	place("jazz", 3)
	place("clive", 6)
	comfort("jazz", 2, FLOOR_ROW, "beanbag")
	comfort("clive", 7)
	furnish("bar", 5)
	furnish("poster", 9)
	card_at(2, "c3_loop")
	thought_at(4, "jazz", "Tonight the band is called Spoon Theory. Last night it was The Overdraft. Branding is a journey.")
	add_biscuit(8, 14)
	plank(3, 5, 10)
	add_biscuit(4, 10)

	# The speaker stack, and the band's raised floor beside it.
	var stack := add_lift("", STACK_X, FLOOR_ROW, 2, 1, 6, Lift.Look.SPEAKERS)
	stack.rises_on_strum = true
	stack.topple_above = 4
	block(STACK_X + 2, width - 2, RAISED, 13)
	# A beer crate: a step up to the speakers for anyone.
	block(STACK_X - 1, STACK_X - 1, 12, 13)
	add_laptop(10, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"comment": "Each strum lifts the speakers one notch."},
		{"for": [0, {"slot": "op"}, 4], "body": [
			{"call": ["jazz", "strum", []]},
		]},
	], {"op": [">", "<=", "<"]}), 11, FLOOR_ROW, "Four notches up and I can climb off. Count the laps. Then count them again, I don't trust you.").resets = [stack]
	thought_at(11, "clive", "Stand on the speakers, let Jazz play, rise up like a man in a lift made of noise.")

	# Up on the band's floor.
	comfort("clive", 18, RAISED)
	comfort("jazz", 21, RAISED, "beanbag")
	add_router(16, RAISED)
	furnish("drumkit", 23, RAISED)
	add_biscuit(19, 8)
	add_biscuit(27, 7)
	card_at(22, "c3_for_of")
	thought_at(21, "clive", "The stage is up there. Of course it is. Musicians love being slightly higher than everyone.")

	# Three amps, three risers: a stair to the stage.
	var amps: Array = []
	for index in 3:
		var riser := add_lift("", 31 + index * 2, RAISED, 2, 2 * (index + 1), 1, Lift.Look.SPEAKERS)
		var amp := Amp.new()
		amp.js_name = "amp%d" % (index + 1)
		amp.riser = riser
		add_gadget(amp, tile(25 + index * 2, RAISED))
		amps.append(amp)
	add_laptop(30, RAISED, JsProgram.make("amps.js", "", [
		{"const": "amps", "value": {"array": [{"id": "amp1"}, {"id": "amp2"}, {"id": "amp3"}]}},
		{"for_of": ["amp", {"slot": "list"}], "body": [
			{"call": ["amp", "switchOn", []]},
		]},
	], {"list": [{"index": [{"id": "amps"}, 0]}, {"method": [{"id": "amps"}, "slice", [1]]}, {"id": "amps"}]}), 0, RAISED, "Every amp in the list. Not most of them. Clive would never leave an amp behind. Clive doesn't know what an amp is.")

	# The stage.
	shelf(37, width - 2, 3)
	add_biscuit(40, 3)
	add_biscuit(44, RAISED)
	add_exit(46, 3, "The stage")


func _clear_line() -> String:
	return "The band played one song. Twice. Then the landlord pulled the plug for real."
