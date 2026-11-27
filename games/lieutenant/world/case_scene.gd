class_name CaseScene
extends Node2D

## One case, built from its entry in data/cases.json.
##
## It opens the way the show does: on the murder. A cold open, letterboxed,
## shows who did it and how they covered it, so the player knows what to
## look for before the Lieutenant has even arrived. Then the episode's title
## card, and the Lieutenant shuffles in with his dog.
##
## From there the player walks him around. A "?" marks a record worth a look
## (it goes into the notebook as a table). A "!" over the suspect means their
## story is ready to be checked: talking to them opens the notebook with one
## question for Records, to be spelled in SQL. A beat is settled when the
## query returns what the question asked for. Before the last beat the
## Lieutenant says goodnight, heads for the door, and turns round.
## After it, the confession, a freeze frame and the sting.

const FLOOR_Y := 244.0
const REACH := 36.0
const DOOR_X := 44.0
const COLD_LIFT := 44.0
const PERSON := preload("res://world/person.gd")
const DOG := preload("res://world/dog.gd")
const HUD := preload("res://ui/hud.gd")
const NOTEBOOK := preload("res://ui/notebook.gd")
## Where the suspect stands for each caption of the cold open.
const COLD_SPOTS := [150.0, 236.0, 318.0, 262.0, 200.0]

## Tests set this before a case starts.
static var test_pace: float = 1.0

var case_id: int = 1
var data: Dictionary = {}
var lt: Person
var suspect: Person
var dog: Dog
var hud: Hud
var notebook: Notebook
var beats: Array = []
var beat_index: int = 0
## Props looked at, and the tables in the notebook, in the order found.
var found: Dictionary = {}
var tables: Array = []
## Calls to Records so far.
var calls: int = 0
## Seconds between steps are multiplied by this; tests shrink it.
var pace: float = test_pace
## "intro", "free", "busy", "notebook", "ending", "cleared"
var state: String = "intro"

var _audio_locked: bool = false
var _leave_armed: float = 0.0
var _claimed: Dictionary = {}
var _cards_seen: Dictionary = {}
var _looked: Dictionary = {}
var _backdrop: Sprite2D
var _night: Sprite2D
var _markers: Node2D
var _clock: float = 0.0


func _ready() -> void:
	add_to_group(&"case_scene")
	data = Story.case(case_id)
	beats = data.get("beats", [])
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_backdrop = _picture("res://assets/backgrounds/%s.png" % data.get("key", ""))
	_night = _picture("res://assets/backgrounds/night.png")
	_backdrop.visible = false
	suspect = _person(str(data.get("killer", "")), float(data.get("killer_x", 320)))
	lt = _person("lt", -40.0)
	lt.min_x = -60.0
	lt.z_index = 2
	dog = DOG.new() as Dog
	dog.master = lt
	dog.position = Vector2(-80, FLOOR_Y)
	dog.z_index = 1
	add_child(dog)
	lt.visible = false
	dog.visible = false
	_markers = Node2D.new()
	_markers.z_index = 3
	_markers.draw.connect(_draw_markers)
	add_child(_markers)
	hud = HUD.new() as Hud
	add_child(hud)
	notebook = NOTEBOOK.new() as Notebook
	add_child(notebook)
	notebook.called.connect(_on_called)
	notebook.closed.connect(func() -> void:
		if state == "notebook":
			state = "free")
	if OS.has_feature("web") and not StageAudio.web_audio_unlocked:
		_audio_locked = true
		hud.show_press_to_start()
	else:
		_start.call_deferred()


func _picture(path: String) -> Sprite2D:
	var sprite := Backdrop.sprite(path)
	sprite.z_index = -10
	add_child(sprite)
	return sprite


func _person(who: String, x: float) -> Person:
	var person := PERSON.new() as Person
	person.who = who
	person.display_name = Story.name_of(who)
	person.position = Vector2(x, FLOOR_Y)
	add_child(person)
	return person


func _unhandled_input(event: InputEvent) -> void:
	if _audio_locked and event.is_pressed() and not event.is_echo():
		_audio_locked = false
		StageAudio.web_audio_unlocked = true
		hud.hide_press_to_start()
		get_viewport().set_input_as_handled()
		_start()
		return
	if state != "free" or notebook.just_closed():
		return
	if event.is_action_pressed(&"edit") or event.is_action_pressed(&"confirm"):
		var target := _near()
		if not target.is_empty():
			get_viewport().set_input_as_handled()
			interact(target)
	elif event.is_action_pressed(&"pause"):
		if _leave_armed > 0.0:
			_leave_to(Main.FILES)
		else:
			_leave_armed = 2.0


# --- The cold open and the arrival ------------------------------------------

func _start() -> void:
	_music("cold")
	hud.set_letterbox(1.0)
	# The letterbox covers the foot of the picture, so the street is lifted clear of it.
	_night.position.y = -COLD_LIFT
	suspect.position = Vector2(-30.0, FLOOR_Y - COLD_LIFT)
	suspect.min_x = -40.0
	suspect.speed = 120.0
	var spot := 0
	for line: Array in data.get("cold_open", []):
		suspect.walk_to(COLD_SPOTS[spot % COLD_SPOTS.size()])
		spot += 1
		await _until(func() -> bool: return not suspect.is_walking(), 4.0)
		await hud.caption(str(line[0]), str(line[1]))
	suspect.strike(Person.Pose.ONE, 60.0)
	MusicDirector.stop()
	StageAudio.play(get_tree(), preload("res://assets/audio/sting.wav"))
	await hud.title_card(str(data.get("title", "")), PackedStringArray(["Tonight's SQL: %s" % data.get("lesson", ""), str(data.get("place", ""))]))
	# The scene of the questioning.
	hud.set_letterbox(0.0)
	hud.place = str(data.get("place", ""))
	_night.visible = false
	_backdrop.visible = true
	suspect.min_x = 18.0
	suspect.position = Vector2(float(data.get("killer_x", 320)), FLOOR_Y)
	suspect.strike(Person.Pose.IDLE, 0.0)
	suspect.facing = -1
	lt.visible = true
	dog.visible = true
	_music("case")
	lt.walk_to(84.0)
	await _until(func() -> bool: return not lt.is_walking(), 4.0)
	lt.min_x = 18.0
	for line: Array in data.get("opening", []):
		await _say(line)
	state = "free"


func _music(name: String) -> void:
	var path := "res://assets/audio/music_%s.ogg" % name
	if ResourceLoader.exists(path):
		MusicDirector.play(load(path) as AudioStream)


# --- Walking around ---------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	_leave_armed = maxf(_leave_armed - delta, 0.0)
	_markers.queue_redraw()
	suspect.marker = "!" if state == "free" and beat_ready() else ""
	if state != "free":
		lt.walk_dir = 0.0
		hud.prompt = ""
		return
	lt.walk_dir = Input.get_axis(&"move_left", &"move_right")
	var target := _near()
	if _leave_armed > 0.0:
		hud.prompt = "Esc again: back to the case files"
	elif target.get("kind", "") == "suspect":
		hud.prompt = "%s: talk to %s" % [Controls.talk_key(), suspect.display_name]
	elif target.get("kind", "") == "prop":
		hud.prompt = "%s: look at %s" % [Controls.talk_key(), target.prop.label]
	elif beat_ready():
		hud.prompt = "Go and talk to %s" % suspect.display_name
	else:
		var missing := _missing_props()
		hud.prompt = "Look around: find %s" % missing[0].label if not missing.is_empty() else ""


func current_beat() -> Dictionary:
	return beats[beat_index] if beat_index < beats.size() else {}


func prop(id: String) -> Dictionary:
	for p: Dictionary in data.get("props", []):
		if str(p.id) == id:
			return p
	return {}


## The records the current beat needs that he hasn't looked at yet.
func _missing_props() -> Array:
	var out: Array = []
	for id: String in current_beat().get("needs", []):
		if not found.has(id):
			out.append(prop(id))
	return out


## Is there a question ready to put to the suspect?
func beat_ready() -> bool:
	return beat_index < beats.size() and _missing_props().is_empty()


## A prop is worth a look when the current beat needs its record, or when
## it's only there to be remarked on and hasn't been.
func _live(p: Dictionary) -> bool:
	var id := str(p.id)
	if p.has("table"):
		return not found.has(id) and (current_beat().get("needs", []) as Array).has(id)
	return not _looked.has(id)


## What the Lieutenant is standing next to: {kind: "suspect"} or
## {kind: "prop", prop}, or {}.
func _near() -> Dictionary:
	if beat_ready() and absf(suspect.position.x - lt.position.x) <= REACH:
		return {"kind": "suspect"}
	for p: Dictionary in data.get("props", []):
		if _live(p) and absf(float(p.x) - lt.position.x) <= REACH * 0.8:
			return {"kind": "prop", "prop": p}
	return {}


func interact(target: Dictionary) -> void:
	if target.kind == "suspect":
		talk()
	else:
		look(target.prop)


## Looks at a record (or a couch). A record goes into the notebook.
func look(p: Dictionary) -> void:
	state = "busy"
	await _look(p)
	state = "free"


func _look(p: Dictionary) -> void:
	lt.face(float(p.x))
	for line: Array in p.get("lines", []):
		await _say(line)
	_looked[str(p.id)] = true
	if not p.has("table"):
		return
	found[str(p.id)] = true
	var added := PackedStringArray()
	for name: String in [str(p.table)] + (p.get("also", []) as Array):
		if not tables.has(name):
			tables.append(name)
		var columns := PackedStringArray()
		for column: Array in data.tables[name].columns:
			columns.append(str(column[0]))
		added.append("%s(%s)" % [name, ", ".join(columns)])
	StageAudio.play(get_tree(), preload("res://assets/audio/page.wav"))
	hud.slip("In the notebook, as a table:" if added.size() == 1 else "In the notebook, as tables:", added)


## Puts the current question to the suspect: their claim the first time,
## a lesson card if the beat has a new one, then the notebook.
func talk() -> void:
	if not beat_ready():
		return
	state = "busy"
	await _open_beat()


func _open_beat() -> void:
	var beat := current_beat()
	var id := str(beat.id)
	lt.face(suspect.position.x)
	suspect.face(lt.position.x)
	var fresh := not _claimed.has(id)
	if fresh:
		_claimed[id] = true
		for line: Array in beat.get("claim", []):
			await _say(line)
	var card_id := str(beat.get("card", ""))
	if card_id != "" and not _cards_seen.has(card_id):
		_cards_seen[card_id] = true
		var card := Story.card(card_id, case_id)
		if not card.is_empty():
			Progress.read_card(card_id)
			await hud.show_card(card)
	state = "notebook"
	notebook.open(beat, Story.db(case_id), tables, "Case %d: %s" % [case_id, data.get("title", "")], fresh)


func _on_called(verdict: Dictionary) -> void:
	calls += 1
	if verdict.verdict != "ok":
		return
	state = "busy"
	var beat := current_beat()
	for line: Array in beat.get("success", []):
		await _say(line)
	beat_index += 1
	if beat_index >= beats.size():
		await _ending()
	elif bool(current_beat().get("final", false)):
		await _false_exit()
	else:
		state = "free"


## He says goodnight and makes for the door. Then he stops. If the last
## question needs a record he hasn't seen, it's the thing he stops at.
func _false_exit() -> void:
	var missing := _missing_props()
	var stop := float(missing[0].x) if not missing.is_empty() else DOOR_X
	lt.walk_to(stop)
	await _until(func() -> bool: return not lt.is_walking(), 8.0)
	await _pause(0.7)
	for p: Dictionary in missing:
		await _look(p)
	lt.face(suspect.position.x)
	StageAudio.play(get_tree(), preload("res://assets/audio/turn.wav"))
	await _pause(0.4)
	await _open_beat()


## The confession, a held look, the sting, and the end card.
func _ending() -> void:
	state = "ending"
	for line: Array in data.get("ending", []):
		await _say(line)
	MusicDirector.stop()
	hud.set_freeze(1.0)
	lt.strike(Person.Pose.ONE, 99.0)
	suspect.strike(Person.Pose.TWO, 99.0)
	get_tree().paused = true
	await get_tree().create_timer(0.8 * maxf(pace, 0.05), true).timeout
	StageAudio.play(get_tree(), preload("res://assets/audio/sting.wav"))
	await get_tree().create_timer(1.6 * maxf(pace, 0.05), true).timeout
	Progress.mark_cleared(case_id, calls)
	state = "cleared"
	var lines := PackedStringArray(["Tonight's SQL: %s" % data.get("lesson", ""), "%d %s to Records" % [calls, "call" if calls == 1 else "calls"]])
	if case_id == Story.count():
		lines.append("That's every case on file. More are being typed in.")
	await hud.end_card(str(data.get("title", "")), lines)
	get_tree().paused = false
	_leave_to(Main.FILES)


func _leave_to(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func _say(line: Array) -> void:
	var who := str(line[0])
	var person: Person = lt if who == "lt" else (suspect if who == str(data.get("killer", "")) else null)
	var mood := str(line[2]) if line.size() > 2 else ""
	if person == lt:
		suspect.face(lt.position.x)
	elif person == suspect and lt.visible:
		lt.face(suspect.position.x)
	await hud.say(person, str(line[1]), mood, Voice.of(line))


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace, false).timeout


## Waits until `test` is true, or `seconds` have passed.
func _until(test: Callable, seconds: float) -> void:
	var left := seconds
	while not test.call() and left > 0.0:
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


func _draw_markers() -> void:
	if state != "free":
		return
	var bob := roundf(sin(_clock * 4.0) * 1.5)
	for p: Dictionary in data.get("props", []):
		if _live(p):
			Marker.draw(_markers, Vector2(float(p.x), float(p.get("y", 140)) + bob), "?")
