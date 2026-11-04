extends Control

## The title screen. The prototype has one episode, so it's one button.

const EPISODE := preload("res://scenes/episode.gd")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := UI.place(UI.panel(Palette.PAPER), Rect2(0, 0, 480, 270))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var bar := UI.place(UI.panel(Palette.GREEN), Rect2(0, 0, 480, 6))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var name_label := UI.place(UI.title("MISSION SILICON", 34, Palette.SLATE), Rect2(0, 70, 480, 44)) as Label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	var line := UI.place(UI.panel(Palette.GREEN), Rect2(190, 116, 100, 4))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var sub := UI.place(UI.label("A Dunder Quest game. You can't code. Your AI can, a bit too confidently.", Palette.LABEL, Palette.SLATE_MID), Rect2(0, 126, 480, 14)) as Label
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var play := UI.button("PLAY EPISODE 8: VIRAL", "primary", Vector2(200, 34))
	play.name = "Play"
	UI.place(play, Rect2(140, 160, 200, 34))
	play.pressed.connect(_play)
	add_child(play)
	var best: Dictionary = Progress.best.get("8", {})
	var note := "Prototype: one episode of fourteen."
	if not best.is_empty():
		note = "Best runway %.2f months.  %s" % [best["runway"], note]
	var foot := UI.place(UI.label(note, Palette.BODY, Palette.SLATE_LIGHT), Rect2(0, 206, 480, 12)) as Label
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)


func _play() -> void:
	var ep := EPISODE.new() as Episode
	ep.episode_id = 8
	get_tree().change_scene_to_node(ep)
