extends "res://tests/bot.gd"

## The bot's full run, recorded for the trailer. Mutes the stage music (the
## trailer has its own cue), holds each laptop's editor open with the picks
## filled in before it runs, lets lesson cards sit long enough to read, and
## logs a MARK line for every moment worth cutting to, keyed by movie frame.
## godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_run.tscn
##   ->  trailer/captures/run/f00000000.png ... f.wav, and MARK lines on stdout

const EDITOR_HOLD := 110
const CARD_HOLD := 150

var _start_frame := 0
var _seen := {}
var _cards_held := {}


func _ready() -> void:
	super()
	seed(7)
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	await super()
	print("MARK %d end" % _frame())


## Shows the editor with the answer in, as a player would see it, then runs.
func run_laptop(index: int, picks: Dictionary, wait: int = 0) -> Laptop:
	var laptop: Laptop = _stage._laptops[index]
	laptop.program.set_picks(picks)
	_stage.editor.open(laptop, _stage.active.who)
	_mark("editor on %s %s" % [laptop.program.file_name, JSON.stringify(picks)])
	for _i in EDITOR_HOLD:
		await get_tree().physics_frame
	_stage.editor._run()
	_mark("run %s" % laptop.program.file_name)
	await _frames(wait)
	return laptop


## The first time each card opens it stays up for a read, without eating
## into the walk budgets of the moves that triggered it.
func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
		if _stage != null and is_instance_valid(_stage) and _stage.hud._card_open:
			var key := _stage.hud._card.get_instance_id() if _stage.hud._card != null else 0
			if not _cards_held.has(key):
				_cards_held[key] = true
				for _j in CARD_HOLD:
					await get_tree().physics_frame
		_dismiss()


func _physics_process(_delta: float) -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	var hud := _stage.hud
	_flag("stage", str(_stage.stage_id))
	_flag("pov", _stage.active.who)
	_flag("card", str(hud._card_open))
	_flag("voice", hud._voice_full if hud._voice_box.visible else "")
	var said: Array = []
	for bubble in hud._bubbles:
		said.append(str(bubble["text"]))
	_flag("speech", " | ".join(said))
	_flag("cleared", str(_stage._cleared))
	_flag("fall", str(_stage._falls))


## Prints a marker each time `key`'s value changes.
func _flag(key: String, value: String) -> void:
	if _seen.get(key, null) == value:
		return
	_seen[key] = value
	_mark("%s %s" % [key, value])


func _mark(text: String) -> void:
	var where := ""
	if _stage != null and is_instance_valid(_stage):
		where = " clive=%.0f,%.0f jazz=%.0f,%.0f" % [_stage.clive.global_position.x, _stage.clive.global_position.y, _stage.jazz.global_position.x, _stage.jazz.global_position.y]
	print("MARK %d %s%s" % [_frame(), text, where])


func _frame() -> int:
	return Engine.get_process_frames() - _start_frame
