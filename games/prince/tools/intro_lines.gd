extends Node

## Prints every line the prologue reads aloud, as one JSON line, for
## tools/voice.py. A scene rather than a --script, so the autoloads the
## prologue leans on are there:
##
##     godot --headless --path . res://tools/intro_lines.tscn


func _ready() -> void:
	var intro := Intro.new()
	print("INTRO_LINES " + JSON.stringify(intro.lines()))
	intro.free()
	get_tree().quit(0)
