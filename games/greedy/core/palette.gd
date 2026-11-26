class_name Palette
extends RefCounted

## Backslash Ridge at sundown: wanted-poster parchment, weathered boards,
## the gold of a tin star, wanted-notice red, and a purple dusk behind it all.

const INK := Color(0.16, 0.09, 0.06)
const PAPER := Color(0.93, 0.85, 0.65)
const PAPER_DARK := Color(0.79, 0.7, 0.49)
const PAPER_LINE := Color(0.7, 0.6, 0.4)
const WOOD := Color(0.36, 0.22, 0.13)
const WOOD_DARK := Color(0.22, 0.13, 0.08)
const WOOD_LIGHT := Color(0.55, 0.36, 0.2)
const GOLD := Color(0.91, 0.63, 0.23)
const GOLD_LIGHT := Color(1.0, 0.84, 0.45)
const RED := Color(0.64, 0.15, 0.11)
const RED_LIGHT := Color(0.9, 0.34, 0.24)
const GREEN := Color(0.25, 0.45, 0.2)
const GREEN_LIGHT := Color(0.55, 0.78, 0.4)
const DUSK := Color(0.23, 0.12, 0.29)
const CREAM := Color(1.0, 0.93, 0.76)
const DIM := Color(0.5, 0.4, 0.3)
## What a pattern caught on a line, and the part a group rounded up.
const MATCH := Color(1.0, 0.78, 0.2, 0.8)
const TAKE := Color(1.0, 0.5, 0.12, 0.95)
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


## The titles' western slab (Rye, OFL).
static func titles() -> Font:
	if _titles == null:
		_titles = load("res://assets/fonts/Rye.ttf") as Font
	return _titles
