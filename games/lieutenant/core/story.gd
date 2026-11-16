class_name Story
extends RefCounted

## The script of every case, from data/cases.json: the cast, each case's
## cold open, its tables (the case database), the props that put a table in
## the Lieutenant's notebook, the beats (a claim, a question, the chips on
## the page and the query that answers it), the lesson cards, and the stock
## lines for errors and near misses. tests/replay.gd reads the same file and
## tests/verify_sql.ts holds every query in it to the real SQLite.

const PATH := "res://data/cases.json"

static var _data: Dictionary = {}
static var _dbs: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("data/cases.json is missing or malformed")
	return _data


static func cases() -> Array:
	return data().get("cases", [])


static func count() -> int:
	return cases().size()


static func case(id: int) -> Dictionary:
	for c: Dictionary in cases():
		if int(c.id) == id:
			return c
	return {}


static func name_of(who: String) -> String:
	return str((data().get("cast", {}) as Dictionary).get(who, {}).get("name", who.capitalize()))


static func full_name(who: String) -> String:
	return str((data().get("cast", {}) as Dictionary).get(who, {}).get("full", who.capitalize()))


static func stock(section: String) -> Variant:
	return (data().get("stock", {}) as Dictionary).get(section, {})


## A case's database, loaded once.
static func db(id: int) -> Dictionary:
	if not _dbs.has(id):
		_dbs[id] = Sql.load_tables(case(id).get("tables", {}))
	return _dbs[id]


## A lesson card: its title, SQL and text, and the tables its SQL runs on
## (its own, or the case's).
static func card(card_id: String, case_id: int) -> Dictionary:
	var c: Dictionary = (data().get("cards", {}) as Dictionary).get(card_id, {})
	if c.is_empty():
		return c
	var out := c.duplicate()
	out["id"] = card_id
	out["db"] = Sql.load_tables(c.tables) if c.has("tables") else db(case_id)
	return out
