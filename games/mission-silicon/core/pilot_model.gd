class_name PilotModel
extends RefCounted

## Episode 1, the Pilot's rules, apart from its screens (scenes/pilot.gd) so
## tests/cases.gd can check them headless: which options fit Thursday's
## requirements, the 200 testers and what happens to each on a build, the
## feed beside the meter, and the marks. Everything it reads is in
## data/pilot.json.


static func platform(id: String) -> Dictionary:
	for p in Season.pilot()["platforms"]:
		if p["id"] == id:
			return p
	return {}


## An option fits when every requirement Thursday must have is a yes, and
## it fits the hours. "partly" is fine only for what isn't a must.
static func passes(option: Dictionary, reqs: Array, hours: float) -> bool:
	if option.is_empty() or float(option["h"]) > hours:
		return false
	for q in reqs:
		var r: Array = option["r"].get(q["id"], ["n", ""])
		if q.get("later", false):
			continue
		if r[0] == "n" or (q.get("must", false) and r[0] != "y"):
			return false
	return true


## The 200 testers: when each arrives (minutes after 4pm) and whether the
## restaurant list has a place that fits them, from a seeded generator so
## every play and every test sees the same Thursday.
static func testers() -> Dictionary:
	var t: Dictionary = Season.pilot()["thursday"]
	var state := [int(t["seed"]) & 0xFFFFFFFF]
	var out := {}
	for dev in t["devices"]:
		var list := []
		for _i in int(dev["count"]):
			var at := floori(_rand(state) * float(t["minutes"]))
			var ok := _rand(state) < float(t["ok_share"])
			list.append({"at": at, "ok": ok})
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
		out[dev["id"]] = list
	return out


## mulberry32, as the storyboard has it.
static func _rand(state: Array) -> float:
	state[0] = (int(state[0]) + 0x6D2B79F5) & 0xFFFFFFFF
	var a: int = state[0]
	var t := _imul(a ^ (a >> 15), 1 | a)
	t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
	return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0


static func _imul(x: int, y: int) -> int:
	x &= 0xFFFFFFFF
	y &= 0xFFFFFFFF
	return ((x & 0xFFFF) * y + ((((x >> 16) * y) & 0xFFFF) << 16)) & 0xFFFFFFFF


## One tester's evening on a build: "none" if their device can't open it,
## "wrong" if the iPhone bug got them before the fix landed, else "fit" or
## "near" (a near miss: nothing on the list quite fit).
static func outcome(build: String, dev: String, who: Dictionary) -> String:
	var t: Dictionary = Season.pilot()["thursday"]
	var p := platform(build)
	if dev == "laptop" and not p.get("laptops", false):
		return "none"
	var bug := int(t["bug"])
	var fix_at := bug + int(p.get("fix", 0)) if int(p.get("fix", 0)) > 0 else 1 << 30
	if dev == "iphone" and int(who["at"]) >= bug and int(who["at"]) < fix_at:
		return "wrong"
	return "fit" if who["ok"] else "near"


## Thursday on a build, up to a minute (the whole test by default): the
## count of each outcome and the share who found a place that fits.
static func thursday(build: String, upto: int = -1) -> Dictionary:
	var t: Dictionary = Season.pilot()["thursday"]
	if upto < 0:
		upto = int(t["minutes"])
	var c := {"fit": 0, "near": 0, "wrong": 0, "none": 0, "n": 0}
	var all := testers()
	for dev in t["devices"]:
		for who in all[dev["id"]]:
			if int(who["at"]) < upto:
				c[outcome(build, dev["id"], who)] += 1
				c["n"] += 1
	c["share"] = float(c["fit"]) / float(c["n"]) if c["n"] > 0 else 0.0
	return c


## The feed beside the meter, up to a minute.
static func feed(build: String, m: int) -> Array:
	var f: Dictionary = Season.pilot()["thursday"]["feed"]
	var p := platform(build)
	var out := []
	if not p.get("laptops", false):
		out.append(f["no_laptops"])
	if m >= int(f["bug"]["at"]):
		out.append(f["bug"])
	if int(p.get("fix", 0)) > 0 and m >= int(f["fixed"]["at"]):
		out.append(f["fixed"])
	if int(p.get("fix", 0)) == 0 and m >= int(f["review"]["at"]):
		out.append(f["review"])
	return out


## The marks. Live: nine in ten found a place. Lean: only what Thursday
## needed (the plain web app; reminders aren't Thursday's). Ulrich: never
## picked native apps for show.
static func marks(build: String, tried_native: bool) -> Dictionary:
	var pd := Season.pilot()
	var live: bool = thursday(build)["share"] >= float(pd["goal_share"])
	return {"live": live, "lean": live and build == pd["lean_platform"], "ulrich": live and not tried_native}


