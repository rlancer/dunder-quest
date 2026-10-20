extends Node

## Drives the menus with real input events through real scene changes:
## title -> map -> Amber Hollow -> pause/resume -> fall + respawn
## -> wizard quiz (one wrong answer, then a different question answered right)
## -> pause -> world map -> Esc -> title.
## godot --headless --path . res://tests/flow_check.tscn   ->  FLOW result=ok

var _driver: Node


func _ready() -> void:
	GameProgression.persist = false
	GameProgression.load_data()
	# The driver must outlive scene changes, so it lives beside the current scene.
	_driver = Node.new()
	_driver.set_script(_Driver)
	_driver.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(_driver)
	get_tree().change_scene_to_file.call_deferred("res://ui/title_screen.tscn")


class _Driver extends Node:
	var _step := 0
	var _wait := 0
	var _fails: PackedStringArray = []
	var _quiz_taps := 0
	var _first_code := ""
	var _clock_at_open := 0.0

	func _physics_process(_delta: float) -> void:
		_wait += 1
		if _wait > 900:
			_fail("timed out at step %d" % _step)
			_finish()
			return
		var scene := get_tree().current_scene
		match _step:
			0:
				if _scene_is(scene, "TitleScreen") and _wait > 40:
					_tap(&"ui_accept")
					_next()
			1:
				if _scene_is(scene, "WorldMap") and _wait > 40:
					_tap(&"confirm")
					_next()
			2:
				if _scene_is(scene, "Level01") and _wait > 40:
					_tap(&"pause")
					_next()
			3:
				if _wait == 5:
					_expect(get_tree().paused, "pause opens")
					_tap(&"pause")
				elif _wait == 10:
					_expect(not get_tree().paused, "pause closes")
					var player := scene.get_node(^"Player") as Node2D
					player.global_position = Vector2(200.0, 330.0)
					_next()
			4:
				if _wait == 90:
					var player := scene.get_node(^"Player") as Node2D
					var hud := scene.get_node(^"Hud") as StageHud
					_expect(not bool(player.call(&"is_dead")), "player revived")
					_expect(player.global_position.distance_to(Vector2(56, 214)) < 4.0, "back at spawn")
					_expect(hud.falls == 1, "fall counted (got %d)" % hud.falls)
					# Step into the wizard's zone.
					var wizard := _wizard(scene)
					_expect(wizard != null and not wizard.barrier_open(), "wizard bars the way")
					if wizard != null:
						player.global_position = Vector2(wizard.zone_position().x, 214.0)
					_next()
			5:
				var hud := scene.get_node(^"Hud") as StageHud
				var player := scene.get_node(^"Player") as PlayerBody
				if hud.is_quiz_asking():
					if _first_code == "":
						_first_code = str(hud.quiz_question().get("code", ""))
						_clock_at_open = float(scene.get(&"_elapsed"))
						_expect(not player.controls_enabled, "quiz freezes controls")
					# Pick a wrong option on purpose.
					if _steer_quiz(hud, posmod(hud.quiz_answer_index() + 1, 4)):
						_next()
			6:
				var hud := scene.get_node(^"Hud") as StageHud
				if _wait == 20:
					_expect(hud.is_quiz_open() and not hud.is_quiz_asking(), "wrong answer shows a verdict")
					_expect(not _wizard(scene).barrier_open(), "barrier holds after a wrong answer")
				elif _wait == 40:
					# Skip the rest of the verdict with confirm.
					_tap(&"confirm")
				elif _wait > 44 and hud.is_quiz_asking():
					_expect(str(hud.quiz_question().get("code", "")) != _first_code, "a different question follows")
					_next()
			7:
				var hud := scene.get_node(^"Hud") as StageHud
				if _steer_quiz(hud, hud.quiz_answer_index()):
					_next()
			8:
				var hud := scene.get_node(^"Hud") as StageHud
				var player := scene.get_node(^"Player") as PlayerBody
				var wizard := _wizard(scene)
				if not hud.is_quiz_open() and wizard.barrier_open():
					_expect(wizard.banished, "wizard banished")
					# The quiz ran for seconds; a frame or two of slack covers the close.
					var drift := float(scene.get(&"_elapsed")) - _clock_at_open
					_expect(absf(drift) < 0.1, "clock held during the quiz (drift %.2f)" % drift)
					_next()
				elif _wait == 30:
					_expect(not hud.is_quiz_asking(), "right answer closes the question")
			9:
				var player := scene.get_node(^"Player") as PlayerBody
				if _wait == 20:
					_expect(player.controls_enabled, "controls return after the quiz")
					_expect(float(scene.get(&"_elapsed")) > _clock_at_open, "clock runs again")
					_tap(&"pause")
				elif _wait == 26:
					_expect(get_tree().paused, "pause reopens")
					(scene.get_node(^"Hud/PausePanel/Center/Box/Items/QuitButton") as Button).pressed.emit()
					_next()
			10:
				if _scene_is(scene, "WorldMap") and _wait > 40:
					_expect(not get_tree().paused, "map unpaused")
					_tap(&"pause")
					_next()
			11:
				if _scene_is(scene, "TitleScreen") and _wait > 10:
					_finish()

	## Steps the real selection with move_right taps, then presses confirm.
	## True once confirm has been sent.
	func _steer_quiz(hud: StageHud, target: int) -> bool:
		if not hud.is_quiz_asking():
			return false
		_quiz_taps += 1
		if _quiz_taps % 6 != 0:
			return false
		if hud.quiz_selected_index() != target:
			_tap(&"move_right")
			return false
		_tap(&"confirm")
		_quiz_taps = 0
		return true

	func _wizard(scene: Node) -> Wizard:
		for node in scene.get_tree().get_nodes_in_group(&"wizard"):
			if scene.is_ancestor_of(node):
				return node as Wizard
		return null

	func _scene_is(scene: Node, scene_name: String) -> bool:
		return scene != null and str(scene.name) == scene_name

	func _tap(action: StringName) -> void:
		var press := InputEventAction.new()
		press.action = action
		press.pressed = true
		Input.parse_input_event(press)
		var release := InputEventAction.new()
		release.action = action
		release.pressed = false
		Input.parse_input_event.call_deferred(release)

	func _next() -> void:
		print("FLOW step %d ok" % _step)
		_step += 1
		_wait = 0

	func _expect(ok: bool, what: String) -> void:
		if not ok:
			_fail(what)

	func _fail(what: String) -> void:
		_fails.append(what)
		print("FLOW fail ", what)

	func _finish() -> void:
		print("FLOW result=%s fails=%d" % ["ok" if _fails.is_empty() else "fail", _fails.size()])
		get_tree().quit(0 if _fails.is_empty() else 1)
