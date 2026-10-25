extends Stage

## The wedding at St Agatha's: Tess from Accounts and Gary from Sales.
## Lesson 6: async and await.
##
## Jazz is the music. He has to strum the wedding march once Clive (doing a
## reading, against his better judgement) reaches the altar: in an async
## function, `await clive.reach(altar)` waits for Clive to get there, and
## without the await Jazz strums straight away, to an empty church. The
## vestry door opens after a march on cue.
##
## Out the back, the getaway car to the reception leaves on car.drive().
## Awaiting Promise.all of both flatmates reaching it means it waits for the
## pair of them; without the await it goes at once, with nobody in it.

const ALTAR_X := 24
const VESTRY_X := 28
const CAR_X := 50

var _altar: Spot
var _car: Spot
var _vestry: Slab
var _married: bool = false
var _driving: bool = false


func _init() -> void:
	stage_id = 6
	width = 58
	starts_as = "clive"
	theme_row = 5
	sky_color = Color(0.2, 0.17, 0.2)
	backdrop = [
		["res://assets/backgrounds/church_far.png", 0.1, Color(0.85, 0.85, 0.88)],
		["res://assets/backgrounds/church_near.png", 0.4, Color(0.7, 0.7, 0.72)],
	]
	if ResourceLoader.exists("res://assets/audio/music_church.ogg"):
		music = load("res://assets/audio/music_church.ogg") as AudioStream


func _build() -> void:
	ground(0, width - 1)
	block(0, 0, 0, 13)
	block(width - 1, width - 1, 0, 13)

	# The aisle.
	place("clive", 3)
	place("jazz", 8)
	comfort("clive", 4, FLOOR_ROW, "pew")
	comfort("jazz", 11, FLOOR_ROW, "pew")
	for x in [14, 18]:
		furnish("pew", x)
	furnish("flowers", 21)
	card_at(2, "c6_async")
	thought_at(5, "clive", "Tess from Accounts is marrying Gary from Sales. I'm doing a reading. I'll be dignified. I'll be devastated, but dignified.")
	add_biscuit(12, 13)
	_altar = add_spot("altar", ALTAR_X, FLOOR_ROW, Spot.Look.ALTAR)
	furnish("flowers", 26)
	add_laptop(6, FLOOR_ROW, JsProgram.make("jazz.js", "jazz", [
		{"async": "ceremony", "body": [
			{"await": ["clive", "reach", [{"id": "altar"}]], "kw": {"slot": "wait"}},
			{"call": ["jazz", "strum", []]},
		]},
	], {"wait": ["", "await"]}), 8, FLOOR_ROW, "The march starts when I reach the altar. Not before. Not when Jazz gets bored. Which is always before.")
	thought_at(16, "jazz", "Wedding march. On a Telecaster. They said 'no rock'. I said 'what's rock?'. That's a legally binding loophole.")

	# The vestry, and out the back to the car.
	_vestry = add_slab("vestry", VESTRY_X, 11, Vector2i(1, 3), Slab.Look.DOOR)
	block(VESTRY_X, VESTRY_X, 0, 10)
	add_router(31)
	comfort("clive", 33, FLOOR_ROW, "")
	comfort("jazz", 34, FLOOR_ROW, "")
	card_at(32, "c6_all")
	add_biscuit(36, 14)
	furnish("cake", 38)
	plank(41, 43, 11)
	add_biscuit(42, 11)
	add_biscuit(54, 14)
	_car = add_spot("car", CAR_X, FLOOR_ROW, Spot.Look.CAR, "Just Married")
	_car.actions = {"drive": _drive}
	add_laptop(36, FLOOR_ROW, JsProgram.make("car.js", "jazz", [
		{"all": [["clive", "reach", [{"id": "car"}]], ["jazz", "reach", [{"id": "car"}]]], "kw": {"slot": "wait"}},
		{"call": ["car", "drive", []]},
	], {"wait": ["", "await"]}), 37, FLOOR_ROW, "Both of us in the car, then drive. In that order. Gary's driving, and Gary's never waited for anyone.")
	add_biscuit(46, 14)
	add_biscuit(18, 10)
	plank(17, 19, 11)


## A strum anywhere in the church is the wedding march: on cue if Clive is
## at the altar, otherwise to an empty aisle.
func strum_at(mate: Flatmate) -> void:
	super.strum_at(mate)
	if _married:
		return
	if clive.is_at(_altar):
		_married = true
		speech_at(_altar.global_position + Vector2(-10, -40), "Here comes the bride!")
		_vestry.open()
		Fx.sparks(self, _altar.global_position + Vector2(0, -20), Palette.JS, 16, 80.0)
	else:
		speech_at(_altar.global_position + Vector2(-10, -40), "Not yet! Nobody's at the altar!")


func _drive(_args: Array) -> Variant:
	if _driving:
		return null
	if clive.is_at(_car) and jazz.is_at(_car):
		_driving = true
		speech_at(_car.global_position + Vector2(0, -44), "To the reception!")
		_clear()
	else:
		speech_at(_car.global_position + Vector2(0, -44), "Gary drove off without you. He's coming back. Slowly.")
	return null


func _clear_line() -> String:
	return "Tess and Gary are married. Clive caught the bouquet. He's choosing to see it as a sign."
