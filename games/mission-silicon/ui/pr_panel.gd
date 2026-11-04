class_name PrPanel
extends Control

## The right-hand panel while planning. It shows the pull request's cards
## (tap one to read it, tap KEEP/CUT to decide), a card's detail with the two
## engineers' takes, a box's dials, or a short text (the staging summary).
## Nothing here says whether a choice is right: only the live moment does.

signal changed
signal ask_pressed(id: String)
## A card, the questions or a box was opened (the first episode's
## tutorial says a line the first time each is).
signal opened(what: String)

const TTL_NAMES := {0: "off", 10: "10 sec", 30: "30 sec", 60: "1 min", 600: "10 min", 3600: "1 hour"}

var plan: Plan
var ep: Dictionary
var _body: VBoxContainer
var _scroll: ScrollContainer
var _header: Label
var _back: Button
var mode: String = "list"


func _ready() -> void:
	var bg := UI.place(UI.panel(Palette.PAPER, Palette.RULE, 1), Rect2(Vector2.ZERO, size))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_back = UI.button("<", "quiet", Vector2(30, 30))
	_back.name = "Back"
	UI.place(_back, Rect2(0, 0, 30, 30))
	_back.pressed.connect(show_list)
	add_child(_back)
	_header = UI.place(UI.label("", Palette.LABEL, Palette.SLATE, true), Rect2(4, 2, size.x - 8, 28)) as Label
	_header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_header)
	_scroll = ScrollContainer.new()
	UI.place(_scroll, Rect2(2, 30, size.x - 4, size.y - 32))
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = UI.vbox(2)
	_body.custom_minimum_size.x = size.x - 10
	_scroll.add_child(_body)


func setup(p: Plan) -> void:
	plan = p
	ep = p.ep
	show_list()


func _start(title: String, back: bool) -> void:
	UI.clear(_body)
	_scroll.scroll_vertical = 0
	_back.visible = back
	_header.text = title
	_header.position.x = 32.0 if back else 4.0
	_header.size.x = size.x - _header.position.x - 4.0


func show_list() -> void:
	mode = "list"
	_start(ep["pr"]["title"], false)
	for c in plan.visible_cards():
		var row := UI.hbox(2)
		var open := UI.button("", "normal", Vector2(0, Palette.TAP))
		open.name = "Card_" + c["id"]
		open.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		open.alignment = HORIZONTAL_ALIGNMENT_LEFT
		open.clip_text = true
		var tag := ""
		if c.get("by", "aleister") != "aleister":
			tag = Season.person(c["by"])["name"] + ": "
		elif c.has("from_ask"):
			tag = "+ "
		open.text = "%s%s  %s" % [tag, c["label"], _hours(c.get("time", 0))]
		open.pressed.connect(show_card.bind(c["id"]))
		row.add_child(open)
		row.add_child(_keep_button(c["id"], Vector2(46, Palette.TAP)))
		_body.add_child(row)


## The questions to put to Aleister, worded as the curriculum's "What to
## tell your AI" lines. Asked ones stay, greyed, to be heard again.
func show_asks() -> void:
	mode = "asks"
	_start("Ask Aleister", true)
	opened.emit("asks")
	for a in ep.get("asks", []):
		var b := UI.button(a["text"], "cut" if plan.asked.has(a["id"]) else "normal", Vector2(size.x - 14, Palette.TAP))
		b.name = "Ask_" + a["id"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", Palette.BODY)
		b.pressed.connect(func() -> void: ask_pressed.emit(a["id"]))
		_body.add_child(b)


func _hours(t: Variant) -> String:
	var v := float(t)
	return ("%dh" % int(v)) if is_equal_approx(v, roundf(v)) else ("%.1fh" % v)


func _keep_button(id: String, min_size: Vector2) -> Button:
	var on: bool = plan.kept.get(id, false)
	var b := UI.button("KEEP" if on else "CUT", "primary" if on else "cut", min_size)
	b.name = "Keep_" + id
	b.pressed.connect(func() -> void:
		plan.kept[id] = not plan.kept.get(id, false)
		changed.emit()
		if mode == "list":
			show_list()
		else:
			show_card(id))
	return b


func show_card(id: String) -> void:
	mode = "card"
	opened.emit("card")
	var c := plan.card(id)
	_start(c["label"], true)
	_body.add_child(UI.label(c["term"], Palette.BODY, Palette.GREEN_DARK))
	var desc := UI.label(c["plain"], Palette.BODY, Palette.SLATE, true)
	desc.custom_minimum_size.x = size.x - 14
	_body.add_child(desc)
	var with := plan.copy()
	with.kept[id] = true
	var without := plan.copy()
	without.kept[id] = false
	var delta := Sim.monthly_of(with.config()) - Sim.monthly_of(without.config())
	var cost := "%s to build" % _hours(c.get("time", 0))
	if absf(delta) > 0.5:
		cost += ", %s%s a month" % ["+" if delta > 0 else "", Palette.money(delta)]
	_body.add_child(UI.label(cost, Palette.BODY, Palette.SLATE_MID))
	for need in c.get("needs", []):
		if not plan.active(need):
			_body.add_child(UI.label("Needs: " + plan.card(need)["label"], Palette.BODY, Palette.AMBER))
	for take in c.get("takes", []):
		var row := UI.hbox(4)
		var face := Portrait.new(take["who"])
		face.custom_minimum_size = Vector2(24, 24)
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
		var said := UI.label("%s: %s" % [Season.person(take["who"])["name"], take["say"]], Palette.BODY, Palette.SLATE, true)
		said.custom_minimum_size.x = size.x - 44
		row.add_child(said)
		_body.add_child(row)
	_body.add_child(_keep_button(id, Vector2(size.x - 14, Palette.TAP)))


func show_box(id: String) -> void:
	mode = "box"
	opened.emit("box")
	var piece_id := _piece_for(id)
	var piece: Dictionary = Season.pieces()["pieces"].get(piece_id, {})
	_start(piece.get("label", id), true)
	if piece.has("term"):
		_body.add_child(UI.label(piece["term"], Palette.BODY, Palette.GREEN_DARK))
	if piece.has("plain"):
		var desc := UI.label(piece["plain"], Palette.BODY, Palette.SLATE, true)
		desc.custom_minimum_size.x = size.x - 14
		_body.add_child(desc)
	var any := false
	for d in ep.get("dials", []):
		if d.get("box", "") != id:
			continue
		if not plan.dial_available(d["id"]):
			continue
		any = true
		_body.add_child(_stepper(d))
	if not any and (id == "app" or id == "cache"):
		_body.add_child(UI.label("Nothing to set here yet.", Palette.BODY, Palette.SLATE_MID))


func _piece_for(id: String) -> String:
	match id:
		"app":
			var cfg := plan.config()
			if cfg.get("mvp", false):
				# Episode 7's launch moves the MVP onto a platform host.
				return "platform" if cfg["host"] == "cloud" and cfg.has("deploy") else "mvp"
			if cfg["host"] == "cloud":
				return "app_server"
			return "prototype" if cfg.has("concierge") else "garage_server"
		"phones":
			return "visitors" if plan.config().has("page") and not plan.config().has("front") else "phones"
		"page":
			return "landing"
		"web":
			return "backend"
		"db":
			return "bookings_db" if plan.config().has("store") and plan.config()["host"] != "cloud" else "postgres"
		"copy":
			return "live_copy"
		"login":
			return "auth_service" if str(plan.config().get("auth", "home")) == "service" else "home_login"
		"cache":
			return "redis"
		"model":
			return "model_api"
		"lb":
			return "load_balancer"
		"dash":
			return "dashboard"
		"bot":
			return "scraper"
		"pay":
			return "payments"
		"pkg":
			return "package"
		"agent":
			return "agent"
		"index":
			return "index"
	return id


func _stepper(d: Dictionary) -> Control:
	var col := UI.vbox(0)
	var what: String = d["label"]
	if d["id"].ends_with(".ttl"):
		what += ": keep for"
	elif d["id"].ends_with(".scope"):
		what += ": whose copy"
	col.add_child(UI.label(what, Palette.BODY, Palette.SLATE_MID))
	var row := UI.hbox(2)
	var dec := UI.button("<", "normal", Vector2(30, 30))
	dec.name = "Dec_" + d["id"].replace(".", "_")
	dec.pressed.connect(_step.bind(d["id"], -1))
	row.add_child(dec)
	var value := UI.label(_value_name(d, plan.dial_value(d["id"])), Palette.LABEL, Palette.SLATE)
	value.name = "Value_" + d["id"].replace(".", "_")
	value.custom_minimum_size = Vector2(size.x - 84, 30)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(value)
	var inc := UI.button(">", "normal", Vector2(30, 30))
	inc.name = "Inc_" + d["id"].replace(".", "_")
	inc.pressed.connect(_step.bind(d["id"], 1))
	row.add_child(inc)
	col.add_child(row)
	return col


func _value_name(d: Dictionary, v: Variant) -> String:
	if d["id"].ends_with(".ttl"):
		return TTL_NAMES.get(int(v), str(v))
	if d.has("names"):
		# JSON numbers arrive as floats: 100.0 is named by "100".
		var key := str(int(v)) if v is float and is_equal_approx(v, roundf(v)) else str(v)
		return d["names"].get(key, key)
	if str(v) == "per_user":
		return "per user"
	if d["id"] == "app.size":
		return {"S": "small", "M": "medium", "L": "large"}.get(str(v), str(v))
	if v is float and is_equal_approx(v, roundf(v)):
		return str(int(v))
	return str(v)


func _step(id: String, by: int) -> void:
	var d := plan.dial(id)
	var options: Array = d["options"]
	var at := 0
	for i in options.size():
		if str(options[i]) == str(plan.dial_value(id)):
			at = i
	var i := at
	for _n in options.size():
		i = clampi(i + by, 0, options.size() - 1)
		if plan.option_available(id, options[i]):
			break
	if plan.option_available(id, options[i]):
		plan.dials[id] = options[i]
	changed.emit()
	var box: String = d.get("box", "")
	show_box(box)


func show_text(title: String, lines: Array) -> void:
	mode = "text"
	_start(title, true)
	for line in lines:
		var color := Palette.SLATE
		var text: String = line
		if text.begins_with("+"):
			color = Palette.GREEN_DARK
		elif text.begins_with("-"):
			color = Palette.RED
		var l := UI.label(text, Palette.BODY, color, true)
		l.custom_minimum_size.x = size.x - 14
		_body.add_child(l)
