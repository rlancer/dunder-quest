class_name Loop
extends RefCounted

## The JavaScript event loop, small enough to read in one sitting.
##
## A scene's script is data (data/episodes.json): a list of statements, some
## of them with a slot a cue card can go on. `build` puts the cues on and
## returns the program; `source` writes it out as the JavaScript it is (that
## text is what the player reads, and what tests/verify_loop.ts runs with the
## real engine); `run` plays it the way a JavaScript engine does:
##
## - the script runs top to bottom, one statement at a time;
## - a setTimeout callback joins the timers, due `ms` after it was set (0 is
##   treated as 1, as Node does), and timers go by when they're due, then by
##   the order they were set in;
## - a promise reaction (a .then callback, a queueMicrotask callback, the
##   rest of an async function after an await) joins the microtasks, which go
##   strictly in order;
## - whenever nothing is running (the script has finished, or a timer's
##   callback has), every microtask runs, including any queued meanwhile,
##   before the next timer;
## - an async function runs like any other until its first await, and hands
##   back a promise that settles when its last line has run; `await` on
##   anything waits for it to settle (a value that isn't a promise counts as
##   settled already) and then carries on as a microtask.
##
## Statements:
##   {"log": "words"}                    log("words");
##   {"timeout": 500, "body": [...]}     setTimeout(() => { ... }, 500);
##   {"then": [...]}                     Promise.resolve().then(() => { ... });
##   {"micro": [...]}                    queueMicrotask(() => { ... });
##   {"chain": [[...], [...]]}           Promise.resolve().then(...).then(...);
##   {"async": "name", "body": [...]}    async function name() { ... }
##   {"call": "name"}                    name();
##   {"wait": 100}                       await wait(100);
##   {"await": {statement}}              await name();  (or await log("x");)
## and any of them may carry "slot": "a", where a cue card can go.
##
## Cue cards: "timeout:N", "then" and "micro" wrap the statement in a
## callback; "wait:N" puts `await wait(N);` in front of it; "await" puts
## `await` in front of it. The last two only go inside an async function.

## How much later than another a timer set afterwards has to be due for its
## order not to hang on how long the computer took to get there (ms).
const PHOTO_FINISH := 20.0
## Statements run before a program is given up on (none of the game's can loop).
const MAX_STEPS := 4000

const HEADER := ["const log = console.log;"]
const WAIT_HEADER := ["const wait = (ms) =>", "  new Promise((r) =>", "    setTimeout(r, ms));"]
## The longest link of a chain written on one line; a longer one gets a block.
const ONE_LINER := 32


# --- Cues --------------------------------------------------------------------

## What a cue card says on its face.
static func cue_label(cue: String) -> String:
	var parts := cue.split(":")
	match parts[0]:
		"timeout":
			return "setTimeout(…, %s)" % parts[1]
		"then":
			return "Promise.resolve().then(…)"
		"micro":
			return "queueMicrotask(…)"
		"wait":
			return "await wait(%s);" % parts[1]
		"await":
			return "await …"
	return cue


## True for the cues that only go inside an async function.
static func needs_async(cue: String) -> bool:
	return cue == "await" or cue.begins_with("wait:")


## Every slot in a script, in reading order: {"id", "async": inside an async
## function's own lines, "stmt"}.
static func slots(script: Array) -> Array:
	var out: Array = []
	_find_slots(script, false, out)
	return out


static func _find_slots(stmts: Array, in_async: bool, out: Array) -> void:
	for s: Dictionary in stmts:
		if s.has("slot"):
			out.append({"id": str(s.slot), "async": in_async, "stmt": s})
		if s.has("body"):
			_find_slots(s.body, s.has("async"), out)
		for key: String in ["then", "micro"]:
			if s.has(key):
				_find_slots(s[key], false, out)
		if s.has("chain"):
			for link: Array in s.chain:
				_find_slots(link, false, out)
		if s.has("await"):
			_find_slots([s.await], in_async, out)


## Whether `cue` may go on slot `slot_id` of `script`: "" if it may, or the
## reason it may not ("async": only inside an async function).
static func refuse(script: Array, slot_id: String, cue: String) -> String:
	for slot: Dictionary in slots(script):
		if slot.id == slot_id:
			return "async" if needs_async(cue) and not bool(slot.async) else ""
	return "slot"


## Every way a scene's cards can go on its hooks: slot id -> cue, each card
## used once at most, each hook holding one at most, each where it may go.
static func placements(scene: Dictionary) -> Array:
	var found := slots(scene.script)
	var left := {}
	for cue: String in scene.cues:
		left[cue] = int(left.get(cue, 0)) + 1
	var out: Array = []
	_place(scene.script, found, 0, left, {}, out)
	return out


static func _place(script: Array, found: Array, at: int, left: Dictionary, cues: Dictionary, out: Array) -> void:
	if at == found.size():
		out.append(cues.duplicate())
		return
	_place(script, found, at + 1, left, cues, out)
	var id := str(found[at].id)
	for cue: String in left:
		if int(left[cue]) <= 0 or refuse(script, id, cue) != "":
			continue
		left[cue] = int(left[cue]) - 1
		cues[id] = cue
		_place(script, found, at + 1, left, cues, out)
		cues.erase(id)
		left[cue] = int(left[cue]) + 1


## The script with the cues on: `cues` is slot id -> cue.
static func build(script: Array, cues: Dictionary) -> Array:
	var out: Array = []
	for s: Dictionary in script:
		var copy := s.duplicate()
		if copy.has("body"):
			copy.body = build(copy.body, cues)
		for key: String in ["then", "micro"]:
			if copy.has(key):
				copy[key] = build(copy[key], cues)
		if copy.has("chain"):
			var links: Array = []
			for link: Array in copy.chain:
				links.append(build(link, cues))
			copy.chain = links
		var cue := str(cues.get(str(s.get("slot", "")), "")) if s.has("slot") else ""
		if cue == "":
			out.append(copy)
			continue
		copy.erase("slot")
		var parts := cue.split(":")
		var marked := {"cue": cue, "slot": str(s.slot)}
		match parts[0]:
			"timeout":
				marked.merge({"timeout": int(parts[1]), "body": [copy]})
				out.append(marked)
			"then":
				marked.merge({"then": [copy]})
				out.append(marked)
			"micro":
				marked.merge({"micro": [copy]})
				out.append(marked)
			"wait":
				marked.merge({"wait": int(parts[1])})
				out.append(marked)
				copy["slot"] = str(s.slot)
				copy["cued"] = true
				out.append(copy)
			"await":
				marked.merge({"await": copy})
				out.append(marked)
	return out


static func uses_wait(stmts: Array) -> bool:
	for s: Dictionary in stmts:
		if s.has("wait"):
			return true
		for key: String in ["body", "then", "micro"]:
			if s.has(key) and uses_wait(s[key]):
				return true
		if s.has("chain"):
			for link: Array in s.chain:
				if uses_wait(link):
					return true
		if s.has("await") and uses_wait([s.await]):
			return true
	return false


# --- The source --------------------------------------------------------------

## The program as JavaScript, a line at a time: {"text", "indent", "slot": the
## slot the line belongs to (or ""), "cue": true on the lines a cue added,
## "header": true on the definitions at the top}.
static func lines(program: Array, header: bool = true) -> Array:
	var out: Array = []
	if header:
		var head: Array = HEADER.duplicate()
		if uses_wait(program):
			head.append_array(WAIT_HEADER)
		for text: String in head:
			out.append({"text": text, "indent": 0, "slot": "", "cue": false, "header": true})
	_write(program, 0, out, "")
	return out


## The program as one piece of text, exactly as it's shown and run.
static func source(program: Array, header: bool = true) -> String:
	var text := ""
	for line: Dictionary in lines(program, header):
		text += "  ".repeat(int(line.indent)) + str(line.text) + "\n"
	return text


static func _line(out: Array, text: String, indent: int, slot: String, cue: bool) -> void:
	out.append({"text": text, "indent": indent, "slot": slot, "cue": cue, "header": false})


## A statement on one line, if it is one ("" if it needs a block).
static func _inline(s: Dictionary) -> String:
	if s.has("log"):
		return "log(%s)" % JSON.stringify(str(s.log))
	if s.has("call"):
		return "%s()" % s.call
	return ""


static func _write(stmts: Array, indent: int, out: Array, owner: String) -> void:
	for s: Dictionary in stmts:
		# The lines of a statement belong to its own slot, or to the cue
		# wrapped round it. The lines a cue added are marked as the cue's.
		var slot := str(s.get("slot", owner))
		var cue_line := s.has("cue")
		if s.has("log") or s.has("call"):
			_line(out, _inline(s) + ";", indent, slot, false)
		elif s.has("timeout"):
			_line(out, "setTimeout(() => {", indent, slot, cue_line)
			_write(s.body, indent + 1, out, slot)
			_line(out, "}, %d);" % int(s.timeout), indent, slot, cue_line)
		elif s.has("then"):
			_line(out, "Promise.resolve().then(() => {", indent, slot, cue_line)
			_write(s.then, indent + 1, out, slot)
			_line(out, "});", indent, slot, cue_line)
		elif s.has("micro"):
			_line(out, "queueMicrotask(() => {", indent, slot, cue_line)
			_write(s.micro, indent + 1, out, slot)
			_line(out, "});", indent, slot, cue_line)
		elif s.has("chain"):
			_line(out, "Promise.resolve()", indent, slot, cue_line)
			var links: Array = s.chain
			for i in links.size():
				var link: Array = links[i]
				var end := ";" if i == links.size() - 1 else ""
				var single := _inline(link[0]) if link.size() == 1 and not (link[0] as Dictionary).has("slot") else ""
				if single != "" and (".then(() => %s)%s" % [single, end]).length() > ONE_LINER:
					single = ""
				if single != "":
					_line(out, ".then(() => %s)%s" % [single, end], indent + 1, slot, cue_line)
				else:
					_line(out, ".then(() => {", indent + 1, slot, cue_line)
					_write(link, indent + 2, out, slot)
					_line(out, "})%s" % end, indent + 1, slot, cue_line)
		elif s.has("async"):
			_line(out, "async function %s() {" % s.async, indent, slot, cue_line)
			_write(s.body, indent + 1, out, slot)
			_line(out, "}", indent, slot, cue_line)
		elif s.has("wait"):
			_line(out, "await wait(%d);" % int(s.wait), indent, slot, cue_line)
		elif s.has("await"):
			var inner := _inline(s.await)
			_line(out, "await %s;" % inner, indent, slot, cue_line)


# --- Running it --------------------------------------------------------------

## Plays the program, and returns:
##   "out": every line logged, in order;
##   "trace": what happened, step by step, for the event loop on screen
##     ({"kind", "now", "running", "micro", "timers", "log"});
##   "photo": true if two timers are due so close together that which goes
##     first would depend on the computer's speed (the tests keep these out
##     of the game);
##   "error": set if it never finished (it always should).
static func run(program: Array) -> Dictionary:
	var vm := _Machine.new()
	return vm.play(program)


## A label for a job on the event loop: the first thing it logs.
static func label_of(stmts: Array) -> String:
	for s: Dictionary in stmts:
		if s.has("log"):
			return str(s.log)
		if s.has("call"):
			return "%s()" % s.call
		for key: String in ["body", "then", "micro"]:
			if s.has(key):
				var inner := label_of(s[key])
				if inner != "":
					return inner
		if s.has("chain"):
			for link: Array in s.chain:
				var inner := label_of(link)
				if inner != "":
					return inner
		if s.has("await"):
			return label_of([s.await])
	return ""


class _Promise:
	var settled: bool = false
	var reactions: Array = []


class _Machine:
	var now: float = 0.0
	var micro: Array = []
	var timers: Array = []
	var out: Array = []
	var trace: Array = []
	var fns: Dictionary = {}
	var running: String = "the script"
	var seq: int = 0
	var steps: int = 0
	var photo: bool = false
	var fired: Array = []

	func play(program: Array) -> Dictionary:
		_hoist(program)
		_snap("start", "")
		_exec(program, 0, null)
		running = ""
		_snap("idle", "")
		_drain()
		while not timers.is_empty() and steps < Loop.MAX_STEPS:
			var best := 0
			for i in range(1, timers.size()):
				var t: Dictionary = timers[i]
				var b: Dictionary = timers[best]
				if t.due < b.due or (t.due == b.due and t.seq < b.seq):
					best = i
			var timer: Dictionary = timers[best]
			timers.remove_at(best)
			_check_photo(timer)
			fired.append(timer)
			now = maxf(now, float(timer.due))
			running = str(timer.label)
			_snap("timer", "")
			(timer.job as Callable).call()
			running = ""
			_snap("idle", "")
			_drain()
		var result := {"out": out, "trace": trace, "photo": photo}
		if steps >= Loop.MAX_STEPS:
			result["error"] = "it never finished"
		return result

	## A timer set later than one already gone, but due before it or with it,
	## would go first or not depending on how long the computer took.
	func _check_photo(timer: Dictionary) -> void:
		for other: Dictionary in timers + fired:
			if float(other.set_at) < float(timer.set_at) and float(other.due) >= float(timer.due) and float(other.due) - float(timer.due) < Loop.PHOTO_FINISH:
				photo = true
			if float(timer.set_at) < float(other.set_at) and float(timer.due) >= float(other.due) and float(timer.due) - float(other.due) < Loop.PHOTO_FINISH:
				photo = true

	func _hoist(stmts: Array) -> void:
		for s: Dictionary in stmts:
			if s.has("async"):
				fns[str(s.async)] = s.body

	func _snap(kind: String, logged: String) -> void:
		var queue := PackedStringArray()
		for job: Dictionary in micro:
			queue.append(str(job.label))
		var waiting: Array = []
		var sorted := timers.duplicate()
		sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.due < b.due or (a.due == b.due and a.seq < b.seq))
		for t: Dictionary in sorted:
			waiting.append([str(t.label), float(t.due)])
		trace.append({"kind": kind, "now": now, "running": running, "micro": queue, "timers": waiting, "log": logged})

	func _drain() -> void:
		while not micro.is_empty() and steps < Loop.MAX_STEPS:
			var job: Dictionary = micro.pop_front()
			running = str(job.label)
			_snap("micro", "")
			(job.run as Callable).call()
			running = ""
			_snap("idle", "")

	func _queue(label: String, job: Callable) -> void:
		micro.append({"label": label if label != "" else "…", "run": job})
		_snap("queue", "")

	func _timer(ms: int, label: String, job: Callable) -> void:
		seq += 1
		timers.append({"due": now + maxf(float(ms), 1.0), "seq": seq, "set_at": now, "label": label if label != "" else "…", "job": job})
		_snap("queue", "")

	## When `p` settles, `job` joins the microtasks (at once, if it already has).
	func _when(p: _Promise, label: String, job: Callable) -> void:
		if p.settled:
			_queue(label, job)
		else:
			p.reactions.append([label, job])

	func _settle(p: _Promise) -> void:
		if p == null or p.settled:
			return
		p.settled = true
		for r: Array in p.reactions:
			_queue(str(r[0]), r[1])
		p.reactions.clear()

	func _resolved() -> _Promise:
		var p := _Promise.new()
		p.settled = true
		return p

	func _then(p: _Promise, body: Array) -> _Promise:
		var next := _Promise.new()
		_when(p, Loop.label_of(body), func() -> void:
			_exec(body, 0, null)
			_settle(next))
		return next

	func _call(name: String) -> _Promise:
		var p := _Promise.new()
		if not fns.has(name):
			_settle(p)
			return p
		var saved := running
		_exec(fns[name], 0, p)
		running = saved
		return p

	## Runs `stmts` from `start`. `done` is the promise of the async function
	## these are the lines of (null for any other block); it settles when the
	## last line has run, and an await stops here and carries on later.
	func _exec(stmts: Array, start: int, done: _Promise) -> void:
		for i in range(start, stmts.size()):
			steps += 1
			if steps > Loop.MAX_STEPS:
				return
			var s: Dictionary = stmts[i]
			if s.has("log"):
				out.append(str(s.log))
				_snap("log", str(s.log))
			elif s.has("timeout"):
				var body: Array = s.body
				_timer(int(s.timeout), Loop.label_of(body), func() -> void: _exec(body, 0, null))
			elif s.has("then"):
				_then(_resolved(), s.then)
			elif s.has("micro"):
				var body: Array = s.micro
				_queue(Loop.label_of(body), func() -> void: _exec(body, 0, null))
			elif s.has("chain"):
				var p := _resolved()
				for link: Array in s.chain:
					p = _then(p, link)
			elif s.has("async"):
				pass
			elif s.has("call"):
				_call(str(s.call))
			elif s.has("wait") or s.has("await"):
				var p: _Promise
				var label := "…"
				if s.has("wait"):
					p = _Promise.new()
					var ms := int(s.wait)
					_timer(ms, "wait(%d)" % ms, func() -> void: _settle(p))
				else:
					var inner: Dictionary = s.await
					if inner.has("call"):
						p = _call(str(inner.call))
					else:
						_exec([inner], 0, null)
						p = _resolved()
				# The rest of this function, as a microtask once p settles.
				label = _rest_label(stmts, i + 1)
				_when(p, label, func() -> void: _exec(stmts, i + 1, done))
				return
		_settle(done)

	func _rest_label(stmts: Array, from: int) -> String:
		var rest := Loop.label_of(stmts.slice(from))
		return rest if rest != "" else "…"
