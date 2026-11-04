extends Control

## The title screen, over the incubator house at dusk: one button per built
## episode. Every episode starts from its own board, so any can be played
## first.

const EPISODE := preload("res://scenes/episode.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var house := Backdrop.new()
	house.place = "house"
	add_child(house)
	var card := UI.place(UI.panel(Color(Palette.PAPER, 0.94), Palette.GREEN, 1), Rect2(40, 50, 400, 190))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	Sound.music("title")
	var bar := UI.place(UI.panel(Palette.GREEN), Rect2(0, 0, 480, 6))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var name_label := UI.place(UI.title("MISSION SILICON", 34, Palette.SLATE), Rect2(0, 56, 480, 44)) as Label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	var line := UI.place(UI.panel(Palette.GREEN), Rect2(190, 102, 100, 4))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var sub := UI.place(UI.label("A Dunder Quest game. You can't code. Your AI can, a bit too confidently.", Palette.BODY, Palette.SLATE_MID, true), Rect2(0, 112, 480, 12)) as Label
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)
	var y := 132.0
	for ep in Season.episodes():
		var id := int(ep["id"])
		var text := "EPISODE %d: %s" % [id, ep["title"].to_upper()]
		var best: Dictionary = Progress.best.get(str(id), {})
		if not best.is_empty():
			text += "   %.1f mo" % best["runway"]
		var play := UI.button(text, "primary", Vector2(280, 32))
		play.name = "Play_%d" % id
		UI.place(play, Rect2(100, y, 280, 32))
		play.pressed.connect(_play.bind(id))
		add_child(play)
		y += 38.0
	var foot := UI.place(UI.label("Prototype: %d episodes of fourteen." % Season.episodes().size(), Palette.BODY, Palette.SLATE_MID), Rect2(0, y + 2, 480, 12)) as Label
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)


func _play(id: int) -> void:
	var ep := EPISODE.new() as Episode
	ep.episode_id = id
	get_tree().change_scene_to_node(ep)
