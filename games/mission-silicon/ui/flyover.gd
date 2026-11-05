class_name Flyover
extends Control

## The title sequence: a short pixel-art flyover of San Francisco, the way
## the show's intro flew over its valley. In over the bay with the Golden
## Gate in the fog, past the Mission's painted Victorians, where Forkcast's
## tiny sign pops up on the shabby one's roof, across the downtown skyline,
## where today's AI companies' signs pop up on the roofs, and out to the Bay
## Bridge, ending on the title. It plays over the season screen once a
## session, and a tap skips it.
##
## The art is three parallax layers from tools/flyover.py, with no writing
## on it. The signs are drawn here in the game's pixel font: the companies'
## real names, as SHOW.md decides for the title sequence (companies only,
## never people), on plain boards, never their logo artwork. The gags are
## about the industry, not any one company: a dot-com's sign crossed out
## for the same name plus "AI", and a billboard promising AGI next quarter.

signal finished

## Once a session: the season screen shows it only the first time.
static var seen: bool = false

const SKY := preload("res://assets/flyover/sky.png")
const CITY := preload("res://assets/flyover/city.png")
const HOUSES := preload("res://assets/flyover/houses.png")

## How far the camera travels, and how fast each layer moves with it.
const TRAVEL := 1000.0
const PAN := 11.0
const SKY_RATE := 0.12
const CITY_RATE := 0.6
## Where each layer starts, in screen pixels at the start of the pan.
const CITY_X := 480.0
const HOUSES_X := 250.0
const TITLE_HOLD := 2.6
const FADE := 0.5

## The signs on the skyline: where on the city layer (x), the name, and the
## board's colour. In the order they pass.
const SIGNS := [
	[50, "OpenAI", "#2b3440"],
	[116, "PetSnacks.com", "#c0603a"],
	[178, "Anthropic", "#d98a5f"],
	[238, "NVIDIA", "#4c8a2e"],
	[290, "Google DeepMind", "#3a6fc4"],
	[344, "Perplexity", "#1f7a7a"],
	[412, "AGI NEXT QUARTER", "#ffffff"],
	[460, "Meta", "#3d5fa8"],
	[510, "Scale AI", "#6b4fa0"],
]
## The dot-com that becomes an AI company: its sign is crossed out, then
## comes back as this.
const REBRAND := {"PetSnacks.com": "PetSnacks AI"}
## Forkcast's sign, on the shabby Victorian's flat roof (on the houses layer).
const FORKCAST_X := 350

var _t: float = 0.0
var _done: bool = false
var _leaving: float = -1.0
## On the web, sound waits for a first tap; that tap turns it on instead of
## skipping, and the next one skips.
var _tap_for_sound: bool = false
## Per sign: its rect on the city layer and when it popped up (-1: not yet).
var _signs: Array = []
var _forkcast: Dictionary = {}
var _hint: Label


func _ready() -> void:
	seen = true
	name = "Flyover"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_tap_for_sound = not Sound.unlocked
	Sound.music("title")
	_place_signs()
	_hint = UI.label("Tap for sound" if _tap_for_sound else "Tap to skip", Palette.BODY, Palette.WHITE)
	_hint.add_theme_color_override("font_shadow_color", Color(Palette.SLATE, 0.8))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.place(_hint, Rect2(300, 254, 172, 12))
	add_child(_hint)


## Puts each sign on its building's roof (the highest drawn pixel near its
## x), raised on a taller pole when it would cover the one before.
func _place_signs() -> void:
	var font := Palette.body()
	var city := CITY.get_image()
	var placed: Array[Rect2] = []
	for s in SIGNS:
		var text: String = s[1]
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8.0
		var roof := _roof(city, int(s[0]))
		var rect := Rect2(float(s[0]) - w / 2.0, roof - 17.0, w, 13.0)
		var moved := true
		while moved:
			moved = false
			for p in placed:
				if p.grow(1.0).intersects(rect):
					rect.position.y = p.position.y - 15.0
					moved = true
		placed.append(rect)
		_signs.append({"rect": rect, "roof": roof, "text": text, "color": Color(s[2]), "at": -1.0})
	var houses := HOUSES.get_image()
	var fw := font.get_string_size("Forkcast", HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8.0
	var froof := _roof(houses, FORKCAST_X)
	_forkcast = {"rect": Rect2(FORKCAST_X - fw / 2.0, froof - 16.0, fw, 13.0), "roof": froof, "at": -1.0}


## The highest drawn pixel within a few pixels of column x.
static func _roof(img: Image, x: int) -> float:
	var best := img.get_height()
	for cx in range(maxi(0, x - 3), mini(img.get_width(), x + 4)):
		for y in img.get_height():
			if img.get_pixel(cx, y).a > 0.5:
				best = mini(best, y)
				break
	return float(best)


func _process(delta: float) -> void:
	_t += delta
	if _leaving >= 0.0:
		_leaving += delta
		modulate.a = clampf(1.0 - _leaving / FADE, 0.0, 1.0)
		if _leaving >= FADE:
			_finish()
			return
	elif _t >= PAN + TITLE_HOLD:
		_leaving = 0.0
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Touches arrive as mouse presses too (emulate_mouse_from_touch), so only
	# those count, or one touch would be two taps.
	var tap: bool = event is InputEventMouseButton and event.is_pressed()
	if not tap:
		return
	accept_event()
	if _tap_for_sound:
		_tap_for_sound = false
		_hint.text = "Tap to skip"
		return
	skip()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo():
		skip()


func skip() -> void:
	if _leaving < 0.0:
		_leaving = FADE * 0.5
		_t = maxf(_t, PAN + TITLE_HOLD)


func _finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	queue_free()


func camera() -> float:
	var u := clampf(_t / PAN, 0.0, 1.0)
	return TRAVEL * (u * u * (3.0 - 2.0 * u))


func _draw() -> void:
	var cam := camera()
	var sky_x := floorf(-cam * SKY_RATE)
	draw_texture(SKY, Vector2(sky_x, 0))
	var city_at := Vector2(floorf(CITY_X - cam * CITY_RATE), 270.0 - CITY.get_height())
	draw_texture(CITY, city_at)
	var font := Palette.body()
	var houses_at := Vector2(floorf(HOUSES_X - cam), 270.0 - HOUSES.get_height())
	for s in _signs:
		var r: Rect2 = s["rect"]
		var screen := Rect2(r.position + city_at, r.size)
		# A sign pops up once it's on screen and clear of the houses in front.
		if s["at"] < 0.0 and screen.get_center().x < 430.0 and screen.position.x > houses_at.x + HOUSES.get_width():
			s["at"] = _t
		if s["at"] >= 0.0:
			_draw_sign(font, screen, city_at.y + s["roof"], s, _t - s["at"])
	draw_texture(HOUSES, houses_at)
	var fr: Rect2 = _forkcast["rect"]
	var fscreen := Rect2(fr.position + houses_at, fr.size)
	if _forkcast["at"] < 0.0 and fscreen.get_center().x < 380.0:
		_forkcast["at"] = _t
	if _forkcast["at"] >= 0.0:
		_draw_forkcast(font, fscreen, houses_at.y + _forkcast["roof"], _t - _forkcast["at"])
	if _t > PAN - 0.4:
		_draw_title(clampf((_t - PAN + 0.4) / 0.5, 0.0, 1.0))


## A pop: up from nothing, a bounce past full size, settling.
static func _pop(age: float) -> float:
	if age <= 0.0:
		return 0.0
	if age < 0.18:
		return age / 0.18 * 1.2
	if age < 0.32:
		return lerpf(1.2, 1.0, (age - 0.18) / 0.14)
	return 1.0


func _draw_sign(font: Font, r: Rect2, roof: float, s: Dictionary, age: float) -> void:
	var text: String = s["text"]
	var color: Color = s["color"]
	# The rebrand: up as the dot-com, crossed out, then back as an AI company.
	var crossed := false
	if REBRAND.has(text):
		if age > 1.6:
			text = REBRAND[text]
			color = Palette.GREEN_DARK
			age -= 1.6
		elif age > 0.9:
			crossed = true
	var k := _pop(age)
	if k <= 0.0:
		return
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8.0
	var box := Rect2(r.get_center().x - w / 2.0, r.position.y, w, r.size.y)
	# The poles down to the roof.
	var base := Vector2(box.get_center().x, box.end.y)
	draw_set_transform(base, 0.0, Vector2(k, k))
	var local := Rect2(box.position - base, box.size)
	var drop := maxf(roof - box.end.y, 0.0)
	draw_rect(Rect2(local.position.x + 4, 0, 2, drop), Palette.SLATE)
	draw_rect(Rect2(local.end.x - 6, 0, 2, drop), Palette.SLATE)
	draw_rect(local.grow(1.0), Palette.SLATE)
	draw_rect(local, color)
	var ink := Palette.SLATE if color.get_luminance() > 0.6 else Palette.WHITE
	draw_string(font, local.position + Vector2(4, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, ink)
	if crossed:
		draw_line(local.position + Vector2(1, 1), local.end - Vector2(1, 1), Palette.RED, 2.0)
		draw_line(Vector2(local.position.x + 1, local.end.y - 1), Vector2(local.end.x - 1, local.position.y + 1), Palette.RED, 2.0)
	draw_set_transform(Vector2.ZERO)


## Forkcast: a single green pixel on the roof that grows into a tiny sign.
func _draw_forkcast(font: Font, r: Rect2, roof: float, age: float) -> void:
	var base := Vector2(r.get_center().x, r.end.y)
	if age < 0.6:
		draw_rect(Rect2(base.x - 1, roof - 3, 2, 2), Palette.GREEN)
		return
	var k := _pop(age - 0.6)
	draw_set_transform(base, 0.0, Vector2(k, k))
	var local := Rect2(r.position - base, r.size)
	draw_rect(Rect2(-1, 0, 2, maxf(roof - r.end.y, 0.0)), Palette.SLATE)
	draw_rect(local.grow(1.0), Palette.GREEN_DARK)
	draw_rect(local, Palette.GREEN)
	draw_string(font, local.position + Vector2(4, 10), "Forkcast", HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.WHITE)
	draw_set_transform(Vector2.ZERO)


## The title, over the bridge at the end: a paper band with the name.
func _draw_title(a: float) -> void:
	var band := Rect2(0, 96, 480, 64)
	draw_rect(band, Color(Palette.PAPER, 0.94 * a))
	draw_rect(Rect2(0, band.position.y, 480, 3), Color(Palette.GREEN, a))
	draw_rect(Rect2(0, band.end.y - 3, 480, 3), Color(Palette.GREEN, a))
	var titles := Palette.titles()
	var text := "MISSION SILICON"
	var w := titles.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(titles, Vector2(240.0 - w / 2.0, 140), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(Palette.SLATE, a))
