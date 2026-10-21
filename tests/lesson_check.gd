extends Node

## Drives each stage's lesson pieces with real bodies and real input events:
## Amber Hollow  - a scroll card pauses and resumes play, a known scroll does
##                 not, the index row pays out only for row[2], and the duel:
##                 walking in seals the arena and holds the clock, the wizard
##                 asks about read scrolls, a thin pool widens to the whole
##                 lesson, both hint tiers (the second cracks a wrong block),
##                 a wrong bump costs a spark and brings a new question, each
##                 right bump breaks a ward, spells hurt, and losing every
##                 spark knocks the player out with the wards kept. Then the
##                 Spellbook pages.
## Cinder Span   - buckets refuse without keys and for the wrong key, keys go
##                 into hash(key) % 4, and the door opens once both are stored.
## Kiln Mouth    - each forge loads its range into the lift, which runs only
##                 when ridden, one notch per lap, and a new loop sinks it first.
## godot --headless --path . res://tests/lesson_check.tscn   ->  LESSON result=ok

const AMBER := preload("res://levels/level_01.tscn")
const SPAN := preload("res://levels/level_02.tscn")
const KILN := preload("res://levels/level_03.tscn")
const FLOOR_Y := 214.0

var _fails: PackedStringArray = []
var _stage: StageLevel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameProgression.persist = false
	GameProgression.came_from_map = false
	GameProgression.load_data()
	StageAudio.web_audio_unlocked = true
	_run.call_deferred()


func _run() -> void:
	await _check_amber()
	await _check_span()
	await _check_kiln()
	for fail in _fails:
		print("LESSON fail ", fail)
	print("LESSON result=%s fails=%d" % ["ok" if _fails.is_empty() else "fail", _fails.size()])
	get_tree().quit(0 if _fails.is_empty() else 1)


func _check_amber() -> void:
	await _open(AMBER)
	var hud := _stage.hud
	# Walk into the first scroll.
	_place(Vector2(40.0, FLOOR_Y))
	Input.action_press(&"move_right")
	await _until(func() -> bool: return hud.is_card_open(), 90)
	Input.action_release(&"move_right")
	_expect(hud.is_card_open(), "scroll opens its card")
	_expect(hud.card_title() == "Counting from Zero", "card shows the scroll (got %s)" % hud.card_title())
	_expect(get_tree().paused, "card pauses the stage")
	_expect(GameProgression.knows_scroll("list_zero"), "scroll is learned")
	var held_x := _stage.player.global_position.x
	await _frames(10)
	_expect(is_equal_approx(_stage.player.global_position.x, held_x), "player holds still under the card")
	await _tap(&"confirm")
	await _frames(25)
	await _tap(&"confirm")
	await _frames(3)
	_expect(not hud.is_card_open() and not get_tree().paused, "confirm closes the card and resumes")
	_expect(hud.scroll_found == 1 and hud.scroll_total == 4, "scroll count 1/4 (got %d/%d)" % [hud.scroll_found, hud.scroll_total])

	# The index row: a wrong block pays nothing, row[2] pops the bonus scroll.
	var before := _scroll_count()
	_block(1).receive_head_bump()
	await _frames(2)
	_expect(_scroll_count() == before and _block(1).label_text == "1", "row[1] reveals its index and holds nothing")
	_block(2).receive_head_bump()
	await _frames(2)
	_expect(_scroll_count() == before + 1, "row[2] releases a scroll")
	_expect(_block(2).lit, "row[2] lights")
	_block(2).receive_head_bump()
	await _frames(2)
	_expect(_scroll_count() == before + 1, "row[2] pays out once")
	var bonus := _scroll("list_change")
	_expect(bonus != null and not bonus.monitoring, "bonus scroll is dormant while it rises")
	await _frames(70)
	_expect(bonus != null and is_instance_valid(bonus) and bonus.monitoring, "bonus scroll wakes on the floor")

	# A scroll already in the Spellbook is picked up without a card.
	GameProgression.learn_scroll("list_negative")
	_place(Vector2(488.0, FLOOR_Y - 32.0))
	await _frames(4)
	_expect(not hud.is_card_open(), "a known scroll opens no card")
	_expect(_scroll("list_negative") == null, "a known scroll is still picked up")

	# Walking into the arena seals it and starts the duel.
	GameProgression.learn_scroll("list_slice")
	var duel := _stage.duel()
	var wizard := duel.wizard
	_expect(wizard.ward_total == Lessons.trial(1) and Lessons.trial(1) == 3, "the Ash Hexer's trial is three questions")
	_place(Vector2(duel.global_position.x + 80.0, FLOOR_Y))
	await _until(func() -> bool: return duel.is_asking(), 180)
	_expect(duel.is_asking() and hud.is_duel_open(), "the duel opens its question strip")
	var seal := duel.get_node(^"Seal") as ArcaneBarrier
	_expect(not seal.is_open(), "the seal rises behind the player")
	var clock := float(_stage.get(&"_elapsed"))
	await _frames(30)
	_expect(is_equal_approx(float(_stage.get(&"_elapsed")), clock), "the clock holds during the duel")
	var question := duel.question()
	_expect(GameProgression.knows_scroll(str(question.get("scroll", ""))), "question draws on a read scroll (%s)" % question.get("scroll", ""))
	_expect(hud.duel_status() == str(question.get("prompt", "")), "the strip shows the prompt (got %s)" % hud.duel_status())

	var narrow := WizardQuiz.for_stage(1)
	narrow.focus(PackedStringArray(["list_zero"]))
	var only_zero := true
	for _ask in 12:
		only_zero = only_zero and narrow.next_question().get("scroll") == "list_zero"
	_expect(only_zero, "a focused quiz asks only about the scrolls read")
	var spread := WizardQuiz.for_stage(1)
	spread.focus(PackedStringArray(["list_zero", "list_negative", "list_slice"]), 3)
	var dealt := {}
	for _ask in 3:
		dealt[str(spread.next_question().get("scroll"))] = true
	_expect(dealt.size() == 3, "a trial's questions come from different scrolls (%d)" % dealt.size())
	var thin := WizardQuiz.for_stage(1)
	thin.focus(PackedStringArray(["list_slice"]), 3)
	var widened := false
	for _ask in 10:
		widened = widened or thin.next_question().get("scroll") != "list_slice"
	_expect(widened, "too few read questions for a trial widens to the whole lesson")

	# Hint one: the riddle and the scroll. Hint two: a wrong block cracks.
	await _tap(&"hint")
	var speech := hud.duel_speech()
	_expect(speech.contains(str(question.get("hint", "?"))), "first hint whispers the riddle")
	var scroll_title := str(Lessons.scroll(str(question.get("scroll", ""))).get("title", "?"))
	_expect(speech.contains(scroll_title), "first hint names the scroll")
	_expect(hud.duel_dimmed().is_empty() and _cracked(duel).is_empty(), "first hint cracks nothing")
	await _tap(&"hint")
	var cracked := _cracked(duel)
	_expect(cracked.size() == 1 and cracked[0] != duel.answer_index(), "second hint cracks one wrong block")
	_expect(hud.duel_dimmed() == cracked, "the strip dims the same answer")
	await _tap(&"hint")
	_expect(_cracked(duel).size() == 1 and hud.hints_used == 2, "no third hint (used %d)" % hud.hints_used)
	duel.block(cracked[0]).receive_head_bump()
	await _frames(2)
	_expect(duel.is_asking() and duel.answers == 0, "a cracked block is no answer")

	# A wrong bump: zapped, a spark gone, the block cracked, a fresh question.
	var first_code := str(question.get("code", ""))
	var wrong := posmod(duel.answer_index() + 1, 4)
	if wrong == cracked[0]:
		wrong = posmod(wrong + 1, 4)
	duel.block(wrong).receive_head_bump()
	await _frames(2)
	_expect(not duel.is_asking() and duel.sparks == WizardDuel.SPARKS - 1, "a wrong answer costs a spark (left %d)" % duel.sparks)
	_expect(duel.block(wrong).cracked and wizard.wards_left == 3, "a wrong answer cracks its block and breaks no ward")
	_expect(hud.duel_status().begins_with("Zapped!"), "the strip says zapped (got %s)" % hud.duel_status())
	await _until(func() -> bool: return duel.is_asking(), 400)
	_expect(str(duel.question().get("code", "")) != first_code, "a different question follows")
	_expect(_cracked(duel).is_empty(), "blocks mend for the new question")

	# A right bump breaks one ward; the barrier holds while wards remain.
	duel.block(duel.answer_index()).receive_head_bump()
	await _frames(4)
	_expect(wizard.wards_left == 2, "one right answer breaks one ward (left %d)" % wizard.wards_left)
	_expect(not wizard.barrier_open(), "the barrier holds while wards remain")
	await _until(func() -> bool: return duel.is_asking(), 400)

	# His spells hurt once per grace period; the last spark knocks the player out.
	var falls := hud.falls
	await _frames(int(WizardDuel.INVULNERABLE * 60.0) + 4)
	duel.call(&"_on_spell_hit", _stage.player, _stage.player)
	duel.call(&"_on_spell_hit", _stage.player, _stage.player)
	_expect(duel.sparks == WizardDuel.SPARKS - 2, "a spell costs one spark, then grace (left %d)" % duel.sparks)
	await _frames(int(WizardDuel.INVULNERABLE * 60.0) + 4)
	duel.call(&"_on_spell_hit", _stage.player, _stage.player)
	await _until(func() -> bool: return hud.falls > falls, 30)
	_expect(hud.falls == falls + 1 and not duel.is_engaged(), "the last spark knocks the player out")
	await _until(func() -> bool: return not _stage.player.is_dead() and _stage.player.controls_enabled and _stage.player.global_position.x < duel.global_position.x, 180)
	_expect(seal.is_open() and not hud.is_duel_open(), "a knockout drops the seal and the strip")
	_expect(_stage.player.global_position.x < duel.global_position.x, "the player wakes at the lantern outside")
	_expect(wizard.wards_left == 2, "broken wards stay broken (left %d)" % wizard.wards_left)

	# Walking back in starts again with full sparks; two right answers end it.
	_place(Vector2(duel.global_position.x + 80.0, FLOOR_Y))
	await _until(func() -> bool: return duel.is_asking(), 240)
	_expect(duel.sparks == WizardDuel.SPARKS, "sparks refill for a new attempt")
	for _round in 2:
		await _until(func() -> bool: return duel.is_asking(), 400)
		duel.block(duel.answer_index()).receive_head_bump()
		await _frames(2)
	await _until(func() -> bool: return duel.is_won(), 400)
	_expect(wizard.banished and wizard.barrier_open() and seal.is_open(), "the last ward banishes the wizard and opens both walls")
	_expect(not hud.is_duel_open(), "the strip closes")

	# The Spellbook opens from pause on this stage's scrolls and pages through them.
	await _frames(20)
	await _tap(&"pause")
	_expect(hud.is_paused(), "pause opens")
	hud.call(&"_open_spellbook")
	await _frames(2)
	_expect(hud.is_spellbook_open() and hud.is_card_open(), "Spellbook opens")
	var first := hud.card_title()
	await _tap(&"move_right")
	_expect(hud.card_title() != first, "Spellbook pages forward")
	await _tap(&"pause")
	_expect(not hud.is_spellbook_open() and hud.is_paused(), "Esc closes the Spellbook back to pause")
	await _tap(&"pause")
	_expect(not get_tree().paused, "pause closes")


func _check_span() -> void:
	await _open(SPAN)
	var door := get_tree().get_first_node_in_group(&"vault_door") as VaultDoor
	_expect(door != null and not door.is_open(), "vault starts shut")
	var buckets: Array[int] = _stage.call(&"vault_buckets")
	_expect(buckets == [RuneKey.rune_hash("ash") % 4, RuneKey.rune_hash("ember") % 4], "vault buckets follow the rune hash")
	_expect(buckets[0] != buckets[1], "the two keys hash to different buckets")
	_block(buckets[0]).receive_head_bump()
	await _frames(2)
	_expect(door.lit_locks() == 0, "a bucket refuses without a key")

	await _collect_key("ash")
	var wrong := posmod(buckets[0] + 1, 4)
	if wrong == buckets[1]:
		wrong = posmod(wrong + 1, 4)
	_block(wrong).receive_head_bump()
	await _frames(2)
	_expect(door.lit_locks() == 0 and not _block(wrong).lit, "the wrong bucket is a KeyError")
	_block(buckets[0]).receive_head_bump()
	await _frames(2)
	_expect(door.lit_locks() == 1 and _block(buckets[0]).lit, "ash goes into its bucket")
	_block(buckets[1]).receive_head_bump()
	await _frames(2)
	_expect(door.lit_locks() == 1, "ember's bucket waits for its key")

	await _collect_key("ember")
	_block(buckets[1]).receive_head_bump()
	await _frames(2)
	_expect(door.is_open(), "both keys stored open the vault")
	_place(Vector2(door.global_position.x - 30.0, FLOOR_Y))
	Input.action_press(&"move_right")
	await _frames(30)
	Input.action_release(&"move_right")
	_expect(_stage.player.global_position.x > door.global_position.x, "the player walks through the open vault")


func _check_kiln() -> void:
	await _open(KILN)
	var hud := _stage.hud
	_expect(hud.seed_total == int(GameProgression.get_stage_data(3).get("max_seeds", 0)), "seed total matches the map (%d)" % hud.seed_total)
	var lift := _stage.call(&"lift") as KilnLift
	_place(Vector2(lift.global_position.x, FLOOR_Y))
	await _frames(30)
	_expect(lift.state == KilnLift.State.REST, "an empty lift stays put")
	_place(Vector2(lift.global_position.x - 80.0, FLOOR_Y))
	_block(0).receive_head_bump()
	await _frames(4)
	_expect(lift.values == [1, 4, 7] and lift.state == KilnLift.State.REST, "forge A loads range(1, 9, 3): %s" % [lift.values])
	await _frames(30)
	_expect(lift.height() == 0.0, "a loaded lift waits to be ridden")
	_place(Vector2(lift.global_position.x, FLOOR_Y))
	await _until(func() -> bool: return lift.is_topped(), 240)
	_expect(lift.is_topped() and is_equal_approx(lift.height(), KilnLift.LAP_RISE * 3.0), "three laps raise three notches (%.0f)" % lift.height())
	_block(1).receive_head_bump()
	await _frames(2)
	_expect(lift.values == [0, 1, 2, 3] and lift.state == KilnLift.State.SINKING, "loading range(4) sinks the lift first")
	await _until(func() -> bool: return lift.is_topped(), 400)
	_expect(is_equal_approx(lift.height(), KilnLift.LAP_RISE * 4.0), "four laps raise four notches (%.0f)" % lift.height())


func _collect_key(key_name: String) -> void:
	var key: RuneKey = null
	for node in get_tree().get_nodes_in_group(&"rune_key"):
		if (node as RuneKey).key_name == key_name and _stage.is_ancestor_of(node):
			key = node
	_expect(key != null, "key %s exists" % key_name)
	if key == null:
		return
	_place(Vector2(key.global_position.x, FLOOR_Y))
	await _until(func() -> bool: return _stage.hud.is_card_open(), 30)
	_expect(_stage.hud.card_title() == "The key \"%s\"" % key_name, "key %s shows its card" % key_name)
	await _frames(25)
	await _tap(&"confirm")
	await _frames(3)
	_expect(not _stage.hud.is_card_open(), "key card closes")
	_place(Vector2(_block(0).global_position.x, FLOOR_Y))
	await _frames(2)


func _open(packed: PackedScene) -> void:
	if _stage != null:
		_stage.queue_free()
		await _frames(2)
	get_tree().paused = false
	_stage = packed.instantiate() as StageLevel
	_stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_stage)
	await _frames(10)


func _place(at: Vector2) -> void:
	_stage.player.global_position = at
	_stage.player.velocity = Vector2.ZERO


func _cracked(duel: WizardDuel) -> Array:
	var found: Array = []
	for index in 4:
		if duel.block(index).cracked:
			found.append(index)
	return found


func _block(index: int) -> RuneBlock:
	for node in get_tree().get_nodes_in_group(&"rune_block"):
		var block := node as RuneBlock
		if block.index == index and _stage.is_ancestor_of(block):
			return block
	return null


func _scroll(scroll_id: String) -> LoreScroll:
	for node in get_tree().get_nodes_in_group(&"lore_scroll"):
		var scroll := node as LoreScroll
		if scroll.scroll_id == scroll_id and not scroll.taken and _stage.is_ancestor_of(scroll):
			return scroll
	return null


func _scroll_count() -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(&"lore_scroll"):
		if _stage.is_ancestor_of(node) and not node.is_queued_for_deletion():
			count += 1
	return count


func _seed_xs() -> Array[float]:
	var xs: Array[float] = []
	for node in get_tree().get_nodes_in_group(&"emberseed"):
		if _stage.is_ancestor_of(node) and not node.is_queued_for_deletion():
			xs.append((node as Node2D).global_position.x)
	return xs


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _until(condition: Callable, limit: int) -> void:
	for _index in limit:
		if condition.call():
			return
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(2)
	var release := InputEventAction.new()
	release.action = action
	Input.parse_input_event(release)
	await _frames(2)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_fails.append(label)
