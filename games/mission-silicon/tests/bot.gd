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

const CAP := 60 * 120

var _fails: PackedStringArray = []
var _shots: bool = false
var _shot_n: int = 0
var ep_node: Episode


func _ready() -> void:
	Progress.persist = false
	_shots = OS.get_cmdline_user_args().has("shots")
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	Dialogue.test_auto_frames = 20 if _shots else 2
	Card.test_auto_frames = 20 if _shots else 2
	Episode.test_ticks_per_frame = 4 if _shots else 30
	Episode.test_stay = true
	if _shots:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/shots"))
		tree.change_scene_to_file("res://ui/boot.tscn")
		await _frames(10)
		await _shot("title")
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


func _shot(name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/shots/%02d_%s.png" % [_shot_n, name])


func _wait_phase(want: String) -> bool:
	for _i in CAP:
		if ep_node.phase == want:
			return true
		await get_tree().process_frame
	_fail("never reached %s (stuck in %s)" % [want, ep_node.phase])
	return false


func _find(name: String) -> Control:
	return ep_node.find_child(name, true, false) as Control


## A real tap: a press and a release at the control's centre, once any
## dialogue on screen (the first episode's tutorial lines) has moved on.
func _tap(name: String) -> bool:
	for _i in CAP:
		if not ep_node.dialogue.visible:
			break
		await get_tree().process_frame
	var c := _find(name)
	if c == null or not c.is_visible_in_tree():
		_fail("no visible %s to tap in %s" % [name, ep_node.phase])
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
	_check_node(ep_node, where)


func _check_node(n: Node, where: String) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
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
