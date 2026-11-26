class_name Palette
extends RefCounted

## The Standard Inn's kitchen: stainless steel, white ticket paper, the
## amber of the heat lamps over the pass, green tape with marker on it, an
## apron's blue, and a terminal's black for the line itself.

const INK := Color(0.1, 0.11, 0.13)
const PAPER := Color(0.95, 0.94, 0.9)
const PAPER_DARK := Color(0.83, 0.82, 0.77)
const PAPER_LINE := Color(0.62, 0.63, 0.61)
const STEEL := Color(0.25, 0.29, 0.34)
const STEEL_DARK := Color(0.11, 0.13, 0.16)
const STEEL_LIGHT := Color(0.5, 0.56, 0.62)
const LAMP := Color(0.96, 0.62, 0.18)
const LAMP_LIGHT := Color(1.0, 0.82, 0.42)
const RED := Color(0.76, 0.17, 0.13)
const RED_LIGHT := Color(0.97, 0.42, 0.33)
const GREEN := Color(0.13, 0.47, 0.3)
const GREEN_LIGHT := Color(0.47, 0.87, 0.57)
const BLUE := Color(0.15, 0.29, 0.56)
const BLUE_LIGHT := Color(0.52, 0.72, 1.0)
const CREAM := Color(0.97, 0.95, 0.88)
const DIM := Color(0.47, 0.49, 0.52)
## The line, and what comes out of it, are a terminal.
const TERM := Color(0.04, 0.06, 0.07)
const TERM_TEXT := Color(0.82, 0.93, 0.84)
const TERM_DIM := Color(0.42, 0.52, 0.47)
const SIZE := 16

static var _mono: Font
static var _pixel: Font
static var _titles: Font


static func mono() -> Font:
	if _mono == null:
		_mono = load("res://assets/fonts/VT323.ttf") as Font
	return _mono


static func pixel() -> Font:
	if _pixel == null:
		_pixel = load("res://assets/fonts/PixelifySans.ttf") as Font
	return _pixel


## The titles' tall capitals (Bebas Neue, OFL).
static func titles() -> Font:
	if _titles == null:
		_titles = load("res://assets/fonts/BebasNeue.ttf") as Font
	return _titles
