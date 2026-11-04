extends Node

## Paints the site's art for /mission-silicon/: the social preview card
## (1200x630, into site/static/img/og/mission-silicon.png) and the page's
## screenshots, taken from the bot's shots and halved (into
## site/static/img/mission-silicon/). Run the bot with shots first.
##
## godot --path . res://tests/bot.tscn -- shots
## godot --path . res://tools/site_art.tscn

## The screenshot on the card, kept alive until it has been drawn.
var _shot: ImageTexture
const SHOTS := {"05_planning.png": "planning.png", "07_live.png": "trouble.png",
	"11_dials.png": "dials.png", "09_postmortem_take_one.png": "postmortem.png", "12_live.png": "live.png"}


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var site := ProjectSettings.globalize_path("res://").path_join("../../site/static/img").simplify_path()
	DirAccess.make_dir_recursive_absolute(site.path_join("mission-silicon"))
	for from in SHOTS:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://tests/shots/" + from))
		if img == null or img.is_empty():
			push_error("No shot %s: run the bot with shots first" % from)
			get_tree().quit(1)
			return
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_LANCZOS)
		img.save_png(site.path_join("mission-silicon").path_join(SHOTS[from]))
		print("wrote ", SHOTS[from])

	var vp := SubViewport.new()
	vp.size = Vector2i(1200, 630)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.transparent_bg = false
	add_child(vp)
	var card := Control.new()
	card.size = Vector2(1200, 630)
	card.draw.connect(_draw_card.bind(card))
	vp.add_child(card)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(site.path_join("og/mission-silicon.png"))
	print("wrote og/mission-silicon.png")
	get_tree().quit(0)


func _draw_card(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1200, 630), Palette.PAPER)
	c.draw_rect(Rect2(0, 0, 1200, 16), Palette.GREEN)
	if _shot == null:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://tests/shots/12_live.png"))
		img.resize(600, 338, Image.INTERPOLATE_LANCZOS)
		_shot = ImageTexture.create_from_image(img)
	c.draw_rect(Rect2(556, 150, 608, 346), Palette.SLATE)
	c.draw_texture(_shot, Vector2(560, 154))
	var titles := Palette.titles()
	c.draw_string(titles, Vector2(60, 230), "MISSION", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Palette.SLATE)
	c.draw_string(titles, Vector2(60, 330), "SILICON", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Palette.SLATE)
	c.draw_rect(Rect2(64, 360, 160, 10), Palette.GREEN)
	var body := Palette.body()
	c.draw_string(body, Vector2(64, 430), "You can't code. Your AI can,", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.SLATE_MID)
	c.draw_string(body, Vector2(64, 478), "a bit too confidently.", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.SLATE_MID)
	c.draw_string(body, Vector2(64, 580), "a dunder_quest game", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Palette.GREEN_DARK)
