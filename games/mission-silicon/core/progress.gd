extends Node

## Each episode's best runway and marks, saved as JSON in user:// under its
## own name so it never touches the other games' saves.

const SAVE_PATH := "user://mission_silicon_save.json"

## Tests turn this off so a bot run never rewrites the player's save.
static var persist: bool = true

var best: Dictionary = {}


func _ready() -> void:
	if not persist or not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f else null
	if parsed is Dictionary:
		best = parsed.get("best", {})


func record(id: int, runway: float, marks: Dictionary) -> void:
	var key := str(id)
	var old: Dictionary = best.get(key, {})
	var merged := {"runway": maxf(runway, float(old.get("runway", 0.0)))}
	for m in marks:
		merged[m] = marks[m] or old.get(m, false)
	best[key] = merged
	if persist:
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify({"best": best}))


func cleared(id: int) -> bool:
	return best.has(str(id))
