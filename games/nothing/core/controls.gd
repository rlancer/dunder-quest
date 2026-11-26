extends Node

## Registers every input action at startup, so project.godot carries no
## hand-serialized InputEvents. Keys go by physical position.

const KEYS: Dictionary = {
	&"move_left": [KEY_LEFT],
	&"move_right": [KEY_RIGHT],
	&"move_up": [KEY_UP],
	&"move_down": [KEY_DOWN],
	## Put the card on the slip (or take it off), press the button, turn the page.
	&"confirm": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	## Take the last card back off the slip.
	&"erase": [KEY_BACKSPACE, KEY_DELETE],
	## Send the slip over the counter.
	&"send": [KEY_S],
	## Turn the right-hand panel between the counter's board and its response.
	&"turn": [KEY_TAB],
	&"pause": [KEY_ESCAPE],
}
const BUTTONS: Dictionary = {
	&"move_left": [JOY_BUTTON_DPAD_LEFT],
	&"move_right": [JOY_BUTTON_DPAD_RIGHT],
	&"move_up": [JOY_BUTTON_DPAD_UP],
	&"move_down": [JOY_BUTTON_DPAD_DOWN],
	&"confirm": [JOY_BUTTON_A],
	&"erase": [JOY_BUTTON_X],
	&"send": [JOY_BUTTON_Y],
	&"turn": [JOY_BUTTON_BACK],
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


## "Enter", "A" or "Tap": how prompts name the go-on button on this device.
static func go_key() -> String:
	if TouchControls.active:
		return "Tap"
	return "A" if not Input.get_connected_joypads().is_empty() else "Enter"
