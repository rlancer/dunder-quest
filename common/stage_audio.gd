class_name StageAudio
extends Node

var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	add_to_group(&"stage_audio")
	for _index in 6:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_players.append(player)


func play_sfx(stream: AudioStream) -> void:
	if stream == null or _players.is_empty():
		return
	var chosen: AudioStreamPlayer = _players[0]
	for player in _players:
		if not player.playing:
			chosen = player
			break
	chosen.stream = stream
	chosen.play()


static func play(tree: SceneTree, stream: AudioStream) -> void:
	if tree == null or stream == null:
		return
	var nodes := tree.get_nodes_in_group(&"stage_audio")
	if nodes.is_empty():
		return
	var audio := nodes[0] as StageAudio
	if audio != null:
		audio.play_sfx(stream)
