class_name Sfx
extends RefCounted

## Sound effects and music by name, from assets/audio. A missing file is
## silence, so the game runs before every sound is made.

static var _cache: Dictionary = {}
## The take each sound played last.
static var _last: Dictionary = {}


static func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[path]


## A sound with takes (`sting_1.ogg`, `sting_2.ogg`, ...) plays one of them
## at random, never the same one twice running; otherwise its `.wav`.
static func play(node: Node, name: String) -> void:
	if node == null or not node.is_inside_tree() or name == "":
		return
	var takes := _takes(name)
	var stream: AudioStream = _stream("res://assets/audio/%s.wav" % name)
	if not takes.is_empty():
		var pick := randi() % takes.size()
		if takes.size() > 1 and pick == int(_last.get(name, -1)):
			pick = (pick + 1 + randi() % (takes.size() - 1)) % takes.size()
		_last[name] = pick
		stream = takes[pick]
	StageAudio.play(node.get_tree(), stream)


static func _takes(name: String) -> Array:
	var key := "takes:" + name
	if not _cache.has(key):
		var found: Array = []
		var n := 1
		while ResourceLoader.exists("res://assets/audio/%s_%d.ogg" % [name, n]):
			found.append(_stream("res://assets/audio/%s_%d.ogg" % [name, n]))
			n += 1
		_cache[key] = found
	return _cache[key]


static func music(name: String) -> void:
	var stream := _stream("res://assets/audio/music_%s.ogg" % name)
	if stream != null and (not OS.has_feature("web") or StageAudio.web_audio_unlocked):
		MusicDirector.play(stream)
