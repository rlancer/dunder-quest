extends "res://tests/bot.gd"

## The bot's full run, paced for the trailer: real timings for the cards,
## the Vizier's speeches and the rewind, the dagger's console held open long
## enough to read each button and Git's reply, and the scene music muted
## (the trailer has its own cue). Logs a MARK line, keyed by movie frame, for
## every moment worth cutting to:
##
##   MARK <frame> title                     the title screen
##   MARK <frame> room <n> <title>          a room starts (its title card)
##   MARK <frame> state <n> <state>         play, dagger, dead, rewind, cutscene, clear
##   MARK <frame> git <n> <exit> <command>  a command the dagger ran, and its exit code
##   MARK <frame> conflict <n> <files>      a merge stopped on a conflict
##   MARK <frame> moment <name>             the bot's named moments (1_dead, 2_vizier, ...)
##   MARK <frame> end-of-run
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Add `-- room=5` to capture one room.

## How long the clear card (with the room's lesson) stays up.
const CLEAR_HOLD := 240

var _start_frame := 0
var _seen := {}
var _logged := 0


func _init() -> void:
	fast = false
	press_frames = 40
	hold_frames = 80


func _ready() -> void:
	super()
	seed(7)
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	await tree.create_timer(0.3).timeout
	_mark("title")
	await tree.create_timer(4.0).timeout
	tree.current_scene.queue_free()
	await super()
	_mark("end-of-run")


func moment(name: String) -> void:
	_mark("moment %s" % name)
	if name.ends_with("_title"):
		_logged = 0
		_mark("room %d %s" % [_id, Story.level(_id).get("title", "")])
	elif name.ends_with("_clear"):
		for _i in CLEAR_HOLD:
			await get_tree().process_frame


func _physics_process(_delta: float) -> void:
	if room == null or not is_instance_valid(room) or room.repo == null:
		return
	_flag("state", "%d %s" % [_id, room.state])
	var log: Array = room.repo.log
	if _logged > log.size():
		_logged = 0
	while _logged < log.size():
		var entry: Dictionary = log[_logged]
		_logged += 1
		if entry.has("cmd") and room.state != "opening":
			_mark("git %d %d %s" % [_id, int(entry.get("exit", 0)), Console.shown(entry.cmd)])
	var conflicts := room.repo.unresolved()
	_flag("conflict", "%d %s" % [_id, " ".join(conflicts)] if not conflicts.is_empty() else "")


## Prints a marker each time `key`'s value changes to something non-empty.
func _flag(key: String, value: String) -> void:
	if _seen.get(key, "") == value:
		return
	_seen[key] = value
	if value != "":
		_mark("%s %s" % [key, value])


func _mark(text: String) -> void:
	print("MARK %d %s" % [_frame(), text])


func _frame() -> int:
	return Engine.get_process_frames() - _start_frame
