class_name JobScene
extends Control

## One job, start to finish, from its entry in data/jobs.json: a title
## card, the talk that sets it up, then each poster in turn (its lesson
## card if it has one, the desk where it's written, and what gets said when
## it works), the talk that wraps it up, and the card that says how it went.

signal pressed

const FADE := 0.4

## The tests set this, so every job they open plays itself.
static var bot: bool = false
## How many frames a page of talk stays up when the bot is playing.
static var bot_frames: int = 2
## tests/layout.gd puts the scene up without playing it.
static var still: bool = false

var job_id: int = 1
var job: Dictionary = {}
## "title", "talk", "card", "build", "won", "end" or "leaving".
var state: String = "start"
## The bot sets this: pages turn themselves and nothing waits to be watched.
var auto: bool = false
var dialogue: Dialogue
var builder: Builder
var card: LessonCard
## Draws in the whole job, and posters written in the fewest chips.
var draws: int = 0
var stars: int = 0
## The poster on the desk, and the one just won (for the banner).
var poster: Dictionary = {}
var poster_index: int = 0

var _backdrop: Sprite2D
var _dim: ColorRect
var _overlay: Control
var _fade: ColorRect
var _place: String = ""
var _clock: float = 0.0
var _esc_armed: float = 0.0
var _quip: String = ""
var _waits: int = 0


func _ready() -> void:
	add_to_group(&"job_scene")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	auto = auto or bot
	job = Story.job(job_id)
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_backdrop = Backdrop.sprite("")
	add_child(_backdrop)
	_set_place(str(job.get("place", "street")))
	_dim = ColorRect.new()
	_dim.color = Color(0.08, 0.04, 0.03, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	builder = Builder.new()
	builder.visible = false
	add_child(builder)
	dialogue = Dialogue.new()
	add_child(dialogue)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_overlay_input)
	add_child(_overlay)
	card = LessonCard.new()
	add_child(card)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, FADE)
	if not still:
		_run.call_deferred()


func _set_place(place: String) -> void:
	if place == _place:
		return
	_place = place
	var path := "res://assets/backgrounds/%s.png" % place
	if ResourceLoader.exists(path):
		_backdrop.texture = load(path) as Texture2D
		_backdrop.scale = Vector2(480, 270) / _backdrop.texture.get_size()


func _run() -> void:
	if auto:
		dialogue.auto_frames = bot_frames
		card.auto_frames = bot_frames + 1
		builder.instant = true
	Sfx.music(str(job.get("music", "town")))
	state = "title"
	_show_overlay(true)
	Sfx.play(self, "sting")
	await _wait_press(2.6)
	_show_overlay(false)
	for line: Dictionary in job.get("intro", []):
		await _say(line)
	var posters: Array = job.get("posters", [])
	for i in posters.size():
		poster = posters[i]
		poster_index = i
		if poster.has("card"):
			await _card(str(poster.card))
		await _build()
		if poster.has("after"):
			await _say(poster.after)
		for step: Dictionary in poster.get("then", []):
			if step.has("card"):
				await _card(str(step.card))
			else:
				await _say(step)
	for line: Dictionary in job.get("outro", []):
		await _say(line)
	dialogue.visible = false
	Progress.mark_cleared(job_id, draws, stars)
	state = "end"
	_dim.visible = true
	_show_overlay(true)
	Sfx.play(self, "win")
	await _wait_press(0.0)
	leave()


func _say(line: Dictionary) -> void:
	state = "talk"
	builder.visible = false
	_dim.visible = false
	if line.has("place"):
		_set_place(str(line.place))
	await dialogue.say(line)


func _card(id: String) -> void:
	state = "card"
	dialogue.visible = false
	await card.show_card(Story.card(id))
	Progress.read_card(id)


## The desk, until the poster on it works.
func _build() -> void:
	state = "build"
	dialogue.visible = false
	_dim.visible = true
	builder.visible = true
	var posters: Array = job.posters
	builder.setup(poster, "Job %d: %s" % [job_id, job.title], "Poster %d of %d" % [poster_index + 1, posters.size()], draws)
	Sfx.play(self, str(poster.get("sound", "")))
	while true:
		var won: bool = await builder.drew
		draws = builder.draws
		if won:
			break
	var at_par := builder.tokens.size() <= Story.par(poster)
	if at_par:
		stars += 1
	var quips := Story.stock("par" if at_par else "over")
	_quip = str(quips[poster_index % quips.size()]) if not quips.is_empty() else ""
	state = "won"
	_show_overlay(true)
	await _wait_press(0.0)
	_show_overlay(false)
	builder.visible = false
	_dim.visible = false


func _show_overlay(on: bool) -> void:
	_clock = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_overlay.queue_redraw()


## Waits for Enter, a click or a tap; or, if `after` is set, that many
## seconds, whichever comes first.
func _wait_press(after: float) -> void:
	if auto:
		for _i in bot_frames + 1:
			await get_tree().process_frame
		return
	_waits += 1
	if after > 0.0:
		# Only this wait's own timer may end it.
		var mine := _waits
		get_tree().create_timer(after).timeout.connect(func() -> void:
			if mine == _waits:
				pressed.emit())
	await pressed
	_waits += 1


func leave() -> void:
	if state == "leaving":
		return
	state = "leaving"
	Voice.hush()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.01 if auto else FADE)
	tween.tween_callback(func() -> void: get_tree().change_scene_to_file(Main.BOARD))


func _process(delta: float) -> void:
	_clock += delta
	if _esc_armed > 0.0:
		_esc_armed -= delta
	_overlay.queue_redraw()


func _overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_overlay.accept_event()
		if _clock > 0.3:
			pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if _esc_armed > 0.0:
			leave()
		else:
			_esc_armed = 2.5
	elif event.is_action_pressed(&"confirm") and state in ["title", "won", "end"] and _clock > 0.3:
		get_viewport().set_input_as_handled()
		pressed.emit()


# --- The cards over the top --------------------------------------------------

func _draw_overlay() -> void:
	Fit.frame(_overlay)
	match state:
		"title":
			_draw_title()
		"won":
			_draw_won()
		"end":
			_draw_end()
	if _esc_armed > 0.0 and state != "leaving":
		Ui.prompt(_overlay, "Esc again: back to the job board")


func _draw_title() -> void:
	var band := Rect2(0, 84, 480, 96)
	_overlay.draw_rect(band, Color(Palette.WOOD_DARK, 0.9))
	_overlay.draw_rect(Rect2(0, band.position.y, 480, 2), Palette.GOLD)
	_overlay.draw_rect(Rect2(0, band.end.y - 2, 480, 2), Palette.GOLD)
	Fit.cover(band)
	Fit.begin(band, "the job's title card")
	Fit.centred(_overlay, Palette.pixel(), 240, band.position.y + 22, "JOB %d OF %d" % [job_id, Story.count()], 10, Palette.GOLD_LIGHT)
	Fit.centred(_overlay, Palette.titles(), 240, band.position.y + 52, str(job.get("title", "")), 22, Palette.CREAM)
	Fit.centred(_overlay, Palette.mono(), 240, band.position.y + 76, str(job.get("lesson", "")), 16, Palette.GOLD_LIGHT)
	Fit.end()


func _draw_won() -> void:
	var sheet := Rect2(110, 180, 260, 84)
	_overlay.draw_rect(sheet.grow(3), Color(0, 0, 0, 0.4))
	Ui.paper(_overlay, sheet)
	_overlay.draw_rect(sheet.grow(-3), Palette.RED, false, 2.0)
	Fit.begin(sheet, "the caught banner")
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 28, "CAUGHT!", 22, Palette.RED)
	var chips := builder.tokens.size()
	var par := Story.par(poster)
	var words := "%d %s. Par is %d." % [chips, "chip" if chips == 1 else "chips", par]
	var mono := Palette.mono()
	var wide := Fit.width(mono, words, 16)
	var at_par := chips <= par
	var x := roundf(240 - (wide + (16 if at_par else 0)) / 2.0)
	Fit.text(_overlay, mono, Vector2(x, sheet.position.y + 46), words, 16, Palette.INK)
	if at_par:
		Ui.star(_overlay, Vector2(x + wide + 10, sheet.position.y + 41), 7, Palette.GOLD)
	Fit.para(_overlay, mono, Vector2(sheet.position.x + 12, sheet.position.y + 62), _quip, 16, Palette.DIM, sheet.size.x - 24, 12)
	Fit.end()
	Fit.text(_overlay, Palette.pixel(), Vector2(sheet.end.x - 12 - Fit.width(Palette.pixel(), "%s: go on" % Controls.go_key(), 10), sheet.position.y + 14), "%s: go on" % Controls.go_key(), 10, Palette.DIM)


func _draw_end() -> void:
	var sheet := Rect2(72, 30, 336, 206)
	_overlay.draw_rect(sheet.grow(3), Color(0, 0, 0, 0.4))
	Ui.paper(_overlay, sheet)
	Ui.nails(_overlay, sheet)
	Fit.begin(sheet, "the job's end card")
	var mono := Palette.mono()
	Fit.centred(_overlay, Palette.pixel(), 240, sheet.position.y + 20, "JOB %d OF %d" % [job_id, Story.count()], 10, Palette.DIM)
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 46, "JOB DONE", 24, Palette.RED)
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 68, str(job.get("title", "")), 13, Palette.INK)
	var posters := (job.get("posters", []) as Array).size()
	var best := Progress.best_tries(job_id)
	var drew := "You drew %d %s." % [draws, "time" if draws == 1 else "times"]
	if best > 0 and best < draws:
		drew += " Your best is %d." % best
	Fit.centred(_overlay, mono, 240, sheet.position.y + 94, drew, 16, Palette.INK)
	# A star for every poster written in the fewest chips.
	var x := 240.0 - posters * 9.0 + 9.0
	for i in posters:
		Ui.star(_overlay, Vector2(x + i * 18.0, sheet.position.y + 112), 7, Palette.GOLD if i < stars else Palette.PAPER_DARK)
	Fit.centred(_overlay, mono, 240, sheet.position.y + 136, "%d of %d posters at par" % [stars, posters], 16, Palette.INK)
	Fit.centred(_overlay, Palette.pixel(), 240, sheet.position.y + 156, "YOU CAN NOW READ", 10, Palette.DIM)
	Fit.centred(_overlay, mono, 240, sheet.position.y + 172, str(job.get("lesson", "")), 16, Palette.RED)
	if job_id >= Story.count():
		Fit.centred(_overlay, mono, 240, sheet.position.y + 192, "That's every job in town, for now.", 16, Palette.DIM)
	Fit.end()
	Ui.prompt(_overlay, "%s: back to the job board" % Controls.go_key())
