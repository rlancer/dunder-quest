extends Node

## The music and the stings, kept across scene changes: `Sound.music("plan")`
## crossfades to assets/audio/music_plan.ogg, `Sound.sting("merge")` plays
## assets/audio/sting_merge.ogg over the music, ducking it. A browser won't
## play sound before the first tap, so on the web the music waits for it.
## Headless (the checks) it stays quiet: smoke.gd loads every file instead.

const VOLUME_DB := -6.0
const SILENT_DB := -40.0
const FADE := 0.5
## The Music bus level in core/default_bus_layout.tres.
const MUSIC_BUS_DB := -6.0

const TRACKS := ["title", "plan", "live"]
const STINGS := ["title", "merge", "fail", "postmortem"]

var unlocked: bool = not OS.has_feature("web")
var _quiet: bool = DisplayServer.get_name() == "headless"
var _music: AudioStreamPlayer
var _sting: AudioStreamPlayer
var _track: String = ""
var _queue: Array[String] = []
var _tween: Tween
var _duck_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = &"Music"
	add_child(_music)
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"SFX"
	_sting.finished.connect(_on_sting_done)
	add_child(_sting)


func _input(event: InputEvent) -> void:
	if not unlocked and event.is_pressed() and not event.is_echo():
		unlocked = true
		if _track != "":
			_start()


func music(track: String) -> void:
	if track == _track:
		return
	_track = track
	if unlocked:
		_start()


func stop_music() -> void:
	_track = ""
	_fade_to(SILENT_DB, _music.stop)


## `after`: wait for the sting already playing, if any, instead of cutting it off.
func sting(name: String, after: bool = false) -> void:
	if not unlocked or _quiet:
		return
	if after and _sting.playing:
		_queue.append(name)
		return
	var stream := load("res://assets/audio/sting_%s.ogg" % name) as AudioStream
	if stream == null:
		return
	_sting.stream = stream
	_sting.play()
	_duck(true)


func _on_sting_done() -> void:
	if _queue.is_empty():
		_duck(false)
	else:
		sting(_queue.pop_front())


func playing() -> String:
	return _track if _music.playing else ""


func _start() -> void:
	if _quiet:
		return
	var stream := load("res://assets/audio/music_%s.ogg" % _track) as AudioStreamOggVorbis
	if stream == null:
		return
	stream = stream.duplicate() as AudioStreamOggVorbis
	stream.loop = true
	if not _music.playing:
		_music.stream = stream
		_music.volume_db = SILENT_DB
		_music.play()
		_fade_to(VOLUME_DB)
		return
	_fade_to(SILENT_DB, func() -> void:
		_music.stream = stream
		_music.play()
		_fade_to(VOLUME_DB))


## Dips the Music bus under a sting, apart from the track's own fades.
func _duck(on: bool) -> void:
	var bus := AudioServer.get_bus_index(&"Music")
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(bus, db),
		AudioServer.get_bus_volume_db(bus), MUSIC_BUS_DB - (14.0 if on else 0.0), 0.15)


func _fade_to(db: float, then: Callable = Callable(), seconds: float = FADE) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_music, "volume_db", db, seconds)
	if then.is_valid():
		_tween.tween_callback(then)


## Lets go of the streams at quit, so tests exit clean.
func _exit_tree() -> void:
	for player in [_music, _sting]:
		player.stop()
		player.stream = null
