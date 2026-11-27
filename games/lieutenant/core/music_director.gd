extends Node

## Owns the one music player for the whole game, so a track keeps playing across
## scene changes (title -> map) and only crossfades when the track changes.
## It owns the one voice too (core/voice.gd), and drops the music under it.

const VOLUME_DB := -8.0
const SILENT_DB := -40.0
const FADE := 0.4
## How far the music drops under a voice.
const DUCK_DB := 9.0

var _player: AudioStreamPlayer
var _source: AudioStream
var _tween: Tween
var _voice: AudioStreamPlayer
var _ducked: bool = false
## How far down the music is for an interruption (a lesson card), on top of a voice.
var _held: bool = false
## Clips waiting to be said once the one playing finishes.
var _queue: Array[AudioStream] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)
	_voice = AudioStreamPlayer.new()
	_voice.bus = &"Voice"
	add_child(_voice)
	_voice.finished.connect(_next_voice)


func play(stream: AudioStream) -> void:
	if stream == null:
		return
	if stream == _source and _player.playing:
		return
	_source = stream
	if _tween != null:
		_tween.kill()
	var looped := _looping_copy(stream)
	if not _player.playing:
		_start(looped)
		return
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, FADE)
	_tween.tween_callback(_start.bind(looped))


func stop() -> void:
	_source = null
	_player.stop()


## Drops the music under an interruption, and brings it back after.
func duck(on: bool) -> void:
	_held = on
	_relevel()


## One voice at a time: a new line cuts off the last, and anything queued.
func speak(clip: AudioStream) -> void:
	_queue.clear()
	_voice.stop()
	_voice.stream = clip
	_voice.play()
	_ducked = true
	_relevel()


## Says `clip` once the line playing now has finished (at once if none is).
func speak_next(clip: AudioStream) -> void:
	if _voice.playing:
		_queue.append(clip)
	else:
		speak(clip)


func hush() -> void:
	_queue.clear()
	if _voice.playing:
		_voice.stop()
	if _ducked:
		_ducked = false
		_relevel()


func speaking() -> bool:
	return _voice.playing or not _queue.is_empty()


func _next_voice() -> void:
	if _queue.is_empty():
		_ducked = false
		_relevel()
		return
	_voice.stream = _queue.pop_front()
	_voice.play()


func _level() -> float:
	return VOLUME_DB - (14.0 if _held else (DUCK_DB if _ducked else 0.0))


func _relevel() -> void:
	if _player == null or not _player.playing:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", _level(), 0.25)


func _start(stream: AudioStream) -> void:
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", _level(), FADE)


func _looping_copy(stream: AudioStream) -> AudioStream:
	var copy: Resource = stream.duplicate()
	if copy is AudioStreamOggVorbis:
		(copy as AudioStreamOggVorbis).loop = true
	elif copy is AudioStreamMP3:
		(copy as AudioStreamMP3).loop = true
	elif copy is AudioStreamWAV:
		var wav := copy as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
	return copy as AudioStream
