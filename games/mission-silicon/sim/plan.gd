class_name Plan
extends RefCounted

## What the player has decided for one episode: which of the pull request's
## cards are kept, which questions have been asked (asking can add cards),
## the dials, and the answers to the live moment's hotfixes. `config()` turns
## that into the board the simulation runs.

var ep: Dictionary
var kept: Dictionary = {}
var asked: Dictionary = {}
var dials: Dictionary = {}
var hotfix: Dictionary = {}


func _init(episode: Dictionary) -> void:
	ep = episode
	for card in cards():
		kept[card["id"]] = true
	for dial in ep.get("dials", []):
		dials[dial["id"]] = dial.get("default", _start_value(dial["id"]))


## Aleister's pull request, kept exactly as proposed.
static func proposed(episode: Dictionary) -> Plan:
	return Plan.new(episode)


## The episode's authored answer.
static func solution(episode: Dictionary) -> Plan:
	var p := Plan.new(episode)
	var sol: Dictionary = episode["solution"]
	for id in sol.get("asks", []):
		p.asked[id] = true
	for card in p.cards():
		p.kept[card["id"]] = sol["keep"].has(card["id"])
	for id in sol.get("dials", {}):
		p.dials[id] = sol["dials"][id]
	p.hotfix = sol.get("hotfix", {}).duplicate()
	return p


func copy() -> Plan:
	var p := Plan.new(ep)
	p.kept = kept.duplicate()
	p.asked = asked.duplicate()
	p.dials = dials.duplicate()
	p.hotfix = hotfix.duplicate()
	return p


func cards() -> Array:
	return ep["pr"]["cards"]


func card(id: String) -> Dictionary:
	for c in cards():
		if c["id"] == id:
			return c
	return {}


## The cards on the table: the proposal, plus any an ask has added.
func visible_cards() -> Array:
	var out := []
	for c in cards():
		if not c.has("from_ask") or asked.has(c["from_ask"]):
			out.append(c)
	return out


func ask(id: String) -> void:
	asked[id] = true
	for a in ep.get("asks", []):
		if a["id"] == id:
			for card_id in a.get("adds", []):
				kept[card_id] = true


## Kept, on the table, and with everything it needs also kept.
func active(card_id: String) -> bool:
	var c := card(card_id)
	if c.is_empty() or not kept.get(card_id, false):
		return false
	if c.has("from_ask") and not asked.has(c["from_ask"]):
		return false
	for need in c.get("needs", []):
		if not active(need):
			return false
	return true


func dial(id: String) -> Dictionary:
	for d in ep.get("dials", []):
		if d["id"] == id:
			return d
	return {}


func dial_available(id: String) -> bool:
	for need in dial(id).get("needs", []):
		if not active(need):
			return false
	return true


func option_available(id: String, value: Variant) -> bool:
	for need in dial(id).get("option_needs", {}).get(str(value), []):
		if not active(need):
			return false
	return true


## A dial's value as the simulation sees it: unavailable dials and options
## fall back to where the board started.
func dial_value(id: String) -> Variant:
	var v: Variant = dials.get(id)
	if not dial_available(id) or not option_available(id, v):
		return _start_value(id)
	return v


func time_used() -> float:
	var total := 0.0
	for c in visible_cards():
		if active(c["id"]):
			total += float(c.get("time", 0))
	for d in ep.get("dials", []):
		var cost: Dictionary = d.get("time", {})
		var v := str(dial_value(d["id"]))
		if cost.has(v):
			total += float(cost[v])
	return total


func fits() -> bool:
	return time_used() <= float(ep["budget"]["time"]) + 0.001


## The board as the simulation runs it, before any hotfix.
func config() -> Dictionary:
	var cfg: Dictionary = ep["board"].duplicate(true)
	for c in visible_cards():
		if active(c["id"]):
			for change in c.get("changes", []):
				apply_change(cfg, change)
	for d in ep.get("dials", []):
		if dial_available(d["id"]) and not _overridden(d["id"]):
			_set_path(cfg, d["id"], dial_value(d["id"]))
	return cfg


## A card that sets a dial's value outright (Ulrich's forty servers) wins
## over the dial.
func _overridden(path: String) -> bool:
	for c in visible_cards():
		if active(c["id"]):
			for change in c.get("changes", []):
				if change.get("set", "") == path:
					return true
	return false


static func apply_change(cfg: Dictionary, change: Dictionary) -> void:
	if change.has("set"):
		_set_path(cfg, change["set"], change["to"])
	elif change.has("add"):
		_set_path(cfg, change["add"], int(_get_path(cfg, change["add"])) + int(change["by"]))


func _start_value(path: String) -> Variant:
	var v: Variant = _get_path(ep["board"], path)
	if v == null:
		var d := dial(path)
		return d.get("default", d.get("options", [null])[0])
	return v


static func _get_path(cfg: Dictionary, path: String) -> Variant:
	var node: Variant = cfg
	for part in path.split("."):
		if not (node is Dictionary) or not node.has(part):
			return null
		node = node[part]
	return node


static func _set_path(cfg: Dictionary, path: String, value: Variant) -> void:
	var parts := path.split(".")
	var node: Dictionary = cfg
	for i in parts.size() - 1:
		if not (node.get(parts[i]) is Dictionary):
			node[parts[i]] = {}
		node = node[parts[i]]
	node[parts[-1]] = value


## A short fingerprint, for test output.
func describe() -> String:
	var keep := []
	for c in visible_cards():
		if active(c["id"]):
			keep.append(c["id"])
	return "keep=%s asked=%s dials=%s hotfix=%s" % [",".join(keep), ",".join(asked.keys()), JSON.stringify(dials), JSON.stringify(hotfix)]
