extends Stage

## East Croydon station. Lesson 5: timers and the event loop.
##
## The ticket barrier opens for one second when the help button is pressed,
## and the button is a long walk from the barrier. Left alone, each
## flatmate drifts to a bench, so nobody can wait at the barrier while the
## player presses the button. setTimeout presses it for them, later: from
## the laptop Clive needs two and a half seconds to reach the barrier.
##
## On the platform the train doors open when the tannoy hears "mind", "the",
## "gap!" in that order. The laptop logs "gap!" from a setTimeout of 0 and
## two lines straight after; a timer of 0 still waits for the lines below
## it, so "gap!" comes last.

const BARRIER_X := 26
const BUTTON_X := 12
const DOORS_X := 46
const HEARD: Array[String] = ["mind", "the", "gap!"]

var _doors: Slab
var _heard: Array[String] = []


func _init() -> void:
	stage_id = 5
	width = 58
	starts_as = "clive"
	theme_row = 4
	sky_color = Color(0.12, 0.13, 0.2)
	backdrop = [
		["res://assets/backgrounds/station_far.png", 0.1, Color(0.85, 0.85, 0.9)],
		["res://assets/backgrounds/station_near.png", 0.4, Color(0.7, 0.7, 0.75)],
	]
	if ResourceLoader.exists("res://assets/audio/music_station.ogg"):
		music = load("res://assets/audio/music_station.ogg") as AudioStream


func _build() -> void:
	ground(0, width - 1)
	block(0, 0, 0, 13)
	block(width - 1, width - 1, 0, 13)

	# The concourse.
	place("clive", 3)
	place("jazz", BUTTON_X)
	comfort("clive", 5, FLOOR_ROW, "bench")
	comfort("jazz", 15, FLOOR_ROW, "bench")
	card_at(2, "c5_timeout")
	thought_at(4, "clive", "The 18:04 to the wedding. If we miss it, we get the 18:34, which is fine, which is not fine.")
	add_biscuit(7, 14)

	# The help button, and the barrier it opens for one second.
	var barrier := add_slab("barrier", BARRIER_X, 11, Vector2i(1, 3), Slab.Look.BARRIER)
	var button := add_switch("button", BUTTON_X, FLOOR_ROW, Switch.Look.BUTTON, "press", [barrier])
	button.open_seconds = 1.0
	add_laptop(9, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"comment": "Jazz is at the help button."},
		{"timeout": [{"slot": "ms"}], "body": [
			{"call": ["jazz", "press", []]},
		]},
	], {"ms": [0, 500, 2500]}), BUTTON_X, FLOOR_ROW, "The barrier stays open one second. From here it's a good two seconds' walk. I need Jazz to press it when I get there, not now.")
	thought_at(14, "jazz", "Pressing a help button for a laugh. That's not a crime. It's a cry for help, which is what the button's for.")
	plank(18, 20, 11)
	add_biscuit(19, 11)

	# The platform.
	comfort("clive", 32, FLOOR_ROW, "bench")
	comfort("jazz", 38, FLOOR_ROW, "bench")
	add_router(30)
	add_biscuit(34, 14)
	plank(36, 38, 11)
	add_biscuit(37, 11)
	add_biscuit(44, 14)
	card_at(33, "c5_event_loop")
	thought_at(31, "jazz", "Jumped the barrier. I'll pay later. Or never. Spiritually, I've paid.")
	add_laptop(41, FLOOR_ROW, JsProgram.make("tannoy.js", "", [
		{"timeout": [0], "body": [
			{"log": ["gap!"]},
		]},
		{"log": [{"slot": "first"}]},
		{"log": [{"slot": "second"}]},
	], {"first": ["gap!", "the", "mind"], "second": ["gap!", "mind", "the"]}), 0, FLOOR_ROW, "The tannoy wants: mind, the, gap. The 0 in that setTimeout is a lie. Like everything at this station.")

	# The train.
	_doors = add_slab("doors", DOORS_X, 11, Vector2i(1, 3), Slab.Look.DOOR)
	block(DOORS_X, DOORS_X, 0, 10)
	add_biscuit(50, 12)
	add_exit(52, FLOOR_ROW, "The 18:04")


## The tannoy: the last three console lines, in order.
func _heard_log(text: String) -> void:
	_heard.append(text)
	while _heard.size() > HEARD.size():
		_heard.pop_front()
	if _heard == HEARD and _doors.on:
		_doors.open()
		speech_at(_doors.global_position + Vector2(-20, -24), "Mind the gap! Doors opening.")


func _on_run(_laptop: Laptop) -> void:
	_heard.clear()


func _clear_line() -> String:
	return "They made the 18:04. Clive got a seat. Jazz got a seat and Clive's seat."
