class_name Palette
extends RefCounted

## The Croydon palette: magnolia walls, brown carpet, sodium streetlight,
## and a laptop's syntax colors with JavaScript yellow on top.

const INK := Color(0.08, 0.07, 0.1)
const PAPER := Color(0.96, 0.92, 0.84)
const MAGNOLIA := Color(0.9, 0.84, 0.72)
const CARPET := Color(0.45, 0.3, 0.22)
const STEEL := Color(0.62, 0.66, 0.72)
const STEEL_DARK := Color(0.32, 0.35, 0.42)
const WOOD := Color(0.62, 0.42, 0.26)
const WOOD_DARK := Color(0.38, 0.24, 0.16)
const RED := Color(0.88, 0.3, 0.28)
const GREEN := Color(0.46, 0.84, 0.5)
const AMBER := Color(1.0, 0.7, 0.3)
## JavaScript yellow.
const JS := Color(0.97, 0.87, 0.12)
const CODE := Color(0.86, 0.9, 1.0)
const CODE_BG := Color(0.1, 0.11, 0.16, 0.96)
const CODE_LINE := Color(0.26, 0.28, 0.4)
## Syntax colors for the editor and lesson cards.
const SYN_KEYWORD := Color(0.78, 0.56, 1.0)
const SYN_STRING := Color(0.62, 0.9, 0.52)
const SYN_NUMBER := Color(1.0, 0.66, 0.4)
const SYN_COMMENT := Color(0.5, 0.54, 0.66)
const SYN_CALL := Color(0.5, 0.78, 1.0)
## Clive's blue and Jazz's red, for whose head you are in.
const CLIVE := Color(0.46, 0.66, 0.98)
const JAZZ := Color(0.98, 0.42, 0.38)
## VT323 size for names and labels drawn in the world.
const SMALL := 16

static var _mono: Font


static func mono() -> Font:
	if _mono == null:
		_mono = load("res://assets/fonts/VT323.ttf") as Font
	return _mono


static func tint_of(who: String) -> Color:
	return CLIVE if who == "clive" else JAZZ
