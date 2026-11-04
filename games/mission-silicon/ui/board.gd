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
}
const PIPELINE_NAMES := {"hourly": "hourly", "nightly": "nightly", "stream": "streamed"}

var cfg: Dictionary = {}
var start_cfg: Dictionary = {}
var live: bool = false
var frame: Dictionary = {}
var _boxes: Dictionary = {}
var _clock: float = 0.0


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


func box_rect(id: String) -> Rect2:
	return _boxes.get(id, {}).get("rect", Rect2())


func _present(c: Dictionary) -> Dictionary:
	var out := {"phones": true, "app": true, "model": true}
	var cloud: bool = c.get("host", "") == "cloud"
	if c.get("cdn", false):
		out["cdn"] = true
	if cloud and int(c["app"]["count"]) > 1:
		out["lb"] = true
	if c.get("cache", false):
		out["cache"] = true
	if cloud:
		out["db"] = true
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
				label = "Diners"
				sub = "phones"
			"cdn":
				label = "CDN"
				sub = "photos"
			"lb":
				label = "Load"
				sub = "balancer"
			"app":
				if cloud:
					label = "App x%d" % int(cfg["app"]["count"])
					sub = "8 services" if cfg.get("cluster", false) else "size %s" % str(cfg["app"]["size"])
				else:
					label = "Aleister"
					sub = "app + db"
			"cache":
				label = "Redis"
				sub = "cache"
			"db":
				label = "Postgres x3" if cfg.get("shards", false) else "Postgres"
				sub = "indexed" if cfg.get("index", false) else "database"
				if int(cfg.get("db_x", 1)) > 1:
					sub = "%dx size" % int(cfg["db_x"])
			"model":
				label = "Model API"
				sub = "per call"
				if cfg.has("rotated"):
					sub = "new key" if cfg["rotated"] else "old key"
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
		var badges := []
		if id == "app":
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
		if id == "db" and cfg.get("owner_check", false):
			badges.append("owner check")
		if id == "phones" and str(cfg.get("key_where", "")) == "frontend":
			badges.append("key in app")
		if id == "phones" and cfg.get("forknet", false):
			badges.append("ForkNet")
		if id == "lb" and cfg.get("limiter", false):
			badges.append("%d/min" % int(cfg.get("rate_limit", 0)))
		if id == "model":
			if cfg.get("ai_cache", false):
				badges.append("cached")
			if cfg.get("model", "standard") == "big":
				badges.append("biggest")
		var rect := Rect2(SPOTS[id], Vector2(W, H))
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


func _wires() -> Array:
	var out := []
	var has := func(id: String) -> bool: return _boxes.has(id)
	var front := "lb" if has.call("lb") else "app"
	if has.call("cdn"):
		out.append(["phones", "cdn", "browse"])
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
		"replica", "warehouse":
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
			if id == "agent" and bx > r.position.x and bx + bw > r.end.x:
				bx = r.position.x
				by += 12.0
			draw_rect(Rect2(Vector2(bx, by + 1), Vector2(bw, 11)), Palette.GREEN)
			draw_string(font, Vector2(bx + 2, by + 10), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.WHITE)
			bx += bw + 2
		if live and id in ["app", "db", "model", "replica", "warehouse"]:
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
		var y_used := {}
		for tag in frame.get("tags", []):
			if not BUBBLES.has(tag):
				continue
			var spot: String = BUBBLES[tag][0]
			if not _boxes.has(spot):
				spot = "app"
			var text: String = BUBBLES[tag][1]
			var r: Rect2 = _boxes[spot]["rect"]
			var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY).x + 8
			var stack := int(y_used.get(spot, 0))
			y_used[spot] = stack + 1
			var pos := Vector2(clampf(r.get_center().x - tw / 2.0, 2, size.x - tw - 2), r.position.y - 15 - stack * 14)
			if pos.y < 2:
				pos.y = r.end.y + 12 + stack * 14
			draw_rect(Rect2(pos, Vector2(tw, 13)), Palette.RED)
			draw_string(font, pos + Vector2(4, 10), text, HORIZONTAL_ALIGNMENT_LEFT, -1, Palette.BODY, Palette.WHITE)


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
