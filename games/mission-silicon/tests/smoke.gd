extends Node

## Loads the title (skipping its flyover), the Pilot and every other built episode for a few frames and quits.
## godot --headless --path . res://tests/smoke.tscn   ->  SMOKE result=ok


func _ready() -> void:
	Progress.persist = false
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	tree.change_scene_to_file("res://ui/boot.tscn")
	for _i in 10:
		await tree.process_frame
	# The title flyover plays over the season screen first; skipped, it goes.
	var fly := tree.current_scene.find_child("Flyover", true, false) as Flyover
	if fly == null:
		print("SMOKE result=fail no title flyover")
		tree.quit(1)
		return
	fly.skip()
	for _i in 60:
		await tree.process_frame
	if is_instance_valid(fly):
		print("SMOKE result=fail the title flyover didn't skip")
		tree.quit(1)
		return
	print("ok title")
	var sounds := []
	for track in Sound.TRACKS:
		sounds.append("res://assets/audio/music_%s.ogg" % track)
	for sting in Sound.STINGS:
		sounds.append("res://assets/audio/sting_%s.ogg" % sting)
	for path in sounds:
		if not load(path) is AudioStreamOggVorbis:
			print("SMOKE result=fail missing ", path)
			tree.quit(1)
			return
	print("ok audio")
	# Episode 1, the Pilot, is its own scene.
	var pilot := Pilot.new()
	tree.change_scene_to_node(pilot)
	for _i in 30:
		await tree.process_frame
	if Season.pilot().is_empty() or pilot.phase == "":
		print("SMOKE result=fail the Pilot didn't start")
		tree.quit(1)
		return
	print("ok episode 1 (the Pilot)")
	for ep in Season.episodes():
		var node := Episode.new()
		node.episode_id = int(ep["id"])
		tree.change_scene_to_node(node)
		for _i in 30:
			await tree.process_frame
		print("ok episode ", ep["id"])
	print("SMOKE result=ok")
	tree.quit(0)
