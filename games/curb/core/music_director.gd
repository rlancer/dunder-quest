extends Node

## Owns the one music player for the whole game, so a track keeps playing across
## scene changes (title -> map) and only crossfades when the track changes.

const VOLUME_DB := -8.0
const SILENT_DB := -40.0
const FADE := 0.4

var _player: AudioStreamPlayer
var _source: AudioStream
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = &"Music"
	_player.volume_db = VOLUME_DB
	add_child(_player)


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
	if _player == null or not _player.playing:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME_DB - 14.0 if on else VOLUME_DB, 0.25)


func _start(stream: AudioStream) -> void:
	_player.stream = stream
	_player.volume_db = SILENT_DB
	_player.play()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", VOLUME_DB, FADE)


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
