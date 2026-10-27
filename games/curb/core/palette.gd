class_name Palette
extends RefCounted

## Westside LA: stucco, terracotta, pool blue, golf green, and Rust's own
## oxide orange for the code. Plus the plain black-and-white of a title card,
## and the show's yellow for the name.

const INK := Color(0.07, 0.06, 0.08)
const PAPER := Color(0.97, 0.94, 0.86)
const STUCCO := Color(0.93, 0.86, 0.74)
const STEEL := Color(0.64, 0.66, 0.72)
const STEEL_DARK := Color(0.32, 0.33, 0.4)
const RED := Color(0.86, 0.24, 0.2)
const GREEN := Color(0.42, 0.78, 0.42)
const AMBER := Color(1.0, 0.72, 0.32)
const POOL := Color(0.36, 0.72, 0.86)
## The show's yellow, for the name and the highlights.
const YELLOW := Color(0.98, 0.83, 0.11)
## Rust orange, for the language and the logo.
const RUST := Color(0.85, 0.42, 0.18)
## The legal pad: yellow paper, blue rules, a red margin.
const PAD := Color(0.99, 0.95, 0.62)
const PAD_RULE := Color(0.55, 0.7, 0.86)
const PAD_MARGIN := Color(0.88, 0.36, 0.34)
const PAD_INK := Color(0.12, 0.14, 0.3)
## Syntax colors, dark enough to read on yellow paper.
const SYN_KEYWORD := Color(0.56, 0.16, 0.56)
const SYN_STRING := Color(0.12, 0.46, 0.18)
const SYN_NUMBER := Color(0.72, 0.32, 0.06)
const SYN_COMMENT := Color(0.44, 0.44, 0.5)
const SYN_CALL := Color(0.1, 0.32, 0.66)
const SYN_MACRO := Color(0.72, 0.2, 0.12)
const SYN_TYPE := Color(0.06, 0.44, 0.5)
## The rehearsal (Barry running it in his head) is tinted sepia.
const SEPIA := Color(0.78, 0.62, 0.42)
## VT323 sizes for the code font.
const SMALL := 16

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


## The title cards' heavy Franklin Gothic, as the show sets its titles
## (Libre Franklin, an OFL revival; the show's ITC Franklin Gothic Heavy is
## commercial).
static func titles() -> Font:
	if _titles == null:
		var font := FontVariation.new()
		font.base_font = load("res://assets/fonts/LibreFranklin.ttf") as Font
		font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
		_titles = font
	return _titles
