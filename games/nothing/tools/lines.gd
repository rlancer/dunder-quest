extends Node

## Prints every line the game speaks, for tools/voice.py: the prologue, each
## episode's talk and briefs, and Stu reading each of his sets.
##
##     godot --headless --path . res://tools/lines.tscn


func _ready() -> void:
	var out: Array = []
	var seen: Dictionary = {}
	var lines: Array = Intro.lines() + Story.spoken_lines()
	for id: String in Story.data().cards:
		lines.append(LessonCard.spoken(Story.card(id)))
	for line: Dictionary in lines:
		var said := Voice.spoken(line)
		var key := Voice.key_of(line)
		if said == "" or seen.has(key):
			continue
		seen[key] = true
		out.append({"key": key, "voice": str(line.get("who", "narrator")), "text": said})
	print("LINES " + JSON.stringify(out))
	get_tree().quit()
