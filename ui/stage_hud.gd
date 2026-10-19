class_name StageHud
extends CanvasLayer

var seed_count: int = 0
var cleared: bool = false


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


func show_clear() -> void:
	cleared = true
	%ClearPanel.show()
	%Hint.hide()


func is_cleared() -> bool:
	return cleared


func _hide_hint() -> void:
	if not cleared:
		%Hint.hide()
