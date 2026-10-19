class_name StageHud
extends CanvasLayer

var seed_count: int = 0
var cleared: bool = false
var waiting_for_start: bool = false


func _ready() -> void:
	add_to_group(&"stage_hud")
	var timer := Timer.new()
	timer.wait_time = 4.0
	timer.one_shot = true
	timer.timeout.connect(_hide_hint)
	add_child(timer)
	timer.start()


func note_seed() -> void:
	seed_count += 1
	%SeedCount.text = "Emberseeds %d" % seed_count


func show_press_to_start() -> void:
	waiting_for_start = true
	%Hint.text = "Press any key to play"
	%Hint.show()


func hide_press_to_start() -> void:
	waiting_for_start = false
	if not cleared:
		%Hint.hide()


func show_clear() -> void:
	cleared = true
	waiting_for_start = false
	%ClearPanel.show()
	%Hint.hide()


func is_cleared() -> bool:
	return cleared


func _hide_hint() -> void:
	if not cleared and not waiting_for_start:
		%Hint.hide()
