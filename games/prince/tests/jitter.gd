extends Node

## Mashes the controls in every room and reports any frame where the Prince
## moves further than running, jumping or falling can carry him while play
## carries on (no rewind, no death). Also pulls levers and commits at random,
## so gates and bridges change under him.
##
##     godot --headless --path . res://tests/jitter.tscn    # JITTER result=ok

const FRAMES := 60 * 40
## Most he can move in one frame: a run step across, the fastest fall down.
const MAX_STEP := Vector2(Prince.RUN / 60.0 + 0.6, Prince.MAX_FALL / 60.0 + 0.6)

var _fails: PackedStringArray = []


func _ready() -> void:
	Progress.persist = false
	Room.test_fast = true
	StageAudio.web_audio_unlocked = true
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	var rng := RandomNumberGenerator.new()
	for id in range(1, Story.count() + 1):
		for seed_value in 4:
			rng.seed = id * 100 + seed_value
			await _mash(id, rng)
	for action in [&"move_left", &"move_right", &"jump", &"dagger"]:
		Input.action_release(action)
	print("JITTER result=%s" % ("ok" if _fails.is_empty() else "FAIL (%d)\n  " % _fails.size() + "\n  ".join(_fails.slice(0, 25))))
	tree.quit(0 if _fails.is_empty() else 1)


func _mash(id: int, rng: RandomNumberGenerator) -> void:
	var tree := get_tree()
	Main.play(tree, id)
	for _i in 30:
		await tree.physics_frame
	var room := tree.current_scene as Room
	var last := room.prince.pos
	var last_state := room.state
	var last_cmds := room.commands_run
	var hold := 0
	var was_floor := true
	for frame in FRAMES:
		if not is_instance_valid(room) or tree.current_scene != room:
			return
		if hold <= 0:
			hold = rng.randi_range(4, 50)
			for action in [&"move_left", &"move_right", &"jump"]:
				Input.action_release(action)
			var pick := rng.randi_range(0, 9)
			if pick < 5:
				Input.action_press(&"move_right")
			elif pick < 8:
				Input.action_press(&"move_left")
			if rng.randf() < 0.45:
				Input.action_press(&"jump")
		hold -= 1
		# Now and then, the dagger: any button that's there.
		if room.state == "play" and rng.randf() < 0.004:
			room.draw_dagger()
		if room.state == "dagger":
			var acts := room.console.acts()
			acts = Array(acts).filter(func(a: String) -> bool: return a != "restart")
			if acts.is_empty():
				return
			room.console.press(acts[rng.randi_range(0, acts.size() - 1)])
			await tree.process_frame
		await tree.physics_frame
		if not is_instance_valid(room) or tree.current_scene != room:
			return
		var now := room.prince.pos
		var moved := (now - last).abs()
		var steady := room.state == "play" and last_state == "play" and room.commands_run == last_cmds
		if steady and room.prince.alive and (moved.x > MAX_STEP.x or moved.y > MAX_STEP.y):
			_fails.append("room %d frame %d: %s -> %s (on_floor %s, vel %s)" % [id, frame, last, now, room.prince.on_floor, room.prince.vel])
		# And the floor never flickers out from under him.
		if steady and room.prince.alive:
			var fell := not room.prince.on_floor and was_floor and not room.prince.jumped and absf(now.y - last.y) < 1.0 and room.is_solid(floori(now.x / Room.T), floori((now.y + 1.0) / Room.T))
			if fell:
				_fails.append("room %d frame %d: %s %s -> %s vel %s" % [id, frame, "the floor flickered under him", last, now, room.prince.vel])
		was_floor = room.prince.on_floor
		last = now
		last_state = room.state
		last_cmds = room.commands_run
		if room.state == "clear" or room.state == "timeout":
			return
