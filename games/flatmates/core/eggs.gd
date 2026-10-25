class_name Eggs
extends RefCounted

## Hidden nods to the flat-share sitcom the game is an homage to. Short,
## and only where you have to go looking. Every line is here so they are
## easy to find, with its trigger above it.

## Title: type the band's real name.
const BAND_WORD := "ELDUDE"
const BAND := "The El Dude Brothers. One night only. Possibly no nights."
## Title: a minute with no input.
const IDLE := "Just stand here. Normal. Very normal. Is this how long people stand?"
## A stage: the third fall in one go.
const THIRD_FALL := {
	"clive": "Three falls. Classic me. Absolutely classic.",
	"jazz": "Three times. Like a hat trick. Of pain.",
}
## A stage: swapping heads ten times in a row without moving.
const DIZZY := "Who am I? Where am I? Is this Croydon?"
const DIZZY_SWAPS := 10
## Line map: type C R O Y D O N.
const TOWN_WORD := "CROYDON"
const TOWN := "Croydon: twinned with nowhere, by mutual agreement."
## The band's name changes every time Jazz strums on the title screen.
const BAND_NAMES: Array[String] = [
	"Hot Pocket Rebellion", "Spoon Theory", "The Overdraft", "Council Tax Band D",
	"Mum's Lasagne", "Replacement Bus Service", "Dad Rock Fury", "Unpaid Internship",
]


## Adds a key press to the letters typed so far and returns the last
## `word.length()` of them. Any key that isn't a letter starts over.
static func spell(typed: String, event: InputEvent, word: String) -> String:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return typed
	var key := OS.get_keycode_string((event as InputEventKey).physical_keycode)
	if key.length() != 1 or key < "A" or key > "Z":
		return ""
	return (typed + key).right(word.length())
