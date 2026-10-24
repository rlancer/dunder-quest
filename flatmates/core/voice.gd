class_name Voice
extends RefCounted

## The inner voices: what each flatmate thinks when you land in his head,
## when a script throws, and when he falls off something. Clive worries in
## full sentences. Jazz doesn't worry.

const SWAP := {
	"clive": [
		"Back in here. Calm. Orderly. Like a well-kept spreadsheet.",
		"Right. Clive again. Sensible shoes, sensible plan.",
		"Five minutes as Jazz. Never again. Possibly once more.",
		"Note to self: buy a label maker. Label the label maker.",
		"Breathe. You are a man who reads the terms and conditions.",
		"His head smells of crisps. Mine smells of ambition. And fabric softener.",
	],
	"jazz": [
		"Yes. Jazz. The vibe returns.",
		"Clive's brain is a filing cabinet. On fire. With boredom.",
		"Am I a genius? Statistically, somebody has to be.",
		"Note to self: write a song about this. A sad one. Key change at the end.",
		"Who needs a plan when you've got instinct and three chords?",
		"Being Clive is like wearing a tie on the inside.",
	],
}
const ERROR := {
	"clive": [
		"An error. In red. Like a bank statement.",
		"Read the message. The message is your friend. A cruel friend.",
		"It's fine. The computer is just being honest. Unlike Jazz.",
	],
	"jazz": [
		"Red text. Red means stop. Or danger. Or rock and roll.",
		"The laptop's being a bit of a Clive about it.",
		"Computers are just jealous of musicians.",
	],
}
## Said out loud, wandering off when you leave his head.
const DRIFT := {
	"clive": ["Back to the chair, then.", "I'll just sit. Productively.", "Armchair. Safe space."],
	"jazz": ["Sofa time.", "I'll be on the sofa. Visualising.", "Need a lie down after all that."],
}
const FALL := {
	"clive": [
		"Gravity. The one rule nobody gets let off.",
		"That will look terrible on my LinkedIn.",
		"Up you get. Nobody saw. Everybody saw.",
	],
	"jazz": [
		"Meant to do that. Stage dive. No crowd.",
		"Ow. Rock and roll. Ow.",
		"The floor came at me. Respect the floor.",
	],
}


static func swap_line(who: String) -> String:
	return _pick(SWAP, who)


static func error_line(who: String) -> String:
	return _pick(ERROR, who)


static func drift_line(who: String) -> String:
	return _pick(DRIFT, who)


static func fall_line(who: String, falls: int) -> String:
	if falls == 3:
		return Eggs.THIRD_FALL.get(who, "")
	return _pick(FALL, who)


static func _pick(table: Dictionary, who: String) -> String:
	var lines: Array = table.get(who, [])
	return str(lines.pick_random()) if not lines.is_empty() else ""
