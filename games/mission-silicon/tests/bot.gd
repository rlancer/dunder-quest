extends Node

## Plays every built episode the way a player would, by tapping the real
## buttons. Take one merges Aleister's pull request with only what it must
## cut to fit the time (it can't merge as proposed), and checks the night
## fails into the postmortem. Take two asks the solution's questions, keeps
## and cuts its cards, turns its dials, answers the hotfix, and checks the
## night passes with every mark. Both nights must match the simulation run
## headless, and every screen it visits is checked for tap targets of at
## least 30x30 and text of at least 9 pixels.
##
## godot --headless --path . res://tests/bot.tscn               ->  BOT result=ok
## godot --path . res://tests/bot.tscn -- shots                  (screenshots into tests/shots/)
## godot --path . res://tests/bot.tscn -- shots phone=844x390    (at a phone held sideways,
##                                                                into tests/shots/phone_844x390/)
##
## At a phone size the window is that many pixels, with the project's own
## stretch settings, and every tap target and text size is also checked
## after scaling (30x30 and 9 px on the phone's screen). It starts with the
## phone held upright (390x844) to check the "turn your phone sideways" card.

const CAP := 60 * 120

var _fails: PackedStringArray = []
var _shots: bool = false
var _shot_n: int = 0
var _dir: String = "res://tests/shots"
## The window at a phone size (zero: the project's own window).
var _phone: Vector2i = Vector2i.ZERO
var ep_node: Episode
## The scene being played: the Pilot or an episode (both have `phase` and
## `dialogue`).
var scene


func _ready() -> void:
	Progress.persist = false
	_shots = OS.get_cmdline_user_args().has("shots")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("phone="):
			var wh := arg.trim_prefix("phone=").split("x")
			_phone = Vector2i(int(wh[0]), int(wh[1]))
			_dir = "res://tests/shots/phone_%dx%d" % [_phone.x, _phone.y]
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	Dialogue.test_auto_frames = 20 if _shots else 2
	Card.test_auto_frames = 20 if _shots else 2
	Episode.test_ticks_per_frame = 4 if _shots else 30
	Episode.test_stay = true
	Pilot.test_minutes_per_frame = 2 if _shots else 20
	Pilot.test_stay = true
	if _shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
		if _phone != Vector2i.ZERO:
			await _upright()
			get_window().size = _phone
			await _frames(10)
		tree.change_scene_to_file("res://ui/boot.tscn")
		await _frames(10)
		await _flyover()
		await _shot("title")
	await _play_pilot()
	# BOT_PILOT_ONLY=1 plays just the Pilot, for quick checks.
	if OS.get_environment("BOT_PILOT_ONLY") == "":
		for ep in Season.episodes():
			await _play(ep)
	print("BOT result=%s" % ("ok" if _fails.is_empty() else "FAIL " + "; ".join(_fails)))
	tree.quit(0 if _fails.is_empty() else 1)


func _fail(what: String) -> void:
	_fails.append(what)
	print("  FAIL ", what)


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _shot(name: String, numbered: bool = true) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if not numbered:
		img.save_png("%s/00_%s.png" % [_dir, name])
		return
	_shot_n += 1
	img.save_png("%s/%02d_%s.png" % [_dir, _shot_n, name])


## The phone held upright: the "turn your phone sideways" card must cover
## the screen, its text readable.
func _upright() -> void:
	get_window().size = Vector2i(390, 844)
	await _frames(10)
	if not Sideways.upright() or not Sideways.covered():
		_fail("upright, the sideways card isn't showing")
	await _shot("upright_390x844", false)


## The title flyover plays first, once a session: one shot partway through,
## then a tap skips it to the season screen.
func _flyover() -> void:
	var fly := get_tree().current_scene.find_child("Flyover", true, false) as Control
	if fly == null:
		_fail("no title flyover before the season screen")
		return
	await get_tree().create_timer(7.0).timeout
	await _shot("flyover", false)
	var at := get_viewport().get_visible_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
	# A tap that only unlocked the browser's sound doesn't skip; there's no
	# such lock off the web.
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(fly) and fly.is_inside_tree():
		_fail("a tap didn't skip the title flyover")


func _wait_phase(want: String) -> bool:
	for _i in CAP:
		if scene.phase == want:
			return true
		await get_tree().process_frame
	_fail("never reached %s (stuck in %s)" % [want, scene.phase])
	return false


func _find(name: String) -> Control:
	return scene.find_child(name, true, false) as Control


## A real tap: a press and a release at the control's centre, once any
## dialogue on screen (the first episode's tutorial lines) has moved on.
func _tap(name: String) -> bool:
	for _i in CAP:
		if not scene.dialogue.visible:
			break
		await get_tree().process_frame
	var c := _find(name)
	if c == null or not c.is_visible_in_tree():
		_fail("no visible %s to tap in %s" % [name, scene.phase])
		return false
	# Scroll it into view first, as a player would.
	var up := c.get_parent()
	while up != null:
		if up is ScrollContainer:
			(up as ScrollContainer).ensure_control_visible(c)
			await _frames(2)
			break
		up = up.get_parent()
	var at := c.get_global_rect().get_center()
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await get_tree().process_frame
	await get_tree().process_frame
	return true


func _check_layout(where: String) -> void:
	_check_node(scene, where)


func _check_node(n: Node, where: String) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if _phone != Vector2i.ZERO and (n is Button or n is Label):
		_check_on_phone(n as Control, where)
	if n is Button and n.get_parent() != null:
		var r := (n as Button).get_global_rect()
		if r.size.x < Palette.TAP - 0.5 or r.size.y < Palette.TAP - 0.5:
			_fail("%s: %s is %dx%d, under a tap target" % [where, n.name, r.size.x, r.size.y])
	if n is Label or n is Button:
		var size := (n as Control).get_theme_font_size("font_size")
		if size < Palette.BODY:
			_fail("%s: %s text is %dpx" % [where, n.name, size])
	# A button that clips its text (the PR list's cards) must still fit it.
	if n is Button and (n as Button).clip_text and (n as Button).text != "":
		var b := n as Button
		var font := b.get_theme_font("font")
		var w := font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, b.get_theme_font_size("font_size")).x
		var room := b.size.x - b.get_theme_stylebox("normal").get_content_margin(SIDE_LEFT) - b.get_theme_stylebox("normal").get_content_margin(SIDE_RIGHT)
		if w > room + 0.5:
			_fail("%s: '%s' is clipped (%d px of text in %d)" % [where, b.text, w, room])
	for c in n.get_children():
		_check_node(c, where)


## At a phone size: the same control as the phone's screen shows it, after
## the stretch (min of width / 480 and height / 270, the "keep" aspect).
func _check_on_phone(c: Control, where: String) -> void:
	var s := minf(_phone.x / 480.0, _phone.y / 270.0)
	if c is Button:
		var r := c.get_global_rect()
		if r.size.x * s < 30.0 - 0.5 or r.size.y * s < 30.0 - 0.5:
			_fail("%s at %dx%d: %s is %dx%d on screen, under a tap target" % [where, _phone.x, _phone.y, c.name, r.size.x * s, r.size.y * s])
	if c.get_theme_font_size("font_size") * s < 9.0:
		_fail("%s at %dx%d: %s text is %.1f px on screen" % [where, _phone.x, _phone.y, c.name, c.get_theme_font_size("font_size") * s])


## Watches the live moment through to the postmortem, answering each
## hotfix as `answers` says (cut when it doesn't say).
func _through_live(ep: Dictionary, answers: Dictionary) -> bool:
	# A plan can skip the live moment for a flash-forward (the pilot's sale).
	for _i in CAP:
		if ep_node.phase in ["live", "flashforward", "postmortem"]:
			break
		await get_tree().process_frame
	var shot_live := false
	var shot_ff := false
	for _i in CAP:
		if ep_node.phase == "flashforward" and not shot_ff and ep_node.dialogue.visible:
			shot_ff = true
			await _frames(4)
			await _shot("flashforward")
		if ep_node.phase == "hotfix":
			await _frames(2)
			_check_layout("hotfix")
			await _shot("hotfix")
			await _tap("HotfixKeep" if answers.get(ep_node.pending_hotfix, false) else "HotfixCut")
		if ep_node.phase == "postmortem":
			await _frames(2)
			return true
		if ep_node.phase == "live" and not shot_live and _shots and ep_node.last_tick > int(ep["live"]["ticks"]) * 5 / 12:
			shot_live = true
			_check_layout("live")
			await _shot("live")
		await get_tree().process_frame
	_fail("ep %d: the live moment never ended" % ep["id"])
	return false


func _play(ep: Dictionary) -> void:
	ep_node = Episode.new()
	ep_node.episode_id = int(ep["id"])
	scene = ep_node
	get_tree().change_scene_to_node(ep_node)
	if _shots:
		await _frames(8)
		await _shot("cold_open")
		await _wait_phase("title")
		await _frames(6)
		await _shot("title_card")
		await _wait_phase("goal")
		await _frames(10)
		await _shot("goal")
	if not await _wait_phase("planning"):
		return
	await _frames(2)
	_check_layout("planning")
	await _shot("planning")

	# Take one: as proposed, it doesn't fit.
	if not _find("Merge").disabled:
		_fail("ep %d: Aleister's PR as proposed can merge" % ep["id"])
	var plan := ep_node.plan
	for c in plan.visible_cards():
		if plan.fits():
			break
		if float(c.get("time", 0)) > float(ep["budget"]["time"]) / 2.0 or c["id"] == "rust":
			await _tap("Keep_" + c["id"])
	if not plan.fits():
		_fail("ep %d: couldn't make the PR fit by cutting the big cards" % ep["id"])
		return
	await _tap("Card_" + plan.visible_cards()[0]["id"])
	_check_layout("card")
	await _shot("card")
	await _tap("Back")
	var expect_one := Sim.play(ep, plan.copy())
	await _tap("Merge")
	if not await _through_live(ep, {}):
		return
	_check_layout("postmortem one")
	await _shot("postmortem_take_one")
	var res := ep_node.last_result
	print("ep %d take one: passed=%s runway=%.3f tags=%s" % [ep["id"], res["passed"], res["runway"], ",".join(res["tags"].slice(0, 3))])
	if res["passed"]:
		_fail("ep %d: take one passed" % ep["id"])
	if absf(res["runway"] - expect_one["runway"]) > 0.000001:
		_fail("ep %d: take one's night differs from the headless run" % ep["id"])
	await _tap("PostmortemNext")

	# Take two: the solution, through the UI.
	if not await _wait_phase("planning"):
		return
	var sol: Dictionary = ep["solution"]
	for id in sol.get("asks", []):
		await _tap("ShowAsks")
		await _tap("Ask_" + id)
		for _i in CAP:
			if not ep_node.dialogue.visible:
				break
			await get_tree().process_frame
	await _shot("after_asks")
	if ep_node.panel.mode != "list":
		await _tap("ShowPR")
	for c in plan.visible_cards():
		var want: bool = sol["keep"].has(c["id"])
		if plan.kept.get(c["id"], false) != want:
			await _tap("Keep_" + c["id"])
	var shot_box := false
	for d in ep["dials"]:
		var id: String = d["id"]
		if not sol["dials"].has(id) or not plan.dial_available(id):
			continue
		var target: Variant = sol["dials"][id]
		if str(plan.dial_value(id)) == str(target):
			continue
		var b := ep_node.board.find_child("Box_" + d["box"], true, false) as Control
		if b == null:
			_fail("ep %d: no %s box to open" % [ep["id"], d["box"]])
			continue
		await _tap("Box_" + d["box"])
		var options: Array = d["options"]
		var dir := "Inc_" if options.find(target) > options.find(plan.dial_value(id)) else "Dec_"
		for _n in options.size():
			if str(plan.dial_value(id)) == str(target):
				break
			await _tap(dir + id.replace(".", "_"))
		if str(plan.dial_value(id)) != str(target):
			_fail("ep %d: couldn't set %s to %s" % [ep["id"], id, target])
		if not shot_box:
			shot_box = true
			_check_layout("dials")
			await _shot("dials")
	var want_cfg := Plan.solution(ep).config()
	if JSON.stringify(plan.config()) != JSON.stringify(want_cfg):
		_fail("ep %d: the board after take two isn't the solution's: %s" % [ep["id"], plan.describe()])
	await _tap("Merge")
	if not await _through_live(ep, sol.get("hotfix", {})):
		return
	_check_layout("postmortem two")
	await _shot("postmortem_take_two")
	res = ep_node.last_result
	var expect := Sim.play(ep, Plan.solution(ep))
	print("ep %d take two: passed=%s runway=%.3f marks=%s" % [ep["id"], res["passed"], res["runway"], ep_node.marks(res)])
	if not res["passed"]:
		_fail("ep %d: the solution failed on screen" % ep["id"])
	if absf(res["runway"] - expect["runway"]) > 0.000001:
		_fail("ep %d: take two's night differs from the headless run" % ep["id"])
	for m in ep_node.marks(res).values():
		if not m:
			_fail("ep %d: the solution missed a mark" % ep["id"])
	await _tap("PostmortemNext")
	if _shots:
		await _wait_phase("lessons")
		await _frames(6)
		await _shot("lesson")
		await _wait_phase("cliffhanger")
		await _frames(30)
		await _shot("cliffhanger")
	if not await _wait_phase("done"):
		return
	print("ep %d done in %d takes" % [ep["id"], ep_node.takes])


func _visible(name: String) -> bool:
	var c := _find(name)
	return c != null and c.is_visible_in_tree()


func _next_ready() -> bool:
	var b := _find("Next") as Button
	return b != null and b.is_visible_in_tree() and not b.disabled


## Waits for any dialogue on screen to move on.
func _quiet() -> void:
	for _i in CAP:
		if not scene.dialogue.visible:
			return
		await get_tree().process_frame


## The Pilot, through its real buttons: every box on the map, every step of
## the search, every way to ship; then one wrong pick before the right one
## at each decision (native apps, the key on the phone, our own backend,
## MERGE before the key is fixed), each checked to hold the player back.
## Thursday must match the headless run on the web and fall short on
## native apps, and the marks must follow the picks (native was tried, so
## no Ulrich mark).
func _play_pilot() -> void:
	var p := Pilot.new()
	scene = p
	get_tree().change_scene_to_node(p)
	if _shots:
		await _frames(8)
		await _shot("pilot_cold_open")
		await _wait_phase("title")
		await _frames(6)
		await _shot("pilot_title_card")
	if not await _wait_phase("goal"):
		return
	await _frames(2)
	_check_layout("pilot goal")
	await _shot("pilot_goal")
	await _tap("Next")

	# The map: Next only once all four boxes are open.
	await _wait_phase("map")
	await _frames(2)
	_check_layout("pilot map")
	await _shot("pilot_map")
	for k in ["device", "server", "db", "model"]:
		if _visible("Next"):
			_fail("pilot: the map's Next shows before every box is open")
		await _tap("Box_" + k)
		if k == "model":
			_check_layout("pilot map info")
			await _shot("pilot_map_model")
	await _tap("Next")

	# One search, step by step.
	await _wait_phase("steps")
	for i in 5:
		if _visible("Next"):
			_fail("pilot: the search's Next shows before the last step")
		await _tap("StepNext")
		if i == 0:
			await _frames(30 if _shots else 2)
			_check_layout("pilot steps")
			await _shot("pilot_step_wire")
	await _tap("Next")

	# Four ways to ship.
	await _wait_phase("ways")
	if _shots:
		await _frames(4)
		await _shot("pilot_ways_lines")
	await _quiet()
	for k in ["web", "pwa", "native", "cross"]:
		await _tap("Way_" + k)
	_check_layout("pilot ways")
	await _shot("pilot_ways")
	await _tap("Next")

	# Decision 1: native first (Ulrich's card), then the web app.
	await _wait_phase("pick")
	await _tap("Pick_native")
	_check_layout("pilot pick native")
	await _shot("pilot_pick_native")
	if _visible("Next"):
		_fail("pilot: native apps can go on to Thursday")
	await _tap("Pick_cross")
	if _visible("Next"):
		_fail("pilot: cross-platform can go on to Thursday")
	await _tap("Pick_pwa")
	_check_layout("pilot pick pwa")
	await _shot("pilot_pick_pwa")
	await _tap("Pick_web")
	if not _next_ready():
		_fail("pilot: the web app can't go on")
	_check_layout("pilot pick web")
	await _shot("pilot_pick_web")
	await _tap("Next")

	# Aleister's no-server plan, and the key in the code.
	await _wait_phase("noserver")
	await _tap("OpenCode")
	await _quiet()
	await _frames(2)
	if not _visible("Stamp"):
		_fail("pilot: no rule stamp after the key")
	_check_layout("pilot noserver")
	await _shot("pilot_noserver")
	await _tap("Next")

	# Decision 2: the key on the phone first, then where everything lives.
	await _wait_phase("sort")
	await _frames(2)
	_check_layout("pilot sort")
	await _shot("pilot_sort")
	await _tap("Piece_key")
	await _tap("Zone_front")
	if not _visible("Placed_key") or _visible("Next"):
		_fail("pilot: the key on the phone isn't shown in the wrong place")
	_check_layout("pilot sort wrong")
	await _shot("pilot_sort_wrong")
	await _tap("Placed_key")
	await _tap("Zone_back")
	var right := {"ui": "front", "state": "front", "fee": "back", "who": "back", "all": "db", "menu": "db"}
	for id in right:
		await _tap("Piece_" + id)
		await _tap("Zone_" + right[id])
	if not _next_ready():
		_fail("pilot: every piece in its place and still no Next")
	_check_layout("pilot sort done")
	await _shot("pilot_sort_done")
	await _tap("Next")

	# Decision 3: our own backend first, then renting.
	await _wait_phase("backend")
	await _tap("Back_own")
	if _visible("Next"):
		_fail("pilot: writing our own backend fits the hours left")
	_check_layout("pilot backend own")
	await _shot("pilot_backend_own")
	await _tap("Back_builder")
	if _visible("Next"):
		_fail("pilot: the AI app builder can go on")
	await _tap("Back_baas")
	if not _next_ready():
		_fail("pilot: renting the backend can't go on")
	_check_layout("pilot backend rent")
	await _shot("pilot_backend_rent")
	await _tap("Next")

	# Decision 4: MERGE waits until every line is read and the key is fixed.
	await _wait_phase("plan")
	await _frames(2)
	await _shot("pilot_plan")
	for i in 5:
		if _next_ready():
			_fail("pilot: MERGE before the plan's read")
		await _tap("Line_%d" % i)
	_check_layout("pilot plan bad line")
	await _shot("pilot_plan_key")
	if _next_ready():
		_fail("pilot: MERGE with the key still public")
	await _tap("TellAleister")
	await _quiet()
	if not _next_ready():
		_fail("pilot: the key's fixed and every line read, and still no MERGE")
	_check_layout("pilot plan fixed")
	await _shot("pilot_plan_fixed")
	await _tap("Next")

	# Thursday: the player's web app, then the native comparison.
	await _wait_phase("thursday")
	await _quiet()
	var shot_mid := false
	for _i in CAP:
		if _next_ready():
			break
		if not shot_mid and p._minute >= 46.0:
			shot_mid = true
			_check_layout("pilot thursday")
			await _shot("pilot_thursday_bug")
		await get_tree().process_frame
	var expect := PilotModel.thursday("web")
	var share := (_find("Share") as Label).text
	if share != "%d%%" % roundi(expect["share"] * 100.0):
		_fail("pilot: Thursday on screen says %s, the headless run %d%%" % [share, roundi(expect["share"] * 100.0)])
	if expect["share"] < float(Season.pilot()["goal_share"]):
		_fail("pilot: the web app misses Thursday's goal")
	await _shot("pilot_thursday_web")
	await _tap("Build_native")
	for _i in CAP:
		if p._minute >= float(Season.pilot()["thursday"]["minutes"]):
			break
		await get_tree().process_frame
	await _frames(2)
	_check_layout("pilot thursday native")
	await _shot("pilot_thursday_native")
	if PilotModel.thursday("native")["share"] >= float(Season.pilot()["goal_share"]):
		_fail("pilot: native apps make Thursday's goal")
	await _tap("Next")

	# Gerard's record, the runway and the marks.
	await _wait_phase("postmortem")
	await _frames(2)
	_check_layout("pilot postmortem")
	await _shot("pilot_postmortem")
	if p.result.get("share", 0.0) != expect["share"]:
		_fail("pilot: the record's Thursday isn't the web app's")
	await _tap("Next")
	await _wait_phase("record")
	await _frames(4)
	_check_layout("pilot record")
	await _shot("pilot_record")
	var want := {"live": true, "lean": true, "ulrich": false}
	if JSON.stringify(p.earned) != JSON.stringify(want):
		_fail("pilot: marks %s, not %s" % [p.earned, want])
	print("pilot: Thursday %d%% on the web, marks %s" % [roundi(expect["share"] * 100.0), p.earned])
	await _quiet()
	await _tap("Next")
	if _shots:
		await _wait_phase("cliffhanger")
		await _frames(8)
		await _shot("pilot_cliffhanger")
	if not await _wait_phase("done"):
		return
	print("ep 1 (the Pilot) done")
