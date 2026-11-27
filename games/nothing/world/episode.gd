class_name EpisodeScene
extends Control

## One episode, start to finish, from its entry in data/episodes.json: a
## title card, the talk that sets it up, then each scene in turn (Stu's set
## if it has one, the counter where its request is made, and what gets said
## when it works), the talk that wraps it up, and the card that says how it
## went. A slap-bass sting between everything, as is traditional.

signal pressed

const FADE := 0.4

## The tests set this, so every episode they open plays itself.
static var bot: bool = false
## How many frames a page of talk stays up when the bot is playing.
static var bot_frames: int = 2
## tests/shots.gd sets this, so a response arrives at its own pace to be looked at.
static var watch: bool = false
## tests/layout.gd puts the scene up without playing it.
static var still: bool = false

var episode_id: int = 1
var episode: Dictionary = {}
## "title", "talk", "card", "build", "won", "end" or "leaving".
var state: String = "start"
## The bot sets this: pages turn themselves and nothing waits to be watched.
var auto: bool = false
var dialogue: Dialogue
var builder: Builder
var card: LessonCard
## Takes in the whole episode, and scenes played with the fewest cards.
var takes: int = 0
var stars: int = 0
## The scene in the room, and the one just won (for the banner).
var scene: Dictionary = {}
var scene_index: int = 0

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
	add_to_group(&"episode_scene")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	auto = auto or bot
	episode = Story.episode(episode_id)
	var audio := StageAudio.new()
	audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(audio)
	_backdrop = Backdrop.sprite("")
	add_child(_backdrop)
	_set_place(str(episode.get("place", "apartment")))
	_dim = ColorRect.new()
	_dim.color = Color(0.05, 0.03, 0.07, 0.55)
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
		builder.instant = not watch
	Sfx.music(str(episode.get("music", "apartment")))
	state = "title"
	_show_overlay(true)
	Sfx.play(self, "sting")
	await _wait_press(2.6)
	_show_overlay(false)
	for line: Dictionary in episode.get("intro", []):
		await _say(line)
	var scenes: Array = episode.get("scenes", [])
	for i in scenes.size():
		scene = scenes[i]
		scene_index = i
		if scene.has("card"):
			await _card(str(scene.card))
		await _build()
		if scene.has("after"):
			await _say(scene.after)
	for line: Dictionary in episode.get("outro", []):
		await _say(line)
	dialogue.visible = false
	Progress.mark_cleared(episode_id, takes, stars)
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


## The counter, until a take gets what the scene wants.
func _build() -> void:
	state = "build"
	dialogue.visible = false
	_dim.visible = true
	builder.visible = true
	var scenes: Array = episode.scenes
	builder.setup(scene, "Episode %d: %s" % [episode_id, episode.title], "Scene %d of %d" % [scene_index + 1, scenes.size()], takes)
	while true:
		var won: bool = await builder.sent
		takes = builder.takes
		if won:
			break
	var at_par := builder.cards.size() <= Story.par(scene)
	if at_par:
		stars += 1
	var quips := Story.stock("par" if at_par else "over")
	_quip = str(quips[scene_index % quips.size()]) if not quips.is_empty() else ""
	Sfx.play(self, "sting")
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
		Ui.prompt(_overlay, "Esc again: back to the TV guide")


func _draw_title() -> void:
	var band := Rect2(0, 84, 480, 96)
	_overlay.draw_rect(band, Color(Palette.PLUM_DARK, 0.92))
	_overlay.draw_rect(Rect2(0, band.position.y, 480, 2), Palette.MUSTARD)
	_overlay.draw_rect(Rect2(0, band.end.y - 2, 480, 2), Palette.MUSTARD)
	Fit.cover(band)
	Fit.begin(band, "the episode's title card")
	Fit.centred(_overlay, Palette.pixel(), 240, band.position.y + 22, "EPISODE %d OF %d" % [episode_id, Story.count()], 10, Palette.MUSTARD_LIGHT)
	Fit.centred(_overlay, Palette.titles(), 240, band.position.y + 54, str(episode.get("title", "")), 30, Palette.CREAM)
	Fit.centred(_overlay, Palette.mono(), 240, band.position.y + 78, str(episode.get("lesson", "")), 16, Palette.MUSTARD_LIGHT)
	Fit.end()


func _draw_won() -> void:
	var sheet := Rect2(110, 150, 260, 84)
	_overlay.draw_rect(sheet.grow(3), Color(0, 0, 0, 0.4))
	Ui.paper(_overlay, sheet)
	_overlay.draw_rect(sheet.grow(-3), Palette.BRICK, false, 2.0)
	Fit.begin(sheet, "the and-scene banner")
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 30, "AND SCENE!", 22, Palette.BRICK)
	var used := builder.cards.size()
	var par := Story.par(scene)
	var words := "%d %s. Par is %d." % [used, "card" if used == 1 else "cards", par]
	var mono := Palette.mono()
	var wide := Fit.width(mono, words, 16)
	var at_par := used <= par
	var x := roundf(240 - (wide + (16 if at_par else 0)) / 2.0)
	Fit.text(_overlay, mono, Vector2(x, sheet.position.y + 48), words, 16, Palette.INK)
	if at_par:
		Ui.star(_overlay, Vector2(x + wide + 10, sheet.position.y + 43), 7, Palette.MUSTARD)
	Fit.para(_overlay, mono, Vector2(sheet.position.x + 12, sheet.position.y + 64), _quip, 16, Palette.DIM, sheet.size.x - 24, 12)
	Fit.end()
	Fit.text(_overlay, Palette.pixel(), Vector2(sheet.end.x - 12 - Fit.width(Palette.pixel(), "%s: go on" % Controls.go_key(), 10), sheet.position.y + 14), "%s: go on" % Controls.go_key(), 10, Palette.DIM)


func _draw_end() -> void:
	var sheet := Rect2(72, 30, 336, 206)
	_overlay.draw_rect(sheet.grow(3), Color(0, 0, 0, 0.4))
	Ui.paper(_overlay, sheet)
	Ui.brads(_overlay, sheet)
	Fit.begin(sheet, "the episode's end card")
	var mono := Palette.mono()
	Fit.centred(_overlay, Palette.pixel(), 240, sheet.position.y + 20, "EPISODE %d OF %d" % [episode_id, Story.count()], 10, Palette.DIM)
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 46, "THAT'S A WRAP", 24, Palette.BRICK)
	Fit.centred(_overlay, Palette.titles(), 240, sheet.position.y + 68, str(episode.get("title", "")), 15, Palette.INK)
	var scenes := (episode.get("scenes", []) as Array).size()
	var best := Progress.best_tries(episode_id)
	var took := "It took %d %s." % [takes, "take" if takes == 1 else "takes"]
	if best > 0 and best < takes:
		took += " Your best is %d." % best
	Fit.centred(_overlay, mono, 240, sheet.position.y + 94, took, 16, Palette.INK)
	# A star for every scene done with the fewest cards.
	var x := 240.0 - scenes * 9.0 + 9.0
	for i in scenes:
		Ui.star(_overlay, Vector2(x + i * 18.0, sheet.position.y + 112), 7, Palette.MUSTARD if i < stars else Palette.PAPER_DARK)
	Fit.centred(_overlay, mono, 240, sheet.position.y + 136, "%d of %d scenes at par" % [stars, scenes], 16, Palette.INK)
	Fit.centred(_overlay, Palette.pixel(), 240, sheet.position.y + 156, "YOU CAN NOW USE", 10, Palette.DIM)
	Fit.centred(_overlay, mono, 240, sheet.position.y + 172, str(episode.get("lesson", "")), 16, Palette.BRICK)
	if episode_id >= Story.count():
		Fit.centred(_overlay, mono, 240, sheet.position.y + 192, "That's the whole season, for now.", 16, Palette.DIM)
	Fit.end()
	Ui.prompt(_overlay, "%s: back to the TV guide" % Controls.go_key())
