extends Node

## The prologue for the trailer: played through on its own, read aloud and
## with its own music, the way a first run sees it. Logs a MARK line, keyed by
## movie frame, as each beat starts:
##
##   MARK <frame> beat <n> <say> <git_at> <git_len>   beat n (1-based): its line's
##        clip length, when the Git word is read, and that clip's length (seconds)
##   MARK <frame> end-of-intro
##
## bash trailer/capture.sh intro   (records at 1920x1080, like the run)

var _start_frame := 0
var _beat := -1


func _ready() -> void:
	Progress.persist = false
	StageAudio.web_audio_unlocked = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	reparent(tree.root)
	tree.current_scene = null
	_start_frame = Engine.get_process_frames()
	Main.intro(tree, 1)
	while not tree.current_scene is Room:
		var intro := tree.current_scene as Intro
		if intro != null and intro.beat() != _beat:
			_beat = intro.beat()
			var say: float = intro._say.get_length() if intro._say != null else 0.0
			var git_len: float = intro._say_git.get_length() if intro._say_git != null else 0.0
			_mark("beat %d %.3f %.3f %.3f" % [_beat + 1, say, intro._git_at, git_len])
		await tree.process_frame
	_mark("end-of-intro")
	for _i in 30:
		await tree.process_frame
	tree.quit()


func _mark(text: String) -> void:
	print("MARK %d %s" % [Engine.get_process_frames() - _start_frame, text])
