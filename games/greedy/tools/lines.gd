extends Node

## Prints every line the game speaks, for tools/voice.py: the prologue, each
## job's talk and briefs, and the Kid reading each lesson card.
##
##     godot --headless --path . res://tools/lines.tscn


func _ready() -> void:
	var out: Array = []
	var seen: Dictionary = {}
	var lines: Array = Intro.lines() + Story.spoken_lines()
	for id: String in Story.data().cards:
		lines.append({"who": "kid", "say": str(Story.card(id).get("say", ""))})
	for line: Dictionary in lines:
		var said := Voice.spoken(line)
		var key := Voice.key_of(line)
		if said == "" or seen.has(key):
			continue
		seen[key] = true
		out.append({"key": key, "voice": str(line.get("who", "narrator")), "text": said})
	print("LINES " + JSON.stringify(out))
	get_tree().quit()
