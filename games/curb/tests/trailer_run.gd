extends "res://tests/bot.gd"

## The bot's full run, paced for the trailer. Mutes the scene music (the
## trailer has its own cue), leaves every line up long enough to read, holds
## the legal pad open with the picks showing before each run, and logs a
## MARK line for every moment worth cutting to, keyed by movie frame:
##
##   MARK <frame> scene <n> <title>        a scene starts (its black title card)
##   MARK <frame> say <who> <text>         a bubble (opening, success, ending)
##   MARK <frame> card <id>                a lesson card
##   MARK <frame> pad <plan> <picks>       the legal pad, open, picks in
##   MARK <frame> rehearsal <plan>         sepia: Barry runs it in his head
##   MARK <frame> rant <code> <line>       Sharon bursts in with the rustc error
##   MARK <frame> panic <plan>             a runtime panic
##   MARK <frame> run <plan>               it compiles, the scene plays it out
##   MARK <frame> squint <who>             a squint close-up
##   MARK <frame> freeze <n>               the freeze frame before the sting
##   MARK <frame> end <n>                  the black end card
##
## bash trailer/capture.sh   (records at 1920x1080, so the text is sharp)
## Add `-- scene=5` to capture one scene.

const PAD_HOLD := 120

var _start_frame := 0
var _seen := {}


func _init() -> void:
	line_frames = 75
	per_char = 1.4
	pace = 1.0
	extra_tries = {
		"2a": [{"body": "tray + taken"}],
		"8b": [{"ret": "-> Result<(), String>", "q": ".unwrap()"}],
	}


func _ready() -> void:
	super()
	seed(7)
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	await super()
	print("MARK %d end-of-run" % _frame())


func moment(name: String) -> void:
	if name.begins_with("open"):
		var id := int(name.get_slice(" ", 1))
		_mark("scene %d %s" % [id, Story.scene(id).get("title", "")])


## Shows the pad with the picks in, as a player would see it, then runs.
func run_pad() -> void:
	var plan: Plan = scene.pad.plan
	_mark("pad %s %s" % [plan.id, JSON.stringify(plan.picks())])
	for _i in PAD_HOLD:
		await get_tree().process_frame
	await super()


func _physics_process(_delta: float) -> void:
	if scene == null or not is_instance_valid(scene):
		return
	var hud := scene.hud
	var speech := ""
	if not hud.bubble.is_empty():
		speech = "%s %s" % [(hud.bubble.who as Person).who if hud.bubble.who != null else "-", hud.bubble.text]
	_flag("say", speech)
	_flag("card", str(hud._card.get("id", "")))
	_flag("rehearsal", scene.pad.plan.id if hud._sepia > 0.0 and scene.pad.plan != null else "")
	_flag("rant", "%s %d" % [hud._rant.error.get("code", ""), hud._rant.error.get("line", 0)] if not hud._rant.is_empty() else "")
	_flag("panic", scene.pad.plan.id if not hud._panic.is_empty() else "")
	_flag("run", hud._code_plan.id if hud._code_plan != null and not hud._code_sepia else "")
	_flag("squint", str(hud._closeup.get("who", "")))
	_flag("freeze", str(scene.scene_id) if hud._freeze > 0.0 else "")
	_flag("end", str(scene.scene_id) if not hud._end.is_empty() else "")


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
