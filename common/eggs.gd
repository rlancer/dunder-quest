class_name Eggs
extends RefCounted

## Monty Python easter eggs, since Python is named after the show. Every line
## lives here so they're easy to find; each one's trigger and spot are listed
## on the admin site's Easter eggs page (stats/src/routes/eggs.tsx).

## Title: type S P A M.
const SPAM := "Spam, spam, spam, spam... lovely spam!"
## Title: a minute with no input.
const DIFFERENT := "And now for something completely different."
## Map: type N I.
const NI := "Ni! Bring us... a shrubbery!"
## A stage: turn back and forth fast on the ground.
const SILLY_WALK := "A very silly walk!"
## A stage: the third fall in one attempt, on the respawn.
const GOT_BETTER := "I got better."
const GOT_BETTER_FALLS := 3
## A stage: caught by a copperling, the first time each visit.
const RUN_AWAY := "Run away! Run away!"
## Bellows Bridge: falling into the chasm.
const AUGH := "Auuuuuugh!"
## Pause: left open for half a minute.
const RESTING := "It's not paused, it's resting!"
const RESTING_AFTER := 30.0
## Final card: clearing Crucible Crown after five or more falls.
const BRIGHT_SIDE := "Always look on the bright side of life!"
const BRIGHT_SIDE_FALLS := 5
## Duel: down to the last spark.
const SCRATCH := "'Tis but a scratch!"
## Duel: walking into the wizard.
const NONE_SHALL_PASS := "None shall pass!"
## Duel intros and final lines, by stage. Stage 1's trial is three questions,
## stage 5's is four (the Bridgekeeper loses count).
const INTRO: Dictionary = {
	3: "There are some who call me... Tim.",
	5: "Stop! Answer me these questions... four!",
}
const LAST_WORDS: Dictionary = {
	1: "Three! Not four. And five is right out!",
	5: "African or European?! Auuugh!",
}
## Kiln Mouth: the first hex strike of each fight.
const HEX_SURPRISE := "Nobody expects the hex strike!"
const HEX_STAGE := 3


## Adds a key press to the letters typed so far and returns the last
## `word.length()` of them; the caller checks for `word`. Any key that isn't
## a letter starts over.
static func spell(typed: String, event: InputEvent, word: String) -> String:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return typed
	var key := OS.get_keycode_string((event as InputEventKey).physical_keycode)
	if key.length() != 1 or key < "A" or key > "Z":
		return ""
	return (typed + key).right(word.length())
