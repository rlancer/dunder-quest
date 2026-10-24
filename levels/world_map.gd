class_name WorldMap
extends Node2D

## World Map navigation for the Cinder Realm stages.
## Supports keyboard (WASD / Arrows / Space / Enter / Esc), gamepad, and mouse selection.

const MUSIC_STREAM := preload("res://assets/audio/music_march.ogg")
## Every hop along the trail is a coconut clop: the squire's horse.
const HOP_SOUND := preload("res://assets/audio/coconut.wav")
const ENTER_SOUND := preload("res://assets/audio/goal.wav")
const REJECT_SOUND := preload("res://assets/audio/bump.wav")
const UNLOCK_SOUND := preload("res://assets/audio/pickup.wav")

## Stage markers, each on its landmark in the map art: the wood, the village
## market, the cave, the ministry, the rope bridge and the castle. The map art
## paints no trail, so every segment is drawn at runtime.
const STAGE_POSITIONS: Dictionary = {
	1: Vector2(60.0, 160.0),
	2: Vector2(130.0, 132.0),
	3: Vector2(430.0, 150.0),
	4: Vector2(400.0, 88.0),
	5: Vector2(250.0, 98.0),
	6: Vector2(96.0, 58.0),
}
## Bezier control for the hop path from each stage to the next.
const PATH_CONTROLS: Dictionary = {
	1: Vector2(92.0, 156.0),
	2: Vector2(280.0, 152.0),
	3: Vector2(444.0, 116.0),
	4: Vector2(326.0, 80.0),
	5: Vector2(170.0, 66.0),
}
## Segments (by their first stage) whose trail the map art already paints.
const PAINTED_SEGMENTS: Array[int] = []
const PATH_STEPS := 7
const TRAIL_DARK := Color(0.12, 0.07, 0.08, 0.85)
const TRAIL_DIRT := Color(0.62, 0.42, 0.24, 0.9)

@onready var stage_audio: StageAudio = %StageAudio
@onready var path_drawer: Node2D = %PathDrawer
@onready var pebble_avatar: Node2D = %PebbleAvatar
@onready var pebble_sprite: Sprite2D = %PebbleSprite
@onready var stage_title_label: Label = %StageTitle
@onready var stage_subtitle_label: Label = %StageSubtitle
@onready var stage_status_label: Label = %StageStatus
@onready var stage_seeds_label: Label = %StageSeeds
@onready var enter_prompt_label: Label = %EnterPrompt
@onready var total_seeds_label: Label = %TotalSeeds
@onready var fade_rect: ColorRect = %FadeRect
@onready var stage_card_button: Button = %StageCardButton

var selected_stage_id: int = 1
var is_moving: bool = false
var is_entering: bool = false
var anim_time: float = 0.0
var _particles: Array[Dictionary] = []
var _unlock_anim_t: float = -1.0
var _unlock_from_id: int = 0
## Letters typed so far, for the Knights Who Say Ni (see `Eggs`).
var _typed: String = ""


func _ready() -> void:
	GameProgression.load_data()
	selected_stage_id = clampi(GameProgression.current_stage_id, 1, GameProgression.get_stage_count())
	if not GameProgression.is_unlocked(selected_stage_id):
		selected_stage_id = 1
	GameProgression.current_stage_id = selected_stage_id

	_init_particles()
	_update_pebble_position_instant()
	_update_nodes_appearance()
	_update_ui()
	_start_music()

	fade_rect.modulate = Color(0, 0, 0, 1)
	var fade_in := create_tween()
	fade_in.tween_property(fade_rect, "modulate:a", 0.0, 0.3)

	if GameProgression.just_cleared_id > 0:
		var cleared_id := GameProgression.just_cleared_id
		GameProgression.just_cleared_id = 0
		GameProgression.save_data()
		_celebrate_clear(cleared_id)


func _process(delta: float) -> void:
	anim_time += delta
	_update_particles(delta)
	path_drawer.queue_redraw()

	if not is_moving and not is_entering:
		var bob := sin(anim_time * 6.0) * 1.5
		pebble_sprite.position.y = -10.0 + bob

	_animate_cleared_seeds()

	if _unlock_anim_t >= 0.0:
		_unlock_anim_t = minf(_unlock_anim_t + delta * 2.0, 1.0)
		if _unlock_anim_t >= 1.0:
			_unlock_anim_t = -1.0


func _unhandled_input(event: InputEvent) -> void:
	if is_moving or is_entering:
		return
	_typed = Eggs.spell(_typed, event, "NI")
	if _typed == "NI":
		_typed = ""
		_knights_say_ni()
		return

	if event.is_action_pressed(&"move_left") or _is_key(event, KEY_A) or _is_key(event, KEY_LEFT):
		_navigate_step(-1)
	elif event.is_action_pressed(&"move_right") or _is_key(event, KEY_D) or _is_key(event, KEY_RIGHT):
		_navigate_step(1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"confirm") or _is_key(event, KEY_KP_ENTER):
		_try_enter_stage()
	elif event.is_action_pressed(&"pause"):
		_back_to_title()
	elif OS.is_debug_build():
		_debug_stage_skip(event)


## Debug builds only: number keys 1-9 drop straight into that stage, locked
## or not, without touching the save. Release exports never reach this.
func _debug_stage_skip(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: Key = event.physical_keycode
	var stage_id := int(key) - int(KEY_0)
	if stage_id < 1 or stage_id > mini(GameProgression.get_stage_count(), 9):
		return
	selected_stage_id = stage_id
	GameProgression.current_stage_id = stage_id
	_update_pebble_position_instant()
	_update_nodes_appearance()
	_update_ui()
	is_entering = true
	_play_sfx(ENTER_SOUND)
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.2)
	fade_tween.tween_callback(func() -> void:
		GameProgression.came_from_map = true
		get_tree().change_scene_to_file(GameProgression.get_stage_data(stage_id).scene))


func _is_key(event: InputEvent, keycode: Key) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == keycode or event.physical_keycode == keycode
	return false


func _navigate_step(dir: int) -> void:
	var target_id := selected_stage_id + dir
	if target_id < 1 or target_id > GameProgression.get_stage_count():
		_shake_avatar(dir)
		_play_sfx(REJECT_SOUND)
		return

	if not GameProgression.is_unlocked(target_id):
		_shake_avatar(dir)
		_play_sfx(REJECT_SOUND)
		_flash_prompt("Complete %s first!" % GameProgression.get_stage_data(selected_stage_id).name)
		return

	_move_to_stage(target_id)


func _move_to_stage(target_id: int) -> void:
	if is_moving or is_entering or target_id == selected_stage_id:
		return

	is_moving = true
	var path_points := _get_path_points_between(selected_stage_id, target_id)
	var forward := target_id > selected_stage_id
	pebble_sprite.scale.x = 1.0 if forward else -1.0

	var tween := create_tween()
	var step_duration := 0.08

	for i in range(1, path_points.size()):
		var pt: Vector2 = path_points[i]
		var start_pt: Vector2 = path_points[i - 1]
		var step_hop := func() -> void:
			_play_sfx(HOP_SOUND)
		tween.tween_callback(step_hop)

		var step_move := func(sub_t: float) -> void:
			var current_ground: Vector2 = start_pt.lerp(pt, sub_t)
			var arc: float = sin(sub_t * PI) * 8.0
			pebble_avatar.position = current_ground + Vector2(0.0, -arc)
		tween.tween_method(step_move, 0.0, 1.0, step_duration)

	var arrive_cb := func() -> void:
		is_moving = false
		selected_stage_id = target_id
		GameProgression.current_stage_id = selected_stage_id
		GameProgression.save_data()
		_play_sfx(REJECT_SOUND)
		_squash_avatar()
		_update_nodes_appearance()
		_update_ui()
	tween.tween_callback(arrive_cb)


func _try_enter_stage() -> void:
	if is_moving or is_entering:
		return

	if not GameProgression.is_unlocked(selected_stage_id):
		_shake_avatar(0)
		_play_sfx(REJECT_SOUND)
		return

	is_entering = true
	_play_sfx(ENTER_SOUND)

	var jump_tween := create_tween()
	jump_tween.tween_property(pebble_avatar, "position:y", pebble_avatar.position.y - 20.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(pebble_avatar, "position:y", pebble_avatar.position.y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.35)
	var enter_cb := func() -> void:
		GameProgression.came_from_map = true
		var stage_data: Dictionary = GameProgression.get_stage_data(selected_stage_id)
		get_tree().change_scene_to_file(stage_data.scene)
	fade_tween.tween_callback(enter_cb)


func _celebrate_clear(cleared_id: int) -> void:
	selected_stage_id = cleared_id
	_update_pebble_position_instant()
	_update_nodes_appearance()
	_update_ui()
	_play_sfx(ENTER_SOUND)

	var next_id := cleared_id + 1
	if next_id <= GameProgression.get_stage_count() and GameProgression.is_unlocked(next_id):
		_unlock_from_id = cleared_id
		_unlock_anim_t = 0.0

		var unlock_timer := get_tree().create_timer(0.6)
		var advance_cb := func() -> void:
			_play_sfx(UNLOCK_SOUND)
			_move_to_stage(next_id)
		unlock_timer.timeout.connect(advance_cb)


func _back_to_title() -> void:
	is_entering = true
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
	fade_tween.tween_callback(func() -> void: get_tree().change_scene_to_file("res://ui/title_screen.tscn"))


func _update_pebble_position_instant() -> void:
	var pos: Vector2 = STAGE_POSITIONS.get(selected_stage_id, STAGE_POSITIONS[1])
	pebble_avatar.position = pos
	pebble_sprite.position.y = -10.0


func _stage_node(id: int) -> Node2D:
	return get_node_or_null("Nodes/StageNode%d" % id) as Node2D


func _update_nodes_appearance() -> void:
	for id in range(1, GameProgression.get_stage_count() + 1):
		var n := _stage_node(id)
		if n == null:
			continue
		var unlocked := GameProgression.is_unlocked(id)
		var cleared := GameProgression.is_cleared(id)
		var is_selected := (id == selected_stage_id)

		var seed_icon: Sprite2D = n.get_node_or_null("SeedSprite")
		var badge: Label = n.get_node_or_null("NumberBadge")
		var name_label: Label = n.get_node_or_null("NameLabel")
		var sel_ring: Node2D = n.get_node_or_null("SelectionRing")

		if seed_icon != null:
			seed_icon.visible = cleared

		if badge != null:
			if cleared:
				badge.modulate = Color(1.0, 0.84, 0.28)
			elif unlocked:
				badge.modulate = Color(1.0, 0.75, 0.25)
			else:
				badge.modulate = Color(0.55, 0.5, 0.65)

		if name_label != null:
			if cleared:
				name_label.modulate = Color(0.4, 0.95, 0.5)
			elif unlocked:
				name_label.modulate = Color(0.95, 0.9, 0.8)
			else:
				name_label.modulate = Color(0.55, 0.5, 0.65)

		if sel_ring != null:
			sel_ring.visible = is_selected


func _animate_cleared_seeds() -> void:
	for id in range(1, GameProgression.get_stage_count() + 1):
		if GameProgression.is_cleared(id):
			var n := _stage_node(id)
			if n != null:
				var seed_icon: Sprite2D = n.get_node_or_null("SeedSprite")
				if seed_icon != null and seed_icon.visible:
					seed_icon.position.y = -22.0 + sin(anim_time * 4.0 + float(id - 1)) * 1.5


func _update_ui() -> void:
	var stage_data := GameProgression.get_stage_data(selected_stage_id)
	var unlocked := GameProgression.is_unlocked(selected_stage_id)
	var cleared := GameProgression.is_cleared(selected_stage_id)
	var best_seeds := GameProgression.get_best_seeds(selected_stage_id)
	var max_seeds: int = stage_data.get("max_seeds", 0)

	stage_title_label.text = "STAGE %d: %s" % [selected_stage_id, stage_data.name.to_upper()]
	stage_subtitle_label.text = stage_data.subtitle

	if cleared:
		stage_status_label.text = "Cleared"
		stage_status_label.modulate = Color(0.4, 0.95, 0.5)
	elif unlocked:
		stage_status_label.text = "Open"
		stage_status_label.modulate = Color(1.0, 0.75, 0.25)
	else:
		stage_status_label.text = "Locked"
		stage_status_label.modulate = Color(0.6, 0.55, 0.7)

	stage_seeds_label.text = "Tins %d/%d   Best %s" % [
		best_seeds,
		max_seeds,
		GameProgression.format_time(GameProgression.get_best_time(selected_stage_id)),
	]

	if unlocked:
		enter_prompt_label.text = "Tap the stage to play" if TouchControls.active else "Press Jump or Enter to play"
		enter_prompt_label.modulate = Color(1.0, 0.95, 0.75)
		stage_card_button.disabled = false
	else:
		enter_prompt_label.text = "Clear the previous stage to unlock"
		enter_prompt_label.modulate = Color(0.65, 0.6, 0.75)
		stage_card_button.disabled = true

	total_seeds_label.text = "%d / %d" % [
		GameProgression.get_total_seeds_collected(),
		GameProgression.get_total_max_seeds(),
	]


func _flash_prompt(msg: String) -> void:
	enter_prompt_label.text = msg
	enter_prompt_label.modulate = Color(1.0, 0.4, 0.4)

	var timer := get_tree().create_timer(1.2)
	var flash_cb := func() -> void:
		_update_ui()
	timer.timeout.connect(flash_cb)


func _knights_say_ni() -> void:
	enter_prompt_label.text = Eggs.NI
	enter_prompt_label.modulate = Color(0.6, 1.0, 0.5)
	_play_sfx(UNLOCK_SOUND)
	_squash_avatar()
	get_tree().create_timer(2.5).timeout.connect(_update_ui)


func _shake_avatar(dir: int) -> void:
	var base_x := pebble_avatar.position.x
	var offset := 4.0 if dir >= 0 else -4.0
	var tween := create_tween()
	tween.tween_property(pebble_avatar, "position:x", base_x + offset, 0.05)
	tween.tween_property(pebble_avatar, "position:x", base_x - offset * 0.7, 0.05)
	tween.tween_property(pebble_avatar, "position:x", base_x, 0.05)


func _squash_avatar() -> void:
	var tween := create_tween()
	tween.tween_property(pebble_sprite, "scale", Vector2(1.25, 0.75), 0.06)
	tween.tween_property(pebble_sprite, "scale", Vector2.ONE, 0.1)


func _play_sfx(stream: AudioStream) -> void:
	stage_audio.play_sfx(stream)


func _start_music() -> void:
	stage_audio.play_music(MUSIC_STREAM)


# Path and node calculations
func _get_bezier_points(p0: Vector2, pctrl: Vector2, p1: Vector2, count: int) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in range(count):
		var t := float(i) / float(count - 1)
		var pt := (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * pctrl + t * t * p1
		result.append(pt)
	return result


## The hop path from stage `from_id` to the next one.
func _segment_points(from_id: int) -> Array[Vector2]:
	return _get_bezier_points(STAGE_POSITIONS[from_id], PATH_CONTROLS[from_id], STAGE_POSITIONS[from_id + 1], PATH_STEPS)


## Every point the avatar hops through between two stages, in either direction.
func _get_path_points_between(from_id: int, to_id: int) -> Array[Vector2]:
	var low := mini(from_id, to_id)
	var high := maxi(from_id, to_id)
	var combined: Array[Vector2] = []
	for id in range(low, high):
		var segment := _segment_points(id)
		if not combined.is_empty():
			segment.remove_at(0)
		combined.append_array(segment)
	if from_id > to_id:
		combined.reverse()
	return combined


# Background embers / stars
func _init_particles() -> void:
	_particles.clear()
	for i in range(22):
		_particles.append({
			"pos": Vector2(randf_range(8.0, 472.0), randf_range(30.0, 190.0)),
			"speed": randf_range(5.0, 14.0),
			"size": 1.0 if randf() < 0.75 else 2.0,
			"phase": randf_range(0.0, PI * 2.0),
			"color": Color(1.0, randf_range(0.5, 0.9), randf_range(0.2, 0.4), randf_range(0.4, 0.9)),
		})


func _update_particles(delta: float) -> void:
	for p in _particles:
		p.pos.y -= p.speed * delta
		p.pos.x += sin(anim_time * 2.0 + p.phase) * 0.25
		if p.pos.y < 30.0:
			p.pos.y = 190.0
			p.pos.x = randf_range(8.0, 472.0)


# Custom drawing for path lines, stepping stones, and pedestal bases
func draw_map_elements(canvas: CanvasItem) -> void:
	var count := GameProgression.get_stage_count()
	for id in range(1, count):
		if not PAINTED_SEGMENTS.has(id):
			_draw_trail(canvas, id)
	for id in range(1, count):
		_draw_path_segment(canvas, _segment_points(id), GameProgression.is_unlocked(id + 1), id)

	for p in _particles:
		var alpha: float = (sin(anim_time * 3.0 + p.phase) * 0.35 + 0.65) * p.color.a
		var c := Color(p.color.r, p.color.g, p.color.b, alpha)
		canvas.draw_rect(Rect2(p.pos, Vector2(p.size, p.size)), c)

	for id in range(1, count + 1):
		_draw_pedestal_base(canvas, STAGE_POSITIONS[id], id)


## A dirt trail where the map art has none: a dark edge with packed earth
## down the middle, traced finely along the hop curve.
func _draw_trail(canvas: CanvasItem, from_id: int) -> void:
	var points := _get_bezier_points(STAGE_POSITIONS[from_id], PATH_CONTROLS[from_id], STAGE_POSITIONS[from_id + 1], 24)
	var line := PackedVector2Array(points)
	canvas.draw_polyline(line, TRAIL_DARK, 5.0)
	canvas.draw_polyline(line, TRAIL_DIRT, 3.0)


func _draw_path_segment(canvas: CanvasItem, points: Array[Vector2], is_unlocked: bool, segment_id: int) -> void:
	# _draw_trail lays the dirt; these are the stepping stones along it.
	for i in range(1, points.size() - 1):
		var pt := points[i].round()
		if is_unlocked:
			var pulse := sin(anim_time * 5.0 + float(i)) * 0.25 + 0.75
			canvas.draw_rect(Rect2(pt - Vector2(2, 2), Vector2(5, 5)), Color(0.16, 0.08, 0.1))
			canvas.draw_rect(Rect2(pt - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.7, 0.25, pulse))
		else:
			canvas.draw_rect(Rect2(pt - Vector2(2, 2), Vector2(5, 5)), Color(0.1, 0.08, 0.14, 0.85))
			canvas.draw_rect(Rect2(pt - Vector2(1, 1), Vector2(3, 3)), Color(0.36, 0.32, 0.44))

	if _unlock_anim_t >= 0.0 and _unlock_from_id == segment_id:
		var beam_idx := int(_unlock_anim_t * float(points.size() - 1))
		var sub_frac := (_unlock_anim_t * float(points.size() - 1)) - float(beam_idx)
		if beam_idx < points.size() - 1:
			var beam_pos := points[beam_idx].lerp(points[beam_idx + 1], sub_frac)
			canvas.draw_circle(beam_pos, 7.0, Color(1.0, 0.95, 0.6, 0.9))
			canvas.draw_circle(beam_pos, 4.0, Color(1.0, 1.0, 1.0, 1.0))


func _draw_pedestal_base(canvas: CanvasItem, pos: Vector2, id: int) -> void:
	var unlocked := GameProgression.is_unlocked(id)
	var cleared := GameProgression.is_cleared(id)
	var is_selected := (id == selected_stage_id)

	if is_selected:
		var pulse_radius := 11.0 + sin(anim_time * 4.0) * 2.0
		canvas.draw_circle(pos, pulse_radius + 2.0, Color(1.0, 0.85, 0.35, 0.3))

	var outer_color := Color(0.08, 0.05, 0.1)
	var border_color := Color(0.4, 0.35, 0.5)
	var inner_color := Color(0.12, 0.1, 0.16)

	if cleared:
		border_color = Color(1.0, 0.84, 0.28)
		inner_color = Color(0.3, 0.2, 0.1)
	elif unlocked:
		border_color = Color(0.95, 0.55, 0.22)
		inner_color = Color(0.26, 0.14, 0.1)

	canvas.draw_circle(pos, 9.0, outer_color)
	canvas.draw_circle(pos, 8.0, border_color)
	canvas.draw_circle(pos, 6.0, inner_color)


func _on_node_clicked(stage_id: int) -> void:
	if is_moving or is_entering:
		return
	if stage_id == selected_stage_id:
		_try_enter_stage()
	else:
		if GameProgression.is_unlocked(stage_id):
			_move_to_stage(stage_id)
		else:
			_shake_avatar(0)
			_play_sfx(REJECT_SOUND)
			_flash_prompt("Stage %d is locked!" % stage_id)


func _on_stage_card_button_pressed() -> void:
	_try_enter_stage()
