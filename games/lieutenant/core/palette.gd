class_name Palette
extends RefCounted

## Los Angeles, 1974, after dark: raincoat tan, cigar-ember orange, mustard
## and avocado, the cream of a spiral notebook, and the pale green stripes of
## computer printout paper.

const INK := Color(0.09, 0.07, 0.08)
const PAPER := Color(0.96, 0.93, 0.84)
## The title's cream and the ember accent that goes with it.
const CREAM := Color(0.99, 0.9, 0.68)
const EMBER := Color(0.94, 0.5, 0.2)
const MUSTARD := Color(0.9, 0.7, 0.24)
const RAINCOAT := Color(0.78, 0.7, 0.55)
const AVOCADO := Color(0.5, 0.58, 0.28)
const NIGHT := Color(0.09, 0.12, 0.24)
const RED := Color(0.86, 0.28, 0.22)
const GREEN := Color(0.36, 0.68, 0.4)
const STEEL := Color(0.66, 0.66, 0.7)
const STEEL_DARK := Color(0.34, 0.33, 0.38)
## The Lieutenant's notebook: cream paper, blue rules, pencil.
const NOTE := Color(0.98, 0.95, 0.85)
const NOTE_RULE := Color(0.6, 0.73, 0.86)
const NOTE_INK := Color(0.14, 0.14, 0.24)
const NOTE_COVER := Color(0.3, 0.2, 0.14)
## Green-bar printout paper, for what Records sends back.
const BAR_LIGHT := Color(0.96, 0.97, 0.93)
const BAR_GREEN := Color(0.82, 0.92, 0.82)
const BAR_INK := Color(0.1, 0.17, 0.13)
## SQL colors, dark enough to read on paper.
const SYN_KEYWORD := Color(0.22, 0.2, 0.62)
const SYN_STRING := Color(0.12, 0.44, 0.2)
const SYN_NUMBER := Color(0.7, 0.32, 0.06)
const SYN_FUNC := Color(0.62, 0.14, 0.4)
## The same four on a dark card.
const DARK_KEYWORD := Color(0.62, 0.72, 1.0)
const DARK_STRING := Color(0.62, 0.86, 0.56)
const DARK_NUMBER := Color(1.0, 0.72, 0.4)
const DARK_FUNC := Color(1.0, 0.6, 0.8)
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


## The titles' fat, soft 1970s serif (Caprasimo, OFL).
static func titles() -> Font:
	if _titles == null:
		_titles = load("res://assets/fonts/Caprasimo.ttf") as Font
	return _titles
