class_name WizardQuiz
extends RefCounted

## One stage's wizard questions from its lesson in `data/lessons.json`.
## The wizard asks about scrolls the player has read, so every question is
## one the stage had a chance to teach. Hands them out in a shuffled order
## that moves between scrolls, and never repeats one until the pool runs dry.

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


## Narrows the pool to questions about the scrolls in `known`. A trial needs
## at least `minimum` different questions; when the read scrolls can't supply
## that many, the wizard draws on the whole lesson instead.
func focus(known: PackedStringArray, minimum: int = 1) -> void:
	var pool: Array[Dictionary] = []
	for entry in _all:
		if known.has(str(entry.get("scroll", ""))):
			pool.append(entry)
	if pool.size() < mini(minimum, _all.size()) or pool.is_empty():
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
		_order = _spread_order()
		if _order.size() > 1 and _pool[_order[0]] == _last:
			_order.append(_order.pop_front())
	_last = _pool[_order.pop_front()]
	return _last


## A shuffled order that deals one question per scroll in turn, so questions
## in a row come from different scrolls whenever the pool allows it.
func _spread_order() -> Array[int]:
	var by_scroll: Dictionary = {}
	var shuffled: Array[int] = []
	for index in _pool.size():
		shuffled.append(index)
	shuffled.shuffle()
	for index in shuffled:
		var scroll := str(_pool[index].get("scroll", ""))
		if not by_scroll.has(scroll):
			by_scroll[scroll] = []
		(by_scroll[scroll] as Array).append(index)
	var order: Array[int] = []
	while order.size() < _pool.size():
		for scroll: String in by_scroll:
			var queue: Array = by_scroll[scroll]
			if not queue.is_empty():
				order.append(int(queue.pop_front()))
	return order
