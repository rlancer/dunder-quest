class_name Palette
extends RefCounted

## A palace at night: deep blue stone, lamp gold, the sand of the hourglass,
## the teal of the tiles and the crimson of the Prince's sash.

const INK := Color(0.07, 0.05, 0.1)
const NIGHT := Color(0.09, 0.11, 0.2)
const STONE := Color(0.33, 0.36, 0.5)
const PAPER := Color(0.96, 0.92, 0.8)
## The sand of the dagger: the name, the trail and every highlight.
const SAND := Color(0.91, 0.73, 0.29)
const SAND_PALE := Color(0.96, 0.89, 0.63)
const TEAL := Color(0.12, 0.6, 0.62)
const CRIMSON := Color(0.82, 0.2, 0.24)
const VIOLET := Color(0.56, 0.36, 0.78)
const GREEN := Color(0.45, 0.8, 0.47)
const STEEL := Color(0.66, 0.7, 0.8)
## Branch colours on the sand trail: main first.
const LANES: Array[Color] = [Color(0.91, 0.73, 0.29), Color(0.3, 0.78, 0.8), Color(0.93, 0.45, 0.6), Color(0.6, 0.85, 0.45)]

static var _pixel: Font
static var _mono: Font


## The two typefaces, without ligatures: Pixelify's "fi" reads as an "A".
static func pixel() -> Font:
	if _pixel == null:
		_pixel = _plain(load("res://assets/fonts/PixelifySans.ttf") as Font)
	return _pixel


static func mono() -> Font:
	if _mono == null:
		_mono = _plain(load("res://assets/fonts/VT323.ttf") as Font)
	return _mono


static func _plain(font: Font) -> Font:
	var out := FontVariation.new()
	out.base_font = font
	var server := TextServerManager.get_primary_interface()
	out.opentype_features = {server.name_to_tag("liga"): 0, server.name_to_tag("clig"): 0, server.name_to_tag("calt"): 0}
	return out
