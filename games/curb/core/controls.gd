extends Node

## Registers every input action at startup, so project.godot carries no
## hand-serialized InputEvents. Keys go by physical position.

const KEYS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"move_up": [KEY_W, KEY_UP],
	&"move_down": [KEY_S, KEY_DOWN],
	&"jump": [KEY_SPACE, KEY_W, KEY_UP],
	## Swap whose head you are in.
	&"swap": [KEY_TAB, KEY_Q],
	## Open the other flatmate's script at a laptop.
	&"edit": [KEY_E],
	&"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	&"run": [KEY_R],
	&"pause": [KEY_ESCAPE, KEY_P],
}
const BUTTONS: Dictionary = {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"jump": [JOY_BUTTON_A],
	&"swap": [JOY_BUTTON_Y, JOY_BUTTON_RIGHT_SHOULDER],
	&"edit": [JOY_BUTTON_X],
	&"confirm": [JOY_BUTTON_A],
	&"run": [JOY_BUTTON_LEFT_SHOULDER],
	&"pause": [JOY_BUTTON_START],
}
const AXES: Dictionary = {
	&"move_left": [JOY_AXIS_LEFT_X, -1.0],
	&"move_right": [JOY_AXIS_LEFT_X, 1.0],
	&"move_up": [JOY_AXIS_LEFT_Y, -1.0],
	&"move_down": [JOY_AXIS_LEFT_Y, 1.0],
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


## "E", "X" or "tap": how prompts name an action for the current device.
static func label(action: StringName) -> String:
	if TouchControls.active:
		return {&"swap": "SWAP", &"edit": "CODE", &"jump": "JUMP"}.get(action, "tap")
	if not Input.get_connected_joypads().is_empty():
		return {&"swap": "Y", &"edit": "X", &"jump": "A", &"confirm": "A", &"run": "LB", &"pause": "Start"}.get(action, "?")
	return {&"swap": "Tab", &"edit": "E", &"jump": "Space", &"confirm": "Enter", &"run": "R", &"pause": "Esc"}.get(action, "?")
