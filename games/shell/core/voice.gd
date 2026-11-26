class_name Voice
extends RefCounted

## The cast's voices: a clip for a line of dialogue, lesson card or prologue
## page, if there is one in assets/voice/, named for who says it and what
## they say (so a line that's been rewritten never plays the old reading).
## A line with no clip is read in silence, and so far that is all of them:
## this game was built without a key for the voice generator. The other
## games' tools/voice.py would make the clips this looks for.

## Tests turn the voices off, so a run doesn't wait on them.
static var muted: bool = false

static var _cache: Dictionary = {}


## A line as it is read aloud: the line's `say` if it has one (for a line
## that is a command, or wants a whisper), else its text without quote marks.
static func spoken(line: Dictionary) -> String:
	if line.has("say"):
		return str(line.say)
	return str(line.get("text", "")).replace("\"", "").strip_edges()


static func key(who: String, said: String) -> String:
	return "%s_%s" % [who, (who + "|" + said).md5_text().left(10)]


static func key_of(line: Dictionary) -> String:
	return key(str(line.get("who", "narrator")), spoken(line))


static func stream(line: Dictionary) -> AudioStream:
	var path := "res://assets/voice/%s.ogg" % key_of(line)
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[path]


## Says the line, and returns how long it runs (0 if there's no clip).
static func say(line: Dictionary) -> float:
	hush()
	if muted or (OS.has_feature("web") and not StageAudio.web_audio_unlocked):
		return 0.0
	var clip := stream(line)
	if clip == null:
		return 0.0
	MusicDirector.speak(clip)
	return clip.get_length()


static func hush() -> void:
	MusicDirector.hush()


static func talking() -> bool:
	return MusicDirector.speaking()
