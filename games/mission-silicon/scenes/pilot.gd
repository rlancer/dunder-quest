class_name Pilot
extends Control

## Episode 1, the Pilot, rebuilt teaching-first from storyboard/pilot.html:
## twelve frames in five acts. The cold open and Walter's test; the map of a
## web app (four boxes) and one search followed through it; four ways to
## ship, and one picked against Thursday's requirements; Aleister's
## no-server plan and the key in the app; the sort (phone, server or
## database); build or rent the backend; reading the tech stack and
## catching NEXT_PUBLIC_; Thursday by device, with the 4:40 iPhone bug;
## Gerard's decision record and the runway; the cliffhanger.
##
## Every word is in data/pilot.json. `phase` says which frame is up, for the
## bot. Its rules (the requirement boards, the testers, the marks) are in
## core/pilot_model.gd, which tests/cases.gd checks headless.

signal next_pressed
signal finished

## Tests: Thursday's minutes per frame (0 plays at the real pace), and
## whether to stay put at the end instead of going back to the title.
static var test_minutes_per_frame: int = 0
static var test_stay: bool = false

## Thursday at the real pace: simulated minutes per second.
const MINUTES_PER_SECOND := 10.0
const WHITEBOARD := Color("#fbfbf8")
const CODE_BG := Color("#111417")
const CODE_FG := Color("#d6dde5")
const CODE_DIM := Color("#7f8b99")
const GOOD_BG := Color("#effaf4")
const BAD_BG := Color("#fdf0f0")
const RISK_BG := Color("#fde3e3")
const PICKED_BG := Color("#f2fbf6")
## The map's boxes in its own 456x100 frame, and the envelope's stops.
const MAP_SIZE := Vector2(456, 100)
const MAP_BOX := {
	"device": Rect2(0, 26, 104, 50), "server": Rect2(176, 26, 104, 50),
	"db": Rect2(352, 0, 104, 44), "model": Rect2(352, 56, 104, 44),
}
const MAP_STOP := {"device": Vector2(52, 51), "wire": Vector2(140, 51), "server": Vector2(228, 51),
	"db": Vector2(404, 22), "model": Vector2(404, 78)}

var d: Dictionary
var phase: String = ""
## What the player picked: the platform, every platform tried, the
## backend, the backends tried, how many pieces went to the wrong place.
var picks: Dictionary = {"platform": "", "tried": [], "backend": "", "tried_backend": [], "misplaced": 0, "fixed": false}
## Thursday for the player's build, and the marks, once played.
var result: Dictionary = {}
var earned: Dictionary = {}

var backdrop: Backdrop
var dialogue: Dialogue
var card: Card
var _stage: Control
var _prompt: Label
var _status: Label
var _squares: Array = []
var _timebar: Control
var _time_fill: ColorRect
var _time_text: Label
var _next: Button
var _decided: int = 0

# Each frame's own state.
var _sel: String = ""
var _seen: Dictionary = {}
var _boxes: Dictionary = {}
var _panel: Control
var _left: Control
var _right: Control
var _extra: Control
var _step: int = 0
var _stepped_all: bool = false
var _envelope: Control
var _armed: String = ""
var _placed: Dictionary = {}
var _last: String = ""
var _zones: Dictionary = {}
var _open: Dictionary = {}
var _cur: int = -1
## Thursday's run.
var _build: String = ""
var _minute: float = 0.0
var _running: bool = false
var _paused: bool = false
var _ran_mine: bool = false
var _testers: Dictionary = {}
var _tiles: Dictionary = {}


func _ready() -> void:
	d = Season.pilot()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_run.call_deferred()


func _build_ui() -> void:
	var bg := UI.place(UI.panel(Palette.PAPER), Rect2(0, 0, 480, 270))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_stage = UI.place(Control.new(), Rect2(0, 0, 480, 270))
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	var top := UI.place(UI.panel(Palette.SLATE), Rect2(0, 0, 480, 20))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var short: String = d.get("short", "PILOT")
	var name_label := UI.place(UI.title(short, Palette.HEAD, Palette.GREEN), Rect2(6, 2, 60, 16)) as Label
	top.add_child(name_label)
	var after := 6.0 + ceilf(Palette.titles().get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.HEAD).x)
	_prompt = UI.place(UI.label("", Palette.BODY, Palette.WHITE), Rect2(after + 8.0, 3, 300, 14)) as Label
	_prompt.clip_text = true
	top.add_child(_prompt)
	_status = UI.place(UI.label("", Palette.BODY, Palette.WHITE), Rect2(300, 3, 116, 14)) as Label
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_status)
	# The four decisions, ticked off as they're made.
	for i in 4:
		var sq := UI.place(UI.panel(Palette.SLATE_MID), Rect2(422 + i * 14, 4, 12, 12))
		sq.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(sq)
		var n := UI.place(UI.label(str(i + 1), Palette.BODY, Palette.SLATE_LIGHT), Rect2(0, -1, 12, 12)) as Label
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sq.add_child(n)
		_squares.append(sq)
	_timebar = UI.place(Control.new(), Rect2(292, 0, 126, 20))
	_timebar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_timebar)
	var track := UI.place(ColorRect.new(), Rect2(0, 7, 44, 6)) as ColorRect
	track.color = Palette.SLATE_MID
	_timebar.add_child(track)
	_time_fill = UI.place(ColorRect.new(), Rect2(0, 7, 0, 6)) as ColorRect
	_time_fill.color = Palette.GREEN
	_timebar.add_child(_time_fill)
	_time_text = UI.place(UI.label("", Palette.BODY, Palette.WHITE), Rect2(48, 3, 76, 14)) as Label
	_time_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timebar.add_child(_time_text)
	_timebar.visible = false

	_next = UI.button("NEXT", "primary", Vector2(90, 30))
	_next.name = "Next"
	_next.pressed.connect(func() -> void: next_pressed.emit())
	add_child(_next)
	_hide_next()

	backdrop = Backdrop.new()
	backdrop.visible = false
	add_child(backdrop)
	dialogue = Dialogue.new()
	add_child(dialogue)
	card = Card.new()
	add_child(card)


func _run() -> void:
	await _cold_open()
	await _map_frame()
	await _steps_frame()
	await _ways_frame()
	await _pick_frame()
	await _noserver_frame()
	await _sort_frame()
	await _backend_frame()
	await _plan_frame()
	await _thursday_frame()
	await _postmortem_frame()
	await _record_frame()
	await _cliffhanger()
	phase = "done"
	finished.emit()
	if not test_stay:
		get_tree().change_scene_to_file("res://ui/boot.tscn")


# Shared pieces.

## A new frame: the stage cleared, the top bar's words, no Next yet.
func _frame(p: String, prompt: String, status: String = "") -> void:
	phase = p
	UI.clear(_stage)
	_boxes = {}
	_timebar.visible = false
	_hide_next()
	_set_top(prompt, status)


func _set_top(prompt: String, status: String) -> void:
	_status.text = status
	var w := ceilf(Palette.body().get_string_size(status, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x)
	var right := 416.0 - w - 8.0 if status != "" else 416.0
	if _timebar.visible:
		right = 288.0
	_prompt.text = prompt
	_prompt.size.x = right - _prompt.position.x


func _set_status(status: String) -> void:
	_set_top(_prompt.text, status)


func _decide(n: int) -> void:
	_decided = maxi(_decided, n)
	for i in _squares.size():
		var sq: Panel = _squares[i]
		var done := i < _decided
		sq.add_theme_stylebox_override("panel", UI.box(Palette.GREEN if done else Palette.SLATE_MID))
		(sq.get_child(0) as Label).add_theme_color_override("font_color", Palette.WHITE if done else Palette.SLATE_LIGHT)


func _time(used: float) -> void:
	var budget := float(d["budget"]["time"])
	_timebar.visible = true
	_set_top(_prompt.text, "")
	_time_fill.size.x = 44.0 * minf(1.0, used / budget)
	_time_fill.color = Palette.RED if used > budget else Palette.GREEN
	_time_text.text = "Time %sh / %sh" % [_num(used), _num(budget)]
	_time_text.add_theme_color_override("font_color", Palette.AMBER if used > budget else Palette.WHITE)


func _show_next(text: String = "NEXT", at: Rect2 = Rect2(386, 237, 90, 30), enabled: bool = true) -> void:
	_next.text = text
	UI.place(_next, at)
	_next.visible = true
	_next.disabled = not enabled


func _hide_next() -> void:
	_next.visible = false


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


## Wrapped text at a width, its height set to its lines. Returns the label;
## its bottom is position.y + size.y.
func _para(parent: Control, text: String, at: Vector2, w: float, size: int = Palette.BODY, color: Color = Palette.SLATE) -> Label:
	var l := UI.label(text, size, color, true)
	l.add_theme_constant_override("line_spacing", -1)
	parent.add_child(l)
	l.position = at
	l.size = Vector2(w, 1)
	var lines := l.get_line_count()
	l.size = Vector2(w, lines * (Palette.body().get_height(size) - 1.0) + 1.0)
	return l


func _bottom(l: Control) -> float:
	return l.position.y + l.size.y


func _rect(parent: Control, r: Rect2, bg: Color, border: Color = Color.TRANSPARENT, width: int = 0) -> Panel:
	var p := UI.place(UI.panel(bg, border, width), r) as Panel
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


## A cast member's line in a box on the screen (not the dialogue): their
## close-up, their name and what they say.
func _say(parent: Control, line: Dictionary, r: Rect2) -> Panel:
	var p := _rect(parent, r, Palette.WHITE, Palette.SLATE, 1)
	var face := UI.place(Portrait.new(line["who"]), Rect2(5, 5, 48, 48))
	p.add_child(face)
	p.add_child(UI.place(UI.label(Season.person(line["who"])["name"], Palette.BODY, Palette.GREEN_DARK), Rect2(59, 4, r.size.x - 64, 12)))
	_para(p, line["say"], Vector2(59, 17), r.size.x - 64)
	return p


## A notice: a pale panel with a dashed-looking border, green when it's
## good news, red when it's bad. Returns the panel, sized to its text.
func _notice(parent: Control, text: String, at: Vector2, w: float, kind: String = "", head: String = "") -> Panel:
	var bg := Palette.PAPER
	var border := Palette.SLATE_LIGHT
	if kind == "good":
		bg = GOOD_BG
		border = Palette.GREEN
	elif kind == "bad":
		bg = BAD_BG
		border = Palette.RED
	var p := _rect(parent, Rect2(at, Vector2(w, 20)), bg, border, 1)
	var y := 3.0
	if head != "":
		var h := _para(p, head, Vector2(6, y), w - 12, Palette.BODY, Palette.GREEN_DARK if kind == "good" else Palette.SLATE)
		y = _bottom(h)
	if text != "":
		y = _bottom(_para(p, text, Vector2(6, y), w - 12))
	p.size.y = y + 4.0
	return p


## A NEW WORD (or THE RULE) stamp: the label, the term, what it means.
func _stamp(parent: Control, s: Dictionary, r: Rect2) -> Panel:
	var p := _rect(parent, r, Palette.WHITE, Palette.GREEN, 2)
	p.name = "Stamp"
	p.add_child(UI.place(UI.label(s.get("label", "NEW WORD"), Palette.BODY, Palette.GREEN_DARK), Rect2(8, 4, 200, 12)))
	p.add_child(UI.place(UI.title(s["term"], Palette.HEAD, Palette.SLATE), Rect2(8, 16, r.size.x - 16, 16)))
	var y := _bottom(_para(p, s["plain"], Vector2(8, 33), r.size.x - 16))
	if s.has("eg"):
		y = _bottom(_para(p, s["eg"], Vector2(8, y + 1), r.size.x - 16, Palette.BODY, Palette.SLATE_MID))
	p.size.y = maxf(r.size.y, y + 5.0)
	return p


## A whiteboard behind the map frames.
func _whiteboard() -> void:
	var p := _rect(_stage, Rect2(0, 20, 480, 250), WHITEBOARD)
	p.name = "Whiteboard"


## The map: four boxes and the wires between them, as Buttons named
## Box_<id>. `skip_server` leaves the box in the middle out and draws
## Aleister's direct wire from the phone to the model.
func _map(origin: Vector2, skip_server: bool = false) -> void:
	_boxes = {}
	var wires := Wires.new()
	UI.place(wires, Rect2(origin, MAP_SIZE))
	_stage.add_child(wires)
	var wire_label := UI.place(UI.label(d["map"]["wire"], Palette.BODY, Palette.SLATE_MID), Rect2(origin + Vector2(104, 28), Vector2(72, 12))) as Label
	wire_label.clip_text = true
	wire_label.size = Vector2(72, 12)
	wire_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if skip_server:
		wires.segs = [[Vector2(104, 60), Vector2(352, 78), Palette.RED, true]]
		wire_label.position = origin + Vector2(190, 52)
	else:
		wires.segs = [[Vector2(104, 51), Vector2(176, 51), Palette.SLATE_LIGHT, false],
			[Vector2(280, 45), Vector2(352, 22), Palette.SLATE_LIGHT, false],
			[Vector2(280, 57), Vector2(352, 78), Palette.SLATE_LIGHT, false]]
	_stage.add_child(wire_label)
	for k in MAP_BOX:
		if skip_server and k == "server":
			continue
		var r: Rect2 = MAP_BOX[k]
		var b := UI.button("", "normal", r.size)
		b.name = "Box_" + k
		UI.place(b, Rect2(origin + r.position, r.size))
		_stage.add_child(b)
		var info: Dictionary = d["map"]["boxes"][k]
		var n := _para(b, info["n"], Vector2(4, 0), r.size.x - 8, Palette.LABEL, Palette.SLATE)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var s := _para(b, info["s"], Vector2(4, _bottom(n)), r.size.x - 8, Palette.BODY, Palette.SLATE_MID)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Centred up and down in the box.
		var shift := floorf((r.size.y - _bottom(s)) / 2.0)
		n.position.y += shift
		s.position.y += shift
		var strip := UI.place(ColorRect.new(), Rect2(1, r.size.y - 4, r.size.x - 2, 3)) as ColorRect
		strip.name = "Seen"
		strip.color = Palette.GREEN
		strip.visible = false
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(strip)
		_boxes[k] = b


func _box_state(k: String, hot: bool, seen: bool = false) -> void:
	var b: Button = _boxes.get(k)
	if b == null:
		return
	var bg := Palette.GREEN_PALE if hot else Palette.WHITE
	var border := Palette.GREEN if hot else Palette.SLATE
	for s in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, UI.box(bg, border, 2 if hot else 1, 3))
	(b.get_node("Seen") as ColorRect).visible = seen


## Act 1: the cold open, the title card, Walter's test.

func _cold_open() -> void:
	phase = "cold_open"
	Sound.music("plan")
	var c: Dictionary = d["cold_open"]
	backdrop.place = c["backdrop"]
	backdrop.visible = true
	await dialogue.play(c["lines"], c["place"])
	phase = "title"
	Sound.sting("title")
	await card.title_card(d["title"])
	backdrop.visible = false

	_frame("goal", "")
	var g: Dictionary = d["goal_card"]
	var p := _rect(_stage, Rect2(56, 28, 368, 202), Palette.WHITE, Palette.SLATE, 2)
	p.name = "Goal"
	p.add_child(UI.place(UI.title(g["head"], 18, Palette.GREEN), Rect2(14, 10, 340, 24)))
	var y := 40.0
	for item in g["items"]:
		p.add_child(UI.place(UI.label("•", Palette.LABEL, Palette.SLATE), Rect2(14, y, 8, 14)))
		y = _bottom(_para(p, item, Vector2(24, y), 330, Palette.LABEL)) + 3.0
	p.add_child(UI.place(UI.title(g["sub"], Palette.LABEL, Palette.SLATE_MID), Rect2(14, y + 6, 340, 14)))
	y += 24.0
	var names: Array = d["decisions"]
	for i in names.size():
		var chip := _rect(p, Rect2(14 + (i % 2) * 172, y + (i / 2) * 26, 166, 22), Palette.GREEN_PALE, Palette.GREEN, 1)
		chip.add_child(UI.place(UI.label("%d · %s" % [i + 1, names[i]], Palette.BODY, Palette.GREEN_DARK), Rect2(6, 4, 156, 12)))
	_show_next("START", Rect2(386, 237, 90, 30))
	await next_pressed


## Act 1: the map. Four boxes; each opens what it is.

func _map_frame() -> void:
	_frame("map", d["map"]["prompt"], "0 of 4")
	_whiteboard()
	_map(Vector2(12, 26))
	_seen = {}
	_sel = ""
	for k in _boxes:
		(_boxes[k] as Button).pressed.connect(_on_map_box.bind(k))
	_panel = _rect(_stage, Rect2(8, 130, 464, 102), Palette.WHITE, Palette.SLATE, 1)
	_panel.name = "Info"
	_say(_panel, d["map"]["hint"], Rect2(0, 0, 464, 102))
	await next_pressed


func _on_map_box(k: String) -> void:
	_sel = k
	_seen[k] = true
	for b in _boxes:
		_box_state(b, b == k, _seen.has(b))
	UI.clear(_panel)
	var info: Dictionary = d["map"]["info"][k]
	_panel.add_child(UI.place(UI.title(info["h"], Palette.HEAD, Palette.SLATE), Rect2(8, 4, 448, 16)))
	var keys: Dictionary = d["map"]["keys"]
	var y := 23.0
	var row_bottom := y
	var order := ["pic", "real", "fk", "note"]
	for i in order.size():
		var col := i % 2
		if col == 0 and i > 0:
			y = row_bottom + 4.0
		var x := 8.0 + col * 228.0
		_panel.add_child(UI.place(UI.label(str(keys[order[i]]).to_upper(), Palette.BODY, Palette.GREEN_DARK), Rect2(x, y, 220, 12)))
		row_bottom = maxf(row_bottom, _bottom(_para(_panel, info[order[i]], Vector2(x, y + 12), 220)))
	_set_status("%d of 4" % _seen.size())
	if _seen.size() == 4 and not _next.visible:
		var hint := UI.place(UI.label(d["map"]["done"], Palette.BODY, Palette.GREEN_DARK), Rect2(100, 245, 280, 12)) as Label
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stage.add_child(hint)
		_show_next()


## Act 1: one search, step by step, an envelope moving box to box.

func _steps_frame() -> void:
	var steps: Array = d["steps"]["list"]
	_frame("steps", d["steps"]["prompt"], "step 1 of %d" % steps.size())
	_whiteboard()
	_map(Vector2(12, 26))
	_envelope = Envelope.new()
	_envelope.size = Vector2(14, 10)
	_envelope.position = Vector2(12, 26) + MAP_STOP["device"] - Vector2(7, 5)
	_stage.add_child(_envelope)
	_panel = _rect(_stage, Rect2(8, 130, 464, 100), Palette.WHITE, Palette.SLATE, 1)
	_panel.name = "Step"
	var back := UI.button("Back", "normal", Vector2(70, 30))
	back.name = "StepBack"
	UI.place(back, Rect2(8, 237, 70, 30))
	back.pressed.connect(func() -> void: _show_step(_step - 1))
	_stage.add_child(back)
	var fwd := UI.button("Next step", "normal", Vector2(100, 30))
	fwd.name = "StepNext"
	UI.place(fwd, Rect2(84, 237, 100, 30))
	fwd.pressed.connect(func() -> void: _show_step((_step + 1) % steps.size()))
	_stage.add_child(fwd)
	_stepped_all = false
	_show_step(0)
	await next_pressed


func _show_step(i: int) -> void:
	var steps: Array = d["steps"]["list"]
	_step = clampi(i, 0, steps.size() - 1)
	var s: Dictionary = steps[_step]
	_set_status("step %d of %d" % [_step + 1, steps.size()])
	for k in _boxes:
		_box_state(k, k == s["at"])
	var to: Vector2 = Vector2(12, 26) + MAP_STOP[s["at"]] - _envelope.size / 2.0
	var tw := create_tween()
	tw.tween_property(_envelope, "position", to, 0.4).set_trans(Tween.TRANS_SINE)
	UI.clear(_panel)
	_panel.add_child(UI.place(UI.label(str(s["term"]).to_upper(), Palette.BODY, Palette.GREEN_DARK), Rect2(8, 5, 440, 12)))
	var t := _para(_panel, s["t"], Vector2(8, 19), 448, Palette.LABEL)
	_para(_panel, s["eg"], Vector2(8, _bottom(t) + 4), 448, Palette.BODY, Palette.SLATE_MID)
	(_stage.get_node("StepBack") as Button).disabled = _step == 0
	(_stage.get_node("StepNext") as Button).text = "Again" if _step == steps.size() - 1 else "Next step"
	if _step == steps.size() - 1 and not _stepped_all:
		_stepped_all = true
		_show_next()


## Act 2: four ways to put an app in front of people.

func _ways_frame() -> void:
	var w: Dictionary = d["ways"]
	_frame("ways", w["prompt"], w["status"])
	_seen = {}
	_sel = ""
	var plats: Array = d["platforms"]
	for i in plats.size():
		var p: Dictionary = plats[i]
		var b := UI.button("", "normal", Vector2(113, 50))
		b.name = "Way_" + p["id"]
		UI.place(b, Rect2(8 + i * 117, 26, 113, 50))
		_stage.add_child(b)
		var n := _para(b, p["n"], Vector2(5, 3), 104, Palette.LABEL)
		_para(b, p["rn"], Vector2(5, _bottom(n)), 104, Palette.BODY, Palette.SLATE_MID)
		b.pressed.connect(_on_way.bind(p["id"]))
		_boxes[p["id"]] = b
	_panel = _rect(_stage, Rect2(8, 80, 464, 120), Palette.WHITE, Palette.SLATE, 1)
	_panel.name = "Way"
	await dialogue.play(w["lines"])
	if _sel == "":
		_say(_panel, w["hint"], Rect2(0, 0, 464, 64))
	await next_pressed


func _on_way(id: String) -> void:
	_sel = id
	_seen[id] = true
	var p := PilotModel.platform(id)
	for k in d["platforms"]:
		var b: Button = _boxes[k["id"]]
		var on: bool = k["id"] == id
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, UI.box(PICKED_BG if on else Palette.WHITE, Palette.GREEN if on else (Palette.GREEN_DARK if _seen.has(k["id"]) else Palette.SLATE_LIGHT), 2 if on else 1))
	UI.clear(_panel)
	_panel.add_child(UI.place(UI.title(p["n"], 14, Palette.SLATE), Rect2(8, 5, 300, 18)))
	_panel.add_child(UI.place(UI.label(p["rn"], Palette.BODY, Palette.SLATE_MID), Rect2(8, 23, 448, 12)))
	var y := _bottom(_para(_panel, p["how"], Vector2(8, 38), 448, Palette.LABEL)) + 4.0
	y = _bottom(_para(_panel, "+ " + p["good"], Vector2(8, y), 448, Palette.LABEL, Palette.GREEN_DARK)) + 2.0
	_para(_panel, "− " + p["cost"], Vector2(8, y), 448, Palette.LABEL, Palette.RED)
	_set_status("%d of 4 seen" % _seen.size())
	if _seen.size() == d["platforms"].size():
		_show_next()


## Act 2: pick one, against Thursday's requirements. Only the web app and
## the installable web app go on; native and cross-platform say when
## they'd be right.

func _pick_frame() -> void:
	var k: Dictionary = d["pick"]
	_frame("pick", k["prompt"])
	_time(0.0)
	_left = _rect(_stage, Rect2(4, 24, 152, 210), Palette.PAPER, Palette.RULE, 1)
	_left.add_child(UI.place(UI.label(k["head"], Palette.BODY, Palette.SLATE_MID), Rect2(6, 3, 140, 12)))
	var plats: Array = d["platforms"]
	for i in plats.size():
		var p: Dictionary = plats[i]
		var b := UI.button(p["n"], "normal", Vector2(140, 30))
		b.name = "Pick_" + p["id"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_size_override("font_size", Palette.BODY)
		UI.place(b, Rect2(6, 17 + i * 33, 140, 30))
		_left.add_child(b)
		var h := UI.place(UI.label("%sh" % _num(float(p["h"])), Palette.BODY, Palette.SLATE_MID), Rect2(104, 8, 30, 12)) as Label
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(h)
		b.pressed.connect(_on_pick.bind(p["id"]))
		_boxes[p["id"]] = b
	_extra = UI.place(Control.new(), Rect2(6, 150, 140, 58))
	_left.add_child(_extra)
	_right = _rect(_stage, Rect2(160, 24, 316, 244), Palette.WHITE, Palette.RULE, 1)
	_pick_board("")
	await next_pressed
	_decide(1)


func _on_pick(id: String) -> void:
	_sel = id
	picks["platform"] = id
	if not picks["tried"].has(id):
		picks["tried"].append(id)
	var p := PilotModel.platform(id)
	for k in _boxes:
		UI.style(_boxes[k], "normal")
		if k == id:
			for s in ["normal", "hover", "pressed"]:
				(_boxes[k] as Button).add_theme_stylebox_override(s, UI.box(Palette.GREEN_PALE, Palette.GREEN, 2))
	_time(float(p["h"]))
	UI.clear(_extra)
	_say(_extra, d["pick"]["quips"][id], Rect2(0, 0, 140, 58))
	_pick_board(id)
	if PilotModel.passes(p, d["pick"]["reqs"], float(d["budget"]["time"])):
		# Under the four ways, leaving the board the full height.
		_show_next("NEXT", Rect2(4, 237, 152, 30))
	else:
		_hide_next()


func _pick_board(id: String) -> void:
	UI.clear(_right)
	var k: Dictionary = d["pick"]
	var p := PilotModel.platform(id) if id != "" else {}
	var head: String = k["needs"] + (" · " + p["n"] if id != "" else "")
	_right.add_child(UI.place(UI.label(head, Palette.BODY, Palette.SLATE_MID), Rect2(8, 3, 300, 12)))
	var y := _reqs(_right, k["reqs"], p.get("r", {}), Vector2(8, 18), 300, {})
	if id == "":
		return
	if PilotModel.passes(p, k["reqs"], float(d["budget"]["time"])):
		_notice(_right, k["right"], Vector2(6, y + 4), 304, "good", k["right_head"])
	else:
		_notice(_right, k["wrong"], Vector2(6, y + 4), 304, "bad")


## The requirements, each with yes, partly or no and its reason once an
## option is picked. Returns the bottom.
func _reqs(parent: Control, reqs: Array, r: Dictionary, at: Vector2, w: float, fill: Dictionary) -> float:
	var y := at.y
	for q in reqs:
		var tick := Tick.new()
		var res: Array = r.get(q["id"], [])
		tick.kind = res[0] if not res.is_empty() else ""
		UI.place(tick, Rect2(at.x, y + 1, 11, 11))
		parent.add_child(tick)
		var text: String = _fill(q["t"], fill)
		if q.get("later", false):
			text += " " + d["pick"]["later"]
		var l := _para(parent, text, Vector2(at.x + 16, y), w - 16)
		y = _bottom(l)
		if not res.is_empty():
			y = _bottom(_para(parent, _fill(res[1], fill), Vector2(at.x + 16, y), w - 16, Palette.BODY, Palette.SLATE_MID))
		y += 3.0
	return y


static func _fill(text: String, fill: Dictionary) -> String:
	for key in fill:
		text = text.replace("{%s}" % key, str(fill[key]))
	return text


## Act 3: Aleister's no-server plan, and the key in the app's code.

func _noserver_frame() -> void:
	var n: Dictionary = d["noserver"]
	_frame("noserver", n["prompt"])
	_whiteboard()
	_map(Vector2(12, 26), true)
	await dialogue.play(n["lines"])
	var open := UI.button(n["button"], "primary", Vector2(260, 30))
	open.name = "OpenCode"
	UI.place(open, Rect2(110, 196, 260, 30))
	_stage.add_child(open)
	await open.pressed
	_stage.remove_child(open)
	open.queue_free()
	_box_state("device", true)
	var code := _rect(_stage, Rect2(12, 26, 300, 126), CODE_BG)
	code.name = "Code"
	var lines: Array = n["code"]
	for i in lines.size():
		var y := 7.0 + i * 12.5
		if i == int(n["key_line"]):
			var hl := UI.place(ColorRect.new(), Rect2(4, y - 1, 292, 13)) as ColorRect
			hl.color = Color(Palette.RED, 0.45)
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			code.add_child(hl)
		var color := CODE_DIM if str(lines[i]).begins_with("//") else (Palette.WHITE if i == int(n["key_line"]) else CODE_FG)
		code.add_child(UI.place(UI.label(lines[i], Palette.BODY, color), Rect2(8, y - 1, 288, 13)))
	await dialogue.play(n["after"])
	_stamp(_stage, n["stamp"], Rect2(8, 158, 464, 74))
	_show_next()
	await next_pressed


## Act 3: the sort. Tap a piece, then where it lives; a wrong place shows
## what would happen there, in red, until it's taken back.

func _sort_frame() -> void:
	var s: Dictionary = d["sort"]
	_frame("sort", s["prompt"], "0 of %d %s" % [s["pieces"].size(), s["placed"]])
	_armed = ""
	_placed = {}
	_last = ""
	_zones = {}
	var zones: Array = s["zones"]
	for i in zones.size():
		var z: Dictionary = zones[i]
		var b := UI.button("", "normal", Vector2(154, 148))
		b.name = "Zone_" + z["id"]
		UI.place(b, Rect2(4 + i * 158, 121, 154, 148))
		_stage.add_child(b)
		b.add_child(UI.place(UI.label(z["h"], Palette.LABEL, Palette.SLATE), Rect2(6, 2, 142, 14)))
		b.add_child(UI.place(UI.label(z["s"], Palette.BODY, Palette.SLATE_MID), Rect2(6, 15, 142, 12)))
		b.pressed.connect(_on_zone.bind(z["id"]))
		_zones[z["id"]] = b
	# Above the zones, so a placed piece takes its own tap.
	_panel = UI.place(Control.new(), Rect2(0, 0, 480, 270))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_panel)
	_sort_draw()
	await next_pressed
	_decide(2)


func _piece(id: String) -> Dictionary:
	for p in d["sort"]["pieces"]:
		if p["id"] == id:
			return p
	return {}


func _misplaced() -> String:
	for id in _placed:
		if _placed[id] != _piece(id)["z"]:
			return id
	return ""


func _on_piece(id: String) -> void:
	_armed = "" if _armed == id else id
	_sort_draw()


func _on_zone(z: String) -> void:
	if _armed == "":
		return
	# One piece in the wrong place at a time: a second goes back first.
	var wrong := _misplaced()
	if wrong != "" and wrong != _armed:
		_placed.erase(wrong)
	_placed[_armed] = z
	if z != _piece(_armed)["z"]:
		picks["misplaced"] += 1
	_last = _armed
	_armed = ""
	_sort_draw()


func _on_placed(id: String) -> void:
	# With a piece in hand, a tap on a placed one means its zone.
	if _armed != "" and _armed != id:
		_on_zone(_placed[id])
		return
	if _placed[id] != _piece(id)["z"]:
		_placed.erase(id)
		_armed = id
		_last = ""
	else:
		_last = id
	_sort_draw()


func _sort_draw() -> void:
	UI.clear(_panel)
	var s: Dictionary = d["sort"]
	var pieces: Array = s["pieces"]
	for i in pieces.size():
		var p: Dictionary = pieces[i]
		if _placed.has(p["id"]):
			continue
		var b := UI.button("", "normal", Vector2(113, 30))
		b.name = "Piece_" + p["id"]
		UI.place(b, Rect2(8 + (i % 4) * 117, 24 + (i / 4) * 33, 113, 30))
		if _armed == p["id"]:
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, UI.box(Palette.AMBER, Color("#b87318"), 2))
		else:
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, UI.box(Palette.WHITE, Palette.SLATE, 1))
		_panel.add_child(b)
		var l := _para(b, p["t"], Vector2(5, 0), 103)
		l.position.y = floorf((30.0 - l.size.y) / 2.0)
		b.pressed.connect(_on_piece.bind(p["id"]))
	# Each zone's pieces, red when they don't belong.
	for z in _zones:
		var zb: Button = _zones[z]
		var armed := _armed != ""
		for st in ["normal", "hover", "pressed"]:
			zb.add_theme_stylebox_override(st, UI.box(Palette.WHITE, Palette.GREEN if armed else Palette.SLATE_LIGHT, 2 if armed else 1, 3))
		var k := 0
		for p in pieces:
			if _placed.get(p["id"], "") != z:
				continue
			var ok: bool = p["z"] == z
			var b := UI.button(p["t"], "normal", Vector2(142, 30))
			b.name = "Placed_" + p["id"]
			b.add_theme_font_size_override("font_size", Palette.BODY)
			b.clip_text = true
			for st in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(st, UI.box(Palette.GREEN_PALE if ok else RISK_BG, Palette.GREEN if ok else Palette.RED, 1))
			b.position = zb.position + Vector2(6, 27 + k * 30)
			b.size = Vector2(142, 30)
			b.pressed.connect(_on_placed.bind(p["id"]))
			_panel.add_child(b)
			k += 1
	var placed_ok := 0
	for id in _placed:
		if _placed[id] == _piece(id)["z"]:
			placed_ok += 1
	_set_status("%d of %d %s" % [_placed.size(), pieces.size(), s["placed"]])
	var done := placed_ok == pieces.size()
	if done:
		_notice(_panel, s["done"], Vector2(8, 26), 370, "good")
		_show_next("NEXT", Rect2(386, 24, 90, 30))
	else:
		_hide_next()
	if _last != "" and _placed.has(_last):
		var lp := _piece(_last)
		var ok: bool = _placed[_last] == lp["z"]
		var text: String = "%s: %s" % [lp["t"], lp["why"][_placed[_last]]]
		if not ok:
			text += " " + s["take_back"]
		_notice(_panel, text, Vector2(8, 91) if not done else Vector2(8, 62), 464, "good" if ok else "bad")


## Act 4: build the backend, or rent it, in the hours left.

func _backend_frame() -> void:
	var k: Dictionary = d["backend"]
	_frame("backend", k["prompt"])
	_sel = ""
	_time(_spent())
	_left = UI.place(Control.new(), Rect2(4, 24, 176, 244))
	_stage.add_child(_left)
	_right = _rect(_stage, Rect2(184, 24, 292, 244), Palette.WHITE, Palette.RULE, 1)
	_backend_draw()
	await next_pressed
	_decide(3)


func _spent() -> float:
	return float(PilotModel.platform(picks["platform"]).get("h", d["backend"]["spent"]))


func _left_hours() -> float:
	return float(d["budget"]["time"]) - _spent()


func _on_backend(id: String) -> void:
	_sel = id
	picks["backend"] = id
	if not picks["tried_backend"].has(id):
		picks["tried_backend"].append(id)
	_backend_draw()


func _backend_draw() -> void:
	var k: Dictionary = d["backend"]
	UI.clear(_left)
	var y := 0.0
	var b_sel: Dictionary = {}
	for o in k["options"]:
		var on: bool = o["id"] == _sel
		if on:
			b_sel = o
		var b := UI.button("", "normal", Vector2(176, 30))
		b.name = "Back_" + o["id"]
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.box(PICKED_BG if on else Palette.WHITE, Palette.GREEN if on else Palette.RULE, 2 if on else 1))
		_left.add_child(b)
		b.position = Vector2(0, y)
		b.size = Vector2(176, 30)
		var n := _para(b, "%s · %sh" % [o["n"], _num(float(o["h"]))], Vector2(6, 3), 164, Palette.BODY, Palette.SLATE)
		var bottom := _bottom(_para(b, o["rn"], Vector2(6, _bottom(n)), 164, Palette.BODY, Palette.SLATE_MID))
		if on:
			bottom = _bottom(_para(b, "+ " + o["good"], Vector2(6, bottom + 2), 164, Palette.BODY, Palette.GREEN_DARK))
			bottom = _bottom(_para(b, "− " + o["cost"], Vector2(6, bottom + 1), 164, Palette.BODY, Palette.RED))
		b.size.y = maxf(30.0, bottom + 4.0)
		b.pressed.connect(_on_backend.bind(o["id"]))
		y += b.size.y + 3.0
	_time(_spent() + float(b_sel.get("h", 0.0)))
	UI.clear(_right)
	var fill := {"left": _num(_left_hours())}
	var head: String = k["needs"] + (" · " + b_sel["n"] if not b_sel.is_empty() else "")
	var h := _para(_right, head, Vector2(8, 3), 276, Palette.BODY, Palette.SLATE_MID)
	var ry := _reqs(_right, k["reqs"], b_sel.get("r", {}), Vector2(8, _bottom(h) + 2), 276, fill)
	if b_sel.is_empty():
		_say(_right, k["quip"], Rect2(4, ry + 4, 284, 60))
		_hide_next()
	elif PilotModel.passes(b_sel, k["reqs"], _left_hours()):
		_notice(_right, k["right"], Vector2(6, ry + 3), 280, "good", k["right_head"])
		_show_next("NEXT", Rect2(4, 237, 176, 30))
	else:
		_notice(_right, k["wrong"], Vector2(6, ry + 3), 280, "bad")
		_hide_next()


## Act 4: read Aleister's tech stack, line by line; catch NEXT_PUBLIC_.
## The fix replaces the old episode's merge.

func _plan_frame() -> void:
	var k: Dictionary = d["plan"]
	_open = {}
	_cur = -1
	picks["fixed"] = false
	_frame("plan", k["prompt"], "0 of %d %s" % [k["lines"].size(), k["read"]])
	_left = UI.place(Control.new(), Rect2(6, 22, 280, 214))
	_stage.add_child(_left)
	_right = UI.place(Control.new(), Rect2(290, 22, 186, 214))
	_stage.add_child(_right)
	_plan_draw()
	_show_next(k["merge"], Rect2(386, 237, 90, 30), false)
	await next_pressed
	Sound.sting("merge")
	_decide(4)


func _plan_text(line: Dictionary, key: String) -> String:
	var v: Variant = line[key]
	if v is Dictionary:
		return v.get(picks["platform"], v.values()[0])
	return str(v)


func _on_line(i: int) -> void:
	_open[i] = true
	_cur = i
	_plan_draw()


func _on_fix() -> void:
	picks["fixed"] = true
	_plan_draw()
	await dialogue.play([d["plan"]["fixed"]])


func _plan_draw() -> void:
	var k: Dictionary = d["plan"]
	var lines: Array = k["lines"]
	var fixed: bool = picks["fixed"]
	UI.clear(_left)
	_left.add_child(UI.place(UI.title(k["head"], Palette.BODY, Palette.SLATE_MID), Rect2(2, 3, 260, 12)))
	for i in lines.size():
		var line: Dictionary = lines[i]
		var bad: bool = line.get("bad", false)
		var b := UI.button("", "normal", Vector2(214, 34))
		b.name = "Line_%d" % i
		var bg := Palette.PAPER
		var border := Palette.RULE
		if _cur == i:
			bg = Palette.GREEN_PALE
			border = Palette.GREEN
		if bad and _open.has(i) and not fixed:
			bg = RISK_BG
			border = Palette.RED
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.box(bg, border, 2 if _cur == i else 1))
		UI.place(b, Rect2(0, 18 + i * 38, 214, 34))
		_left.add_child(b)
		var text: String = line["fixed"] if bad and fixed else _plan_text(line, "c")
		var l := _para(b, text, Vector2(5, 0), 204)
		l.position.y = floorf((34.0 - l.size.y) / 2.0)
		b.pressed.connect(_on_line.bind(i))
		if _open.has(i):
			var tag: String = (line["fixed_box"] if fixed else "?!") if bad else line["box"]
			var t := UI.place(UI.label(tag, Palette.BODY, Palette.RED if bad and not fixed else Palette.GREEN_DARK), Rect2(218, 18 + i * 38 + 11, 60, 12))
			t.name = "Tag_%d" % i
			_left.add_child(t)
	_set_status("%d of %d %s" % [_open.size(), lines.size(), k["read"]])
	UI.clear(_right)
	var y := 0.0
	var all_read: bool = _open.size() == lines.size()
	# Every line placed and the key fixed: the stamp, above the line in hand.
	if fixed and all_read:
		y = _bottom(_stamp(_right, k["stamp"], Rect2(0, 0, 186, 60))) + 4.0
	if _cur < 0:
		_say(_right, k["intro"], Rect2(0, y, 186, 74))
	else:
		var line: Dictionary = lines[_cur]
		var bad: bool = line.get("bad", false)
		var p := _rect(_right, Rect2(0, y, 186, 30), Palette.WHITE, Palette.SLATE, 1)
		p.name = "Detail"
		var head: String = line["look"] if bad else line["box"]
		p.add_child(UI.place(UI.label(head, Palette.LABEL, Palette.RED if bad and not fixed else Palette.SLATE), Rect2(6, 3, 174, 14)))
		var body := _para(p, _plan_text(line, "plain"), Vector2(6, 17), 174)
		p.size.y = _bottom(body) + 4.0
		y += p.size.y + 4.0
		if bad and not fixed:
			var fix := UI.button("", "primary", Vector2(186, 34))
			fix.name = "TellAleister"
			UI.place(fix, Rect2(0, y, 186, 34))
			_right.add_child(fix)
			var fl := _para(fix, k["fix_button"], Vector2(6, 0), 174, Palette.BODY, Palette.WHITE)
			fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			fl.position.y = floorf((34.0 - fl.size.y) / 2.0)
			fix.pressed.connect(_on_fix)
	_next.disabled = not (fixed and all_read)


## Act 5: Thursday. Two hundred diners by device, the 4:40 iPhone bug, and
## how fast the fix lands on the platform the player picked.

func _thursday_frame() -> void:
	var t: Dictionary = d["thursday"]
	_frame("thursday", _clock(0) + " · " + t["title"])
	Sound.music("live")
	_testers = PilotModel.testers()
	_tiles = {}
	var y := 25.0
	for dev in t["devices"]:
		_stage.add_child(UI.place(UI.label("%s · %d" % [dev["n"], dev["count"]], Palette.BODY, Palette.SLATE), Rect2(8, y, 240, 12)))
		y += 13.0
		var list: Array = []
		var count := int(dev["count"])
		for i in count:
			var r := UI.place(ColorRect.new(), Rect2(8 + (i % 24) * 10, y + (i / 24) * 10, 8, 8)) as ColorRect
			r.color = Palette.RULE
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stage.add_child(r)
			list.append(r)
		_tiles[dev["id"]] = list
		y += ceilf(count / 24.0) * 10.0 + 4.0
	# The legend.
	var lg: Dictionary = t["legend"]
	var colors := {"fit": Palette.GREEN, "near": Palette.AMBER, "wrong": Palette.RED, "none": Palette.SLATE_MID}
	var keys := ["fit", "near", "wrong", "none"]
	for i in keys.size():
		var at := Vector2(8 + (i % 2) * 120, y + 2 + (i / 2) * 13)
		var sq := UI.place(ColorRect.new(), Rect2(at + Vector2(0, 2), Vector2(8, 8))) as ColorRect
		sq.color = colors[keys[i]]
		_stage.add_child(sq)
		_stage.add_child(UI.place(UI.label(lg[keys[i]], Palette.BODY, Palette.SLATE_MID), Rect2(at + Vector2(12, -1), Vector2(104, 12))))
	_right = UI.place(Control.new(), Rect2(256, 24, 220, 210))
	_stage.add_child(_right)

	var pause := UI.button("Pause", "normal", Vector2(64, 30))
	pause.name = "Pause"
	UI.place(pause, Rect2(4, 237, 64, 30))
	pause.pressed.connect(_on_pause)
	_stage.add_child(pause)
	var mine := UI.button("%s: %s" % [t["mine"], PilotModel.platform(picks["platform"])["n"]], "normal", Vector2(170, 30))
	mine.name = "Build_mine"
	mine.add_theme_font_size_override("font_size", Palette.BODY)
	UI.place(mine, Rect2(72, 237, 172, 30))
	mine.pressed.connect(_start_run.bind(picks["platform"]))
	_stage.add_child(mine)
	var native := UI.button(t["native"], "normal", Vector2(112, 30))
	native.name = "Build_native"
	native.add_theme_font_size_override("font_size", Palette.BODY)
	UI.place(native, Rect2(248, 237, 112, 30))
	native.pressed.connect(_start_run.bind("native"))
	_stage.add_child(native)
	_ran_mine = false
	_build = picks["platform"]
	_minute = 0.0
	_thursday_draw()
	await dialogue.play([t["intro"]])
	_start_run(picks["platform"])
	await next_pressed
	_running = false
	result = PilotModel.thursday(picks["platform"])
	Sound.music("plan")


func _clock(m: int) -> String:
	var c: Array = d["thursday"]["clock"]
	var minutes := int(c[0]) * 60 + int(c[1]) + m
	var h := (minutes / 60) % 24
	return "Thu %d:%02d%s" % [((h + 11) % 12) + 1, minutes % 60, "pm" if h >= 12 else "am"]


func _start_run(build: String) -> void:
	_build = build
	_minute = 0.0
	_running = true
	_paused = false
	(_stage.get_node("Pause") as Button).text = "Pause"
	for id in ["mine", "native"]:
		var b: Button = _stage.get_node("Build_" + id)
		var on: bool = (id == "native") == (build == "native")
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.box(Palette.GREEN_PALE if on else Palette.WHITE, Palette.GREEN if on else Palette.SLATE_LIGHT, 2 if on else 1))
	_thursday_draw()


func _on_pause() -> void:
	var total := float(d["thursday"]["minutes"])
	if _minute >= total:
		_start_run(_build)
		return
	_paused = not _paused
	(_stage.get_node("Pause") as Button).text = "Play" if _paused else "Pause"


func _process(delta: float) -> void:
	if phase != "thursday" or not _running or _paused or dialogue.visible:
		return
	var total := float(d["thursday"]["minutes"])
	if _minute >= total:
		return
	if test_minutes_per_frame > 0:
		_minute = minf(total, _minute + test_minutes_per_frame)
	else:
		_minute = minf(total, _minute + delta * MINUTES_PER_SECOND)
	_thursday_draw()
	if _minute >= total:
		(_stage.get_node("Pause") as Button).text = d["thursday"]["again"]
		if _build == picks["platform"] and not _ran_mine:
			_ran_mine = true
			_show_next()


func _thursday_draw() -> void:
	var t: Dictionary = d["thursday"]
	var m := int(_minute)
	_set_top(_clock(m) + " · " + t["title"], "")
	var colors := {"fit": Palette.GREEN, "near": Palette.AMBER, "wrong": Palette.RED, "none": Palette.SLATE_MID}
	for dev in t["devices"]:
		var list: Array = _testers[dev["id"]]
		var tiles: Array = _tiles[dev["id"]]
		for i in list.size():
			var who: Dictionary = list[i]
			(tiles[i] as ColorRect).color = colors[PilotModel.outcome(_build, dev["id"], who)] if int(who["at"]) < m else Palette.RULE
	var c := PilotModel.thursday(_build, m)
	var pct := roundi(100.0 * c["share"])
	UI.clear(_right)
	_right.add_child(UI.place(UI.label(t["meter"], Palette.LABEL, Palette.SLATE), Rect2(0, 0, 170, 14)))
	var big := UI.place(UI.label("%d%%" % pct, Palette.HEAD, Palette.SLATE), Rect2(168, -2, 52, 16)) as Label
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	big.name = "Share"
	_right.add_child(big)
	var track := UI.place(ColorRect.new(), Rect2(0, 17, 220, 10)) as ColorRect
	track.color = Palette.RULE
	_right.add_child(track)
	var fill := UI.place(ColorRect.new(), Rect2(0, 17, 220.0 * c["share"], 10)) as ColorRect
	fill.color = Palette.GREEN if c["share"] >= float(d["goal_share"]) else Palette.RED
	_right.add_child(fill)
	var goal := UI.place(ColorRect.new(), Rect2(220.0 * float(d["goal_share"]) - 1.0, 15, 2, 14)) as ColorRect
	goal.color = Palette.SLATE
	_right.add_child(goal)
	_right.add_child(UI.place(UI.label(t["goal"], Palette.BODY, Palette.SLATE_MID), Rect2(0, 30, 100, 12)))
	var so := UI.label(str(t["so_far"]) % int(c["n"]), Palette.BODY, Palette.SLATE_MID)
	# Clipped before sizing, or its default-size minimum pushes it off the edge.
	so.clip_text = true
	UI.place(so, Rect2(100, 30, 120, 12))
	so.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right.add_child(so)
	var y := 48.0
	for f in PilotModel.feed(_build, m):
		y = _bottom(_notice(_right, f["t"], Vector2(0, y), 220, f["kind"])) + 4.0


## Act 5: Gerard's decision record, built from what the player picked.

func _postmortem_frame() -> void:
	var k: Dictionary = d["postmortem"]
	_frame("postmortem", k["prompt"], k["when"])
	earned = PilotModel.marks(picks["platform"], picks["tried"].has("native"))
	var plat := PilotModel.platform(picks["platform"])
	var chips := [
		"Found a place: %d%% (goal %d%%)" % [roundi(result["share"] * 100.0), roundi(float(d["goal_share"]) * 100.0)],
		"All 3 devices" if plat["laptops"] else "Phones only",
		("iPhone bug fixed in %d min" % int(plat["fix"])) if int(plat["fix"]) > 0 else "iPhone fix in review",
		"AI bill %s" % Palette.money(float(k["bill"])),
	]
	var x := 6.0
	for c in chips:
		var w := ceilf(Palette.body().get_string_size(c, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x) + 12.0
		var p := _rect(_stage, Rect2(x, 24, w, 16), Palette.GREEN_PALE, Palette.GREEN, 1)
		p.add_child(UI.place(UI.label(c, Palette.BODY, Palette.GREEN_DARK), Rect2(6, 1, w - 8, 12)))
		x += w + 4.0
	# The table: one row per decision.
	var widths := [72.0, 124.0, 104.0, 78.0, 86.0]
	var rows := [k["platform_rows"][picks["platform"]]]
	rows.append_array(k["rows"])
	var table := _rect(_stage, Rect2(6, 44, 468, 188), Palette.WHITE, Palette.RULE, 1)
	table.name = "Record"
	var head := _rect(table, Rect2(1, 1, 466, 15), Palette.PAPER)
	var cx := 4.0
	for i in widths.size():
		head.add_child(UI.place(UI.label(k["heads"][i], Palette.BODY, Palette.SLATE_MID), Rect2(cx, 1, widths[i] - 4, 12)))
		cx += widths[i]
	var y := 18.0
	for r in rows:
		cx = 4.0
		var bottom := y
		for i in widths.size():
			var l := _para(table, r[i], Vector2(cx, y), widths[i] - 6, Palette.BODY, Palette.SLATE if i > 0 else Palette.GREEN_DARK)
			bottom = maxf(bottom, _bottom(l))
			cx += widths[i]
		y = bottom + 3.0
		var rule := UI.place(ColorRect.new(), Rect2(2, y, 464, 1)) as ColorRect
		rule.color = Palette.RULE
		table.add_child(rule)
		y += 3.0
	table.size.y = y + 1.0
	var word := _rect(_stage, Rect2(6, 236, 374, 32), Palette.PAPER, Palette.SLATE_LIGHT, 1)
	word.name = "Word"
	_para(word, k["word"], Vector2(6, 3), 362)
	_show_next()
	await next_pressed


## Walter's cheque, the runway, and the three marks.
func _record_frame() -> void:
	var k: Dictionary = d["postmortem"]
	_frame("record", k["prompt"], k["when"])
	Sound.sting("postmortem")
	var budget: Dictionary = d["budget"]
	var runway := float(budget["bank"]) / float(budget["burn"])
	var p := _rect(_stage, Rect2(40, 28, 400, 166), Palette.WHITE, Palette.GREEN, 2)
	p.name = "Runway"
	p.add_child(UI.place(UI.title("RUNWAY: %.1f MONTHS" % runway, 20, Palette.GREEN_DARK), Rect2(14, 10, 372, 26)))
	var y := _bottom(_para(p, k["runway"], Vector2(14, 40), 372, Palette.LABEL)) + 8.0
	for m in ["live", "lean", "ulrich"]:
		var got: bool = earned[m]
		var tick := Tick.new()
		tick.kind = "y" if got else "n"
		UI.place(tick, Rect2(14, y + 1, 11, 11))
		p.add_child(tick)
		p.add_child(UI.place(UI.label(k["marks"][m][0 if got else 1], Palette.LABEL, Palette.SLATE if got else Palette.SLATE_MID), Rect2(30, y - 1, 350, 14)))
		y += 18.0
	p.size.y = y + 6.0
	Progress.record(int(d["id"]), runway, earned)
	await dialogue.play([k["cheque"]])
	_show_next()
	await next_pressed


## The cliffhanger, and the cut to black.
func _cliffhanger() -> void:
	var c: Dictionary = d["cliffhanger"]
	phase = "cliffhanger"
	UI.clear(_stage)
	_hide_next()
	backdrop.place = c["backdrop"]
	backdrop.visible = true
	await dialogue.play(c["lines"], c["place"])
	var n: Dictionary = c["next"]
	await card.next_card(n["top"], n["title"], n["sub"], 150)
	backdrop.visible = false


class Wires extends Control:
	var segs: Array = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for s in segs:
			if s[3]:
				draw_dashed_line(s[0], s[1], s[2], 2.0, 5.0)
			else:
				draw_line(s[0], s[1], s[2], 2.0)


## Yes, partly or no: a coloured square with a tick, a dash or a cross.
class Tick extends Control:
	var kind: String = ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Palette.SLATE_LIGHT
		match kind:
			"y": c = Palette.GREEN
			"p": c = Palette.AMBER
			"n": c = Palette.RED
		draw_rect(Rect2(Vector2.ZERO, size), c)
		var w := Palette.WHITE
		match kind:
			"y": draw_polyline(PackedVector2Array([Vector2(2.5, 5.5), Vector2(4.5, 8), Vector2(8.5, 3)]), w, 1.5)
			"p": draw_line(Vector2(2.5, 5.5), Vector2(8.5, 5.5), w, 1.5)
			"n":
				draw_line(Vector2(3, 3), Vector2(8, 8), w, 1.5)
				draw_line(Vector2(8, 3), Vector2(3, 8), w, 1.5)


## The request as an envelope on the map.
class Envelope extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2(0, 2), size), Color(0.07, 0.08, 0.09, 0.2))
		draw_rect(Rect2(Vector2.ZERO, size), Palette.AMBER)
		draw_polyline(PackedVector2Array([Vector2(1, 1), Vector2(size.x / 2.0, size.y * 0.6), Vector2(size.x - 1, 1)]), Color("#b87318"), 1.0)
