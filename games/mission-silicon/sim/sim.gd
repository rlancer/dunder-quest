class_name Sim
extends RefCounted

## The live moment as a flow model (GAME.md, "The simulation"). Each tick is
## one simulated minute: work out how many of each kind of request reach each
## box, what that does to the box (queueing, overload, overheating), and what
## the diners get (page speed, errors, stale tables, leaks, logouts). No
## randomness: the same plan always gives the same night.
##
## Step it with `step()` (the live view does, and stops for hotfixes), or
## call `run()` to play the whole night (the tests do).

const TICK := 60.0
const KINDS := ["browse", "tables", "search", "my_bookings", "book"]
## A tick counts as down when more than this share of requests fail.
const DOWN_SHARE := 0.25

var ep: Dictionary
var plan: Plan
var pieces: Dictionary
var work: Dictionary
var live: Dictionary
## 1.0 for the real night; staging runs at a tenth.
var scale: float = 1.0

var cfg: Dictionary
var tick: int = 0
var ticks: int = 360
var frames: Array = []

var _app := {"backlog": 0.0}
var _db := {"backlog": 0.0}
var _garage := {"backlog": 0.0, "heat": 0, "down": 0}
var _replica := {"backlog": 0.0}
var _warehouse := {"backlog": 0.0}
## The tick of the last good copy into the analytics database.
var _last_load: float = 0.0
## How old the board's numbers may get before the goal fails, in minutes.
var _age_limit: float = INF
var _worker_backlog: float = 0.0
var _rows: float = 0.0
var _hotfixed: Dictionary = {}

# Totals over the night.
var down_ticks: int = 0
var peak_latency: float = 0.0
var peak_book_latency: float = 0.0
var leaks: float = 0.0
var booked: float = 0.0
var book_tries: float = 0.0
var searched: float = 0.0
var search_tries: float = 0.0
var model_bill: float = 0.0
var cdn_bill: float = 0.0
var revenue: float = 0.0
var melts: int = 0
var dash_tries: float = 0.0
var dash_done: float = 0.0
## The oldest the board's numbers got while its screen was working, in minutes.
var max_age: float = 0.0
## Postmortem tag -> damage (lost or spoiled requests, roughly).
var damage: Dictionary = {}


func _init(episode: Dictionary, p: Plan, staging_scale: float = 1.0) -> void:
	ep = episode
	plan = p
	scale = staging_scale
	var catalogue := Season.pieces()
	pieces = catalogue["pieces"]
	work = catalogue["work"]
	live = ep["live"]
	ticks = int(live["ticks"])
	cfg = plan.config()
	_rows = float(live.get("rows", 0))
	_last_load = float(live.get("pipeline", {}).get("nightly_at", 0))
	for g in ep["goal"]:
		if g["metric"] == "dashboard_age":
			_age_limit = float(g["max"])


func done() -> bool:
	return tick >= ticks


## The hotfix due at this tick, if Aleister has one to offer and it applies.
func hotfix_due() -> Dictionary:
	for h in live.get("hotfixes", []):
		if int(h["tick"]) == tick and not _hotfixed.has(h["id"]) and _needs_met(h):
			return h
	return {}


func run() -> Dictionary:
	while not done():
		step()
	return result()


func step() -> Dictionary:
	_apply_hotfixes()
	var f := _tick()
	frames.append(f)
	tick += 1
	return f


func _apply_hotfixes() -> void:
	for h in live.get("hotfixes", []):
		if int(h["tick"]) <= tick and not _hotfixed.has(h["id"]) and _needs_met(h):
			_hotfixed[h["id"]] = true
			if plan.hotfix.get(h["id"], false):
				for change in h.get("changes", []):
					Plan.apply_change(cfg, change)


func _needs_met(h: Dictionary) -> bool:
	for need in h.get("needs", []):
		if not plan.active(need):
			return false
	return true


func diners_at(t: float) -> float:
	var keys: Array = live["diners"]
	if t <= keys[0][0]:
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if t <= b[0]:
			return lerpf(float(a[1]), float(b[1]), (t - a[0]) / maxf(float(b[0] - a[0]), 1.0))
	return float(keys[-1][1])


func _signups_at(t: int, diners: float) -> float:
	var s: Dictionary = live.get("signups", {})
	var rate := diners * float(s.get("per_diner", 0.0)) / 60.0
	for b in s.get("bursts", []):
		if t >= int(b["from"]) and t < int(b["to"]):
			rate += float(b["total"]) * scale / (float(int(b["to"]) - int(b["from"])) * TICK)
	return rate


## Hit rate of a TTL cache with random arrivals: x / (1 + x), x = rate * TTL / keys.
static func hit_rate(rate: float, ttl: float, keys: float) -> float:
	if ttl <= 0.0 or rate <= 0.0:
		return 0.0
	var x := rate * ttl / maxf(keys, 1.0)
	return x / (1.0 + x)


## Share of hits that are out of date, when each key changes at `mu` per
## second and hits are spread evenly over the TTL: 1 - (1 - e^-muT) / muT.
static func stale_share(mu: float, ttl: float) -> float:
	var m := mu * ttl
	if m <= 0.000001:
		return 0.0
	return 1.0 - (1.0 - exp(-m)) / m


## One box for one tick: queueing below capacity, a backlog above it, and
## timeouts once the backlog passes the limit.
func _box(state: Dictionary, load: float, capacity: float, base: float) -> Dictionary:
	var incoming := load * TICK
	state["backlog"] = maxf(0.0, float(state["backlog"]) + incoming - capacity * TICK)
	var limit := capacity * float(Season.pieces()["backlog_limit"])
	var drop := 0.0
	if state["backlog"] > limit:
		drop = minf(1.0, (state["backlog"] - limit) / maxf(incoming, 0.000001))
		state["backlog"] = limit
	var u := load / maxf(capacity, 0.000001)
	var latency := base / maxf(1.0 - u, 0.05) + float(state["backlog"]) / capacity
	return {"u": u, "latency": latency, "drop": drop}


func _row(name: String) -> Dictionary:
	var rows: Dictionary = cfg.get("rows", {})
	var r: Dictionary = rows.get(name, {})
	return {"ttl": float(r.get("ttl", 0)), "scope": str(r.get("scope", "shared"))}


func _tick() -> Dictionary:
	var diners := diners_at(tick) * scale
	var r := {}
	for k in KINDS:
		r[k] = diners * float(live["rates"].get(k, 0.0)) / 60.0
	var signups := _signups_at(tick, diners)
	var cloud: bool = cfg["host"] == "cloud"
	var cache_on: bool = cfg.get("cache", false)
	var app_cfg: Dictionary = cfg["app"]
	var count := int(app_cfg["count"]) if cloud else 1
	var sessions := str(app_cfg.get("sessions", "memory"))
	if not cache_on:
		sessions = "memory"

	# Caches.
	var hits := {"menus": 0.0, "tables": 0.0, "my_bookings": 0.0}
	var stale_tables := 0.0
	var leak_rate := 0.0
	if cache_on:
		var users := float(ep.get("users", 1))
		for name in hits:
			var spec: Dictionary = ep["cache_rows"][name]
			var row := _row(name)
			var per_user_data: bool = spec.get("per_user", false)
			var keys := float(spec.get("keys", 1))
			if per_user_data:
				keys = users if row["scope"] == "per_user" else 1.0
			elif row["scope"] == "per_user":
				keys *= users
			hits[name] = hit_rate(r[spec["kind"]], row["ttl"], keys)
			if per_user_data and row["scope"] == "shared":
				leak_rate = r[spec["kind"]] * hits[name]
		var tables_mu := float(ep["cache_rows"]["tables"].get("changes_per_hour", 0.0)) / 3600.0
		stale_tables = stale_share(tables_mu, _row("tables")["ttl"])

	var model: Dictionary = pieces["model_api"]
	var ai_hit := 0.0
	if cfg.get("ai_cache", false):
		ai_hit = hit_rate(r["search"], float(model["answer_ttl"]), float(model["answer_keys"]))

	# Work on the app.
	var w := work
	var assets := 0.0 if cfg.get("cdn", false) else float(w["browse"]["assets"])
	var queue: bool = cfg.get("queue", false)
	var book_app := float(w["book"]["app_rust"] if cfg.get("rust", false) else w["book"]["app"])
	var parts := {
		"browse": r["browse"] * float(w["browse"]["app"]),
		"assets": r["browse"] * assets,
		"tables": r["tables"] * float(w["tables"]["app"]),
		"search": r["search"] * float(w["search"]["app"]),
		"my_bookings": r["my_bookings"] * float(w["my_bookings"]["app"]),
		"book": r["book"] * book_app,
		"signup": signups * float(w["signup"]["enqueue"] if queue else w["signup"]["app"]),
	}
	var app_load := 0.0
	for k in parts:
		app_load += parts[k]

	# The worker drains queued sign-ups at its own pace.
	var signup_db_rate := signups
	if queue:
		_worker_backlog += signups * TICK
		var per_tick := float(pieces["queue"]["worker_capacity"]) / float(w["signup"]["app"]) * TICK
		var done_now := minf(_worker_backlog, per_tick)
		_worker_backlog -= done_now
		signup_db_rate = done_now / TICK

	# The board's dashboard: every screen asks every tile's question at each
	# refresh. On a row store each question scans everything; a column store
	# does a small share of that work.
	var dash_on: bool = cfg.get("dashboard", false)
	var dash_spec: Dictionary = live.get("dashboard", {})
	var dash_q := 0.0
	var dash_where := "primary"
	if dash_on:
		dash_q = float(cfg.get("tiles", dash_spec.get("tiles", 0))) * float(dash_spec.get("screens", 1)) / float(dash_spec.get("refresh", 60))
		if cfg.get("warehouse", false):
			dash_where = "warehouse"
		elif cfg.get("replica", false):
			dash_where = "replica"
	var scan := float(live.get("analytics_rows", 0)) * float(w.get("dashboard", {}).get("db_per_row", 0.0))

	# Work on the database.
	var tables_db := float(w["tables"]["db_indexed"]) if cfg.get("index", false) else _rows * float(w["tables"]["db_per_row"])
	var db_parts := {
		"menus": r["browse"] * float(w["browse"]["db"]) * (1.0 - hits["menus"]),
		"tables": r["tables"] * tables_db * (1.0 - hits["tables"]),
		"search": r["search"] * float(w["search"]["db"]),
		"my_bookings": r["my_bookings"] * float(w["my_bookings"]["db"]) * (1.0 - hits["my_bookings"]),
		"book": r["book"] * float(w["book"]["db"]),
		"signup": signup_db_rate * float(w["signup"]["db"]),
		"dashboard": dash_q * scan if dash_where == "primary" else 0.0,
	}
	var db_load := 0.0
	for k in db_parts:
		db_load += db_parts[k]

	# The boxes.
	var app_ok := 1.0
	var db_ok := 1.0
	var latency := 0.0
	var conn_err := 0.0
	var util := {}
	var down_now := false
	var dash_ok := 0.0
	var book_latency := 0.0
	if not cloud:
		var g: Dictionary = pieces["garage_server"]
		var heat: Dictionary = g["overheat"]
		var res: Dictionary
		if _garage["down"] > 0:
			_garage["down"] -= 1
			_garage["backlog"] = 0.0
			res = {"u": 0.0, "latency": 0.0, "drop": 1.0}
			down_now = true
		else:
			res = _box(_garage, app_load + db_load, float(g["capacity"]), float(g["latency"]))
			if res["u"] > float(heat["above"]):
				_garage["heat"] += 1
			else:
				_garage["heat"] = maxi(0, _garage["heat"] - 2)
			if _garage["heat"] >= int(heat["ticks"]):
				_garage["heat"] = 0
				_garage["down"] = int(heat["down"])
				melts += 1
		app_ok = 1.0 - res["drop"]
		latency = res["latency"]
		book_latency = latency
		dash_ok = app_ok
		util["garage"] = res["u"]
	else:
		var app_piece: Dictionary = pieces["app_server"]
		var size: Dictionary = app_piece["sizes"][str(app_cfg["size"])]
		var app_res := _box(_app, app_load, float(size["capacity"]) * count, float(app_piece["latency"]))
		var pg: Dictionary = pieces["postgres"]
		var db_cap := float(pg["capacity"]) * (float(pieces["shards"]["capacity_x"]) if cfg.get("shards", false) else 1.0) * float(cfg.get("db_x", 1))
		var db_res := _box(_db, db_load, db_cap, float(pg["latency"]))
		var conns := count * int(app_piece["pool"])
		conn_err = maxf(0.0, float(conns - int(pg["max_connections"]))) / float(conns)
		app_ok = 1.0 - app_res["drop"]
		db_ok = (1.0 - db_res["drop"]) * (1.0 - conn_err)
		latency = app_res["latency"] + db_res["latency"] * (1.0 - hits["menus"])
		# A booking always writes to the database, so it waits its full latency.
		book_latency = app_res["latency"] + db_res["latency"]
		util["app"] = app_res["u"]
		util["db"] = db_res["u"]
		match dash_where:
			"primary":
				dash_ok = db_ok
			"replica":
				var rep_res := _box(_replica, dash_q * scan, float(pg["capacity"]), float(pg["latency"]))
				dash_ok = 1.0 - rep_res["drop"]
				util["replica"] = rep_res["u"]
			"warehouse":
				var wh: Dictionary = pieces["warehouse"]
				var wh_res := _box(_warehouse, dash_q * scan * float(wh["columnar_share"]), float(wh["capacity"]), float(wh["latency"]))
				dash_ok = 1.0 - wh_res["drop"]
				util["warehouse"] = wh_res["u"]
	var net: Dictionary = Season.pieces()["network"]
	var page := float(net["base"]) + (0.0 if cfg.get("cdn", false) else float(net["no_cdn"])) + latency
	var book_page := float(net["base"]) + book_latency

	# How old the board's numbers are. From the analytics database, as old as
	# its last good copy (hourly, nightly or streamed), and a copy job that
	# breaks stays broken until someone fixes it. Straight from a database,
	# as old as the last refresh.
	var age := 0.0
	var pipeline_broken := false
	if dash_on:
		if dash_where == "warehouse":
			var pipe: Dictionary = live.get("pipeline", {})
			var fails_at := int(pipe.get("fails_at", -1))
			pipeline_broken = fails_at >= 0 and tick >= fails_at and not cfg.get("pipeline_fixed", false)
			var mode := str(cfg.get("pipeline", "hourly"))
			var due := mode == "stream" or (mode == "hourly" and tick % 60 == 0)
			if due and not pipeline_broken:
				_last_load = tick
			age = float(tick) - _last_load
		else:
			age = float(dash_spec.get("refresh", 60)) / 60.0

	# The model provider.
	var calls: float = r["search"] * (1.0 - ai_hit)
	var limit := float(model["limit"]) * scale
	var rate_err: float = maxf(0.0, calls - limit) / calls if calls > 0.0 else 0.0
	var price := float(model["price"])
	if cfg.get("ai_cache", false):
		price *= (1.0 - float(model["fixed_share"])) + float(model["fixed_share"]) * float(model["cached_rate"])
	if cfg.get("model", "standard") == "big":
		price *= 5.0
	util["model"] = calls / limit

	# What the diners get.
	var ok := {
		"browse": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["menus"])),
		"tables": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["tables"])),
		"search": app_ok * db_ok * (1.0 - rate_err),
		"my_bookings": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["my_bookings"])),
		"book": app_ok * db_ok,
	}
	var signup_ok := app_ok if queue else app_ok * db_ok
	var logout := (1.0 - 1.0 / count) if (cloud and count > 1 and sessions == "memory") else 0.0
	var stale_fail: float = hits["tables"] * stale_tables * 0.5
	var logout_fail := logout * 0.6
	var abandon := clampf((maxf(page, book_page) - 2.0) / 4.0, 0.0, 1.0) * 0.6
	var book_success: float = ok["book"] * (1.0 - stale_fail) * (1.0 - logout_fail) * (1.0 - abandon)

	var total := signups
	var failed := signups * (1.0 - signup_ok)
	for k in KINDS:
		total += r[k]
		failed += r[k] * (1.0 - ok[k])
	var err_share := failed / total if total > 0.0 else 0.0
	if err_share > DOWN_SHARE:
		down_now = true
	if down_now:
		down_ticks += 1
	elif ok["browse"] > 0.5:
		peak_latency = maxf(peak_latency, page)
		peak_book_latency = maxf(peak_book_latency, book_page)
	if dash_on:
		dash_tries += dash_q * TICK
		dash_done += dash_q * TICK * dash_ok
		if dash_ok > 0.5:
			max_age = maxf(max_age, age)

	var booked_now: float = r["book"] * TICK * book_success
	booked += booked_now
	book_tries += r["book"] * TICK
	_rows += booked_now
	searched += r["search"] * TICK * ok["search"]
	search_tries += r["search"] * TICK
	leaks += leak_rate * TICK
	model_bill += calls * (1.0 - rate_err) * TICK * price
	if cfg.get("cdn", false):
		cdn_bill += r["browse"] * TICK * float(pieces["cdn"]["per_request"])
	revenue += booked_now * float(live.get("fee", 0.0))

	# Blame, for the postmortem and the bubbles.
	var tags := []
	var lost := failed * TICK + (total * TICK * 0.2 if page > 3.0 else 0.0)
	if not cloud and (_garage["down"] > 0 or down_now):
		tags.append("garage_melt")
	elif lost > 0.0:
		if cloud and util.get("app", 0.0) > 0.9:
			tags.append(_biggest(parts, {"assets": "no_cdn", "signup": "no_queue"}, "app_overload"))
		if cloud and util.get("db", 0.0) > 0.9:
			tags.append(_biggest(db_parts, {"tables": "full_scan", "menus": "no_cache", "dashboard": "olap_on_oltp"}, "db_overload"))
		if not cloud:
			var both := parts.duplicate()
			for k in db_parts:
				both["db_" + k] = db_parts[k]
			tags.append(_biggest(both, {"assets": "no_cdn", "signup": "no_queue", "db_tables": "full_scan", "db_menus": "no_cache"}, "db_overload"))
	for tag in tags:
		_blame(tag, lost)
	if conn_err > 0.0:
		tags.append("too_many_connections")
		_blame("too_many_connections", total * TICK * conn_err)
	if logout > 0.0:
		tags.append("stateless")
		_blame("stateless", (r["book"] + r["my_bookings"]) * TICK * logout)
	if stale_fail > 0.02:
		tags.append("stale_tables")
		_blame("stale_tables", r["book"] * TICK * stale_fail * 50.0)
	if leak_rate > 0.0:
		tags.append("cache_leak")
		_blame("cache_leak", leak_rate * TICK * 100.0)
	if rate_err > 0.01:
		tags.append("rate_limited")
		_blame("rate_limited", r["search"] * TICK * rate_err)
	if dash_on and dash_ok < 0.99 and dash_where != "primary":
		var why := "replica_slow" if dash_where == "replica" else "too_many_tiles"
		tags.append(why)
		_blame(why, dash_q * TICK * (1.0 - dash_ok) * 100.0)
	if dash_on and age > _age_limit:
		var why := "silent_failure" if pipeline_broken else "stale_numbers"
		tags.append(why)
		_blame(why, 1000.0)

	return {
		"tick": tick, "diners": diners, "page": minf(page, 30.0), "err": err_share, "down": down_now,
		"util": util, "tags": tags, "hits": hits, "money": _money_so_far(), "count": count,
		"backlog": _worker_backlog, "cloud": cloud, "dash": dash_on, "age": age,
	}


func _biggest(parts: Dictionary, names: Dictionary, fallback: String) -> String:
	var best := ""
	var best_v := -1.0
	for k in parts:
		if parts[k] > best_v:
			best_v = parts[k]
			best = k
	return names.get(best, fallback)


func _blame(tag: String, amount: float) -> void:
	damage[tag] = float(damage.get(tag, 0.0)) + amount


func _money_so_far() -> float:
	return float(ep["budget"]["bank"]) - model_bill - cdn_bill + revenue


## What the kept boxes add to the monthly bill.
func monthly_extra() -> float:
	return monthly_of(cfg)


static func monthly_of(cfg: Dictionary) -> float:
	var pieces: Dictionary = Season.pieces()["pieces"]
	var m := 0.0
	if cfg["host"] == "cloud":
		var size: Dictionary = pieces["app_server"]["sizes"][str(cfg["app"]["size"])]
		var pg_monthly := float(pieces["postgres"]["monthly"])
		m += float(size["monthly"]) * int(cfg["app"]["count"]) + pg_monthly * float(cfg.get("db_x", 1))
		if cfg.get("replica", false):
			m += pg_monthly
	if cfg.get("cache", false):
		m += float(pieces["redis"]["monthly"])
	if cfg.get("cdn", false):
		m += float(pieces["cdn"]["monthly"])
	if cfg.get("queue", false):
		m += float(pieces["queue"]["monthly"])
	if cfg.get("cluster", false):
		m += float(pieces["cluster"]["monthly"])
	if cfg.get("shards", false):
		m += float(pieces["shards"]["monthly"])
	if cfg.get("warehouse", false):
		m += float(pieces["warehouse"]["monthly"])
		if cfg.get("pipeline", "") == "stream":
			m += float(pieces["stream"]["monthly"])
	if cfg.get("alerts", false):
		m += float(pieces["alerts"]["monthly"])
	return m


func result() -> Dictionary:
	var budget: Dictionary = ep["budget"]
	var incidents := 0.0
	if leaks > 0.0:
		incidents += float(ep.get("incidents", {}).get("cache_leak", 0.0))
	var bank := float(budget["bank"]) - model_bill - cdn_bill - incidents + revenue
	var burn := float(budget["burn"]) + monthly_extra()
	var runway := bank / burn
	var metrics := {
		"down_ticks": down_ticks,
		"peak_latency": peak_latency,
		"peak_book_latency": peak_book_latency,
		"dashboard_success": dash_done / dash_tries if dash_tries > 0.0 else 0.0,
		"dashboard_age": max_age,
		"leaks": leaks,
		"booking_success": booked / book_tries if book_tries > 0.0 else 1.0,
		"search_success": searched / search_tries if search_tries > 0.0 else 1.0,
	}
	var goals := []
	var passed := true
	for g in ep["goal"]:
		var v: float = metrics[g["metric"]]
		var good := true
		if g.has("max"):
			good = v <= float(g["max"]) + 0.000001
		if g.has("min"):
			good = v >= float(g["min"]) - 0.000001
		passed = passed and good
		goals.append({"label": g["label"], "metric": g["metric"], "value": v, "ok": good})
	var blame := damage.duplicate()
	if model_bill > 10000.0:
		blame["ai_bill"] = model_bill / 10.0
	if cfg.get("model", "standard") == "big":
		blame["big_model"] = model_bill / 20.0
	if not cfg.get("dashboard", false):
		for g in ep["goal"]:
			if g["metric"] == "dashboard_success":
				blame["no_dashboard"] = 1.0e9
	if passed and runway < float(budget["par"]):
		blame["overbuilt"] = 1.0
	var order := blame.keys()
	order.sort_custom(func(a, b): return blame[a] > blame[b])
	return {
		"passed": passed, "goals": goals, "metrics": metrics, "runway": runway, "par": float(budget["par"]),
		"lean": runway >= float(budget["par"]) - 0.000001, "bank": bank, "burn": burn,
		"model_bill": model_bill, "cdn_bill": cdn_bill, "incidents": incidents, "revenue": revenue,
		"booked": booked, "melts": melts, "tags": order, "monthly_extra": monthly_extra(),
	}


## Plays a plan through the night, hotfixes and all; a plan that doesn't fit
## the time can't be merged, and comes back as that.
static func play(episode: Dictionary, p: Plan, staging_scale: float = 1.0) -> Dictionary:
	if not p.fits():
		return {"passed": false, "merge": false, "runway": 0.0, "tags": ["too_long"], "goals": []}
	var s := Sim.new(episode, p, staging_scale)
	var res := s.run()
	res["merge"] = true
	return res
