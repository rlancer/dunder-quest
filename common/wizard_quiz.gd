class_name WizardQuiz
extends RefCounted

## One stage's pool of wizard questions from `data/wizard_questions.json`.
## Hands them out in a shuffled order and never repeats one until the pool
## runs dry. `tools/verify_quiz.py` checks every marked answer against Python.

const BANK_PATH := "res://data/wizard_questions.json"

var _pool: Array[Dictionary] = []
var _order: Array[int] = []
var _last: int = -1


static func for_stage(stage: int) -> WizardQuiz:
	var quiz := WizardQuiz.new()
	var text := FileAccess.get_file_as_string(BANK_PATH)
	var bank: Variant = JSON.parse_string(text)
	if typeof(bank) != TYPE_DICTIONARY:
		push_error("Wizard question bank is missing or malformed")
		return quiz
	for entry: Variant in (bank as Dictionary).get(str(stage), []):
		if typeof(entry) == TYPE_DICTIONARY:
			quiz._pool.append(_normalized(entry as Dictionary))
	if quiz._pool.is_empty():
		push_error("No wizard questions for stage %d" % stage)
	return quiz


func size() -> int:
	return _pool.size()


## The next unseen question. A fresh shuffle starts once all have been asked,
## and never opens with the question that was just asked.
func next_question() -> Dictionary:
	if _pool.is_empty():
		return {}
	if _order.is_empty():
		for index in _pool.size():
			_order.append(index)
		_order.shuffle()
		if _order.size() > 1 and _order[0] == _last:
			_order.append(_order.pop_front())
	_last = _order.pop_front()
	return _pool[_last]


static func _normalized(entry: Dictionary) -> Dictionary:
	var lines: PackedStringArray = []
	for line: Variant in entry.get("code", []):
		lines.append(str(line))
	var options: PackedStringArray = []
	for option: Variant in entry.get("options", []):
		options.append(str(option))
	return {
		"code": "\n".join(lines),
		"prompt": str(entry.get("prompt", "What does this print?")),
		"options": options,
		"answer": int(entry.get("answer", 0)),
		"explanation": str(entry.get("explanation", "")),
	}
