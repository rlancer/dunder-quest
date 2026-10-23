extends "res://tests/trail_check.gd"

## The trail bot's full run, recorded for the trailer. Mutes the stage music
## (the trailer has its own cue) and logs a marker line for every moment worth
## cutting to, keyed by the movie frame it lands on.
## godot --path . --write-movie trailer/captures/run/f.png --fixed-fps 60 res://tests/trailer_capture.tscn
##   ->  trailer/captures/run/f00000000.png ... f.wav, and MARK lines on stdout

var _start_frame := 0
var _seen := {}


func _ready() -> void:
	super()
	_start_frame = Engine.get_process_frames()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Music"), true)


func _run() -> void:
	await _play_through(1)
	for fail in _fails:
		print("TRAIL fail ", fail)
	print("MARK %d end" % _frame())
	get_tree().quit(0)


func _physics_process(_delta: float) -> void:
	if _stage == null or not is_instance_valid(_stage):
		return
	var index := _stage.stage_index()
	var hud := _stage.hud
	var player := _stage.player
	var duel := _stage.duel()
	_flag("stage%d" % index, true)
	_flag("s%d_card" % index, hud.is_card_open())
	_flag("s%d_dead" % index, player.is_dead())
	_flag("s%d_air" % index, not player.is_on_floor())
	if _stage.get(&"_building") != null:
		_flag("s%d_building" % index, bool(_stage.get(&"_building")))
	if duel != null:
		_flag("s%d_duel" % index, duel.is_engaged())
		_flag("s%d_asking" % index, duel.is_asking())
		_flag("s%d_answers%d" % [index, duel.answers], duel.answers > 0)
		_flag("s%d_misses%d" % [index, duel.misses], duel.misses > 0)
		_flag("s%d_banished" % index, duel.wizard.banished)
	_flag("s%d_passage" % index, hud.passage_shown or hud.is_cleared())


## Prints a marker each time `on` flips, so every span has a start and an end.
func _flag(key: String, on: bool) -> void:
	if bool(_seen.get(key, false)) == on:
		return
	_seen[key] = on
	print("MARK %d %s %s x=%.0f" % [_frame(), key, "on" if on else "off", _stage.player.global_position.x])


func _frame() -> int:
	return Engine.get_process_frames() - _start_frame
