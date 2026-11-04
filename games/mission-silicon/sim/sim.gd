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
## Deposits (Episode 11): the provider's fees, deposits tried and taken,
## diners charged wrongly (twice, or for a booking that failed), and tables
## booked twice.
var pay_bill: float = 0.0
var dep_tries: float = 0.0
var dep_done: float = 0.0
var bad_charges: float = 0.0
var double_bookings: float = 0.0
## Secrets (Episode 12): calls strangers made on our model key, what they
## cost us, and bookings read by someone they don't belong to.
var stolen_calls: float = 0.0
var stolen_bill: float = 0.0
var peeked: float = 0.0
## AI inside the app (Episode 13): answers given, answers made up, answers
## that repeated a planted review's instructions, agent jobs tried and
## done, jobs a planted review steered, and things the agent did that
## nobody asked for (deposits paid, other diners' bookings cancelled).
var answered: float = 0.0
var made_up: float = 0.0
var hijacked: float = 0.0
var agent_tries: float = 0.0
var agent_done: float = 0.0
var fooled: float = 0.0
var unasked: float = 0.0
var cancelled: float = 0.0
## Whether what was built is what was asked for (Episode 1): searches
## tried, and searches answered with a place that fits every part of the
## request.
var fit_tries: float = 0.0
var fit_done: float = 0.0
## The landing page (Episode 2): sign-ups tried and kept, the backend's
## server and database if there are any, and the tick a rollback started.
var signup_tries: float = 0.0
var signed: float = 0.0
var _web := {"backlog": 0.0}
var _signups_db := {"backlog": 0.0}
var _rolled_at: int = -1
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


## A hotfix needs cards kept, or (the finale, where the season's boxes are
## already on the board) boxes the board has: a need that isn't a card is
## read from the board.
func _needs_met(h: Dictionary) -> bool:
	for need in h.get("needs", []):
		if plan.card(need).is_empty():
			if not cfg.get(need, false):
				return false
		elif not plan.active(need):
			return false
	return true


func diners_at(t: float) -> float:
	return keyed(live["diners"], t)


## A value over the night from keyframes [[tick, value], ...], straight lines between.
static func keyed(keys: Array, t: float) -> float:
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
	# A landing page and its waitlist (Episode 2) is its own small night.
	if live.has("landing"):
		return _tick_landing()
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
	# Episode 1: nothing may have been built yet, or Forkcast may have been
	# sold to Hubbub, which keeps it in a drawer. Either way nothing answers.
	var built: bool = str(cfg["host"]) != "none" and not cfg.get("sold", false)

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
	# Phones calling the model themselves (the finale's decoy) skip our app
	# for searches, and need the key in the app to do it.
	var direct: bool = cfg.get("direct_ai", false)
	var parts := {
		"browse": r["browse"] * float(w["browse"]["app"]),
		"assets": r["browse"] * assets,
		"tables": r["tables"] * float(w["tables"]["app"]),
		"search": 0.0 if direct else r["search"] * float(w["search"]["app"]),
		"my_bookings": r["my_bookings"] * float(w["my_bookings"]["app"]),
		"book": r["book"] * book_app,
		"signup": signups * float(w["signup"]["enqueue"] if queue else w["signup"]["app"]),
	}
	# Hubbub's scraper (Episode 10): `clients` machines, each asking for
	# tonight's tables `per_client` times a minute, with combinations no diner
	# asks for, so the cache never has them. A rate limit lets each client
	# through at most `rate_limit` a minute and turns the rest away at the door
	# with a 429, for almost no work. A limit under what a busy diner does
	# turns away some of the diners too. Off unless the episode has a scraper.
	var sc: Dictionary = live.get("scraper", {})
	var limiter: bool = cfg.get("limiter", false)
	var limit_pm := float(cfg.get("rate_limit", 0))
	var scrape_in := 0.0
	var scrape_through := 0.0
	var diner_blocked := 0.0
	if not sc.is_empty():
		var per_client := keyed(sc["per_client"], tick)
		var through_pm := minf(per_client, limit_pm) if limiter else per_client
		var bots: Dictionary = live.get("captcha", {})
		if cfg.get("captcha", false):
			through_pm *= float(bots.get("bots_through", 1.0))
		scrape_in = float(sc["clients"]) * per_client / 60.0 * scale
		scrape_through = float(sc["clients"]) * through_pm / 60.0 * scale
		var peak := float(sc.get("diner_peak", 0.0))
		if limiter and limit_pm < peak:
			diner_blocked = float(sc.get("busy_share", 0.0)) * (1.0 - limit_pm / peak)
	parts["scrape"] = scrape_through * float(w.get("scrape", {}).get("app", 0.0)) + (scrape_in - scrape_through) * float(w.get("scrape", {}).get("turned_away", 0.0))

	# Microservices (Episode 10): with the app split into services, each kind
	# of request crosses `hops` network calls between them. Every call adds a
	# little latency and a little work, and fails now and then; a request
	# needs every call on its path to work, so the chances multiply. Off
	# unless the episode describes the services.
	var svc: Dictionary = live.get("services", {})
	var chain_ok := {}
	var chain_lat := {}
	var chain_work := 0.0
	for k in KINDS:
		chain_ok[k] = 1.0
		chain_lat[k] = 0.0
	if cfg.get("cluster", false) and not svc.is_empty():
		for k in KINDS:
			var hops := float(svc["hops"].get(k, 0))
			chain_ok[k] = pow(1.0 - float(svc["hop_fail"]), hops)
			chain_lat[k] = hops * float(svc["hop_latency"])
			chain_work += r[k] * hops * float(svc["hop_work"])
	parts["services"] = chain_work

	# Bookings by number (Episode 12): from a scripted tick, a bot asks for
	# booking after booking by counting through the numbers in the links.
	# Without an ownership check, every number that exists shows someone
	# else's booking; with one, the app answers "not found". A small load
	# either way. Off unless the episode has `live.idor`.
	var idor: Dictionary = live.get("idor", {})
	var peek := 0.0
	var peek_rate := 0.0
	if not idor.is_empty() and tick >= int(idor["from"]):
		peek = float(idor["per_minute"]) / 60.0
		if not cfg.get("owner_check", false):
			peek_rate = peek * float(idor["exists"])
	parts["peek"] = peek * float(w["my_bookings"]["app"])

	# The concierge as an agent (Episode 13): a share of searches become
	# jobs ("find us somewhere and book it"), which the agent carries out by
	# looping: ask the model, use one of our app's tools, look at the result,
	# ask again. Each job is several model calls (more with a team of agents
	# talking to each other) and a little work for the app and the database.
	# Retrieval (RAG) looks up the relevant menus for every answer first: a
	# small search of an index in our database, and longer prompts. Off
	# unless the episode has `live.agent` and `live.grounding`.
	var ag: Dictionary = live.get("agent", {})
	var gr: Dictionary = live.get("grounding", {})
	var agent_on: bool = cfg.get("agent", false) and not ag.is_empty()
	var rag: bool = cfg.get("rag", false) and not gr.is_empty()
	var runs := 0.0
	if agent_on:
		runs = r["search"] * float(ag["share"])
	parts["agent"] = runs * float(ag.get("app", 0.0))

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
		"scrape": scrape_through * float(w.get("scrape", {}).get("db", 0.0)),
		"peek": peek * float(w["my_bookings"]["db"]),
		"agent": runs * float(ag.get("db", 0.0)),
		"retrieval": r["search"] * float(gr.get("db", 0.0)) if rag else 0.0,
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
	if not built:
		app_ok = 0.0
		dash_ok = 0.0
		down_now = true
		util["garage"] = 0.0
	elif not cloud:
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
	var page := float(net["base"]) + (0.0 if cfg.get("cdn", false) else float(net["no_cdn"])) + latency + float(chain_lat["browse"])
	var book_page := float(net["base"]) + book_latency + float(chain_lat["book"])

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
	# Whether what was built is what was asked for (Episode 1). A photo feed
	# has nowhere to type a request, so it asks the model nothing; a
	# concierge answers, but only as well as it was told what a request is:
	# from a vague one-liner it fills the gaps with what's common (a popular
	# place for two), and a share of answers fit every part of the request
	# (party size, night, area, needs). Off unless the episode has `live.fit`.
	var fit: Dictionary = live.get("fit", {})
	var fit_share := 0.0
	if not fit.is_empty():
		if cfg.get("concierge", false):
			fit_share = float(fit[str(cfg.get("detail", "none"))] if cfg.get("spec", false) else fit["none"])
		else:
			calls = 0.0
		if not built:
			calls = 0.0
	# Switched off by a hotfix (Episode 12): no searches, no calls of ours.
	var ai_off: bool = cfg.get("ai_off", false)
	if ai_off:
		calls = 0.0
	# A leaked key (Episode 12). Strangers who have our key call the model
	# provider directly, never through our app, and we pay for every call.
	# Each place the key is exposed brings its own strangers, from the tick
	# a scanner finds it: the old key in the Git history (already found)
	# until it's rotated, whichever key is in the app's code once a bot reads
	# the app, and whichever key the server has once a malicious package has
	# sent it away. Deleting the file or making the repository private
	# doesn't stop the old key working; only rotating it does. Their calls
	# share our rate limit. Off unless the episode has `live.leak`.
	var leak: Dictionary = live.get("leak", {})
	var stolen_parts := {}
	if not leak.is_empty():
		var ex: Dictionary = leak["exposures"]
		if not cfg.get("rotated", false):
			stolen_parts["leaked_key"] = keyed(ex["history"], tick) / 60.0
		if str(cfg.get("key_where", "server")) == "frontend":
			stolen_parts["key_in_app"] = keyed(ex["bundle"], tick) / 60.0
		if cfg.get("keysafe", false):
			stolen_parts["fake_package"] = keyed(ex["package"], tick) / 60.0
	var stolen := 0.0
	for k in stolen_parts:
		stolen += stolen_parts[k]
	# The agent's calls can't come from the answer cache: each one depends on
	# what the tools just said. A second AI checking every answer (Episode
	# 13's decoy) makes every call twice.
	if agent_on:
		calls += runs * float(ag["calls"]) * (float(ag["swarm_x"]) if cfg.get("swarm", false) else 1.0)
	if cfg.get("checker", false):
		calls *= 2.0
	# A higher limit from the provider (the finale) multiplies the cap.
	var limit := float(model["limit"]) * float(cfg.get("limit_x", 1)) * scale
	var asked := calls + stolen
	var rate_err: float = maxf(0.0, asked - limit) / asked if asked > 0.0 else 0.0
	var price := float(model["price"])
	if cfg.get("ai_cache", false):
		price *= (1.0 - float(model["fixed_share"])) + float(model["fixed_share"]) * float(model["cached_rate"])
	# Retrieved menus go in with every question: more tokens, and different
	# for every question, so prompt caching doesn't cover them.
	if rag:
		price += float(model["price"]) * float(gr["extra"])
	if cfg.get("model", "standard") == "big":
		price *= 5.0
	util["model"] = asked / limit

	# What the diners get.
	var ok := {
		"browse": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["menus"])),
		"tables": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["tables"])),
		"search": app_ok * db_ok * (1.0 - rate_err),
		"my_bookings": app_ok * (1.0 - (1.0 - db_ok) * (1.0 - hits["my_bookings"])),
		"book": app_ok * db_ok,
	}
	# Turned away by too tight a rate limit, failed somewhere along a chain of
	# services, or given up at a CAPTCHA.
	var gave_up := float(live.get("captcha", {}).get("give_up", 0.0)) if cfg.get("captcha", false) else 0.0
	for k in KINDS:
		ok[k] *= (1.0 - diner_blocked) * chain_ok[k]
	ok["search"] *= 1.0 - gave_up
	if ai_off:
		ok["search"] = 0.0
	ok["book"] *= 1.0 - gave_up
	var signup_ok := app_ok if queue else app_ok * db_ok
	var logout := (1.0 - 1.0 / count) if (cloud and count > 1 and sessions == "memory") else 0.0
	var stale_fail: float = hits["tables"] * stale_tables * 0.5
	var logout_fail := logout * 0.6
	var abandon := clampf((maxf(page, book_page) - 2.0) / 4.0, 0.0, 1.0) * 0.6
	var book_success: float = ok["book"] * (1.0 - stale_fail) * (1.0 - logout_fail) * (1.0 - abandon)

	# Grounding (Episode 13). Without the real menus in front of it, a share
	# of the model's answers about dishes and allergies are made up, and
	# sound as sure as the rest. Retrieval cuts that share a long way, not to
	# nothing; a bigger model or a second AI checking cuts it a little,
	# because neither has seen tonight's menus. Off unless `live.grounding`.
	var answers: float = r["search"] * ok["search"]
	var made_up_share := 0.0
	if not gr.is_empty():
		made_up_share = float(gr["rag"] if rag else gr["none"])
		if cfg.get("model", "standard") == "big":
			made_up_share *= float(gr["big_x"])
		if cfg.get("checker", false):
			made_up_share *= float(gr["checker_x"])
	# A planted review (Episode 13). From a scripted tick, a review written
	# for AIs ("ignore your instructions...") sits on one restaurant's page,
	# and a share of answers read it, more right after the stage demo. Of
	# those, a share follow it: the model can't reliably tell text it reads
	# from instructions it's given. Marking everything it reads as data cuts
	# that share sharply; nothing makes it zero. A steered answer repeats
	# the review's message to the diner. A steered agent job also tries to
	# pay a deposit somewhere the diner never chose, which a confirmation
	# step puts in front of the diner (and nearly all say no), and, if the
	# agent has every tool our app has, cancels other diners' bookings at
	# that restaurant, which no confirmation from this diner covers: only
	# not having the tool does. Off unless the episode has `live.injection`.
	var inj: Dictionary = live.get("injection", {})
	var follow_share := 0.0
	var fooled_runs := 0.0
	var spend_rate := 0.0
	var cancel_rate := 0.0
	var confirm := str(cfg.get("confirm", "none"))
	if not inj.is_empty():
		follow_share = keyed(inj["reads"], tick) * float(inj["follow_marked"] if cfg.get("data_marked", false) else inj["follow"])
		if agent_on:
			fooled_runs = runs * ok["search"] * follow_share
			spend_rate = fooled_runs * float(inj["spend"]) * (float(inj["approve"]) if confirm != "none" else 1.0)
			# Only that restaurant's bookings tonight can be cancelled.
			if str(cfg.get("tools", "all")) == "all":
				cancel_rate = minf(fooled_runs * float(inj["cancels"]), maxf(0.0, float(inj["cancel_cap"]) - cancelled) / TICK)
	# Asking the diner before a step costs a share of jobs: some give up at
	# the question. Asking before paying loses a few; asking before every
	# search and look at a table loses a lot.
	var confirm_give_up := 0.0
	if agent_on:
		confirm_give_up = float(ag["give_up"].get(confirm, 0.0))
		agent_tries += runs * TICK
		agent_done += runs * TICK * ok["search"] * (1.0 - confirm_give_up) * (1.0 - follow_share)
	answered += answers * TICK
	made_up += answers * made_up_share * TICK
	hijacked += answers * follow_share * TICK
	fooled += fooled_runs * TICK
	unasked += (spend_rate + cancel_rate) * TICK
	cancelled += cancel_rate * TICK
	bad_charges += spend_rate * TICK

	# Deposits (Episode 11): a share of bookings take a deposit through the
	# payment provider, one call over the network. A scripted share of those
	# calls time out, and some of the ones that time out actually went
	# through: only the reply was lost. Without retries a timeout is reported
	# as a failure, so some diners are charged for a table they didn't get.
	# Retrying repeats the call, so the ones that went through are charged
	# twice, unless every call carries an idempotency key, which lets the
	# provider recognise the repeat and answer it with the first result. A
	# backup provider can't recognise another provider's key. Off unless the
	# episode takes payments.
	var pay: Dictionary = live.get("payments", {})
	var deposits_on: bool = cfg.get("deposits", false) and not pay.is_empty()
	var pay_rate := 0.0
	var pay_fail := 0.0
	var bad_rate := 0.0
	var bad_tag := ""
	if deposits_on:
		pay_rate = r["book"] * float(pay["share"])
		var t := keyed(pay["timeouts"], tick)
		var went_through := t * float(pay["succeeded"])
		var backup: bool = cfg.get("backup", false)
		if backup or str(cfg.get("retries", "on")) == "on":
			pay_fail = t * t
			if backup:
				bad_tag = "backup_provider"
			elif not cfg.get("idem", false):
				bad_tag = "double_charge"
		else:
			pay_fail = t
			bad_tag = "timeout_unknown"
		if bad_tag != "":
			bad_rate = pay_rate * ok["book"] * went_through
		book_success *= 1.0 - float(pay["share"]) * pay_fail
		book_page += float(pay["latency"])
		pay_bill += pay_rate * ok["book"] * TICK * float(pay["fee"])
		dep_tries += pay_rate * TICK
		dep_done += pay_rate * TICK * ok["book"] * (1.0 - pay_fail)
	elif not pay.is_empty():
		dep_tries += r["book"] * float(pay["share"]) * TICK

	# The last table (Episode 11). Checking a table is free and then booking
	# it are two steps; two parties who check the same last table inside the
	# gap both get it. Per hot table, bookings arrive at rate h / H, and a
	# second within the gap w of the first doubles it, so double bookings run
	# at h * (h / H) * w: they grow with the square of the traffic on hot
	# tables. Waiting for the deposit between the two steps widens the gap.
	# A transaction that holds the table before the deposit closes it. On
	# ForkNet every phone keeps its own copy of the tables, and a booking
	# takes log2(phones) rounds of gossip to reach them all, so the gap is
	# that long whatever the database does, and a phone that drops off
	# before passing a booking on loses it. Off unless the episode has a race.
	var race: Dictionary = live.get("race", {})
	var dbl_rate := 0.0
	var forknet: bool = cfg.get("forknet", false) and not race.is_empty()
	var forknet_lost := 0.0
	if not race.is_empty():
		var hot: float = r["book"] * book_success * float(race["hot_share"])
		var gap := 0.0
		if forknet:
			gap = float(race["gossip_hop"]) * log(maxf(diners, 2.0)) / log(2.0)
			forknet_lost = float(race["offline"])
			book_success *= 1.0 - forknet_lost
		elif not cfg.get("txn", false):
			gap = float(race["window"]) + (float(pay["latency"]) if deposits_on else 0.0)
		dbl_rate = hot * hot * gap / float(race["hot_tables"])

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
	if not fit.is_empty():
		fit_tries += r["search"] * TICK
		fit_done += r["search"] * TICK * ok["search"] * fit_share
	leaks += (leak_rate + peek_rate) * TICK
	peeked += peek_rate * TICK
	if stolen > 0.0:
		var stolen_now := stolen * (1.0 - rate_err) * TICK
		stolen_calls += stolen_now
		stolen_bill += stolen_now * float(leak["price"])
		model_bill += stolen_now * float(leak["price"])
	model_bill += calls * (1.0 - rate_err) * TICK * price
	if cfg.get("cdn", false):
		cdn_bill += r["browse"] * TICK * float(pieces["cdn"]["per_request"])
	revenue += booked_now * float(live.get("fee", 0.0))
	bad_charges += bad_rate * TICK
	double_bookings += dbl_rate * TICK

	# Blame, for the postmortem and the bubbles.
	var tags := []
	var lost := failed * TICK + (total * TICK * 0.2 if page > 3.0 else 0.0)
	if not built:
		var why := "sold" if cfg.get("sold", false) else "nothing_built"
		tags.append(why)
		_blame(why, total * TICK * 1000.0)
	elif not cloud and (_garage["down"] > 0 or down_now):
		tags.append("garage_melt")
	elif lost > 0.0:
		if cloud and util.get("app", 0.0) > 0.9:
			tags.append(_biggest(parts, {"assets": "no_cdn", "signup": "no_queue", "scrape": "scraper", "services": "service_chain"}, "app_overload"))
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
	if diner_blocked > 0.0:
		tags.append("limit_too_tight")
		_blame("limit_too_tight", total * TICK * diner_blocked)
	var chain_lost := 0.0
	for k in KINDS:
		chain_lost += r[k] * TICK * (1.0 - chain_ok[k])
	if chain_lost > 0.0:
		tags.append("service_chain")
		_blame("service_chain", chain_lost * 10.0)
	if gave_up > 0.0:
		tags.append("captcha")
		_blame("captcha", (r["search"] + r["book"]) * TICK * gave_up * 10.0)
	if bad_rate > 0.0:
		tags.append(bad_tag)
		_blame(bad_tag, bad_rate * TICK * 100.0)
	if dbl_rate > 0.0 or forknet_lost > 0.0:
		var why := "forknet" if forknet else "double_booking"
		tags.append(why)
		_blame(why, dbl_rate * TICK * 100.0 + r["book"] * TICK * forknet_lost * 10.0)
	for why in stolen_parts:
		if stolen_parts[why] > 0.0:
			tags.append(why)
			_blame(why, stolen_parts[why] * TICK * 100.0)
	if peek_rate > 0.0:
		tags.append("idor")
		_blame("idor", peek_rate * TICK * 100.0)
	if ai_off:
		tags.append("ai_off")
		_blame("ai_off", r["search"] * TICK * 10.0)
	# Tagged only past a small share, so a grounded, well-fenced night
	# doesn't show a bubble for every rare slip.
	if made_up_share >= 0.05:
		tags.append("hallucination")
		_blame("hallucination", answers * made_up_share * TICK)
	if follow_share >= 0.005:
		tags.append("prompt_injection")
		_blame("prompt_injection", answers * follow_share * TICK * 2.0)
	if spend_rate > 0.0 and confirm == "none":
		tags.append("no_confirm")
		_blame("no_confirm", spend_rate * TICK * 100.0)
	if cancel_rate > 0.0:
		tags.append("excess_agency")
		_blame("excess_agency", cancel_rate * TICK * 100.0)
	if confirm_give_up >= 0.1:
		tags.append("confirm_fatigue")
		_blame("confirm_fatigue", runs * TICK * confirm_give_up * 10.0)
	if built and not fit.is_empty() and fit_share < 0.9:
		var why := "vague" if cfg.get("concierge", false) else "wrong_thing"
		tags.append(why)
		_blame(why, r["search"] * TICK * (1.0 - fit_share) * 10.0)
	if dash_on and age > _age_limit:
		var why := "silent_failure" if pipeline_broken else "stale_numbers"
		tags.append(why)
		_blame(why, 1000.0)

	return {
		"tick": tick, "diners": diners, "page": minf(page, 30.0), "err": err_share, "down": down_now,
		"util": util, "tags": tags, "hits": hits, "money": _money_so_far(), "count": count,
		"backlog": _worker_backlog, "cloud": cloud, "dash": dash_on, "age": age,
		"scrape_in": scrape_in, "scrape_through": scrape_through,
		"pay": deposits_on, "bad_charges": bad_charges, "double_bookings": double_bookings,
		"stolen": stolen * 60.0, "peeked": peeked,
		"made_up": made_up, "fooled": fooled, "unasked": unasked, "agent": agent_on,
	}


## A landing page and its waitlist (Episode 2), a night of its own: the
## diners' app isn't public yet, so the only traffic is visitors loading
## the page and joining the waitlist. Off unless the episode has
## `live.landing`.
##
## A static page is the same files for everyone, so a static host copies
## them to servers near every visitor and no server of ours builds it. A
## dynamic page is built by our backend for every visit, reading its words
## from the database and sending its photo itself, so one small server
## queues like any other box. A sign-up has to be kept somewhere: a form
## service (someone else's backend), or our backend and its database. A
## static page alone has nowhere to send it.
##
## A bad change (`live.bad_change`) goes live at a scripted tick and breaks
## the sign-up box. With Git, a rollback to the last commit fixes it in
## minutes, if there's a commit from just before the change; one commit a
## day goes back to before the page existed, so the site is gone until
## Aleister rebuilds it by hand. Without Git (or with the rollback cut),
## Aleister rebuilds it by hand, from what it remembers.
func _tick_landing() -> Dictionary:
	var ld: Dictionary = live["landing"]
	var visitors := keyed(ld["visitors"], tick) * scale
	var views := visitors * float(ld["views"]) / 60.0
	var signups := visitors * float(ld["signups"]) / 60.0
	var page_on: bool = cfg.get("page", false)
	var static_site: bool = cfg.get("static", false)
	var backend: bool = cfg.get("backend", false)
	var pg: bool = cfg.get("postgres", false)
	var form: bool = cfg.get("form", false)
	var net: Dictionary = Season.pieces()["network"]

	# The bad change, and how long it stays broken.
	var bc: Dictionary = live.get("bad_change", {})
	var broken := false
	var gone := false
	var bc_tag := ""
	if not bc.is_empty() and tick >= int(bc["at"]):
		if cfg.get("rollback", false) and _rolled_at < 0:
			_rolled_at = tick
		var fixed_at := int(bc["at"]) + int(bc["by_hand"])
		var each: bool = str(cfg.get("commits", "daily")) == "each"
		if _rolled_at >= 0 and each:
			fixed_at = mini(fixed_at, _rolled_at + int(bc["rollback"]))
		elif _rolled_at >= 0:
			gone = tick < fixed_at
		broken = tick < fixed_at
		if broken:
			if _rolled_at >= 0:
				bc_tag = "rolled_back" if each else "commit_often"
			elif not cfg.get("git", false):
				bc_tag = "no_git"
			else:
				# Until the rollback is offered, it's just the change that broke;
				# after that, a skipped rollback.
				var offered := 0
				for h in live.get("hotfixes", []):
					if h.get("changes", [{}])[0].get("set", "") == "rollback":
						offered = int(h["tick"])
				bc_tag = "bad_change" if tick <= offered else "rollback_skipped"

	# Where the page comes from.
	var dynamic := page_on and not static_site and backend and not gone
	var web_load := 0.0
	var db_load := 0.0
	if dynamic:
		web_load += views * (float(ld["page_app"]) + float(ld["assets"]))
		if pg:
			db_load += views * float(ld["page_db"])
	var to_backend := not form and backend and pg
	if to_backend:
		web_load += signups * float(ld["signup_app"])
		db_load += signups * float(ld["signup_db"])
	var util := {}
	var web_ok := 1.0
	var web_lat := 0.0
	var db_ok := 1.0
	var db_lat := 0.0
	if backend:
		var app_piece: Dictionary = pieces["app_server"]
		var res := _box(_web, web_load, float(app_piece["sizes"]["S"]["capacity"]), float(app_piece["latency"]))
		web_ok = 1.0 - res["drop"]
		web_lat = res["latency"]
		util["web"] = res["u"]
	if pg:
		var pgp: Dictionary = pieces["postgres"]
		var res := _box(_signups_db, db_load, float(pgp["capacity"]), float(pgp["latency"]))
		db_ok = 1.0 - res["drop"]
		db_lat = res["latency"]
		util["signups_db"] = res["u"]

	var page_ok := 0.0
	var page := 0.0
	if page_on and not gone:
		if static_site:
			page_ok = 1.0
			page = float(net["base"])
			cdn_bill += views * TICK * float(pieces["cdn"]["per_request"])
		elif dynamic:
			page_ok = web_ok * (db_ok if pg else 1.0)
			page = float(net["base"]) + float(net["no_cdn"]) + web_lat + (db_lat if pg else 0.0)
	var video: bool = cfg.get("video", false)
	if video and page_ok > 0.0:
		page += float(ld["video_latency"])
		cdn_bill += views * TICK * float(ld["video_price"])

	# Where a sign-up goes.
	var dest_ok := 0.0
	if form:
		dest_ok = 1.0
	elif to_backend:
		dest_ok = web_ok * db_ok
	var works := page_ok * dest_ok * (0.0 if broken else 1.0)
	var give_up := float(ld["accounts_give_up"]) if cfg.get("accounts", false) else 0.0
	var abandon := clampf((page - 2.0) / 4.0, 0.0, 1.0) * 0.6
	var signup_ok := works * (1.0 - give_up) * (1.0 - abandon)

	var total := views + signups
	var failed := views * (1.0 - page_ok) + signups * (1.0 - works)
	var err_share := failed / total if total > 0.0 else 0.0
	var down_now := err_share > DOWN_SHARE
	if down_now:
		down_ticks += 1
	elif page_ok > 0.5:
		peak_latency = maxf(peak_latency, page)
	signup_tries += signups * TICK
	signed += signups * TICK * signup_ok

	var tags := []
	if not page_on:
		tags.append("no_page")
		_blame("no_page", total * TICK * 1000.0)
	elif not static_site and not backend:
		tags.append("no_server")
		_blame("no_server", total * TICK * 1000.0)
	elif dynamic and util.get("web", 0.0) > 0.9 and (page > 3.0 or web_ok < 1.0):
		tags.append("landing_overload")
		_blame("landing_overload", views * TICK * (1.0 - web_ok) + total * TICK * 0.2)
	if page_on and not form and not to_backend:
		tags.append("nowhere_to_sign_up")
		_blame("nowhere_to_sign_up", signups * TICK * 100.0)
	if give_up > 0.0:
		tags.append("accounts")
		_blame("accounts", signups * TICK * give_up * 10.0)
	if video and page_ok > 0.0:
		tags.append("video")
		_blame("video", views * TICK * 0.2)
	if bc_tag != "":
		tags.append(bc_tag)
		_blame(bc_tag, (total * TICK * 100.0) if gone else (signups * TICK * (1.0 if bc_tag in ["rolled_back", "bad_change"] else 100.0)))

	return {
		"tick": tick, "diners": visitors, "page": minf(page, 30.0), "err": err_share, "down": down_now,
		"util": util, "tags": tags, "hits": {}, "money": _money_so_far(), "count": 1,
		"backlog": 0.0, "cloud": true, "signed": signed, "broken": broken,
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
	return float(ep["budget"]["bank"]) - model_bill - cdn_bill - pay_bill - _incidents() + revenue


## What the night's incidents cost: a leak's lawyer, a refund and an apology
## for each wrong charge, a comped dinner for each party turned away.
func _incidents() -> float:
	var inc: Dictionary = ep.get("incidents", {})
	var total := 0.0
	if leaks > 0.0:
		total += float(inc.get("leak", inc.get("cache_leak", 0.0)))
	total += bad_charges * float(inc.get("bad_charge", 0.0))
	total += double_bookings * float(inc.get("double_booking", 0.0))
	total += cancelled * float(inc.get("cancelled", 0.0))
	return total


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
	if cfg.get("backup", false):
		m += float(pieces["payments"]["backup_monthly"])
	if cfg.get("waf", false):
		m += float(pieces["waf"]["monthly"])
	if cfg.get("rag", false):
		m += float(pieces["index"]["monthly"])
	# The front half's small boards (Episodes 1 and 2).
	if cfg.get("feed", false):
		m += float(pieces["feed"]["monthly"])
	if cfg.get("backend", false):
		m += float(pieces["app_server"]["sizes"]["S"]["monthly"])
	if cfg.get("postgres", false):
		m += float(pieces["postgres"]["monthly"])
	if cfg.get("form", false):
		m += float(pieces["form"]["monthly"])
	return m


func result() -> Dictionary:
	var budget: Dictionary = ep["budget"]
	var incidents := _incidents()
	var bank := float(budget["bank"]) - model_bill - cdn_bill - pay_bill - incidents + revenue
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
		"deposit_success": dep_done / dep_tries if dep_tries > 0.0 else 0.0,
		# People are whole: the flow model's expected count, to the nearest one.
		"bad_charges": floorf(bad_charges + 0.5),
		"double_bookings": floorf(double_bookings + 0.5),
		"key_abuse": floorf(stolen_calls + 0.5),
		"agent_success": agent_done / agent_tries if agent_tries > 0.0 else 0.0,
		"bad_answers": (made_up + hijacked) / answered if answered > 0.0 else 0.0,
		"unasked": floorf(unasked + 0.5),
		"fit_success": fit_done / fit_tries if fit_tries > 0.0 else 0.0,
		"signup_success": signed / signup_tries if signup_tries > 0.0 else 0.0,
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
	if not cfg.get("deposits", false):
		for g in ep["goal"]:
			if g["metric"] == "deposit_success":
				blame["no_deposits"] = 1.0e9
	if not cfg.get("agent", false):
		for g in ep["goal"]:
			if g["metric"] == "agent_success":
				blame["no_agent"] = 1.0e9
	# A kept hotfix can carry its own finding (the finale's live, unreviewed
	# fix), named first because it caused what follows.
	for h in live.get("hotfixes", []):
		if h.has("tag") and _hotfixed.has(h["id"]) and plan.hotfix.get(h["id"], false):
			blame[h["tag"]] = 1.0e8
	# The minutes before a rollback belong to the rollback's finding.
	if blame.has("rolled_back") and blame.has("bad_change"):
		blame["rolled_back"] += blame["bad_change"]
		blame.erase("bad_change")
	if passed and runway < float(budget["par"]):
		blame["overbuilt"] = 1.0
	var order := blame.keys()
	order.sort_custom(func(a, b): return blame[a] > blame[b])
	return {
		"passed": passed, "goals": goals, "metrics": metrics, "runway": runway, "par": float(budget["par"]),
		"lean": runway >= float(budget["par"]) - 0.000001, "bank": bank, "burn": burn,
		"model_bill": model_bill, "cdn_bill": cdn_bill, "pay_bill": pay_bill, "incidents": incidents, "revenue": revenue,
		"stolen_bill": stolen_bill, "stolen_calls": stolen_calls, "peeked": peeked,
		"made_up": made_up, "hijacked": hijacked, "fooled": fooled, "unasked": unasked, "cancelled": cancelled,
		"booked": booked, "melts": melts, "signed": signed, "signup_tries": signup_tries, "tags": order, "monthly_extra": monthly_extra(),
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
