class_name WizardQuiz
extends RefCounted

## One stage's wizard questions from its lesson in `data/lessons.json`.
## The wizard only asks about scrolls the player has read, so every question
## is one the stage had a chance to teach. Hands them out in a shuffled order
## and never repeats one until the pool runs dry.

var _all: Array[Dictionary] = []
var _pool: Array[Dictionary] = []
var _order: Array[int] = []
var _last: Dictionary = {}


static func for_stage(stage: int) -> WizardQuiz:
	var quiz := WizardQuiz.new()
	for entry: Dictionary in Lessons.stage(stage).get("questions", []):
		quiz._all.append(entry)
	if quiz._all.is_empty():
		push_error("No wizard questions for stage %d" % stage)
	return quiz


func size() -> int:
	return _all.size()


## Narrows the pool to questions about the scrolls in `known`. With none of
## them read, the wizard falls back to the whole lesson.
func focus(known: PackedStringArray) -> void:
	var pool: Array[Dictionary] = []
	for entry in _all:
		if known.has(str(entry.get("scroll", ""))):
			pool.append(entry)
	if pool.is_empty():
		pool = _all.duplicate()
	if pool != _pool:
		_pool = pool
		_order.clear()


## The next unseen question. A fresh shuffle starts once all have been asked,
## and never opens with the question that was just asked.
func next_question() -> Dictionary:
	if _pool.is_empty():
		_pool = _all.duplicate()
	if _pool.is_empty():
		return {}
	if _order.is_empty():
		for index in _pool.size():
			_order.append(index)
		_order.shuffle()
		if _order.size() > 1 and _pool[_order[0]] == _last:
			_order.append(_order.pop_front())
	_last = _pool[_order.pop_front()]
	return _last
