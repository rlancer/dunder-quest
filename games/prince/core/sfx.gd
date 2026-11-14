class_name Sfx
extends RefCounted

## Sound effects and music by name, from assets/audio. A missing file is
## silence, so the game runs before every sound is made.

static var _cache: Dictionary = {}


static func _stream(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[path]


static func play(node: Node, name: String) -> void:
	if node == null or not node.is_inside_tree():
		return
	StageAudio.play(node.get_tree(), _stream("res://assets/audio/%s.wav" % name))


static func music(_node: Node, name: String) -> void:
	var stream := _stream("res://assets/audio/%s.ogg" % name)
	if stream != null and (not OS.has_feature("web") or StageAudio.web_audio_unlocked):
		MusicDirector.play(stream)
