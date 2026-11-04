class_name Episode
extends Control

## One episode, built from its entry in data/season.json: cold open, title
## card, brief, the night's goal, then planning (Aleister's pull request, the
## asks, the dials, staging, merge), the live moment (with its hotfix), and
## Gerard's postmortem. A failed night goes back to the same board for take
## two; a good one ends with the codex cards and the cliffhanger.
##
## `phase` says where it is, for the bot.

signal merged
signal hotfix_answered(keep: bool)
signal postmortem_done(again: bool)
signal finished

## Tests: live ticks per frame (0 plays at the real pace), and whether to
## stay put at the end instead of going back to the title.
static var test_ticks_per_frame: int = 0
static var test_stay: bool = false

const LIVE_TICKS_PER_SECOND := 4.0

var episode_id: int = 8
var ep: Dictionary
var plan: Plan
var phase: String = ""
var last_result: Dictionary = {}
var takes: int = 0
## Live: the tick just played, and the hotfix on screen, if any.
var last_tick: int = 0
var pending_hotfix: String = ""

var backdrop: Backdrop
var board: Board
var panel: PrPanel
var dialogue: Dialogue
var card: Card
var _top_title: Label
var _top_left: Label
var _top_right: Label
var _bottom: Control
var _merge: Button
var _staging: Button
var _live_panel: Control
var _live_bottom: Control
var _meters: Label
var _corner_face: Portrait
var _corner_text: Label
var _banner: Label
var _overlay: Control
var _paused: bool = false
var _speed: float = 1.0


func _ready() -> void:
	ep = Season.episode(episode_id)
	plan = Plan.new(ep)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_run.call_deferred()


func _build() -> void:
	var bg := UI.place(UI.panel(Palette.PAPER), Rect2(0, 0, 480, 270))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var top := UI.place(UI.panel(Palette.SLATE), Rect2(0, 0, 480, 20))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var short: String = ep.get("short", ep["title"].to_upper())
	_top_title = UI.place(UI.title(short, Palette.HEAD, Palette.GREEN), Rect2(6, 2, 80, 16)) as Label
	add_child(_top_title)
	# The runway sits just after the episode's name, however long it is.
	var after := 6.0 + ceilf(_top_title.get_theme_font("font").get_string_size(short, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.HEAD).x)
	_top_title.size.x = after - 6.0
	_top_left = UI.place(UI.label("", Palette.LABEL, Palette.WHITE), Rect2(after + 10.0, 3, 290.0 - after - 10.0, 14)) as Label
	add_child(_top_left)
	_top_right = UI.place(UI.label("", Palette.LABEL, Palette.WHITE), Rect2(290, 3, 184, 14)) as Label
	_top_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_top_right)

	board = Board.new()
	board.spots = ep.get("spots", {})
	UI.place(board, Rect2(0, 20, 300, 216))
	board.box_pressed.connect(_on_box)
	add_child(board)

	panel = PrPanel.new()
	UI.place(panel, Rect2(300, 20, 180, 216))
	panel.changed.connect(_refresh)
	add_child(panel)

	_bottom = UI.place(Control.new(), Rect2(0, 236, 480, 34))
	add_child(_bottom)
	var changes := UI.button("The PR", "normal", Vector2(80, 30))
	changes.name = "ShowPR"
	UI.place(changes, Rect2(2, 2, 80, 30))
	changes.pressed.connect(func() -> void: panel.show_list())
	_bottom.add_child(changes)
	var ask := UI.button("Ask Aleister", "normal", Vector2(110, 30))
	ask.name = "ShowAsks"
	UI.place(ask, Rect2(86, 2, 110, 30))
	ask.pressed.connect(func() -> void: panel.show_asks())
	_bottom.add_child(ask)
	panel.ask_pressed.connect(_on_ask)
	_staging = UI.button("Staging", "normal", Vector2(72, 30))
	_staging.name = "Staging"
	UI.place(_staging, Rect2(302, 2, 72, 30))
	_staging.pressed.connect(_on_staging)
	_bottom.add_child(_staging)
	_merge = UI.button("MERGE", "primary", Vector2(100, 30))
	_merge.name = "Merge"
	UI.place(_merge, Rect2(377, 2, 100, 30))
	_merge.pressed.connect(func() -> void:
		if plan.fits():
			Sound.sting("merge")
			merged.emit())
	_bottom.add_child(_merge)

	_live_panel = UI.place(Control.new(), Rect2(300, 20, 180, 216))
	var lp := UI.place(UI.panel(Palette.PAPER, Palette.RULE, 1), Rect2(0, 0, 180, 216))
	lp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_live_panel.add_child(lp)
	_meters = UI.place(UI.label("", Palette.LABEL, Palette.SLATE), Rect2(8, 6, 166, 90)) as Label
	_live_panel.add_child(_meters)
	_corner_face = UI.place(Portrait.new(), Rect2(2, 106, 48, 48)) as Portrait
	_live_panel.add_child(_corner_face)
	_corner_text = UI.place(UI.label("", Palette.BODY, Palette.SLATE, true), Rect2(52, 106, 124, 104)) as Label
	_live_panel.add_child(_corner_text)
	_live_panel.visible = false
	add_child(_live_panel)

	_live_bottom = UI.place(Control.new(), Rect2(0, 236, 480, 34))
	var pause := UI.button("Pause", "normal", Vector2(64, 30))
	pause.name = "Pause"
	UI.place(pause, Rect2(2, 2, 64, 30))
	pause.pressed.connect(func() -> void:
		_paused = not _paused
		pause.text = "Play" if _paused else "Pause")
	_live_bottom.add_child(pause)
	var fast := UI.button("2x", "normal", Vector2(44, 30))
	fast.name = "Fast"
	UI.place(fast, Rect2(70, 2, 44, 30))
	fast.pressed.connect(func() -> void:
		_speed = 1.0 if _speed > 1.0 else 2.0
		fast.text = "1x" if _speed > 1.0 else "2x")
	_live_bottom.add_child(fast)
	_banner = UI.place(UI.label("", Palette.LABEL, Palette.GREEN_DARK), Rect2(122, 8, 354, 20)) as Label
	_live_bottom.add_child(_banner)
	_live_bottom.visible = false
	add_child(_live_bottom)

	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	backdrop = Backdrop.new()
	backdrop.visible = false
	add_child(backdrop)
	dialogue = Dialogue.new()
	add_child(dialogue)
	card = Card.new()
	add_child(card)


func _run() -> void:
	phase = "cold_open"
	Sound.music("plan")
	backdrop.place = ep.get("backdrop", "garage")
	backdrop.visible = true
	await dialogue.play(ep["cold_open"], ep.get("place", ""))
	phase = "title"
	Sound.sting("title")
	await card.title_card(ep["title"])
	backdrop.visible = false
	_refresh()
	phase = "brief"
	await dialogue.play(ep["brief"])
	phase = "goal"
	await card.goal_card(ep["goal"], ep["budget"])
	while true:
		takes += 1
		await _planning()
		var res := await _live()
		last_result = res
		var again: bool = await _postmortem(res)
		if not again:
			break
	phase = "lessons"
	for lesson in ep.get("lessons", []):
		await card.lesson_card(lesson)
	phase = "cliffhanger"
	var cliff: Dictionary = ep["cliffhanger"]
	backdrop.place = cliff.get("backdrop", "kitchen")
	backdrop.visible = true
	await dialogue.play(cliff["lines"], cliff.get("place", ""))
	# The finale has no next episode: its black card says so, and holds.
	await card.black(cliff.get("end", ""), 120 if cliff.has("end") else 60)
	phase = "done"
	finished.emit()
	if not test_stay:
		get_tree().change_scene_to_file("res://ui/boot.tscn")


# Planning.

func _planning() -> void:
	phase = "planning"
	Sound.music("plan")
	panel.visible = true
	_bottom.visible = true
	_live_panel.visible = false
	_live_bottom.visible = false
	board.live = false
	panel.setup(plan)
	_refresh()
	await merged


func _refresh() -> void:
	board.show_plan(plan.config(), ep["board"])
	var budget: Dictionary = ep["budget"]
	var runway := float(budget["bank"]) / (float(budget["burn"]) + Sim.monthly_of(plan.config()))
	_top_left.text = "Runway %.1f mo" % runway
	var used := plan.time_used()
	_top_right.text = "Time %s / %s%s" % [_num(used), _num(float(budget["time"])), budget.get("time_unit", "h")]
	_top_right.add_theme_color_override("font_color", Palette.WHITE if plan.fits() else Palette.AMBER)
	_merge.disabled = not plan.fits()
	_merge.text = "MERGE" if plan.fits() else "TOO LONG"


func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _on_ask(id: String) -> void:
	if phase != "planning" or dialogue.visible:
		return
	var first := not plan.asked.has(id)
	plan.ask(id)
	for a in ep["asks"]:
		if a["id"] == id:
			await dialogue.play(a["reply"])
			# A question that adds a card goes back to the PR to show it.
			if first and not a.get("adds", []).is_empty():
				panel.show_list()
			else:
				panel.show_asks()
	_refresh()


func _on_box(id: String) -> void:
	if phase == "planning":
		panel.show_box(id)


func _on_staging() -> void:
	var res := Sim.play(ep, plan, 0.1)
	var lines := ["At a tenth of tonight's traffic:"]
	if not res.get("merge", true):
		lines.append("- It doesn't fit the time we have.")
	else:
		for g in res["goals"]:
			lines.append(("+ " if g["ok"] else "- ") + g["label"])
	lines.append("Staging is quieter than the real night. Some problems only show up at full load.")
	panel.show_text("Staging", lines)


# The live moment.

func _live() -> Dictionary:
	phase = "live"
	Sound.music("live")
	panel.visible = false
	_bottom.visible = false
	_live_panel.visible = true
	_live_bottom.visible = true
	_paused = false
	board.live = true
	_corner_face.who = ""
	_corner_text.text = ""
	_banner.text = ""
	var sim := Sim.new(ep, plan)
	var seen := {}
	var streak := 0
	var acc := 0.0
	var early := false
	var banners := {}
	for e in ep["live"].get("events", []):
		banners[int(e["tick"])] = e["banner"]
	while not sim.done():
		var due := sim.hotfix_due()
		if not due.is_empty():
			pending_hotfix = due["id"]
			plan.hotfix[due["id"]] = await _hotfix(due, sim.cfg)
			pending_hotfix = ""
			phase = "live"
		var f := sim.step()
		last_tick = int(f["tick"])
		board.set_frame(f, sim.cfg)
		_show_frame(f, sim)
		if banners.has(f["tick"]):
			_banner.text = banners[f["tick"]]
		for tag in f["tags"]:
			if not seen.has(tag):
				seen[tag] = true
				_corner(tag)
		if not seen.has("calm") and f["diners"] > 10000 and f["tags"].is_empty():
			seen["calm"] = true
			_corner("calm")
		streak = streak + 1 if f["down"] else 0
		if streak >= 10:
			early = true
			break
		if test_ticks_per_frame > 0:
			if int(f["tick"]) % test_ticks_per_frame == 0:
				await get_tree().process_frame
		else:
			acc -= 1.0 / (LIVE_TICKS_PER_SECOND * _speed)
			while acc < 0.0 or _paused:
				await get_tree().process_frame
				if not _paused:
					acc += get_process_delta_time()
	if early:
		while not sim.done():
			sim.step()
		Sound.stop_music()
		Sound.sting("fail")
		await card.black("Forkcast is down.", 90)
	board.live = false
	var res := sim.result()
	if not res["passed"] and not early:
		Sound.stop_music()
		Sound.sting("fail")
	res["merge"] = true
	return res


func _show_frame(f: Dictionary, sim: Sim) -> void:
	var minutes := int(ep["live"]["clock"][0]) * 60 + int(ep["live"]["clock"][1]) + int(f["tick"])
	var h := (minutes / 60) % 24
	_top_right.text = "%s %d:%02d%s" % [ep["live"].get("day", "Fri"), ((h + 11) % 12) + 1, minutes % 60, "pm" if h >= 12 else "am"]
	_top_right.add_theme_color_override("font_color", Palette.WHITE)
	_top_left.text = "Bank %s" % Palette.money(f["money"])
	var page: String = "down" if f["down"] else "%.1f s" % f["page"]
	_meters.text = "Diners online  %s\nPage speed  %s\nErrors  %d%%\nBookings  %d\nAI bill  %s" % [
		_thousands(roundi(f["diners"])), page, roundi(f["err"] * 100.0), roundi(sim.booked), Palette.money(sim.model_bill)]
	# The board's numbers only when the goal is about them: the meters have
	# room for six lines above the cast corner.
	if f.get("dash", false) and ep["goal"].any(func(g: Dictionary) -> bool: return str(g["metric"]).begins_with("dashboard")):
		_meters.text +="\nBoard's numbers  %d min old" % roundi(f["age"])
	# Deposits: the night's wrong charges and double bookings take the AI
	# bill's place, to keep to six lines.
	if ep["live"].has("payments"):
		_meters.text = "Diners online  %s\nPage speed  %s\nErrors  %d%%\nBookings  %d\nCharged wrongly  %d\nTables booked twice  %d" % [
			_thousands(roundi(f["diners"])), page, roundi(f["err"] * 100.0), roundi(sim.booked),
			floori(float(f["bad_charges"]) + 0.5), floori(float(f["double_bookings"]) + 0.5)]
	# A leaked key: strangers' calls and bookings read take the bookings'
	# line and the sixth, to keep to six lines.
	if ep["live"].has("leak"):
		_meters.text = "Diners online  %s\nPage speed  %s\nErrors  %d%%\nAI bill  %s\nStrangers' calls  %s/min\nBookings read  %s" % [
			_thousands(roundi(f["diners"])), page, roundi(f["err"] * 100.0), Palette.money(sim.model_bill),
			_thousands(roundi(f["stolen"])), _thousands(roundi(f["peeked"]))]
	# AI inside the app: made-up answers, answers and jobs the planted
	# review steered, and what the agent did unasked take the last three
	# lines, to keep to six.
	if ep["live"].has("injection"):
		_meters.text = "Diners online  %s\nPage speed  %s\nErrors  %d%%\nMade-up answers  %s\nJobs fooled by review  %s\nDone without asking  %s" % [
			_thousands(roundi(f["diners"])), page, roundi(f["err"] * 100.0), _thousands(roundi(f["made_up"])),
			_thousands(roundi(f["fooled"])), _thousands(floori(float(f["unasked"]) + 0.5))]
	if f.get("scrape_in", 0.0) > 0.0:
		_meters.text += "\nHubbubBot  %d/s, %d let in" % [roundi(f["scrape_in"]), roundi(f["scrape_through"])]
	# An episode with every behaviour on (the finale) names its six lines.
	if ep["live"].has("meters"):
		var lines := {
			"diners": "Diners online  %s" % _thousands(roundi(f["diners"])),
			"page": "Page speed  %s" % page,
			"errors": "Errors  %d%%" % roundi(f["err"] * 100.0),
			"bookings": "Bookings  %s" % _thousands(roundi(sim.booked)),
			"ai_bill": "AI bill  %s" % Palette.money(sim.model_bill),
			"scraper": "HubbubBot  %d/s, %d let in" % [roundi(f.get("scrape_in", 0.0)), roundi(f.get("scrape_through", 0.0))],
		}
		var out := []
		for m in ep["live"]["meters"]:
			out.append(lines[m])
		_meters.text = "\n".join(out)


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _corner(tag: String) -> void:
	for c in ep["live"].get("corner", []):
		if c["when"] == tag:
			_corner_face.who = c["who"]
			_corner_text.text = "%s: %s" % [Season.person(c["who"])["name"], c["say"]]
			return


func _hotfix(h: Dictionary, cfg: Dictionary) -> bool:
	phase = "hotfix"
	# "{monthly}" in the line is what keeping the hotfix adds to the bill.
	var after := cfg.duplicate(true)
	for change in h.get("changes", []):
		Plan.apply_change(after, change)
	var say := str(h["say"]).replace("{monthly}", Palette.money(Sim.monthly_of(after) - Sim.monthly_of(cfg)))
	var modal := UI.place(UI.panel(Palette.WHITE, Palette.GREEN, 2), Rect2(40, 60, 260, 120))
	modal.name = "Hotfix"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(modal)
	var face := UI.place(Portrait.new("aleister"), Rect2(6, 8, 48, 48))
	modal.add_child(face)
	modal.add_child(UI.place(UI.label("HOTFIX", Palette.LABEL, Palette.GREEN_DARK), Rect2(60, 8, 192, 14)))
	modal.add_child(UI.place(UI.label(say, Palette.BODY, Palette.SLATE, true), Rect2(60, 22, 194, 54)))
	var keep := UI.button("KEEP", "primary", Vector2(90, 30))
	keep.name = "HotfixKeep"
	UI.place(keep, Rect2(60, 82, 90, 30))
	keep.pressed.connect(func() -> void: hotfix_answered.emit(true))
	modal.add_child(keep)
	var cut := UI.button("CUT", "cut", Vector2(90, 30))
	cut.name = "HotfixCut"
	UI.place(cut, Rect2(160, 82, 90, 30))
	cut.pressed.connect(func() -> void: hotfix_answered.emit(false))
	modal.add_child(cut)
	var answer: bool = await hotfix_answered
	modal.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return answer


# The postmortem.

func marks(res: Dictionary) -> Dictionary:
	var ulrich := true
	for c in plan.visible_cards():
		if c.get("by", "") == "ulrich":
			ulrich = ulrich and plan.active(c["id"]) == c.get("ulrich_right", false)
	return {"live": res["passed"], "lean": res["passed"] and res["lean"], "ulrich": res["passed"] and ulrich}


func _postmortem(res: Dictionary) -> bool:
	phase = "postmortem"
	Sound.sting("postmortem", true)
	Sound.music("plan")
	_live_panel.visible = false
	_live_bottom.visible = false
	var sheet := UI.place(UI.panel(Palette.PAPER, Palette.RULE, 1), Rect2(0, 20, 480, 250))
	sheet.name = "Postmortem"
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(sheet)
	var head := "THE NIGHT WORKED" if res["passed"] else "POSTMORTEM"
	sheet.add_child(UI.place(UI.title(head, Palette.HEAD, Palette.GREEN_DARK if res["passed"] else Palette.RED), Rect2(8, 4, 220, 18)))
	sheet.add_child(UI.place(UI.label("Gerard's spreadsheet", Palette.BODY, Palette.SLATE_MID), Rect2(8, 22, 220, 12)))
	var m: Dictionary = res["metrics"]
	var lines := []
	for g in res["goals"]:
		lines.append(("+ " if g["ok"] else "- ") + g["label"])
	lines.append("")
	lines.append("Page speed at peak: %.1f s" % m["peak_latency"])
	lines.append("Bookings made: %s (%d%%)" % [_thousands(roundi(res["booked"])), roundi(m["booking_success"] * 100.0)])
	lines.append("Searches answered: %d%%" % roundi(m["search_success"] * 100.0))
	lines.append("AI bill: %s   Revenue: %s" % [Palette.money(res["model_bill"]), Palette.money(res["revenue"])])
	if ep["live"].has("payments"):
		lines.append("Charged wrongly: %d   Booked twice: %d" % [roundi(m["bad_charges"]), roundi(m["double_bookings"])])
	if ep["live"].has("leak"):
		lines.append("Strangers' calls: %s   Bookings read: %s" % [_thousands(roundi(res["stolen_calls"])), _thousands(roundi(res["peeked"]))])
	if ep["live"].has("injection"):
		lines.append("Made up: %s  Fooled: %s  Unasked: %d" % [_thousands(roundi(res["made_up"])), _thousands(roundi(res["fooled"])), roundi(m["unasked"])])
	# The spreadsheet has room for about fifteen lines above the marks. An
	# episode with many goals (the finale's eleven) keeps the goals, the
	# bill and the runway, and leaves out the rest.
	if lines.size() + 1 > 15:
		var keep := lines.slice(0, res["goals"].size())
		keep.append("")
		keep.append("AI bill: %s   Revenue: %s" % [Palette.money(res["model_bill"]), Palette.money(res["revenue"])])
		lines = keep
	lines.append("Runway: %.2f months (par %.2f)" % [res["runway"], res["par"]])
	var y := 38.0
	for line in lines:
		var color := Palette.SLATE
		if line.begins_with("+"):
			color = Palette.GREEN_DARK
		elif line.begins_with("-"):
			color = Palette.RED
		sheet.add_child(UI.place(UI.label(line, Palette.BODY, color), Rect2(8, y, 226, 12)))
		y += 12.0
	var mk := marks(res)
	var mark_text := "Marks:  %s Live   %s Lean   %s Ulrich" % [
		"[x]" if mk["live"] else "[ ]", "[x]" if mk["lean"] else "[ ]", "[x]" if mk["ulrich"] else "[ ]"]
	sheet.add_child(UI.place(UI.label(mark_text, Palette.LABEL, Palette.SLATE), Rect2(8, y + 4, 226, 14)))
	if res["passed"]:
		Progress.record(int(ep["id"]), res["runway"], mk)

	var scroll := ScrollContainer.new()
	UI.place(scroll, Rect2(240, 6, 234, 200))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet.add_child(scroll)
	var col := UI.vbox(4)
	col.custom_minimum_size.x = 222
	scroll.add_child(col)
	var shown := 0
	for tag in res["tags"]:
		var f: Dictionary = ep["postmortem"].get(tag, {})
		if f.is_empty() or shown >= 3:
			continue
		shown += 1
		for part in [[f["title"], Palette.SLATE, Palette.LABEL], [f["plain"], Palette.SLATE, Palette.BODY],
				["Real term: " + f["term"], Palette.GREEN_DARK, Palette.BODY], ["Tell your AI: \"%s\"" % f["tell_ai"], Palette.SLATE_MID, Palette.BODY]]:
			var l := UI.label(part[0], part[2], part[1], true)
			l.custom_minimum_size.x = 218
			col.add_child(l)
	if shown == 0:
		var l := UI.label("No findings. Forkcast held, and nobody paid for anything it didn't need.", Palette.LABEL, Palette.SLATE, true)
		l.custom_minimum_size.x = 218
		col.add_child(l)
	var go := UI.button("NEXT" if res["passed"] else "TAKE TWO", "primary", Vector2(110, 30))
	go.name = "PostmortemNext"
	UI.place(go, Rect2(364, 214, 110, 30))
	sheet.add_child(go)
	go.pressed.connect(func() -> void: postmortem_done.emit(not res["passed"]))
	var again: bool = await postmortem_done
	sheet.queue_free()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return again
