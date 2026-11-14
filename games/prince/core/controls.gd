extends Node

## Registers every input action at startup, so project.godot carries no
## hand-serialized InputEvents. Keys go by physical position.

const KEYS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"jump": [KEY_SPACE, KEY_W, KEY_UP],
	## Draw (or sheathe) the Dagger of HEAD: the git console.
	&"dagger": [KEY_Q, KEY_TAB, KEY_E],
	&"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	&"pause": [KEY_ESCAPE, KEY_P],
}
const BUTTONS: Dictionary = {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"jump": [JOY_BUTTON_A],
	&"dagger": [JOY_BUTTON_Y, JOY_BUTTON_X],
	&"confirm": [JOY_BUTTON_A],
	&"pause": [JOY_BUTTON_START],
}
const AXES: Dictionary = {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
}


func _init() -> void:
	for action: StringName in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		for key: Key in KEYS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: StringName in BUTTONS:
		for button: JoyButton in BUTTONS[action]:
			var event := InputEventJoypadButton.new()
			event.button_index = button
			InputMap.action_add_event(action, event)
	for action: StringName in AXES:
		var event := InputEventJoypadMotion.new()
		event.axis = AXES[action][0]
		event.axis_value = AXES[action][1]
		InputMap.action_add_event(action, event)


func _ready() -> void:
	# Buttons and labels get the ligature-free Pixelify too.
	ThemeDB.get_project_theme().default_font = Palette.pixel()


## "Q", "Y" or "DAGGER": how prompts name an action for the current device.
static func label(action: StringName) -> String:
	if TouchControls.active:
		return {&"dagger": "DAGGER", &"jump": "JUMP"}.get(action, "tap")
	if not Input.get_connected_joypads().is_empty():
		return {&"dagger": "Y", &"jump": "A", &"confirm": "A", &"pause": "Start"}.get(action, "?")
	return {&"dagger": "Q", &"jump": "Space", &"confirm": "Enter", &"pause": "Esc"}.get(action, "?")
