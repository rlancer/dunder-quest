extends Control

## The season screen, over the incubator house at dusk: all fourteen
## episodes as tiles in two rows of seven, like a streaming service's season
## page. A built episode is a tile to tap, with its best runway and its
## three marks (Live, Lean, Ulrich) once it's been played; one still to come
## is a quiet tile with its title. Every episode starts from its own board,
## so any built one can be played first.

const EPISODE := preload("res://scenes/episode.gd")
const COLS := 7
const TILE := Vector2(60, 72)
const GAP := 3.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var house := Backdrop.new()
	house.place = "house"
	add_child(house)
	var card := UI.place(UI.panel(Color(Palette.PAPER, 0.94), Palette.GREEN, 1), Rect2(14, 10, 452, 252))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(card)
	Sound.music("title")
	var bar := UI.place(UI.panel(Palette.GREEN), Rect2(0, 0, 480, 6))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var name_label := UI.place(UI.title("MISSION SILICON", 30, Palette.SLATE), Rect2(0, 14, 480, 38)) as Label
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(name_label)
	var line := UI.place(UI.panel(Palette.GREEN), Rect2(200, 52, 80, 3))
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(line)
	var sub := UI.place(UI.label("A Dunder Quest game. You can't code. Your AI can, a bit too confidently.", Palette.BODY, Palette.SLATE_MID), Rect2(0, 58, 480, 12)) as Label
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var outline: Array = Season.data().get("outline", [])
	var x0 := (480.0 - COLS * TILE.x - (COLS - 1) * GAP) / 2.0
	var y0 := 78.0
	var built := 0
	for i in outline.size():
		var entry: Dictionary = outline[i]
		var id := int(entry["id"])
		var at := Vector2(x0 + (i % COLS) * (TILE.x + GAP), y0 + (i / COLS) * (TILE.y + GAP))
		var ep := Season.episode(id)
		if ep.is_empty():
			add_child(_soon(entry, at))
		else:
			built += 1
			add_child(_tile(ep, at))
	var foot := UI.place(UI.label("%d of 14 episodes playable.  Marks: Live, Lean, Ulrich." % built, Palette.BODY, Palette.SLATE_MID), Rect2(0, y0 + 2 * TILE.y + GAP + 4, 480, 12)) as Label
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)


## A built episode: its number, its title, and once played, its best runway
## and marks.
func _tile(ep: Dictionary, at: Vector2) -> Button:
	var id := int(ep["id"])
	var b := UI.button("", "normal", TILE)
	b.name = "Play_%d" % id
	UI.place(b, Rect2(at, TILE))
	UI.style(b, "normal")
	b.add_theme_stylebox_override("normal", UI.box(Palette.WHITE, Palette.GREEN, 1))
	b.pressed.connect(_play.bind(id))
	_fill(b, id, ep.get("short", ep["title"]), Palette.GREEN_DARK, Palette.SLATE)
	var best: Dictionary = Progress.best.get(str(id), {})
	if best.is_empty():
		b.add_child(UI.place(UI.label("new", Palette.BODY, Palette.GREEN_DARK), Rect2(4, 47, 52, 11)))
	else:
		b.add_child(UI.place(UI.label("%.1f mo" % best["runway"], Palette.BODY, Palette.SLATE), Rect2(4, 47, 52, 11)))
		var mx := 4.0
		for m in ["live", "lean", "ulrich"]:
			var dot := ColorRect.new()
			dot.color = Palette.GREEN if best.get(m, false) else Palette.RULE
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UI.place(dot, Rect2(mx, 61, 14, 6))
			b.add_child(dot)
			mx += 17.0
	return b


## An episode still to come: a quiet tile with its title.
func _soon(entry: Dictionary, at: Vector2) -> Control:
	var p := UI.place(UI.panel(Color(Palette.RULE, 0.6), Palette.SLATE_LIGHT, 1), Rect2(at, TILE))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(p, int(entry["id"]), entry.get("short", entry["title"]), Palette.SLATE_LIGHT, Palette.SLATE_MID)
	p.add_child(UI.place(UI.label("soon", Palette.BODY, Palette.SLATE_LIGHT), Rect2(4, 56, 52, 11)))
	return p


func _fill(c: Control, id: int, title: String, number_color: Color, title_color: Color) -> void:
	c.add_child(UI.place(UI.title(str(id), 16, number_color), Rect2(4, 1, 52, 20)))
	var t := UI.place(UI.label(_case(title), Palette.BODY, title_color, true), Rect2(4, 21, 54, 26)) as Label
	t.clip_text = false
	c.add_child(t)


## "THE BOARD MEETING" and "The Board Meeting" both arrive; tiles use title case.
func _case(title: String) -> String:
	var words := []
	for w in title.split(" "):
		words.append(w.substr(0, 1).to_upper() + w.substr(1).to_lower())
	return " ".join(words)


func _play(id: int) -> void:
	var ep := EPISODE.new() as Episode
	ep.episode_id = id
	get_tree().change_scene_to_node(ep)
