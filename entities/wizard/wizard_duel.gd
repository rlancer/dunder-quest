class_name WizardDuel
extends Node2D

## The fight at the end of every stage: the lesson's quiz played as a boss.
##
## The node sits on the floor at the arena's left edge. Walking in raises a
## seal behind the player and the camera settles on the arena. The wizard
## asks a question from his stage's bank (the panel at the top shows the code
## and four lettered answers) and four answer blocks hang over the floor.
## The player answers by bumping a block from below. Right breaks a ward and
## staggers him; wrong cracks the block, gets the player zapped, and earns a
## fresh question. Once he has had a moment to let the question sink in, he
## keeps casting: ward waves along the floor to hop, and from Kiln Mouth on,
## hex strikes that mark a spot and then fall.
##
## The player carries three sparks through the fight. A spell, a zap, or
## walking into him costs one; with none left the player is knocked out and
## goes back to the lantern outside, the wards already broken stay broken,
## and walking back in starts the fight again. With every ward broken he is
## banished and both barriers fall.

signal won
## The player's sparks ran out; the stage knocks them out.
signal downed

const WIZARD := preload("res://entities/wizard/wizard.tscn")
const WARD_WAVE := preload("res://entities/wizard/ward_wave.gd")
const HEX_STRIKE := preload("res://entities/wizard/hex_strike.gd")
const RUNE_BLOCK := preload("res://entities/lesson/rune_block.gd")
const ARCANE_BARRIER := preload("res://entities/wizard/arcane_barrier.gd")
const ZAP := preload("res://assets/audio/break.wav")

## Floor-to-barrier width of the arena, and where things stand in it.
const WIDTH := 448.0
const BLOCK_XS: Array[float] = [72.0, 168.0, 264.0, 360.0]
## Block centers sit this far above the floor: a full jump bumps them.
const BLOCK_RISE := 72.0
const WIZARD_X := 412.0
## How far past the seal the player walks before the fight starts.
const ENGAGE_X := 30.0
const HEX_DROP := 88.0
const SPARKS := 3
const INVULNERABLE := 1.25
const INTRO_TIME := 1.6
const RIGHT_HOLD := 2.4
const WRONG_HOLD := 3.6
## Quiet time after a question appears, before spells start: a base plus a
## beat per line of code, so a longer snippet gets longer to read.
const READ_BASE := 2.2
const READ_PER_LINE := 0.7
const READ_MAX := 6.5
const LETTERS: Array[String] = ["A", "B", "C", "D"]
const GOOD := Color(0.5, 0.92, 0.6)
const BAD := Color(1.0, 0.46, 0.4)
## Per stage: seconds between spells, ward-wave speed, and whether hexes fall.
const PACE: Dictionary = {
	1: [3.4, 78.0, false],
	2: [3.1, 86.0, false],
	3: [2.9, 90.0, true],
	4: [2.7, 96.0, true],
	5: [2.5, 102.0, true],
	6: [2.3, 108.0, true],
}
const RIGHT_LINES: Array[String] = ["Hmph. Lucky.", "So you did read it.", "Grr... correct.", "A ward?! Again!"]
const WRONG_LINES: Array[String] = ["Wrong, little ember!", "Ha! Read it again.", "The scrolls weep.", "Not even close!"]

enum State { IDLE, INTRO, ASKING, VERDICT, WON }

var stage_id: int = 1
var title: String = "Dark Wizard"
var tint: Color = Color(0.55, 0.85, 1.0)
var taunt: String = ""
## Set by the stage before the duel enters the tree.
var hud: StageHud
var player: PlayerBody
## The stage's own camera bounds, restored when the fight ends.
var stage_bounds: Rect2i

var wizard: Wizard
var state: State = State.IDLE
var sparks: int = SPARKS
## Questions answered and missed over the whole visit, for the results.
var answers: int = 0
var misses: int = 0

var _seal: ArcaneBarrier
var _blocks: Array[RuneBlock] = []
var _quiz: WizardQuiz
var _question: Dictionary = {}
var _hint_level: int = 0
var _timer: float = 0.0
var _calm: float = 0.0
var _spell_clock: float = 0.0
var _spell_turn: int = 0
var _invulnerable: float = 0.0


func _ready() -> void:
	add_to_group(&"wizard_duel")
	wizard = WIZARD.instantiate() as Wizard
	wizard.title = title
	wizard.tint = tint
	wizard.taunt = taunt
	wizard.position = Vector2(WIZARD_X, 0.0)
	add_child(wizard)
	wizard.set_wards(Lessons.trial(stage_id))
	wizard.touched.connect(_on_wizard_touched)
	_seal = _build_seal()
	for index in LETTERS.size():
		var block := RUNE_BLOCK.new() as RuneBlock
		block.index = index
		block.label_text = LETTERS[index]
		block.tint = tint
		block.position = Vector2(BLOCK_XS[index], -BLOCK_RISE)
		add_child(block)
		# Kept apart from the stage's own gadget blocks, which share indexes.
		block.remove_from_group(&"rune_block")
		block.add_to_group(&"duel_block")
		block.bumped.connect(_on_block_bumped)
		_blocks.append(block)
	_quiz = WizardQuiz.for_stage(stage_id)
	if hud != null:
		hud.duel_hint_requested.connect(_on_hint_requested)


func _build_seal() -> ArcaneBarrier:
	var seal := ARCANE_BARRIER.new() as ArcaneBarrier
	seal.name = "Seal"
	seal.tint = tint
	seal.collision_layer = 1
	seal.collision_mask = 0
	seal.z_index = -2
	var glow := CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	seal.material = glow
	var wall := CollisionShape2D.new()
	wall.name = "Wall"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8.0, 256.0)
	wall.shape = rect
	wall.position = Vector2(0.0, -128.0)
	seal.add_child(wall)
	add_child(seal)
	seal.open_now()
	return seal


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			if _ready_to_engage():
				_engage()
		State.INTRO:
			_tick_guard(delta)
			_timer -= delta
			if _timer <= 0.0:
				_ask()
		State.ASKING:
			_tick_guard(delta)
			_calm -= delta
			if _calm <= 0.0:
				_spell_clock -= delta
				if _spell_clock <= 0.0:
					_cast_spell()
					_spell_clock = float(_pace()[0])
		State.VERDICT:
			_tick_guard(delta)
			_timer -= delta
			if _timer <= 0.0:
				if wizard.wards_left <= 0:
					_win()
				else:
					_ask()


func is_engaged() -> bool:
	return state == State.INTRO or state == State.ASKING or state == State.VERDICT


func is_asking() -> bool:
	return state == State.ASKING


func is_won() -> bool:
	return state == State.WON


## Test hook: the open question's right answer, or -1.
func answer_index() -> int:
	return int(_question.get("answer", -1)) if state == State.ASKING else -1


func question() -> Dictionary:
	return _question


func block(index: int) -> RuneBlock:
	return _blocks[index] if index >= 0 and index < _blocks.size() else null


## World x of the arena's left seal and right barrier.
func arena_span() -> Vector2:
	return Vector2(global_position.x, global_position.x + WIZARD_X + 16.0)


## Stops the fight without a winner: the player was knocked out or the stage
## restarted. Spells vanish, the seal drops and the camera lets go. The wards
## already broken stay broken.
func call_off() -> void:
	if not is_engaged():
		return
	state = State.IDLE
	_question = {}
	_clear_spells()
	_seal.open_now()
	for answer_block in _blocks:
		answer_block.set_cracked(false)
		answer_block.set_lit(false)
	_restore_view()
	if hud != null:
		hud.close_duel()


## Removes the whole encounter at once, with no fight and no effects.
## Route checks use this to measure the level alone.
func dismiss() -> void:
	call_off()
	state = State.WON
	wizard.dismiss()
	for answer_block in _blocks:
		answer_block.dismiss()


func _ready_to_engage() -> bool:
	if player == null or wizard.banished or player.is_dead() or not player.controls_enabled:
		return false
	var x := player.global_position.x - global_position.x
	return x > ENGAGE_X and x < WIZARD_X - 20.0 and player.is_on_floor()


func _engage() -> void:
	state = State.INTRO
	_timer = INTRO_TIME
	sparks = SPARKS
	_invulnerable = 0.0
	_spell_turn = 0
	_seal.rise()
	player.set_camera_bounds(Rect2i(int(global_position.x) - 16, stage_bounds.position.y, 480, stage_bounds.size.y))
	wizard.say("Bump your answer, if you dare!" if wizard.wards_left == wizard.ward_total else "Back for more?", INTRO_TIME + 0.6)
	if hud != null:
		hud.open_duel(title, tint, wizard.ward_total - wizard.wards_left, wizard.ward_total, sparks)
		hud.duel_say("%s seals the arena. Bump the block with the right answer, and jump his spells." % title)


func _ask() -> void:
	_quiz.focus(GameProgression.known_scrolls(stage_id), wizard.ward_total)
	_question = _quiz.next_question()
	if _question.is_empty():
		# No bank to ask from: the wizard steps aside rather than trap the run.
		_win()
		return
	_hint_level = 0
	for answer_block in _blocks:
		answer_block.set_cracked(false)
		answer_block.set_lit(false)
	var step := wizard.ward_total - wizard.wards_left + 1
	var lines := str(_question.get("code", "")).count("\n") + 1
	_calm = minf(READ_BASE + READ_PER_LINE * float(lines), READ_MAX)
	_spell_clock = 0.0
	state = State.ASKING
	if hud != null:
		hud.duel_question(_question, step, wizard.ward_total)


func _on_block_bumped(answer_block: RuneBlock) -> void:
	if state != State.ASKING or answer_block.cracked:
		return
	answers += 1
	var correct := answer_block.index == int(_question.get("answer", -1))
	var remaining := wizard.wards_left
	var above := answer_block.global_position + Vector2(-10.0, -14.0)
	if correct:
		remaining = wizard.break_ward()
		answer_block.flash(GOOD)
		answer_block.set_lit(true)
		wizard.stagger()
		wizard.say(RIGHT_LINES.pick_random() if remaining > 0 else "No... NO!", RIGHT_HOLD)
		Fx.float_text(get_parent(), above, "Ward broken!", GOOD.lightened(0.3))
		Fx.sparks(get_parent(), answer_block.global_position, GOOD, 12, 70.0)
		player.camera.shake(3.0)
		Fx.hitstop(get_tree(), 0.07)
		_timer = RIGHT_HOLD
	else:
		misses += 1
		answer_block.flash(BAD)
		answer_block.set_cracked(true)
		wizard.say(WRONG_LINES.pick_random(), WRONG_HOLD)
		wizard.zap(player)
		_hurt(Vector2(-140.0 if player.global_position.x > answer_block.global_position.x else 140.0, -200.0), true)
		_timer = WRONG_HOLD
	state = State.VERDICT
	if hud != null:
		hud.duel_verdict(answer_block.index, correct, remaining)


## The wizard helps, grudgingly and never outright. The first hint is his
## riddle for the question plus the scroll it draws on: its lesson if the
## player read it, a jab if they walked past it. The second, he looks away
## from one wrong answer, and its block cracks. There is no third.
func _on_hint_requested() -> void:
	if state != State.ASKING or _hint_level >= 2:
		return
	_hint_level += 1
	if hud != null:
		hud.note_hint()
	var scroll := Lessons.scroll(str(_question.get("scroll", "")))
	var scroll_title := str(scroll.get("title", "the old ways"))
	var detail := "Had you read the scroll %s on the trail, you would not need to ask." % scroll_title
	if GameProgression.knows_scroll(str(scroll.get("id", ""))):
		detail = "Your scroll, %s: %s" % [scroll_title, scroll.get("insight", "")]
	if _hint_level == 1:
		if hud != null:
			hud.duel_hint("\"%s\"" % _question.get("hint", "Think."), detail, -1, true)
		return
	var wrong: Array[int] = []
	var answer := int(_question.get("answer", -1))
	for answer_block in _blocks:
		if answer_block.index != answer and not answer_block.cracked:
			wrong.append(answer_block.index)
	if wrong.is_empty():
		return
	var dim: int = wrong.pick_random()
	_blocks[dim].set_cracked(true)
	if hud != null:
		hud.duel_hint("%s's eyes slide away from %s... He says no more." % [title, LETTERS[dim]], detail, dim, false)


func _win() -> void:
	state = State.WON
	_question = {}
	_clear_spells()
	wizard.banish()
	_seal.dissolve()
	# The answer blocks were his; they crumble with him.
	for answer_block in _blocks:
		Fx.sparks(get_parent(), answer_block.global_position, tint, 8, 50.0)
		Fx.dust(get_parent(), answer_block.global_position, 6)
		answer_block.dismiss()
	_restore_view()
	if hud != null:
		hud.close_duel()
	won.emit()


func _pace() -> Array:
	return PACE.get(stage_id, PACE[1])


func _cast_spell() -> void:
	var pace := _pace()
	wizard.cast()
	if bool(pace[2]) and _spell_turn % 2 == 1:
		_cast_hex(player.global_position.x)
	else:
		_cast_wave(float(pace[1]))
	_spell_turn += 1


func _cast_wave(speed: float) -> void:
	var wave := WARD_WAVE.new() as WardWave
	wave.tint = tint
	wave.speed = speed
	wave.direction = -1.0
	wave.stop_x = global_position.x + 10.0
	wave.position = Vector2(WIZARD_X - 14.0, 0.0)
	add_child(wave)
	wave.hit.connect(_on_spell_hit)


func _cast_hex(at_x: float) -> void:
	var hex := HEX_STRIKE.new() as HexStrike
	hex.tint = tint
	hex.drop = HEX_DROP
	var local_x := clampf(at_x - global_position.x, 20.0, WIZARD_X - 30.0)
	hex.position = Vector2(local_x, -HEX_DROP)
	add_child(hex)
	hex.hit.connect(_on_spell_hit)


func _clear_spells() -> void:
	for child in get_children():
		if child.is_in_group(&"duel_spell"):
			child.queue_free()


func _on_spell_hit(spell: Node2D, body: Node2D) -> void:
	if body != player or not is_engaged():
		return
	var away := signf(player.global_position.x - spell.global_position.x)
	_hurt(Vector2((away if away != 0.0 else -1.0) * 150.0, -210.0))


func _on_wizard_touched(body: Node2D) -> void:
	if body == player and is_engaged():
		_hurt(Vector2(-230.0, -220.0))


## One spark gone, a shove, and a moment of grace. The last spark knocks the
## player out. A zap for a wrong answer always lands, even mid-grace.
func _hurt(push: Vector2, zap: bool = false) -> void:
	if player.is_dead() or (_invulnerable > 0.0 and not zap):
		return
	sparks = maxi(sparks - 1, 0)
	_invulnerable = INVULNERABLE
	player.knock(push)
	if not zap:
		StageAudio.play(get_tree(), ZAP)
	Fx.sparks(get_parent(), player.global_position, BAD, 10, 60.0)
	if hud != null:
		hud.duel_sparks(sparks)
	if sparks <= 0:
		_clear_spells()
		downed.emit()


func _tick_guard(delta: float) -> void:
	_invulnerable = maxf(_invulnerable - delta, 0.0)
	if player.is_dead():
		return
	var blink := _invulnerable > 0.0 and int(_invulnerable * 16.0) % 2 == 0
	player.sprite.modulate.a = 0.35 if blink else 1.0


func _restore_view() -> void:
	if player != null:
		player.sprite.modulate.a = 1.0
		player.set_camera_bounds(stage_bounds)
