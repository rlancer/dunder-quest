extends Node

## Ties the game to the website's social layer (leaderboards, cloud saves,
## certificates, screenshots) when it runs in a browser on dunderquest.com.
## The play page's script (site/static/social/play.js) puts window.DQSocial
## there. Before the game's progress loads, this asks it whether the cloud has
## progress from another device to merge into the save, and after that hands
## it the save file's text whenever it changes. The page decides the rest.
## Outside a browser, or on a page without the script, it does nothing, so
## the tests and the desktop builds never notice it.
##
## It must come before Progress in the autoload list, so a merged save is
## on disk before Progress reads it.

const GAME := "shell"
const SAVE_PATH := "user://shell_save.json"
## Seconds between looks at the save file.
const POLL := 1.0
## How long to keep looking for the page's script if it isn't there at start.
const WAIT := 15.0

var _bridge: JavaScriptObject = null
var _last := ""
var _clock := 0.0
var _waited := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		set_process(false)
		return
	_bridge = JavaScriptBridge.get_interface("DQSocial")
	if _bridge == null:
		return
	var local := _read()
	var merged: Variant = _bridge.boot(GAME, local)
	if merged is String and merged != "":
		_write(merged)
		local = merged
	_last = local
	if local != "":
		_bridge.saved(GAME, local)


func _process(delta: float) -> void:
	_clock += delta
	if _clock < POLL:
		return
	_waited += _clock
	_clock = 0.0
	if _bridge == null:
		# The page's script came late: too late to merge before loading, so it
		# only watches from here (and offers a reload if the cloud has more).
		_bridge = JavaScriptBridge.get_interface("DQSocial")
		if _bridge == null:
			if _waited > WAIT:
				set_process(false)
			return
		_last = _read()
		_bridge.attach(GAME, _last)
		return
	var text := _read()
	if text != _last:
		_last = text
		if text != "":
			_bridge.saved(GAME, text)


func _read() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	return FileAccess.get_file_as_string(SAVE_PATH)


func _write(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()
