extends Node

## Drives the menus with real input events through real scene changes:
## title -> map -> Amber Hollow -> pause/resume -> fall + respawn
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
					_tap(&"pause")
				elif _wait == 96:
					_expect(get_tree().paused, "pause reopens")
					(scene.get_node(^"Hud/PausePanel/Center/Box/Items/QuitButton") as Button).pressed.emit()
					_next()
			5:
				if _scene_is(scene, "WorldMap") and _wait > 40:
					_expect(not get_tree().paused, "map unpaused")
					_tap(&"pause")
					_next()
			6:
				if _scene_is(scene, "TitleScreen") and _wait > 10:
					_finish()

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
