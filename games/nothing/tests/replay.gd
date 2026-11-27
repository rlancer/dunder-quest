extends SceneTree

## Holds data/episodes.json to the game's HTTP, without opening a window:
##
## - every scene's written solution gets exactly what the scene wants, using
##   only cards on its table;
## - nothing with fewer cards does: every slip the scene's cards can make is
##   sent, so "par" on screen is the true fewest;
## - every miss has something said about it, every card has a meaning in
##   plain words, every lesson card's demo answers what the card says it
##   does, and every scene has a brief and a hint;
## - a set of probes (requests no table makes) answer as they should.
##
## Then it writes tests/out/requests.json: every one of those requests, with
## the counter and the data it went to and what the game says came back.
## tests/verify_http.ts sends each to a real HTTP server, with real fetch,
## and demands the same.
##
## godot --headless --path . --script res://tests/replay.gd

const OUT := "res://tests/out/requests.json"
## Requests no table makes, at every counter, to hold the rules wider.
const PROBES := [
	["GET", "/"], ["GET", "/nope"], ["GET", "/menu/1"], ["GET", "/orders/x"], ["GET", "/orders/7/8"], ["DELETE", "/orders"],
	["PUT", "/orders/7", "Content-Type: application/json", "{\"item\":\"pie\",\"table\":1}"],
	["PUT", "/orders/7", "Content-Type: application/json", "{\"item\":\"pie\"}"],
	["PATCH", "/orders/7", "Content-Type: application/json", "{\"table\":9}"],
	["PATCH", "/orders/7", "Content-Type: application/json", "{\"chef\":\"Vic\"}"],
	["PATCH", "/orders/7", "Content-Type: application/json", "[1,2]"],
	["PATCH", "/orders/7", "Content-Type: application/json", "{}"],
	["POST", "/orders", "Content-Type: application/json"], ["POST", "/orders"],
	["POST", "/orders", "Content-Type: application/json", "{\"item\":\"pie\",\"table\":1,}"],
	["POST", "/orders", "Content-Type: application/json", "{\"item\":\"pie\",\"table\":1} x"],
	["POST", "/orders", "Content-Type: application/json", "{\"item\":\"p\\u00efe\",\"table\":-1.5e2}"],
	["POST", "/orders", "Content-Type: application/json", "{\"item\":\"pie\",\"table\":01}"],
	["POST", "/orders", "Content-Type: application/json", "{\"item\" : \"pie\" , \"table\" : [true, null]} "],
	["HEAD", "/orders/7"], ["HEAD", "/orders/99"], ["OPTIONS", "/menu"], ["OPTIONS", "/orders"], ["GET", "/orders", "Accept: */*"],
	["GET", "/orders/7", "Accept: application/xml"], ["DELETE", "/orders/7"], ["DELETE", "/orders/99"],
	["GET", "/orders", "If-None-Match: \"v1\""], ["GET", "/orders/7", "If-None-Match: *"],
	["PATCH", "/orders/7", "If-Match: \"v1\"", "Content-Type: application/json", "{\"table\":1}"],
	["PATCH", "/orders/7", "If-Match: \"v9\"", "Content-Type: application/json", "{\"table\":1}"],
	["DELETE", "/orders/7", "If-Match: *"],
	["GET", "/orders", "Authorization: Bearer stu-1990"], ["GET", "/orders", "Authorization: Basic c3R1"],
	["POST", "/orders", "Authorization: Bearer lenny-1990", "Content-Type: application/json", "{\"item\":\"pie\",\"table\":1}"],
]

var _problems: PackedStringArray = []
var _sent: int = 0


func _init() -> void:
	var dump: Array = []
	var scenes := 0
	for line: Dictionary in Story.spoken_lines():
		_expect(Story.data().cast.has(str(line.who)), "nobody in the cast is called %s" % line.who)
	for e: Dictionary in Story.episodes():
		for key: String in ["title", "lesson", "place", "music", "intro", "scenes", "outro"]:
			_expect(e.has(key), "episode %s has no %s" % [e.get("id", "?"), key])
		for scene: Dictionary in e.get("scenes", []):
			scenes += 1
			if scene.has("card"):
				_expect(Story.data().cards.has(str(scene.card)), "%s: no card called %s" % [scene.id, scene.card])
			dump.append_array(_scene(scene))
	for id: String in Story.data().get("cards", {}):
		var card := Story.card(id)
		for key: String in ["title", "text", "demo", "out"]:
			_expect(card.has(key), "card %s has no %s" % [id, key])
		var demo: Dictionary = card.demo
		var fake := {"id": "card " + id, "counter": demo.counter, "data": demo.data, "versions": demo.get("versions", {}), "goal": {"status": 0}}
		var result := Judge.judge(fake, demo.request)
		_expect(not result.has("refused"), "card %s: its demo can't be sent" % id)
		if result.has("lines"):
			_expect(str(result.lines[0]) == str(card.out), "card %s: its demo answers %s, not what the card says" % [id, result.lines[0]])
			dump.append(_entry(fake, demo.request, result))
	for counter: String in Story.data().counters:
		for request: Array in PROBES:
			var def: Dictionary = (Story.data().counters[counter] as Dictionary).duplicate(true)
			# The probes' paths say /orders: every counter gets an orders collection.
			if not (def.routes as Dictionary).has("orders"):
				def.routes["orders"] = {"type": "collection", "fields": ["item", "table"]}
			var fake := {"id": "probe at " + counter, "counter": def, "data": _sample(counter), "versions": {}, "goal": {"status": 0}}
			var result := Judge.judge(fake, request)
			if not result.has("refused"):
				dump.append(_entry(fake, request, result))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	FileAccess.open(OUT.get_base_dir() + "/.gdignore", FileAccess.WRITE).close()
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(dump, "", false))
	file.close()
	for line in _problems:
		print("PROBLEM ", line)
	print("REPLAY result=%s scenes=%d requests=%d" % ["ok" if _problems.is_empty() else "FAIL %d" % _problems.size(), scenes, _sent])
	quit(0 if _problems.is_empty() else 1)


func _expect(ok: bool, what: String) -> void:
	if not ok and not _problems.has(what):
		_problems.append(what)


## Some data for a counter's probes: two items in each collection, a list in
## each document.
func _sample(counter: String) -> Dictionary:
	var out := {}
	var routes: Dictionary = Story.data().counters[counter].routes
	for name: String in routes:
		var route: Dictionary = routes[name]
		if str(route.type) == "doc":
			out[name] = ["one", "two"]
		else:
			var items: Array = []
			for id: int in [7, 8]:
				var item := {"id": id}
				for field: String in route.fields:
					item[field] = "%s %d" % [field, id]
				items.append(item)
			out[name] = items
	# The probes' paths say /orders: give every counter an orders collection.
	if not out.has("orders"):
		out["orders"] = [{"id": 7, "item": "pie", "table": 1}]
	return out


func _entry(scene: Dictionary, cards: Array, result: Dictionary) -> Dictionary:
	_sent += 1
	var r: Dictionary = result.response
	var counter := Judge.counter(scene)
	return {
		"id": scene.id, "counter": counter, "data": scene.get("data", {}), "versions": scene.get("versions", {}),
		"slip": result.slip, "status": r.status, "reason": r.reason, "headers": r.headers, "body": r.body,
		"state": r.state,
	}


func _scene(scene: Dictionary) -> Array:
	var id := str(scene.id)
	for key: String in ["brief", "hint", "counter", "cards", "solution", "goal"]:
		_expect(scene.has(key), "%s has no %s" % [id, key])
	_expect(not Judge.counter(scene).is_empty(), "%s: no counter called %s" % [id, scene.get("counter", "")])
	for card: String in scene.cards:
		_expect(Story.meaning(card) != "", "%s: the card %s means nothing in the glossary" % [id, card])
	for card: String in scene.solution:
		_expect((scene.cards as Array).has(card), "%s: its solution uses %s, which isn't on the table" % [id, card])
	var won := Judge.judge(scene, scene.solution)
	_expect(bool(won.get("won", false)), "%s: its solution gets %s" % [id, won.get("got", won.get("refused", "?"))])
	var par := Story.par(scene)
	var out: Array = []
	for cards: Array in Http.slips(scene.cards):
		var result := Judge.judge(scene, cards)
		if result.has("refused"):
			continue
		if bool(result.won) and cards.size() < par:
			_expect(false, "%s: %s works with fewer cards than its solution" % [id, cards])
		if not bool(result.won):
			var said := Story.stock(str(result.why))
			_expect(not said.is_empty(), "%s: nothing to say about a miss of the kind \"%s\"" % [id, result.why])
			for template: String in said:
				_expect(not Judge.fill(template, result).contains("{"), "%s: an unfilled blank in \"%s\"" % [id, template])
		out.append(_entry(scene, cards, result))
	return out
