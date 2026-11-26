class_name Http
extends RefCounted

## HTTP, small enough to read in one sitting: a request slip, a counter that
## answers it, and the response, written out the way they go over the wire.
##
## A counter (data/episodes.json, "counters") is a little REST API: its
## routes are either a document ("/menu": read only) or a collection
## ("/orders", and each item in it at "/orders/7"), and it may have rules of
## its own: bodies must be JSON (they all do), every write must say which
## version it's changing (If-Match), you need a token (Authorization), or
## writes are only accepted and finished later (202). `answer` plays a request
## against a counter and the data on it, the way a well-behaved server does
## under RFC 9110:
##
##   no such path, or no such item       404 Not Found
##   a token needed and missing or wrong 401 Unauthorized + WWW-Authenticate
##   a token that isn't allowed to       403 Forbidden
##   a method the path doesn't do        405 Method Not Allowed + Allow
##   OPTIONS                             204 No Content + Allow
##   an Accept the counter can't give    406 Not Acceptable
##   a body that isn't JSON by its type  415 Unsupported Media Type
##   a body missing, broken or wrong     400 Bad Request
##   a write with no If-Match, if needed 428 Precondition Required
##   an If-Match that's out of date      412 Precondition Failed
##   an If-None-Match that's current     304 Not Modified
##   GET or HEAD                         200 OK (HEAD with no body)
##   POST                                201 Created + Location (202 Accepted
##                                       where the counter finishes later)
##   PUT (all of it) or PATCH (part)     200 OK
##   DELETE                              204 No Content
##
## tests/verify_http.ts runs a real HTTP server on the same rules and sends it
## every request the game can make with real fetch, and demands the same
## status, reason, headers and body, and the same data left behind.

const METHODS := ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
const WITH_BODY := ["POST", "PUT", "PATCH"]
const WRITES := ["POST", "PUT", "PATCH", "DELETE"]
const REASONS := {
	200: "OK", 201: "Created", 202: "Accepted", 204: "No Content", 304: "Not Modified",
	400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found", 405: "Method Not Allowed",
	406: "Not Acceptable", 412: "Precondition Failed", 415: "Unsupported Media Type", 428: "Precondition Required",
}
## The response headers the game shows, in this order. (A real server sends
## Date and Content-Length too; they never change what a request means.)
const SHOWN := ["Content-Type", "Location", "ETag", "Allow", "WWW-Authenticate"]


# --- Cards and slips -----------------------------------------------------------

## What a card is: "method", "path", "header" or "body".
static func kind(card: String) -> String:
	if METHODS.has(card):
		return "method"
	if card.begins_with("/"):
		return "path"
	if card.begins_with("{") or card.begins_with("["):
		return "body"
	return "header"


## A request slip from cards: {"method", "path", "headers": [cards], "body"}.
static func slip(cards: Array) -> Dictionary:
	var out := {"method": "", "path": "", "headers": [], "body": ""}
	for card: String in cards:
		match kind(card):
			"method":
				out.method = card
			"path":
				out.path = card
			"body":
				out.body = card
			"header":
				(out.headers as Array).append(card)
	return out


## Every slip a scene's cards can make: a method and a path (one of each),
## any headers (one of each name), and a body or none.
static func slips(cards: Array) -> Array:
	var methods: Array = []
	var paths: Array = []
	var headers: Array = []
	var bodies: Array = [""]
	for card: String in cards:
		match Http.kind(card):
			"method":
				methods.append(card)
			"path":
				paths.append(card)
			"header":
				headers.append(card)
			"body":
				bodies.append(card)
	var sets: Array = [[]]
	for h: String in headers:
		var more: Array = []
		for set: Array in sets:
			var clash := false
			for other: String in set:
				if str(Http.split_header(other)[0]) == str(Http.split_header(h)[0]):
					clash = true
			if not clash:
				more.append(set + [h])
		sets.append_array(more)
	var out: Array = []
	for m: String in methods:
		for p: String in paths:
			for set: Array in sets:
				for b: String in bodies:
					var slip: Array = [m, p] + set
					if b != "":
						slip.append(b)
					out.append(slip)
	return out


## Why a slip can't be sent, or "" if it can: "method", "path" (it needs
## one), or "body" (only POST, PUT and PATCH carry one here: fetch won't even
## send a GET or a HEAD with a body).
static func refuse(s: Dictionary) -> String:
	if str(s.method) == "":
		return "method"
	if str(s.path) == "":
		return "path"
	if str(s.body) != "" and not WITH_BODY.has(str(s.method)):
		return "body"
	return ""


## A header card's name and value.
static func split_header(card: String) -> Array:
	var at := card.find(": ")
	return [card.left(at), card.substr(at + 2)] if at > 0 else [card, ""]


## The value of header `name` on a slip (any case), or "".
static func header(s: Dictionary, name: String) -> String:
	for card: String in s.headers:
		var pair := split_header(card)
		if str(pair[0]).to_lower() == name.to_lower():
			return str(pair[1])
	return ""


## The request as it goes over the wire, a line at a time.
static func request_lines(s: Dictionary, host: String) -> Array:
	var out: Array = ["%s %s HTTP/1.1" % [s.method if s.method != "" else "___", s.path if s.path != "" else "___"], "Host: %s" % host]
	for card: String in s.headers:
		out.append(card)
	if str(s.body) != "":
		out.append("")
		out.append(str(s.body))
	return out


## The response as it comes back over the wire (the headers SHOWN).
static func response_lines(r: Dictionary) -> Array:
	var out: Array = ["HTTP/1.1 %d %s" % [int(r.status), r.reason]]
	for pair: Array in r.headers:
		out.append("%s: %s" % [pair[0], pair[1]])
	if str(r.body) != "":
		out.append("")
		out.append(str(r.body))
	return out


# --- The data on a counter ---------------------------------------------------------

## A counter's data as the scene sets it out: {"items": {route: [objects]},
## "v": {route: n, "route/id": n}}, versions defaulting to 1.
static func state(data: Dictionary, versions: Dictionary = {}) -> Dictionary:
	return {"items": data.duplicate(true), "v": versions.duplicate()}


static func version(st: Dictionary, key: String) -> int:
	return int((st.v as Dictionary).get(key, 1))


static func etag(st: Dictionary, key: String) -> String:
	return "\"v%d\"" % version(st, key)


static func _bump(st: Dictionary, key: String) -> void:
	st.v[key] = version(st, key) + 1


# --- Answering -------------------------------------------------------------------

## The counter's answer to slip `s`, with the data `st` as it stands:
## {"status", "reason", "headers": [[name, value]], "body", "state"}.
static func answer(counter: Dictionary, st: Dictionary, s: Dictionary) -> Dictionary:
	var after := st.duplicate(true)
	var r := _answer(counter, after, s)
	r["state"] = after
	r["reason"] = REASONS.get(int(r.status), "")
	# HEAD gets GET's headers and no body; so do 204 and 304.
	if str(s.method) == "HEAD" or int(r.status) in [204, 304]:
		r.body = ""
		var kept: Array = []
		for pair: Array in r.headers:
			if str(pair[0]) != "Content-Type" or str(s.method) == "HEAD" and int(r.status) not in [204, 304]:
				kept.append(pair)
		r.headers = kept
	return r


static func _error(counter: Dictionary, status: int, message: String, extra: Array = []) -> Dictionary:
	var said := str(counter.get("says", message))
	return {"status": status, "headers": [["Content-Type", "application/json"]] + extra, "body": Wire.write({"error": said})}


static func _ok(status: int, value: Variant, extra: Array = []) -> Dictionary:
	return {"status": status, "headers": [["Content-Type", "application/json"]] + extra, "body": Wire.write(value)}


static func _allow(route: Dictionary, item: bool) -> Array:
	if route.has("methods"):
		return route.methods
	if str(route.type) == "doc":
		return ["GET", "HEAD", "OPTIONS"]
	return ["GET", "HEAD", "PUT", "PATCH", "DELETE", "OPTIONS"] if item else ["GET", "HEAD", "POST", "OPTIONS"]


static func _answer(counter: Dictionary, st: Dictionary, s: Dictionary) -> Dictionary:
	var method := str(s.method)
	# Where: a route, and an item in it.
	var parts := str(s.path).trim_prefix("/").split("/")
	var routes: Dictionary = counter.routes
	if parts.size() > 2 or parts[0] == "" or not routes.has(parts[0]):
		return _error(counter, 404, "Not found")
	var name := parts[0]
	var route: Dictionary = routes[name]
	var item := parts.size() == 2
	var items: Array = (st.items as Dictionary).get(name, [])
	var found := -1
	if item:
		if str(route.type) == "doc" or not parts[1].is_valid_int():
			return _error(counter, 404, "Not found")
		for i in items.size():
			if int(items[i].id) == int(parts[1]):
				found = i
		if found < 0:
			return _error(counter, 404, "Not found")
	var key := "%s/%s" % [name, parts[1]] if item else name
	# Who: a token, if the counter wants one.
	var tokens: Dictionary = counter.get("tokens", {})
	if not tokens.is_empty():
		var auth := header(s, "Authorization")
		var challenge := [["WWW-Authenticate", "Bearer realm=\"%s\"" % counter.host]]
		if not auth.begins_with("Bearer ") or not tokens.has(auth.substr(7)):
			return _error(counter, 401, "Who are you?", challenge)
		var may: Array = tokens[auth.substr(7)]
		if not may.has("write" if WRITES.has(method) else "read"):
			return _error(counter, 403, "Not you.")
	# What: a method this path does.
	var allow := _allow(route, item)
	var allow_line := [["Allow", ", ".join(PackedStringArray(allow))]]
	if not allow.has(method):
		return _error(counter, 405, "Not here", allow_line)
	if method == "OPTIONS":
		return {"status": 204, "headers": allow_line, "body": ""}
	var accept := header(s, "Accept")
	if accept != "" and accept != "application/json" and accept != "*/*":
		return _error(counter, 406, "JSON only")
	# A body, for the methods that carry one.
	var body: Dictionary = {}
	if WITH_BODY.has(method):
		if header(s, "Content-Type") != "application/json":
			return _error(counter, 415, "Say it in JSON")
		if str(s.body) == "":
			return _error(counter, 400, "No body")
		var parsed: Variant = Wire.read(str(s.body))
		if not parsed is Dictionary:
			return _error(counter, 400, "That isn't JSON")
		body = parsed
		var fields: Array = route.get("fields", [])
		for field: String in body:
			if not fields.has(field):
				return _error(counter, 400, "No such field: %s" % field)
		if method != "PATCH":
			for field: String in fields:
				if not body.has(field):
					return _error(counter, 400, "Missing field: %s" % field)
	# Which version: the conditional headers.
	var if_match := header(s, "If-Match")
	if item and ["PUT", "PATCH", "DELETE"].has(method):
		if if_match == "" and bool(counter.get("if_match", false)):
			return _error(counter, 428, "Which version?")
		if if_match != "" and if_match != "*" and if_match != etag(st, key):
			return _error(counter, 412, "It changed")
	var tagged := bool(counter.get("etag", false))
	var tag := [["ETag", etag(st, key)]] if tagged else []
	var if_none := header(s, "If-None-Match")
	if (method == "GET" or method == "HEAD") and tagged and if_none != "" and (if_none == etag(st, key) or if_none == "*"):
		return {"status": 304, "headers": tag, "body": ""}
	# Do it.
	match method:
		"GET", "HEAD":
			return _ok(200, items[found] if item else items, tag)
		"POST":
			var next := 1
			for it: Dictionary in items:
				next = maxi(next, int(it.id) + 1)
			var made := {"id": next}
			for field: String in route.get("fields", []):
				made[field] = body[field]
			items.append(made)
			st.items[name] = items
			_bump(st, name)
			var where := [["Location", "/%s/%d" % [name, next]]]
			return _ok(202 if bool(counter.get("later", false)) else 201, made, where)
		"PUT", "PATCH":
			var changed: Dictionary = (items[found] as Dictionary).duplicate()
			for field: String in body:
				changed[field] = body[field]
			items[found] = changed
			st.items[name] = items
			_bump(st, key)
			_bump(st, name)
			return _ok(200, changed, [["ETag", etag(st, key)]] if tagged else [])
		"DELETE":
			items.remove_at(found)
			st.items[name] = items
			_bump(st, name)
			return {"status": 204, "headers": [], "body": ""}
	return _error(counter, 405, "Not here", allow_line)
