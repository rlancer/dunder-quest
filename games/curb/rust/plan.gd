class_name Plan
extends RefCounted

## One of Barry's plans: a short Rust program on his legal pad, with blanks
## the player fills from a few options. The code is text with «slot» marks;
## a pick replaces each mark with the chosen option's text, so what the
## checker sees, what rustc sees (tests/verify_rust.py) and what the pad
## shows are the same characters.

const OPEN := "«"
const CLOSE := "»"

var id: String = ""
var file_name: String = "plan.rs"
var title: String = ""
var data: Dictionary = {}
var code: Array = []
## Slot id -> Array of option strings.
var slots: Dictionary = {}
var slot_order: PackedStringArray = []
var _picks: Dictionary = {}


static func from_data(d: Dictionary) -> Plan:
	var plan := Plan.new()
	plan.data = d
	plan.id = str(d.get("id", ""))
	plan.file_name = str(d.get("file", "plan.rs"))
	plan.title = str(d.get("title", ""))
	plan.code = d.get("code", [])
	plan.slots = d.get("slots", {})
	for line: String in plan.code:
		var at := line.find(OPEN)
		while at >= 0:
			var close := line.find(CLOSE, at)
			var name := line.substr(at + 1, close - at - 1)
			if not plan.slot_order.has(name):
				plan.slot_order.append(name)
			at = line.find(OPEN, close)
	plan.set_picks(d.get("start", {}))
	return plan


func pick(slot: String) -> int:
	return int(_picks.get(slot, 0))


func set_pick(slot: String, index: int) -> void:
	if slots.has(slot):
		_picks[slot] = posmod(index, (slots[slot] as Array).size())


## Picks by option text, or by index when given a number.
func set_picks(picks: Dictionary) -> void:
	for slot: String in picks:
		var value: Variant = picks[slot]
		if typeof(value) == TYPE_STRING:
			var at := options(slot).find(value)
			set_pick(slot, at if at >= 0 else 0)
		else:
			set_pick(slot, int(value))


func picks() -> Dictionary:
	var out := {}
	for slot: String in slot_order:
		out[slot] = option(slot)
	return out


func options(slot: String) -> Array:
	return slots.get(slot, [])


func option(slot: String) -> String:
	var opts := options(slot)
	return str(opts[pick(slot)]) if not opts.is_empty() else ""


## The code as lines of segments, {"t": text, "slot": id or ""}, for the pad.
func lines() -> Array:
	var out: Array = []
	for line: String in code:
		var segments: Array = []
		var rest := line
		while true:
			var at := rest.find(OPEN)
			if at < 0:
				segments.append({"t": rest, "slot": ""})
				break
			var close := rest.find(CLOSE, at)
			var name := rest.substr(at + 1, close - at - 1)
			segments.append({"t": rest.substr(0, at), "slot": ""})
			segments.append({"t": option(name), "slot": name})
			rest = rest.substr(close + 1)
		out.append(segments)
	return out


## The program as rustc would get it.
func source() -> String:
	var text := PackedStringArray()
	for line: Array in lines():
		var row := ""
		for segment: Dictionary in line:
			row += str(segment["t"])
		text.append(row)
	return "\n".join(text) + "\n"


func expected() -> Array:
	return data.get("expect", [])


## Checks, and if it compiles runs, the program as picked.
## {"ok": compiled, "error": first error or {}, "run": runner result or {},
##  "passed": compiled and printed exactly what the scene needs}
func evaluate() -> Dictionary:
	var src := source()
	var verdict := RustChecker.check(src)
	if not verdict.ok:
		return {"ok": false, "error": verdict.errors[0], "errors": verdict.errors, "run": {}, "passed": false}
	var run := RustRunner.run(src)
	var passed: bool = run.panic == "" and JSON.stringify(run.stdout) == JSON.stringify(expected())
	return {"ok": true, "error": {}, "errors": [], "run": run, "passed": passed}


## Every combination of picks, for the tests.
func combinations() -> Array:
	var combos: Array = [{}]
	for slot: String in slot_order:
		var next: Array = []
		for combo: Dictionary in combos:
			for index in options(slot).size():
				var c := combo.duplicate()
				c[slot] = index
				next.append(c)
		combos = next
	return combos
