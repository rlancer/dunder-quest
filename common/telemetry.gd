extends Node

## Anonymous gameplay stats for the Dunder Quest stats dashboard (stats/).
## A player is a random install id and nothing more: no names, no accounts.
## Events queue up and go out in small batches; when the network is down or
## the player switches stats off on the title screen, the game plays on.

const ENDPOINT := "https://stats.dunderquest.com/api/events"
const SETTINGS_PATH := "user://telemetry.json"
const FLUSH_SECONDS := 10.0
const BATCH_MAX := 50
## Beyond this many unsent events, the oldest are dropped.
const QUEUE_MAX := 500

static var instance: Node

## The player's choice from the title screen. Saved between runs.
static var enabled: bool = true

var _install_id: String = ""
var _session_id: String = ""
var _endpoint: String = ENDPOINT
var _queue: Array[Dictionary] = []
var _in_flight: Array[Dictionary] = []
var _http: HTTPRequest
var _clock: float = 0.0
## Kept alive so the browser can call back when the tab is hidden.
var _on_hidden: JavaScriptObject


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_session_id = _random_id()
	# Editor and debug runs would muddy the real numbers, so only exported
	# release builds report, unless EMBER_TELEMETRY_URL points somewhere.
	if OS.has_environment("EMBER_TELEMETRY_URL"):
		_endpoint = OS.get_environment("EMBER_TELEMETRY_URL")
	elif OS.is_debug_build():
		_endpoint = ""
	_http = HTTPRequest.new()
	_http.timeout = 15.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	if OS.has_feature("web"):
		_watch_tab()
	track("session_start")


func _process(delta: float) -> void:
	_clock += delta
	if _clock >= FLUSH_SECONDS:
		_clock = 0.0
		flush()


## Records one event. `stage` is 0 for events outside a stage.
static func track(type: String, stage: int = 0, data: Dictionary = {}) -> void:
	if instance == null or not enabled or not GameProgression.persist:
		return
	var event := {"type": type, "at": int(Time.get_unix_time_from_system() * 1000.0)}
	if stage > 0:
		event["stage"] = stage
	if not data.is_empty():
		event["data"] = data
	instance._enqueue(event)


static func set_enabled(on: bool) -> void:
	enabled = on
	if instance != null:
		if not on:
			instance._queue.clear()
		instance._save_settings()


## Sends what has queued up, unless a batch is already on its way.
static func flush() -> void:
	if instance == null or instance._endpoint == "" or instance._queue.is_empty() or not instance._in_flight.is_empty():
		return
	instance._send()


func _enqueue(event: Dictionary) -> void:
	_queue.append(event)
	if _queue.size() > QUEUE_MAX:
		_queue = _queue.slice(_queue.size() - QUEUE_MAX)
	if _queue.size() >= BATCH_MAX:
		flush()


func _send() -> void:
	_in_flight = _queue.slice(0, BATCH_MAX)
	_queue = _queue.slice(_in_flight.size())
	var error := _http.request(_endpoint, ["Content-Type: application/json"], HTTPClient.METHOD_POST, _batch_json(_in_flight))
	if error != OK:
		_requeue()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	# A rejected batch would be rejected again, so only network trouble and
	# server errors earn a retry.
	if result != HTTPRequest.RESULT_SUCCESS or code == 429 or code >= 500:
		_requeue()
	else:
		_in_flight.clear()


func _requeue() -> void:
	var retry := _in_flight.duplicate()
	retry.append_array(_queue)
	_queue = retry
	_in_flight.clear()
	if _queue.size() > QUEUE_MAX:
		_queue = _queue.slice(_queue.size() - QUEUE_MAX)


func _batch_json(events: Array[Dictionary]) -> String:
	return JSON.stringify({
		"install_id": _install_id,
		"session_id": _session_id,
		"platform": OS.get_name().to_lower(),
		"version": str(ProjectSettings.get_setting("application/config/version", "dev")),
		"events": events,
	})


## A closing tab never waits for an HTTPRequest, so the last events leave
## with navigator.sendBeacon when the page is hidden.
func _watch_tab() -> void:
	_on_hidden = JavaScriptBridge.create_callback(_on_tab_hidden)
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	document.addEventListener("visibilitychange", _on_hidden)


func _on_tab_hidden(_args: Array) -> void:
	if _endpoint == "" or not enabled or str(JavaScriptBridge.eval("document.visibilityState")) != "hidden":
		return
	var events := _in_flight.duplicate()
	events.append_array(_queue)
	if events.is_empty():
		return
	_in_flight.clear()
	_queue.clear()
	# Text, not JSON, keeps the beacon a simple request that needs no preflight.
	JavaScriptBridge.eval("navigator.sendBeacon(%s, %s)" % [JSON.stringify(_endpoint), JSON.stringify(_batch_json(events.slice(0, BATCH_MAX)))])


func _load_settings() -> void:
	var parsed: Variant = null
	if FileAccess.file_exists(SETTINGS_PATH):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
	if parsed is Dictionary:
		_install_id = str(parsed.get("install_id", ""))
		enabled = bool(parsed.get("enabled", true))
	if _install_id.length() != 32:
		_install_id = _random_id()
		_save_settings()


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"install_id": _install_id, "enabled": enabled}, "\t"))
		file.close()


static func _random_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
