class_name Story
extends RefCounted

## The script of the whole season, from data/scenes.json: the cast, the ten
## scenes (each with its bickering, its plans and its freeze-frame ending),
## Sharon's rants for each rustc error code, and the lesson cards.
## tests/verify_rust.py reads the same file and compiles every plan and card
## with the real rustc.

const PATH := "res://data/scenes.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("data/scenes.json is missing or malformed")
	return _data


static func scenes() -> Array:
	return data().get("scenes", [])


static func count() -> int:
	return scenes().size()


static func scene(id: int) -> Dictionary:
	for s: Dictionary in scenes():
		if int(s.id) == id:
			return s
	return {}


static func name_of(who: String) -> String:
	return str((data().get("cast", {}) as Dictionary).get(who, {}).get("name", who.capitalize()))


static func card(id: String) -> Dictionary:
	var c: Dictionary = (data().get("cards", {}) as Dictionary).get(id, {})
	if c.is_empty():
		return c
	var out := c.duplicate()
	out["id"] = id
	out["code_text"] = "\n".join(PackedStringArray(c.get("code", [])))
	return out


static func checker() -> String:
	return str(data().get("checker", "sharon"))


## Sharon's line for an error: the plan's own, else the stock one.
static func rant(plan: Dictionary, code: String) -> String:
	var own: Dictionary = plan.get("rants", {})
	if own.has(code):
		return str(own[code])
	var stock: Dictionary = data().get("rants", {})
	return str(stock.get(code, stock.get("syntax", "Barry!")))
