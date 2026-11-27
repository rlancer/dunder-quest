class_name Voice
extends RefCounted

## The cast's voices: one clip for every line of dialogue, cold-open
## caption, lesson card, prologue page and word from Records, made by
## tools/voice.py (ElevenLabs, through OpenRouter) and kept in assets/voice/.
## A clip is named for who says it and what they say, so a line that's been
## rewritten never plays the old reading. A line with no clip is simply read
## in silence.
##
## A line is {who, text}, and may carry a `mood` (the pose the speaker
## strikes, which also tells the voice how to say it) and a `say` (the words
## as read aloud, for a line with SQL in it). A line from data/cases.json
## with no `say` of its own is looked up in the file's `say` table, by its
## exact text.

## Tests turn the voices off, so a run doesn't wait on them.
static var muted: bool = false

## How each mood is acted: a v4 direction, which it performs and doesn't read.
const DIRECTIONS := {"think": "[thinking aloud]", "smug": "[smugly]", "sweat": "[nervously]"}

static var _cache: Dictionary = {}


## A line from data/cases.json, [who, text, mood], as a line.
static func of(entry: Array) -> Dictionary:
	var line := {"who": str(entry[0]), "text": str(entry[1])}
	if entry.size() > 2 and str(entry[2]) != "":
		line["mood"] = str(entry[2])
	return line


## A line as it is read aloud: its `say` if it has one, else the entry for
## its text in the script's `say` table, else its text, without quote marks
## and with a column's underscore and a table's dot said the way they're
## said. A mood goes in front as a direction.
static func spoken(line: Dictionary) -> String:
	var text := str(line.get("text", ""))
	var said := ""
	if line.has("say"):
		said = str(line.say)
	else:
		var table: Dictionary = Story.data().get("say", {})
		said = str(table[text]) if table.has(text) else plain(text)
	said = said.strip_edges()
	var direction := str(DIRECTIONS.get(str(line.get("mood", "")), ""))
	if direction != "" and said != "" and not said.begins_with("["):
		said = direction + " " + said
	return said


## Text with the code read out: "checked_at" is "checked at",
## "seating.seat" is "seating dot seat", and a keyword in capitals is said
## as a word ("JOINed" is "joined"), not spelled. COUNT(*) is "count star".
static func plain(text: String) -> String:
	var out := text.replace("\"", "").replace("_", " ").replace("(*)", " star")
	var dot := RegEx.create_from_string("([a-z])\\.([a-z])")
	out = dot.sub(out, "$1 dot $2", true)
	var keyword := RegEx.create_from_string("\\b(SELECT|FROM|WHERE|LEFT JOIN|JOIN|ON|GROUP BY|ORDER BY|HAVING|LIMIT|LIKE|AND|OR|IS NOT NULL|IS NULL|NULL|COUNT|DESC)(ed)?\\b")
	var said := ""
	var at := 0
	for hit in keyword.search_all(out):
		said += out.substr(at, hit.get_start() - at) + hit.get_string().to_lower()
		at = hit.get_end()
	out = said + out.substr(at)
	# Any other word in capitals is said, not shouted.
	said = ""
	at = 0
	for hit in RegEx.create_from_string("\\b[A-Z]{4,}\\b").search_all(out):
		said += out.substr(at, hit.get_start() - at) + hit.get_string().capitalize()
		at = hit.get_end()
	return (said + out.substr(at)).strip_edges()


static func key(who: String, said: String) -> String:
	return "%s_%s" % [who, (who + "|" + said).md5_text().left(10)]


static func key_of(line: Dictionary) -> String:
	return key(str(line.get("who", "narrator")), spoken(line))


static func stream(line: Dictionary) -> AudioStream:
	var path := "res://assets/voice/%s.ogg" % key_of(line)
	if not _cache.has(path):
		_cache[path] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _cache[path]


static func _silent() -> bool:
	return muted or (OS.has_feature("web") and not StageAudio.web_audio_unlocked)


## Says the line, cutting off whatever was being said, and returns how long
## it runs (0 if there's no clip).
static func say(line: Dictionary) -> float:
	hush()
	if _silent():
		return 0.0
	var clip := stream(line)
	if clip == null:
		return 0.0
	MusicDirector.speak(clip)
	return clip.get_length()


## Says the lines one after another, after whatever is being said now.
static func say_after(lines: Array) -> void:
	if _silent():
		return
	for line: Dictionary in lines:
		var clip := stream(line)
		if clip != null:
			MusicDirector.speak_next(clip)


static func hush() -> void:
	MusicDirector.hush()


static func talking() -> bool:
	return MusicDirector.speaking()
