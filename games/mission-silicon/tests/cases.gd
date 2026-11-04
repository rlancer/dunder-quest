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

	# 5. No cheap way round.
	_search(ep, sol, sol_runway)


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
