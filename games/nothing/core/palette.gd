class_name Palette
extends RefCounted

## A 1990s sitcom apartment in New York: plum and teal walls, a mustard
## couch, warm lamplight, the cream of a typed script page, and brick from
## the comedy club's back wall.

const INK := Color(0.11, 0.08, 0.13)
const PAPER := Color(0.97, 0.94, 0.86)
const PAPER_DARK := Color(0.86, 0.82, 0.72)
const PAPER_LINE := Color(0.66, 0.61, 0.55)
const PLUM := Color(0.24, 0.17, 0.3)
const PLUM_DARK := Color(0.13, 0.09, 0.17)
const PLUM_LIGHT := Color(0.52, 0.41, 0.6)
const MUSTARD := Color(0.91, 0.69, 0.23)
const MUSTARD_LIGHT := Color(1.0, 0.85, 0.5)
const TEAL := Color(0.13, 0.5, 0.5)
const TEAL_LIGHT := Color(0.5, 0.86, 0.82)
const BRICK := Color(0.71, 0.27, 0.18)
const BRICK_LIGHT := Color(0.95, 0.5, 0.38)
const GREEN := Color(0.2, 0.52, 0.3)
const GREEN_LIGHT := Color(0.5, 0.88, 0.58)
const BLUE := Color(0.2, 0.32, 0.62)
const CREAM := Color(0.99, 0.96, 0.89)
const DIM := Color(0.48, 0.44, 0.5)
## The counter's panel: a monitor's dark glass.
const GLASS := Color(0.07, 0.05, 0.1)
const GLASS_TEXT := Color(0.88, 0.86, 0.95)
const GLASS_DIM := Color(0.5, 0.46, 0.58)
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


## The titles' rounded capitals (Righteous, OFL).
static func titles() -> Font:
	if _titles == null:
		_titles = load("res://assets/fonts/Righteous.ttf") as Font
	return _titles
