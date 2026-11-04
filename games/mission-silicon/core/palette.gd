class_name Palette
extends RefCounted

## Startup green on off-white and slate: one bright accent, everything else
## quiet, the way a pitch deck looks.

const GREEN := Color("#2BB673")
const GREEN_DARK := Color("#1d8a55")
const GREEN_PALE := Color("#d5f0e2")
const PAPER := Color("#f5f5f0")
const WHITE := Color("#ffffff")
const SLATE := Color("#2b3440")
const SLATE_MID := Color("#5b6675")
const SLATE_LIGHT := Color("#aab2bd")
const RULE := Color("#dcdfe3")
const AMBER := Color("#f0a030")
const RED := Color("#e04848")
const BLACK := Color("#111417")

## Text sizes in viewport pixels. Nothing smaller than BODY: on a phone held
## sideways one viewport pixel is about 1.4 points, so 9 is about 13 points.
const BODY := 9
const LABEL := 10
const HEAD := 12
## The smallest tap target, about 44 points on a phone.
const TAP := 30.0

static var _body: Font
static var _titles: Font


static func body() -> Font:
	if _body == null:
		_body = load("res://assets/fonts/PixelifySans.ttf") as Font
	return _body


## Title cards. Montserrat ExtraBold is the decided face; until its files are
## in assets/fonts, Libre Franklin at the same weight stands in.
static func titles() -> Font:
	if _titles == null:
		var font := FontVariation.new()
		var path := "res://assets/fonts/Montserrat.ttf"
		if not ResourceLoader.exists(path):
			path = "res://assets/fonts/LibreFranklin.ttf"
		font.base_font = load(path) as Font
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_titles = font
	return _titles


## Money as the game shows it: $1.2M, $14k, $300.
static func money(v: float) -> String:
	var a := absf(v)
	var sign := "-" if v < 0 else ""
	if a >= 1000000.0:
		return "%s$%.1fM" % [sign, a / 1000000.0]
	if a >= 10000.0:
		return "%s$%dk" % [sign, roundi(a / 1000.0)]
	if a >= 1000.0:
		return "%s$%.1fk" % [sign, a / 1000.0]
	return "%s$%d" % [sign, roundi(a)]
