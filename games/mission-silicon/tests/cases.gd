extends SceneTree

## Every episode's data must prove its own lesson (GAME.md, "How each
## episode's lesson is checked"), by running the simulation headless:
##   1. the solution passes and reaches par;
##   2. Aleister's PR as proposed fails, and so does doing nothing;
##   3. flipping any one decision in the solution fails the goal, costs
##      runway, or is marked free, and every failure's top finding has a
##      postmortem entry;
##   4. Ulrich's card does what the data says;
##   5. no plan found by a seeded search passes with more runway than the
##      solution (every card combination, every pair of dial changes, and
##      random plans);
##   and the same plan gives the identical night twice.
## Episode 1, the Pilot, is checked on its own decision boards instead
## (`_pilot`, below).
##
## godot --headless --path . --script res://tests/cases.gd   ->  CASES result=ok

const MARGIN := 0.005
const RANDOM_PLANS := 3000

var _fails: PackedStringArray = []
var _runs: int = 0


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	# CASES_EP=9 checks one episode, for quick tuning.
	var only := OS.get_environment("CASES_EP")
	if only == "" or only == "1":
		_pilot()
	for ep in Season.episodes():
		if only == "" or only == str(int(ep["id"])):
			_continuity(ep)
			_check(ep)
	print("CASES %d runs in %.1fs" % [_runs, (Time.get_ticks_msec() - started) / 1000.0])
	print("CASES result=%s" % ("ok" if _fails.is_empty() else "FAIL\n  " + "\n  ".join(_fails)))
	quit(0 if _fails.is_empty() else 1)


func _fail(ep: Dictionary, what: String) -> void:
	_fails.append("ep %d: %s" % [ep["id"], what])


func _play(ep: Dictionary, p: Plan) -> Dictionary:
	_runs += 1
	return Sim.play(ep, p)


func _summary(res: Dictionary) -> String:
	if not res.get("merge", true):
		return "can't merge (too long)"
	var bad := []
	for g in res["goals"]:
		if not g["ok"]:
			bad.append("%s=%.3f" % [g["metric"], g["value"]])
	return "%s runway=%.3f tags=%s %s" % ["PASS" if res["passed"] else "FAIL", res["runway"], ",".join(res["tags"].slice(0, 3)), " ".join(bad)]


func _check(ep: Dictionary) -> void:
	var sol := Plan.solution(ep)
	var best := _play(ep, sol)
	# A script error in the simulation comes back empty, not as a failure.
	if not best.has("passed"):
		_fail(ep, "the simulation didn't run")
		return
	print("ep %d solution: %s" % [ep["id"], _summary(best)])
	print("  model bill %s, revenue %s, monthly +%s" % [Palette.money(best["model_bill"]), Palette.money(best["revenue"]), Palette.money(best["monthly_extra"])])
	if not best["passed"]:
		_fail(ep, "solution fails: " + _summary(best))
		return
	if not best["lean"]:
		_fail(ep, "solution runway %.3f under par %.2f" % [best["runway"], best["par"]])
	var sol_runway: float = best["runway"]

	# Determinism.
	if absf(_play(ep, sol)["runway"] - sol_runway) > 0.0:
		_fail(ep, "the same plan gave a different night")

	# 2. The proposal and doing nothing.
	var proposed := Plan.proposed(ep)
	var res := _play(ep, proposed)
	print("  proposed: " + _summary(res))
	if res["passed"]:
		_fail(ep, "Aleister's PR as proposed passes")
	var nothing := Plan.proposed(ep)
	for c in nothing.cards():
		nothing.kept[c["id"]] = false
	res = _play(ep, nothing)
	print("  nothing: " + _summary(res))
	if res["passed"]:
		_fail(ep, "doing nothing passes")

	# 3 and 4. Every single flip.
	var free: Array = ep.get("free", [])
	for c in sol.cards():
		var p := sol.copy()
		if c.has("from_ask"):
			p.asked[c["from_ask"]] = true
		p.kept[c["id"]] = not sol.active(c["id"])
		_judge_flip(ep, "card %s %s" % [c["id"], "kept" if p.kept[c["id"]] else "cut"], p, sol_runway, false)
		if c.get("by", "") == "ulrich":
			var r := _play(ep, p)
			var hurt: bool = not r["passed"] or r["runway"] < sol_runway - MARGIN
			if c.get("ulrich_right", false) == sol.active(c["id"]) and not hurt:
				_fail(ep, "Ulrich's card %s doesn't matter" % c["id"])
	for d in ep["dials"]:
		if not sol.dial_available(d["id"]):
			continue
		for v in d["options"]:
			if str(v) == str(sol.dials[d["id"]]) or not sol.option_available(d["id"], v):
				continue
			var p := sol.copy()
			p.dials[d["id"]] = v
			_judge_flip(ep, "dial %s=%s" % [d["id"], v], p, sol_runway, free.has(d["id"]))
	for h in ep["live"].get("hotfixes", []):
		var p := sol.copy()
		p.hotfix[h["id"]] = not sol.hotfix.get(h["id"], false)
		_judge_flip(ep, "hotfix %s %s" % [h["id"], p.hotfix[h["id"]]], p, sol_runway, false)

	# The capstone: every box already on the board earns its place.
	_capstone(ep)

	# 5. No cheap way round.
	_search(ep, sol, sol_runway)


## The finale (`capstone` in its data): every box the season put on the
## board must earn its place against the night's replay. Taking any one of
## them away from the solution's board (each entry sets one part of the
## board back to how it was before the episode that fixed it) must fail
## the night, with a finding Gerard can read out.
func _capstone(ep: Dictionary) -> void:
	for entry in ep.get("capstone", []):
		var copy: Dictionary = ep.duplicate(true)
		Plan.apply_change(copy["board"], entry)
		var r := _play(copy, Plan.solution(copy))
		print("  without %s: %s" % [entry["label"], _summary(r)])
		if r["passed"]:
			_fail(ep, "the night passes without %s: it hasn't earned its place" % entry["label"])
		elif not ep["postmortem"].has(r["tags"][0] if not r["tags"].is_empty() else ""):
			_fail(ep, "without %s the top finding '%s' has no postmortem entry" % [entry["label"], r["tags"][0] if not r["tags"].is_empty() else ""])


## 6. Each episode starts where the one before it ended: every part of the
## previous solution's board (hotfixes kept) is the same on this one's,
## unless `changed` names it and the cold open says why.
func _continuity(ep: Dictionary) -> void:
	var prev := Season.episode(int(ep["id"]) - 1)
	if prev.is_empty():
		return
	var sol := Plan.solution(prev)
	var cfg := sol.config()
	for h in prev["live"].get("hotfixes", []):
		if sol.hotfix.get(h["id"], false):
			for change in h.get("changes", []):
				Plan.apply_change(cfg, change)
	var changed: Array = ep.get("changed", [])
	for key in cfg:
		if not changed.has(key) and not _same(cfg[key], ep["board"].get(key)):
			_fail(ep, "starting board's %s isn't where episode %d ended: %s, not %s" % [key, prev["id"], cfg[key], ep["board"].get(key)])


static func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size():
			return false
		for k in a:
			if not b.has(k) or not _same(a[k], b[k]):
				return false
		return true
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _judge_flip(ep: Dictionary, what: String, p: Plan, sol_runway: float, free: bool) -> void:
	var r := _play(ep, p)
	print("  flip %s: %s" % [what, _summary(r)])
	if r["passed"] and r["runway"] > sol_runway + MARGIN:
		_fail(ep, "%s passes with more runway (%.3f) than the solution" % [what, r["runway"]])
	elif r["passed"] and r["runway"] >= sol_runway - MARGIN and not free:
		_fail(ep, "%s changes nothing and isn't marked free" % what)
	if not r["passed"] and r.get("merge", true):
		var top: String = r["tags"][0] if not r["tags"].is_empty() else ""
		if not ep["postmortem"].has(top):
			_fail(ep, "%s fails with no postmortem finding (top tag '%s')" % [what, top])


func _search(ep: Dictionary, sol: Plan, sol_runway: float) -> void:
	var base := sol.copy()
	for a in ep["asks"]:
		base.asked[a["id"]] = true
	var cards := base.cards()
	var found := 0
	# Every card combination, both hotfix answers.
	for mask in 1 << cards.size():
		for hf in [false, true]:
			var p := base.copy()
			for i in cards.size():
				p.kept[cards[i]["id"]] = (mask >> i) & 1 == 1
			for h in ep["live"].get("hotfixes", []):
				p.hotfix[h["id"]] = hf
			if not p.fits():
				continue
			found += _try(ep, p, sol_runway, "combo")
	# Every pair of dial changes, on the solution's cards.
	var moves := []
	for d in ep["dials"]:
		for v in d["options"]:
			if str(v) != str(sol.dials[d["id"]]):
				moves.append([d["id"], v])
	for i in moves.size():
		for j in range(i + 1, moves.size()):
			if moves[i][0] == moves[j][0]:
				continue
			var p := sol.copy()
			p.dials[moves[i][0]] = moves[i][1]
			p.dials[moves[j][0]] = moves[j][1]
			found += _try(ep, p, sol_runway, "dials")
	# Random plans.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for _n in RANDOM_PLANS:
		var p := base.copy()
		for c in cards:
			p.kept[c["id"]] = rng.randf() < 0.5
		for d in ep["dials"]:
			p.dials[d["id"]] = d["options"][rng.randi_range(0, d["options"].size() - 1)]
		for h in ep["live"].get("hotfixes", []):
			p.hotfix[h["id"]] = rng.randf() < 0.5
		if p.fits():
			found += _try(ep, p, sol_runway, "random")
	print("  search: %d cheaper passes" % found)


func _try(ep: Dictionary, p: Plan, sol_runway: float, how: String) -> int:
	var r := _play(ep, p)
	if r["passed"] and r["runway"] > sol_runway + MARGIN:
		_fail(ep, "%s plan passes with runway %.3f > %.3f: %s" % [how, r["runway"], sol_runway, p.describe()])
		return 1
	return 0


## Episode 1, the Pilot (data/pilot.json, scenes/pilot.gd), has no pull
## request or simulation: its lesson is in its decision boards and its
## Thursday. Each board must let through exactly the options that fit
## Thursday (the web app or the installable web app; renting the
## backend), the sort's right answers must be the real ones, Thursday must
## clear nine in ten on the web and fall short on native apps, the tech
## stack must hide exactly one NEXT_PUBLIC_ key, and the marks must follow
## the picks.
func _pilot() -> void:
	var d := Season.pilot()
	var ep := {"id": 1}
	if d.is_empty():
		_fail(ep, "no data/pilot.json")
		return
	var budget := float(d["budget"]["time"])
	# Decision 1: where it runs.
	var reqs: Array = d["pick"]["reqs"]
	var ok := []
	for p in d["platforms"]:
		for q in reqs:
			if not p["r"].has(q["id"]):
				_fail(ep, "platform %s says nothing about %s" % [p["id"], q["id"]])
		if PilotModel.passes(p, reqs, budget):
			ok.append(p["id"])
	print("ep 1 platforms that fit Thursday: %s" % ",".join(ok))
	if ok != ["web", "pwa"]:
		_fail(ep, "the platforms that fit should be web and pwa, not %s" % ",".join(ok))
	# Decision 3: build or rent, in the hours each passing platform leaves.
	var breqs: Array = d["backend"]["reqs"]
	for plat in ok:
		var left := budget - float(PilotModel.platform(plat)["h"])
		var fits := []
		for b in d["backend"]["options"]:
			for q in breqs:
				if not b["r"].has(q["id"]):
					_fail(ep, "backend %s says nothing about %s" % [b["id"], q["id"]])
			if PilotModel.passes(b, breqs, left):
				fits.append(b["id"])
		print("  after %s (%sh left), backends that fit: %s" % [plat, left, ",".join(fits)])
		if fits != ["baas"]:
			_fail(ep, "after %s only renting should fit, not %s" % [plat, ",".join(fits)])
	# Decision 2: the sort's right answers.
	var want := {"ui": "front", "state": "front", "key": "back", "fee": "back", "who": "back", "all": "db", "menu": "db"}
	var zones := []
	for z in d["sort"]["zones"]:
		zones.append(z["id"])
	var seen := {}
	for p in d["sort"]["pieces"]:
		seen[p["id"]] = true
		if want.get(p["id"], "") != p["z"]:
			_fail(ep, "piece %s belongs in %s, not %s" % [p["id"], want.get(p["id"], "?"), p["z"]])
		for z in zones:
			if str(p["why"].get(z, "")) == "":
				_fail(ep, "piece %s says nothing about %s" % [p["id"], z])
	if seen.size() != want.size():
		_fail(ep, "the sort has %d pieces, not %d" % [seen.size(), want.size()])
	# Decision 4: one line of the plan sends the key to the browser.
	var bad := 0
	for line in d["plan"]["lines"]:
		if line.get("bad", false):
			bad += 1
			if not str(line["c"]).contains("NEXT_PUBLIC_") or str(line["fixed"]).contains("NEXT_PUBLIC_"):
				_fail(ep, "the bad plan line isn't the NEXT_PUBLIC_ key, or its fix still is")
	if bad != 1:
		_fail(ep, "the plan should hide exactly one bad line, not %d" % bad)
	# Thursday.
	var goal := float(d["goal_share"])
	for build in ["web", "pwa", "native", "cross"]:
		var t := PilotModel.thursday(build)
		print("  Thursday on %s: %d%% found a place (%d fit, %d near, %d wrong night, %d couldn't open it, of %d)" % [
			build, roundi(t["share"] * 100.0), t["fit"], t["near"], t["wrong"], t["none"], t["n"]])
		if int(t["n"]) != 200:
			_fail(ep, "Thursday on %s has %d testers, not 200" % [build, t["n"]])
		var should: bool = ok.has(build)
		if (t["share"] >= goal) != should:
			_fail(ep, "Thursday on %s %s the goal" % [build, "misses" if should else "makes"])
	if PilotModel.thursday("web")["wrong"] == 0:
		_fail(ep, "the 4:40 iPhone bug hits nobody on the web")
	# Everything a passing pick needs for Gerard's record.
	for plat in ok:
		if not d["postmortem"]["platform_rows"].has(plat):
			_fail(ep, "no decision record row for %s" % plat)
		if float(PilotModel.platform(plat)["h"]) + float(d["backend"]["options"][1]["h"]) > budget:
			_fail(ep, "%s and renting don't fit the %s hours" % [plat, budget])
	for r in d["postmortem"]["rows"] + d["postmortem"]["platform_rows"].values():
		if r.size() != d["postmortem"]["heads"].size():
			_fail(ep, "a decision record row has %d cells, not %d" % [r.size(), d["postmortem"]["heads"].size()])
	# The marks.
	var cases := [["web", false, {"live": true, "lean": true, "ulrich": true}],
		["pwa", false, {"live": true, "lean": false, "ulrich": true}],
		["web", true, {"live": true, "lean": true, "ulrich": false}]]
	for c in cases:
		var m := PilotModel.marks(c[0], c[1])
		if JSON.stringify(m) != JSON.stringify(c[2]):
			_fail(ep, "marks for %s (native tried: %s) are %s, not %s" % [c[0], c[1], m, c[2]])
