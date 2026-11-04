class_name Board
extends Control

## The whiteboard: Forkcast's boxes and wires, drawn from a plan's config.
## Planning, boxes the pull request adds are dashed. Live, dots run along
## the wires in proportion to the traffic, each box shows how hard it's
## working, and short bubbles name what's going wrong, in the real terms.

signal box_pressed(id: String)

const W := 54.0
const H := 34.0
const SPOTS := {
	"phones": Vector2(4, 92), "cdn": Vector2(62, 36), "lb": Vector2(62, 92), "app": Vector2(120, 92),
	"cache": Vector2(178, 36), "db": Vector2(178, 92), "model": Vector2(238, 36), "queue": Vector2(120, 156),
	"warehouse": Vector2(238, 92), "replica": Vector2(178, 156), "dash": Vector2(238, 156),
	"bot": Vector2(4, 156), "pay": Vector2(62, 156), "repo": Vector2(4, 156), "pkg": Vector2(178, 156),
	"agent": Vector2(4, 156), "index": Vector2(120, 36),
	# The front half's small boards: the landing page and what's behind it.
	"page": Vector2(62, 92), "web": Vector2(120, 92), "signups_db": Vector2(178, 92),
	"form": Vector2(120, 36), "git": Vector2(62, 156),
	# The MVP (Episodes 3 and 4): the web app, and Veronica's notebook.
	"front": Vector2(62, 92), "notebook": Vector2(178, 156),
	# The bookings' store and logins (Episodes 5 and 6).
	"sheet": Vector2(178, 92), "backups": Vector2(238, 92), "copy": Vector2(238, 156), "login": Vector2(238, 36),
	# Deploys (Episode 7): Melon's laptop or the pipeline, staging, error tracking.
	"laptop": Vector2(62, 156), "ci": Vector2(62, 156), "staging": Vector2(4, 156), "tracking": Vector2(4, 36),
}
## Which box each postmortem tag's bubble pins to, and what it says.
const BUBBLES := {
	"garage_melt": ["app", "Overheated!"], "app_overload": ["app", "Maxed out"], "no_cdn": ["app", "Every photo!"],
	"no_queue": ["app", "Sign-up pile-up"], "full_scan": ["db", "Full table scan"], "no_cache": ["db", "Same menus again"],
	"db_overload": ["db", "Maxed out"], "too_many_connections": ["db", "Too many connections"],
	"stale_tables": ["cache", "Stale table!"], "cache_leak": ["cache", "Someone else's bookings!"],
	"stateless": ["lb", "Logged out?!"], "rate_limited": ["model", "429: rate limited"],
	"olap_on_oltp": ["db", "Board's dashboard!"], "replica_slow": ["replica", "Timing out"],
	"too_many_tiles": ["warehouse", "Too many tiles"], "silent_failure": ["warehouse", "Copy job failed"],
	"stale_numbers": ["dash", "3am numbers"], "scraper": ["lb", "HubbubBot flood"],
	"limit_too_tight": ["lb", "429s for diners!"], "service_chain": ["app", "Service call failed"],
	"captcha": ["app", "Gave up at CAPTCHA"], "double_charge": ["pay", "Charged twice!"],
	"timeout_unknown": ["pay", "Timed out. Paid?"], "backup_provider": ["pay", "Charged at both!"],
	"double_booking": ["db", "Same table twice!"], "forknet": ["phones", "Phones disagree!"],
	"leaked_key": ["model", "Strangers on old key!"], "key_in_app": ["phones", "Key read from app!"],
	"fake_package": ["pkg", "Sent our key away!"], "idor": ["db", "Someone else's booking!"],
	"ai_off": ["model", "AI search off"], "hallucination": ["model", "Made-up menu!"],
	"prompt_injection": ["agent", "Obeyed a review!"], "no_confirm": ["pay", "Paid, unasked!"],
	"excess_agency": ["db", "Bookings cancelled!"], "confirm_fatigue": ["agent", "Asked too often"],
	"unreviewed": ["app", "Changed live, unreviewed!"],
	"sold": ["phones", "Sold to Hubbub"], "nothing_built": ["phones", "Nothing here!"],
	"wrong_thing": ["app", "Nowhere to ask!"], "vague": ["model", "Party of six? Two."],
	"landing_overload": ["web", "Maxed out"], "no_page": ["phones", "No page!"], "no_server": ["page", "No server!"],
	"nowhere_to_sign_up": ["page", "Sign-ups go nowhere"], "accounts": ["page", "A password? Bye."],
	"video": ["page", "Still loading..."], "no_git": ["page", "Can't undo!"], "bad_change": ["page", "Sign-up broken!"],
	"rollback_skipped": ["page", "Fixing by hand"], "commit_often": ["git", "Site's gone!"], "rolled_back": ["git", "Rolled back"],
	"no_frontend": ["phones", "No app!"], "no_backend": ["front", "Nothing answers"], "notebook_app": ["notebook", "Laptop closed!"],
	"type_bugs": ["app", "undefined!"], "unfamiliar": ["app", "Zig, from memory"], "boundary": ["front", "partySize?"],
	"logic_bugs": ["app", "Wrong night"], "not_mobile": ["front", "Button off-screen"], "price_in_app": ["front", "Fee: $0.00!"],
	"hidden_price": ["front", "Hidden. Still $0!"],
	"overwritten": ["sheet", "Written over!"], "no_backup": ["db", "Restaurants gone!"],
	"untested_backup": ["backups", "Backup's empty!"], "copy_not_backup": ["copy", "Deleted here too!"],
	"restored": ["backups", "Restoring..."], "ai_rebuilt": ["db", "Made-up tables!"],
	"stuffing": ["login", "Leaked passwords!"], "sql_injection": ["login", "' OR 1=1 --"],
	"plain_passwords": ["db", "Passwords readable!"], "fast_hash": ["db", "Hashes cracked!"],
	"pw_rules": ["login", "Needs a symbol?!"], "no_login": ["phones", "No accounts!"],
	"laptop_deploy": ["laptop", "From Melon's laptop!"], "no_tests": ["app", "Booked? Not kept!"],
	"wrong_tests": ["ci", "212 tests passed!"], "no_staging": ["app", "Setting missing!"],
	"real_data": ["front", "Nonna's apostrophe!"], "no_tracking": ["phones", "Nobody's noticed"],
	"errors_hidden": ["front", "Enjoy the party!"], "rollback": ["ci", "Rolling back"],
	"no_rollback": ["app", "Fixing it live"],
}
## The home-made login's passwords, as its badge (Episode 6).
const PW_NAMES := {"plain": "as typed", "fast": "fast hash", "slow": "slow hash"}
## Each language as the box's sub-line (Episode 3).
const LANG_NAMES := {"ts": "TypeScript", "js": "JavaScript", "rust": "Rust", "zig": "Zig", "python": "Python"}
## Specs as the prototype's badge (Episode 1).
const SPEC_NAMES := {"line": "spec: 1 line", "page": "spec: 1 page", "book": "spec: 50 pages"}
const PIPELINE_NAMES := {"hourly": "hourly", "nightly": "nightly", "stream": "streamed"}

var cfg: Dictionary = {}
var start_cfg: Dictionary = {}
## Per-episode box positions that differ from SPOTS.
var spots: Dictionary = {}
## Sticky notes on the whiteboard, per episode ([{"at": [x, y], "text": ...}]),
## so a small board reads as a whiteboard, not an empty one.
var notes: Array = []
var live: bool = false
var frame: Dictionary = {}
var _boxes: Dictionary = {}
var _clock: float = 0.0
## Where this frame's badges were drawn.
var _badge_rects: Array[Rect2] = []
## Bubble places already worked out, keyed by box, width, badges and the
## bubbles before it (the board-wide search is too slow to run every frame).
var _spot_cache: Dictionary = {}


func _ready() -> void:
	clip_contents = true


func show_plan(now: Dictionary, start: Dictionary) -> void:
	cfg = now
	start_cfg = start
	_layout()


func set_frame(f: Dictionary, now: Dictionary) -> void:
	frame = f
	if now.hash() != cfg.hash():
		cfg = now
		_layout()
	queue_redraw()


## Where a box sits: SPOTS, unless the episode moves it (`spots` in its
## data, as [x, y]). The finale, with HubbubBot back beside the agent,
## moves the bot to the free top-left corner; every other episode is as it was.
func _spot(id: String) -> Vector2:
	if spots.has(id):
		return Vector2(float(spots[id][0]), float(spots[id][1]))
	return SPOTS[id]


func box_rect(id: String) -> Rect2:
	return _boxes.get(id, {}).get("rect", Rect2())


func _present(c: Dictionary) -> Dictionary:
	var out := {"phones": true}
	# Nothing built yet (Episode 1's first board): just the diners. A photo
	# feed asks the model nothing.
	if c.get("host", "") != "none":
		out["app"] = true
		if c.get("concierge", true):
			out["model"] = true
	var cloud: bool = c.get("host", "") == "cloud"
	if c.get("cdn", false):
		out["cdn"] = true
	if cloud and int(c["app"]["count"]) > 1:
		out["lb"] = true
	if c.get("cache", false):
		out["cache"] = true
	if cloud or str(c.get("store", "")) == "postgres":
		out["db"] = true
	# The bookings' store (Episode 5): a spreadsheet until it's a database.
	if c.has("store") and str(c["store"]) != "postgres":
		out["sheet"] = true
	if c.get("backups", false):
		out["backups"] = true
	if c.get("live_copy", false):
		out["copy"] = true
	if c.get("logins", false):
		out["login"] = true
	if c.get("queue", false):
		out["queue"] = true
	if cloud and c.get("warehouse", false):
		out["warehouse"] = true
	if cloud and c.get("replica", false):
		out["replica"] = true
	if c.get("dashboard", false):
		out["dash"] = true
	if c.get("scraper", false):
		out["bot"] = true
	if c.get("deposits", false):
		out["pay"] = true
	if c.get("melon_repo", false):
		out["repo"] = true
	if c.get("keysafe", false):
		out["pkg"] = true
	if c.get("agent", false):
		out["agent"] = true
	if c.get("rag", false):
		out["index"] = true
	if c.get("page", false):
		out["page"] = true
	if c.get("backend", false):
		out["web"] = true
	if c.get("postgres", false):
		out["signups_db"] = true
	if c.get("form", false):
		out["form"] = true
	if c.get("git", false):
		out["git"] = true
	if c.get("front", false):
		out["front"] = true
	if c.get("notebook", false):
		out["notebook"] = true
	# Deploys (Episode 7).
	if c.has("deploy"):
		out["laptop" if str(c["deploy"]) == "laptop" else "ci"] = true
	if c.get("staging", false):
		out["staging"] = true
	if c.get("tracking", false):
		out["tracking"] = true
	return out


func _layout() -> void:
	UI.clear(self)
	_boxes.clear()
	var now := _present(cfg)
	var before := _present(start_cfg) if not start_cfg.is_empty() else now
	var cloud: bool = cfg.get("host", "") == "cloud"
	for id in now:
		var label := ""
		var sub := ""
		match id:
			"phones":
				label = "Visitors" if cfg.has("page") and not cfg.has("front") else "Diners"
				# ForkNet is a sub-line, not a badge, so the diners' badges
				# (key in app, calls AI) stay in the two rows above the agent.
				sub = "ForkNet" if cfg.get("forknet", false) else "phones"
				if cfg.has("page") and not cfg.has("front"):
					sub = "browsers"
			"cdn":
				label = "CDN"
				sub = "photos"
			"lb":
				label = "Load"
				sub = "balancer"
			"app":
				# The MVP's backend (Episodes 3 and 4): its language underneath.
				if cfg.has("front"):
					label = "Big server" if cloud else "Aleister"
					# Episode 7's launch: a platform host, not one big server.
					if cloud and cfg.has("deploy"):
						label = "Platform"
					sub = LANG_NAMES.get(str(cfg.get("lang", "")), "") if cfg.get("mvp", false) else "prototype"
				elif cloud:
					label = "App x%d" % int(cfg["app"]["count"])
					sub = "8 services" if cfg.get("cluster", false) else "size %s" % str(cfg["app"]["size"])
				else:
					label = "Aleister"
					sub = "app + db"
					# The front half's prototype, on the garage server.
					if cfg.has("concierge"):
						if cfg.has("page"):
							sub = "prototype"
						elif cfg.get("feed", false) and cfg.get("concierge", false):
							sub = "feed + AI"
						elif cfg.get("feed", false):
							sub = "photo feed"
						else:
							sub = "concierge"
			"cache":
				label = "Redis"
				sub = "cache"
			"db":
				label = "Postgres"
				sub = "indexed" if cfg.get("index", false) else "database"
				if not cloud:
					sub = "on Aleister"
				if int(cfg.get("db_x", 1)) > 1:
					sub = "%dx size" % int(cfg["db_x"])
				if cfg.get("shards", false):
					sub = "sharded"
			"model":
				# The biggest model is in the label: a second badge under the
				# top row would run into the row below.
				label = "Big model" if cfg.get("model", "standard") == "big" else "Model API"
				sub = "per call"
				if cfg.has("rotated"):
					sub = "new key" if cfg["rotated"] else "old key"
				if int(cfg.get("limit_x", 1)) > 1:
					sub = "%dx limit" % int(cfg["limit_x"])
			"queue":
				label = "Queue"
				sub = "+ worker"
			"warehouse":
				label = "Analytics"
				sub = PIPELINE_NAMES.get(str(cfg.get("pipeline", "hourly")), "")
			"replica":
				label = "Replica"
				sub = "read copy"
			"dash":
				label = "Board"
				sub = "%d tiles" % int(cfg.get("tiles", 0))
			"bot":
				label = "HubbubBot"
				sub = "scraper"
			"pay":
				label = "Payments"
				sub = "deposits"
			"repo":
				label = "Melon's"
				sub = "private" if cfg.get("repo_private", false) else "public repo"
			"pkg":
				label = "keysafe"
				sub = "package"
			"agent":
				label = "Agents x4" if cfg.get("swarm", false) else "Agent"
				sub = "all tools" if str(cfg.get("tools", "all")) == "all" else "3 tools"
			"index":
				label = "Menus"
				sub = "index"
			"page":
				label = "Landing"
				if cfg.get("static", false):
					sub = "static"
				elif cfg.get("backend", false):
					sub = "per visit"
				else:
					sub = "no server"
			"web":
				label = "Backend"
				sub = "server"
			"signups_db":
				label = "Postgres"
				sub = "waitlist"
			"form":
				label = "Form"
				sub = "service"
			"front":
				label = "Web app"
				sub = "TypeScript"
			"notebook":
				label = "Notebook"
				sub = "Python"
			"sheet":
				label = "Sheet"
				sub = "40 tabs" if int(cfg.get("sheet_tabs", 1)) > 1 else "Gerard's"
			"backups":
				label = "Backups"
				sub = "nightly"
			"copy":
				label = "Live copy"
				sub = "replica"
			"login":
				label = "Login"
				sub = "service" if str(cfg.get("auth", "home")) == "service" else "our own"
			"git":
				label = "GitHub"
				sub = "per change" if str(cfg.get("commits", "daily")) == "each" else "daily"
			"laptop":
				label = "Melon's"
				sub = "laptop"
			"ci":
				label = "CI"
				sub = "deploys"
				if cfg.get("tests", false):
					label = "CI + tests"
					sub = "a booking" if str(cfg.get("test_check", "")) == "booking" else "page opens"
			"staging":
				label = "Staging"
				sub = "a copy"
			"tracking":
				label = "Errors"
				sub = "hidden" if cfg.get("errors_hidden", false) else "tracked"
		var badges := []
		if id == "app":
			if cfg.get("polyglot", false):
				badges.append("5 languages")
			if cfg.get("investor", false):
				badges.append("investor page")
			if cfg.get("fee", false) and str(cfg.get("price_where", "app")) == "server":
				badges.append("price rule")
			if cfg.get("spec", false):
				badges.append(SPEC_NAMES.get(str(cfg.get("detail", "line")), "spec"))
			if cfg.get("stories", false):
				badges.append("stories")
			if cfg.get("everything", false):
				badges.append("everything")
			if cfg.get("rust", false):
				badges.append("Rust")
			if cfg.get("cluster", false):
				badges.append("K8s")
			if cfg.get("alerts", false):
				badges.append("alerts")
			if cfg.get("captcha", false):
				badges.append("CAPTCHA")
			if cfg.get("waf", false):
				badges.append("WAF")
		if id == "pay":
			if cfg.get("backup", false):
				badges.append("backup")
			elif str(cfg.get("retries", "on")) == "on":
				badges.append("retry + key" if cfg.get("idem", false) else "retry")
			else:
				badges.append("no retry")
		if id == "agent":
			if cfg.get("signoff", false):
				badges.append("asks: all" if str(cfg.get("confirm", "")) == "every" else "asks: pay")
			if cfg.get("data_marked", false):
				badges.append("as data")
			if cfg.get("checker", false):
				badges.append("checker")
		if id == "db" and cfg.get("txn", false):
			badges.append("txn")
		if id == "db" and (cfg.get("owner_check", false) or cfg.get("restaurant_check", false)):
			badges.append("owner check")
		if id == "backups" and cfg.get("restore_tested", false):
			badges.append("restored")
		if id == "login":
			if str(cfg.get("auth", "home")) == "home":
				badges.append(PW_NAMES.get(str(cfg.get("pw_store", "plain")), ""))
			if cfg.get("pw_rules", false):
				badges.append("rules")
		if id == "phones" and str(cfg.get("key_where", "")) == "frontend":
			badges.append("key in app")
		if id == "phones" and cfg.get("direct_ai", false):
			badges.append("calls AI")
		if id == "lb" and cfg.get("limiter", false):
			badges.append("%d/min" % int(cfg.get("rate_limit", 0)))
		if id == "model":
			if cfg.get("ai_cache", false):
				badges.append("cached")
		if id == "phones" and cfg.get("sold", false):
			badges.append("sold")
		if id == "page":
			if cfg.get("video", false):
				badges.append("video")
			if cfg.get("accounts", false):
				badges.append("passwords")
		if id == "phones" and cfg.get("apps", false):
			badges.append("apps")
		if id == "front":
			if str(cfg.get("layout", "")) == "mobile":
				badges.append("mobile first")
			if cfg.get("fee", false) and str(cfg.get("price_where", "app")) == "app":
				badges.append("hidden fee" if cfg.get("price_hidden", false) else "price rule")
			if cfg.get("voice", false):
				badges.append("voice")
		if id == "notebook" and cfg.get("notebook_app", false):
			badges.append("runs the app")
		# Episode 7: Ulrich's error page, and the second region.
		if id == "front" and cfg.get("errors_hidden", false):
			badges.append("no errors")
		if id == "app" and cfg.get("region", false):
			badges.append("2 regions")
		var rect := Rect2(_spot(id), Vector2(W, H))
		_boxes[id] = {"rect": rect, "label": label, "sub": sub, "new": not before.has(id), "badges": badges}
		var b := Button.new()
		b.name = "Box_" + id
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = rect.position
		b.size = rect.size
		b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.pressed.connect(func() -> void: box_pressed.emit(id))
		add_child(b)
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if live:
		queue_redraw()


## Whether the box just right of this one, on the same row, has badges on
## the given badge row (0 is the row just under the boxes). At most, a
## neighbour's badges wrap at its own box's width.
func _neighbour_badged(r: Rect2, row: int = 0) -> bool:
	var font := Palette.body()
	for other in _boxes.values():
		var o: Rect2 = other["rect"]
		if is_equal_approx(o.position.y, r.position.y) and o.position.x > r.position.x and o.position.x - r.end.x < 12.0 and not other["badges"].is_empty():
			var rows := 1
			var bx := 0.0
			for badge in other["badges"]:
				var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 4.0
				if bx > 0.0 and bx + bw > o.size.x:
					rows += 1
					bx = 0.0
				bx += bw + 2.0
			return row < rows
	return false


func _wires() -> Array:
	var out := []
	var has := func(id: String) -> bool: return _boxes.has(id)
	var front := "lb" if has.call("lb") else "app"
	if has.call("cdn"):
		out.append(["phones", "cdn", "browse"])
	# The landing page (Episode 2): visitors ask the page; the page is built
	# by the backend or comes from a static host, and sign-ups go to the
	# form service or the backend. The prototype isn't public.
	# The MVP (Episodes 3 and 4): diners use the web app, which asks the
	# backend (or Ulrich's notebook); Git keeps the code; the notebook reads
	# a copy of the bookings. The landing page stays up beside it.
	if cfg.has("front"):
		if has.call("page"):
			out.append(["phones", "page", "all"])
			if has.call("form"):
				out.append(["page", "form", "signup"])
		if has.call("front"):
			out.append(["phones", "front", "all"])
			if cfg.get("notebook_app", false) and has.call("notebook"):
				out.append(["front", "notebook", "all"])
			elif cfg.get("mvp", false):
				out.append(["front", "app", "all"])
		if has.call("app") and has.call("model"):
			out.append(["app", "model", "model"])
		if has.call("db"):
			out.append(["app", "db", "db"])
		if has.call("sheet"):
			out.append(["app", "sheet", "db"])
		var store := "db" if has.call("db") else "sheet"
		if has.call("backups") and has.call(store):
			out.append([store, "backups", "backup"])
		if has.call("copy") and has.call("db"):
			out.append(["db", "copy", "replica"])
		if has.call("login") and has.call("app"):
			out.append(["app", "login", "login"])
		# Deploys (Episode 7): what's live comes from Melon's laptop, or
		# from Git through the pipeline (by way of staging).
		if has.call("ci"):
			if has.call("git"):
				out.append(["git", "ci", "history"])
			out.append(["ci", "app", "deploy"])
			if has.call("staging"):
				out.append(["ci", "staging", "deploy"])
		else:
			if has.call("git") and has.call("app"):
				out.append(["git", "app", "history"])
			if has.call("laptop") and has.call("app"):
				out.append(["laptop", "app", "deploy"])
		if has.call("tracking") and has.call("phones"):
			out.append(["phones", "tracking", "errors"])
		if has.call("notebook") and not cfg.get("notebook_app", false):
			out.append(["app", "notebook", "data"])
		return out
	if has.call("page"):
		out.append(["phones", "page", "all"])
		if has.call("web"):
			out.append(["page", "web", "all"])
			if has.call("signups_db"):
				out.append(["web", "signups_db", "db"])
		if has.call("form"):
			out.append(["page", "form", "signup"])
		if has.call("git"):
			out.append(["git", "page", "history"])
		if has.call("app") and has.call("model"):
			out.append(["app", "model", "model"])
		return out
	if has.call(front):
		out.append(["phones", front, "all"])
	if has.call("agent"):
		out.append(["phones", "agent", "agent"])
	if has.call("bot"):
		out.append(["bot", front, "scrape"])
	if front == "lb":
		out.append(["lb", "app", "all"])
	if has.call("cache"):
		out.append(["app", "cache", "cache"])
	if has.call("db"):
		out.append(["app", "db", "db"])
	if has.call("app") and has.call("model"):
		out.append(["app", "model", "model"])
	if has.call("pay"):
		out.append(["app", "pay", "pay"])
	if has.call("pkg"):
		out.append(["app", "pkg", "pkg"])
	if has.call("index"):
		out.append(["app", "index", "index"])
	if has.call("queue"):
		out.append(["app", "queue", "queue"])
		if has.call("db"):
			out.append(["queue", "db", "queue"])
	if has.call("warehouse") and has.call("db"):
		out.append(["db", "warehouse", "pipeline"])
	if has.call("replica") and has.call("db"):
		out.append(["db", "replica", "replica"])
	if has.call("dash"):
		for source in ["warehouse", "replica", "db", "app"]:
			if has.call(source):
				out.append([source, "dash", "dash"])
				break
	return out


func _edge(a: Rect2, b: Rect2) -> Array:
	var ca := a.get_center()
	var cb := b.get_center()
	return [_clip(a, ca, cb), _clip(b, cb, ca)]


## Where the line from the box's centre toward `to` leaves the box.
func _clip(r: Rect2, from: Vector2, to: Vector2) -> Vector2:
	var d := to - from
	if d.length() < 0.001:
		return from
	var tx := (r.size.x / 2.0) / absf(d.x) if absf(d.x) > 0.001 else INF
	var ty := (r.size.y / 2.0) / absf(d.y) if absf(d.y) > 0.001 else INF
	return from + d * minf(minf(tx, ty), 1.0)


func _util(id: String) -> float:
	var u: Dictionary = frame.get("util", {})
	match id:
		"app":
			return u.get("garage", u.get("app", 0.0))
		"db":
			return u.get("db", 0.0)
		"model":
			return u.get("model", 0.0)
		"replica", "warehouse", "web", "signups_db":
			return u.get(id, 0.0)
	return 0.0


func _heat_color(u: float) -> Color:
	if u < 0.6:
		return Palette.GREEN
	if u < 0.9:
		return Palette.AMBER
	return Palette.RED


func _draw() -> void:
	var font := Palette.body()
	draw_rect(Rect2(Vector2.ZERO, size), Palette.WHITE)
	# Faint whiteboard grid.
	for x in range(0, int(size.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(Palette.RULE, 0.5))
	for y in range(0, int(size.y), 20):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(Palette.RULE, 0.5))
	# Sticky notes, under everything else.
	for n in notes:
		var at := Vector2(float(n["at"][0]), float(n["at"][1]))
		var tw := font.get_string_size(n["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8
		draw_rect(Rect2(at + Vector2(1, 1), Vector2(tw, 14)), Color(Palette.SLATE, 0.15))
		draw_rect(Rect2(at, Vector2(tw, 14)), Color("#fbefb4"))
		draw_string(font, at + Vector2(4, 11), n["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.SLATE_MID)
	if _boxes.is_empty():
		return
	# Wires, and the traffic on them.
	var diners := float(frame.get("diners", 0.0))
	for w in _wires():
		var ends := _edge(_boxes[w[0]]["rect"], _boxes[w[1]]["rect"])
		# The payments wire leaves the app's lower left corner, between the
		# load balancer's badges and the app's, so it crosses neither.
		if w[2] == "pay":
			var a: Rect2 = _boxes[w[0]]["rect"]
			var p: Rect2 = _boxes[w[1]]["rect"]
			ends = [Vector2(a.position.x, a.end.y - 4), Vector2(p.end.x - 8, p.position.y)]
		var color := Palette.SLATE_LIGHT
		if not live and (_boxes[w[0]]["new"] or _boxes[w[1]]["new"]):
			_dashed(ends[0], ends[1], Palette.GREEN)
		else:
			draw_line(ends[0], ends[1], color, 1.0)
		if live and not frame.is_empty():
			var n := clampi(int(diners / 2000.0) + 1, 1, 12)
			if w[2] == "model" and cfg.get("ai_cache", false):
				n = maxi(1, n / 2)
			if w[2] == "scrape":
				n = clampi(int(float(frame.get("scrape_in", 0.0)) / 150.0), 0, 12)
			var err := float(frame.get("err", 0.0))
			var dot := Palette.RED if err > 0.25 else (Palette.AMBER if err > 0.05 else Palette.GREEN)
			if frame.get("down", false) and w[0] == "phones":
				dot = Palette.RED
			for i in n:
				var t := fposmod(_clock * 0.6 + float(i) / n, 1.0)
				draw_rect(Rect2(ends[0].lerp(ends[1], t) - Vector2(1, 1), Vector2(2, 2)), dot)
	# Boxes.
	_badge_rects.clear()
	for id in _boxes:
		var b: Dictionary = _boxes[id]
		var r: Rect2 = b["rect"]
		var fill := Palette.PAPER
		var edge := Palette.SLATE
		if id == "app" and not cfg.get("host", "") == "cloud":
			fill = Color("#efe4d2")
		if live and id == "app" and frame.get("down", false) and not frame.get("cloud", true):
			fill = Color("#f3c4c4")
		draw_rect(r, fill)
		if b["new"] and not live:
			_dashed_rect(r, Palette.GREEN)
		else:
			draw_rect(r, edge, false, 1.0)
		draw_string(font, r.position + Vector2(3, 11), b["label"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, Palette.BODY, Palette.SLATE)
		var sub: String = b["sub"]
		if live and id == "cache":
			sub = "hits %d%%" % roundi(float(frame.get("hits", {}).get("menus", 0.0)) * 100.0)
		draw_string(font, r.position + Vector2(3, 22), sub, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 4, Palette.BODY, Palette.SLATE_MID)
		var bx := r.position.x
		var by := r.end.y
		for badge in b["badges"]:
			var bw := font.get_string_size(badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 4
			# The agent's badges stack under it, clear of the payments box's.
			# Any box's badges wrap rather than run off the board's edge.
			# So do a box's whose neighbour on the right has badges of its own.
			# A wrapped row may run on past the box when the neighbour's
			# badges don't reach that row (Launch Party's K8s badge used to
			# drop to a third row, under the GitHub box).
			var row := int((by - r.end.y) / 12.0)
			if bx > r.position.x and (((id in ["agent", "phones", "front"] or _neighbour_badged(r, row)) and bx + bw > r.end.x) or bx + bw > size.x - 2):
				bx = r.position.x
				by += 12.0
			draw_rect(Rect2(Vector2(bx, by + 1), Vector2(bw, 11)), Palette.GREEN)
			_badge_rects.append(Rect2(Vector2(bx, by + 1), Vector2(bw, 11)))
			draw_string(font, Vector2(bx + 2, by + 10), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.WHITE)
			bx += bw + 2
		if live and id in ["app", "db", "model", "replica", "warehouse", "web", "signups_db"]:
			var u := _util(id)
			draw_rect(Rect2(r.position + Vector2(2, r.size.y - 6), Vector2(r.size.x - 4, 4)), Palette.RULE)
			draw_rect(Rect2(r.position + Vector2(2, r.size.y - 6), Vector2((r.size.x - 4) * clampf(u, 0.0, 1.0), 4)), _heat_color(u))
		if live and id == "queue":
			var waiting := float(frame.get("backlog", 0.0)) / 250.0 / 60.0
			for i in clampi(int(waiting / 200.0), 0, 10):
				draw_rect(Rect2(r.position + Vector2(3 + i * 4, r.size.y + 3), Vector2(2, 4)), Palette.SLATE_MID)
	# Smoke, when the garage server has given up.
	if live and frame.get("down", false) and not frame.get("cloud", true) and _boxes.has("app"):
		var r: Rect2 = _boxes["app"]["rect"]
		for i in 5:
			var t := fposmod(_clock * 0.5 + i * 0.2, 1.0)
			draw_circle(r.position + Vector2(10 + i * 7, -t * 24.0), 2.0 + t * 3.0, Color(0.4, 0.4, 0.45, 0.6 * (1.0 - t)))
	# Bubbles.
	if live:
		var drawn: Array[Rect2] = []
		for tag in frame.get("tags", []):
			if not BUBBLES.has(tag):
				continue
			var spot: String = BUBBLES[tag][0]
			# Before there's a database, the bookings are in the spreadsheet.
			if spot == "db" and not _boxes.has("db") and _boxes.has("sheet"):
				spot = "sheet"
			if not _boxes.has(spot):
				spot = "app"
			if not _boxes.has(spot):
				continue
			var text: String = BUBBLES[tag][1]
			var r: Rect2 = _boxes[spot]["rect"]
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8
			var pos := _bubble_spot(r, tw, drawn)
			drawn.append(Rect2(pos, Vector2(tw, 13)))
			draw_rect(Rect2(pos, Vector2(tw, 13)), Palette.RED)
			draw_string(font, pos + Vector2(4, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.WHITE)


## Where a bubble for box `r` goes: just above the box, or under it and its
## badges, or a row further out, the first place that covers no box, no
## badge and no other bubble. Crowded boards (Demo Day's, the finale's) can
## run out of those; then the clear place on the whole board nearest the
## box, and only if there's none, a place clear of the other bubbles.
func _bubble_spot(r: Rect2, tw: float, drawn: Array[Rect2]) -> Vector2:
	var key := "%s|%s|%s|%s|%s" % [r, tw, _boxes.keys(), _badge_rects, drawn]
	if _spot_cache.has(key):
		return _spot_cache[key]
	if _spot_cache.size() > 256:
		_spot_cache.clear()
	var spot := _find_bubble_spot(r, tw, drawn)
	_spot_cache[key] = spot
	return spot


func _bubble_clear(rect: Rect2, drawn: Array[Rect2], of_boxes: bool) -> bool:
	for d in drawn:
		if d.intersects(rect):
			return false
	if not of_boxes:
		return true
	for id in _boxes:
		if (_boxes[id]["rect"] as Rect2).intersects(rect):
			return false
	for b in _badge_rects:
		if b.intersects(rect):
			return false
	return true


func _find_bubble_spot(r: Rect2, tw: float, drawn: Array[Rect2]) -> Vector2:
	var under := r.end.y + 1.0
	for b in _badge_rects:
		if b.position.x < r.end.x and b.end.x > r.position.x and b.position.y >= r.end.y and b.position.y < r.end.y + 30.0:
			under = maxf(under, b.end.y + 1.0)
	var rows := []
	for k in 4:
		rows.append(r.position.y - 14.0 - k * 14.0)
		rows.append(under + k * 14.0)
	var cx := r.get_center().x - tw / 2.0
	var xs := [cx, r.position.x, r.end.x - tw, cx - tw / 2.0 - 4.0, cx + tw / 2.0 + 4.0]
	var fallback := Vector2(-1, -1)
	for y in rows:
		if y < 2.0 or y + 13.0 > size.y - 2.0:
			continue
		for x0 in xs:
			var x := clampf(x0, 2.0, size.x - tw - 2.0)
			var rect := Rect2(Vector2(x, y), Vector2(tw, 13)).grow(-0.5)
			if not _bubble_clear(rect, drawn, false):
				continue
			if fallback.x < 0.0:
				fallback = Vector2(x, y)
			if _bubble_clear(rect, drawn, true):
				return Vector2(x, y)
	# Nowhere near the box: the nearest clear place on the board.
	var best := Vector2(-1, -1)
	var best_d := INF
	var gy := 2.0
	while gy + 13.0 <= size.y - 2.0:
		var gx := 2.0
		while gx + tw <= size.x - 2.0:
			var rect := Rect2(Vector2(gx, gy), Vector2(tw, 13)).grow(-0.5)
			var d := rect.get_center().distance_squared_to(r.get_center())
			if d < best_d and _bubble_clear(rect, drawn, true):
				best = Vector2(gx, gy)
				best_d = d
			gx += 4.0
		gy += 2.0
	if best.x >= 0.0:
		return best
	if fallback.x >= 0.0:
		return fallback
	return Vector2(clampf(r.get_center().x - tw / 2.0, 2, size.x - tw - 2), maxf(2.0, r.position.y - 14.0))


func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var length := a.distance_to(b)
	var steps := int(length / 4.0)
	for i in steps:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / steps), a.lerp(b, float(i + 1) / steps), c, 1.0)


func _dashed_rect(r: Rect2, c: Color) -> void:
	_dashed(r.position, Vector2(r.end.x, r.position.y), c)
	_dashed(Vector2(r.end.x, r.position.y), r.end, c)
	_dashed(r.end, Vector2(r.position.x, r.end.y), c)
	_dashed(Vector2(r.position.x, r.end.y), r.position, c)
