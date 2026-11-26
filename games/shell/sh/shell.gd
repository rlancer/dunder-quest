class_name Shell
extends RefCounted

## A small Unix shell, in GDScript: enough of bash and the GNU tools to run
## the lines the chips can spell, and to answer the way the real ones do.
## A line is commands joined by pipes; each command reads the files it is
## given, or else what the one before it printed. `> file` writes a
## command's output down instead of passing it on, `< file` feeds it one.
##
## tests/replay.gd runs every ticket's solution and thousands of other lines
## through this, and tests/verify_shell.ts runs the same lines through the
## real bash and coreutils and demands the same output, the same files, and
## an error wherever this gives one, in the same words.
##
## Three things here are the game's own, and say so:
## - "waiting": a first command with no file would sit and wait for the
##   keyboard. The game refuses it (and bash, handed nothing, accepts it).
## - "unsupported": a real option or pattern this engine doesn't model. It
##   is never run wrongly; it is refused, and the verifier skips it.
## - "clobber": a line that reads a file it also writes, which in a real
##   shell depends on which command gets there first.

const NOT_FOUND := "No such file or directory"
## Every option letter the real tool has. One that's here but not modelled
## is "unsupported"; one that isn't here is the tool's "invalid option".
const REAL_FLAGS := {
	"cat": "AbeEnstTuv", "head": "cnqvz", "tail": "cfFnqsvz", "wc": "clmwL",
	"grep": "EFGPefiywxzsvVbnHhoqLlcrRTUZABCIadm", "sort": "bdfgiMhnRrVcCkmosStTuz",
	"uniq": "cdDfiswuz", "cut": "bcdfnsz", "tr": "cCdst", "ls": "aAbBcCdDfFgGhHiIklLmnNopqQrRsStTuUvwxXZ1",
}
## The ones modelled here, and whether each takes a value.
const FLAGS := {
	"cat": {}, "ls": {}, "head": {"n": true}, "tail": {"n": true}, "wc": {"l": false, "w": false, "c": false, "m": false},
	"grep": {"v": false, "i": false, "c": false, "n": false}, "sort": {"r": false, "n": false, "u": false},
	"uniq": {"c": false, "d": false, "u": false}, "cut": {"d": true, "f": true, "c": true, "s": false}, "tr": {"d": false},
}


## Runs `line` in a kitchen holding `files` (name -> text, each line ended
## with a newline). Returns {"out": what reached the screen, "files": the
## files written (name -> text)}, or {"error": the shell's own words, "kind":
## "real", "syntax", "waiting", "unsupported" or "clobber", "why": a key for
## the plain-words gloss, "token": what it's about, "count": how many of
## the line's commands the real shell would complain about}.
static func run(line: String, files: Dictionary) -> Dictionary:
	var words := split(line)
	if words.is_empty():
		return _err("", "empty", "empty", "")
	var stages: Array = [[]]
	for word: String in words:
		if word == "|":
			stages.append([])
		else:
			(stages[-1] as Array).append(word)
	for i in stages.size():
		if (stages[i] as Array).is_empty():
			if i == stages.size() - 1 and i > 0:
				return _err("bash: syntax error: unexpected end of file", "syntax", "pipe_end", "|")
			return _err("bash: syntax error near unexpected token `|'", "syntax", "pipe_start", "|")
	# Redirections come off each command's words first, as bash takes them.
	var plans: Array = []
	var written := {}
	for stage: Array in stages:
		var plan := {"words": [], "to": "", "from": ""}
		var i := 0
		while i < stage.size():
			var word := str(stage[i])
			if word == ">" or word == "<":
				if i + 1 >= stage.size():
					return _err("bash: syntax error near unexpected token `newline'", "syntax", "redirect", word)
				if word == ">":
					plan.to = str(stage[i + 1])
				else:
					plan.from = str(stage[i + 1])
				i += 2
				continue
			if word.contains(">") or word.contains("<"):
				return _err("", "unsupported", "unsupported", word)
			(plan.words as Array).append(word)
			i += 1
		if plan.to != "":
			if written.has(plan.to):
				return _err("", "clobber", "clobber", str(plan.to))
			written[plan.to] = true
		plans.append(plan)
	for plan: Dictionary in plans:
		for name: String in written:
			if (plan.words as Array).has(name) or plan.from == name:
				return _err("", "clobber", "clobber", name)
	var fs := files.duplicate()
	var out_files := {}
	# bash makes every output file before any command runs.
	for name: String in written:
		fs[name] = ""
		out_files[name] = ""
	# Every command on a line runs, whatever becomes of the others, so one
	# that fails doesn't stop the rest from failing too. The line is refused
	# on the first real complaint; "waiting" only counts if there is none.
	var stream: Variant = null
	var failed: Array = []
	for plan: Dictionary in plans:
		var stdin: Variant = stream
		var regular := false
		var out := ""
		var result := {}
		if plan.from != "" and not fs.has(plan.from):
			result = _err("bash: %s: %s" % [plan.from, NOT_FOUND], "real", "nofile", str(plan.from))
		else:
			if plan.from != "":
				stdin = fs[plan.from]
				regular = true
			if not (plan.words as Array).is_empty():
				result = _command(plan.words, stdin, regular, fs)
		if result.has("error"):
			failed.append(result)
		elif not result.is_empty():
			out = str(result.out)
			for name: String in result.get("wrote", {}):
				fs[name] = result.wrote[name]
				out_files[name] = result.wrote[name]
		if plan.to != "":
			fs[plan.to] = out
			out_files[plan.to] = out
			out = ""
		stream = out
	if not failed.is_empty():
		var real := failed.filter(func(e: Dictionary) -> bool: return e.kind == "real")
		var unsure := failed.filter(func(e: Dictionary) -> bool: return e.kind == "unsupported")
		var chosen: Dictionary = unsure[0] if not unsure.is_empty() else (real[0] if not real.is_empty() else failed[0])
		chosen["count"] = real.size()
		return chosen
	return {"out": str(stream), "files": out_files}


## The words of a line. Chips are joined with spaces, so that's all there is
## to it: no quotes, no escapes.
static func split(line: String) -> PackedStringArray:
	var words := PackedStringArray()
	for word: String in line.split(" ", false):
		words.append(word)
	return words


## The names of the commands this shell has.
static func commands() -> Array:
	return FLAGS.keys()


static func _err(text: String, kind: String, why: String, token: String) -> Dictionary:
	return {"error": text, "kind": kind, "why": why, "token": token}


static func _lines(text: String) -> PackedStringArray:
	if text == "":
		return PackedStringArray()
	var body := text.left(-1) if text.ends_with("\n") else text
	return body.split("\n")


static func _text(lines: Array) -> String:
	var out := ""
	for line: String in lines:
		out += line + "\n"
	return out


## Options and operands, the way GNU getopt reads them: options anywhere,
## letters may share a dash, a value may be attached or be the next word.
static func _parse(cmd: String, args: Array) -> Dictionary:
	var spec: Dictionary = FLAGS[cmd]
	var real: String = REAL_FLAGS[cmd]
	var flags := {}
	var operands: Array = []
	var i := 0
	while i < args.size():
		var word := str(args[i])
		i += 1
		if word.length() < 2 or not word.begins_with("-"):
			# uniq counts its operands as it meets them; the rest wait.
			if cmd == "uniq" and operands.size() == 2:
				return _err("uniq: extra operand '%s'" % word, "real", "extra", word)
			operands.append(word)
			continue
		if word.begins_with("--"):
			return _err("", "unsupported", "unsupported", word)
		var at := 1
		while at < word.length():
			var letter := word[at]
			at += 1
			if not spec.has(letter):
				if real.contains(letter) or letter.is_valid_int():
					return _err("", "unsupported", "unsupported", "-" + letter)
				return _err("%s: invalid option -- '%s'" % [cmd, letter], "real", "option", "-" + letter)
			if not bool(spec[letter]):
				flags[letter] = true
				continue
			var value := ""
			if at < word.length():
				value = word.substr(at)
			elif i < args.size():
				value = str(args[i])
				i += 1
			else:
				return _err("%s: option requires an argument -- '%s'" % [cmd, letter], "real", "needs_value", "-" + letter)
			# The tools check a value the moment they read it, before they
			# look at anything further along the line.
			var problem := _value_problem(cmd, letter, value, flags)
			if not problem.is_empty():
				return problem
			flags[letter] = value
			break
	return {"flags": flags, "operands": operands}


static func _value_problem(cmd: String, letter: String, value: String, flags: Dictionary) -> Dictionary:
	if (cmd == "head" or cmd == "tail") and letter == "n":
		var digits := value.substr(1) if value.begins_with("-") or value.begins_with("+") else value
		if not _all_digits(digits):
			return _err("%s: invalid number of lines: '%s'" % [cmd, digits if value.begins_with("-") else value], "real", "number", value)
	if cmd == "cut":
		if (letter == "f" or letter == "c") and (flags.has("f") or flags.has("c")):
			return _err("cut: only one list may be specified", "real", "list", "-" + letter)
		if letter == "d" and value.length() != 1:
			return _err("cut: the delimiter must be a single character", "real", "delimiter", value)
	return {}


## What a command reads: the files it names, or else the line. Returns
## {"inputs": [[name, text]...]} ("" names the line), or an error.
static func _inputs(cmd: String, names: Array, stdin: Variant, fs: Dictionary, missing: String) -> Dictionary:
	if names.is_empty():
		if stdin == null:
			return _err("", "waiting", "waiting", cmd)
		return {"inputs": [["", str(stdin)]]}
	var inputs: Array = []
	for name: String in names:
		if not fs.has(name):
			return _err(missing % name, "real", "nofile", name)
		inputs.append([name, str(fs[name])])
	return {"inputs": inputs}


static func _joined(inputs: Array) -> String:
	var text := ""
	for pair: Array in inputs:
		text += str(pair[1])
	return text


static func _command(words: Array, stdin: Variant, regular: bool, fs: Dictionary) -> Dictionary:
	var cmd := str(words[0])
	if not FLAGS.has(cmd):
		return _err("bash: %s: command not found" % cmd, "real", "notfound", cmd)
	var parsed := _parse(cmd, words.slice(1))
	if parsed.has("error"):
		return parsed
	var flags: Dictionary = parsed.flags
	var ops: Array = parsed.operands
	match cmd:
		"ls":
			return _ls(ops, fs)
		"cat":
			var got := _inputs(cmd, ops, stdin, fs, "cat: %s: " + NOT_FOUND)
			return got if got.has("error") else {"out": _joined(got.inputs)}
		"head", "tail":
			return _head_tail(cmd, flags, ops, stdin, fs)
		"wc":
			return _wc(flags, ops, stdin, regular, fs)
		"grep":
			return _grep(flags, ops, stdin, fs)
		"sort":
			return _sort(flags, ops, stdin, fs)
		"uniq":
			return _uniq(flags, ops, stdin, fs)
		"cut":
			return _cut(flags, ops, stdin, fs)
		"tr":
			return _tr(flags, ops, stdin)
	return _err("", "unsupported", "unsupported", cmd)


static func _ls(ops: Array, fs: Dictionary) -> Dictionary:
	var names: Array = []
	if ops.is_empty():
		names = fs.keys()
	else:
		for name: String in ops:
			if not fs.has(name):
				return _err("ls: cannot access '%s': %s" % [name, NOT_FOUND], "real", "nofile", name)
			names.append(name)
	names.sort()
	return {"out": _text(names)}


static func _head_tail(cmd: String, flags: Dictionary, ops: Array, stdin: Variant, fs: Dictionary) -> Dictionary:
	var count := 10
	var mode := "plain"
	if flags.has("n"):
		var value := str(flags.n)
		var digits := value
		if value.begins_with("-") or value.begins_with("+"):
			digits = value.substr(1)
			if cmd == "head":
				mode = "allbut" if value.begins_with("-") else "plain"
			else:
				mode = "from" if value.begins_with("+") else "plain"
		count = int(digits)
	var got := _inputs(cmd, ops, stdin, fs, cmd + ": cannot open '%s' for reading: " + NOT_FOUND)
	if got.has("error"):
		return got
	var out := ""
	var inputs: Array = got.inputs
	for i in inputs.size():
		var lines := Array(_lines(str(inputs[i][1])))
		if inputs.size() > 1:
			out += "%s==> %s <==\n" % ["\n" if i > 0 else "", inputs[i][0]]
		var kept: Array
		if cmd == "head":
			kept = lines.slice(0, maxi(lines.size() - count, 0)) if mode == "allbut" else lines.slice(0, count)
		elif mode == "from":
			kept = lines.slice(maxi(count - 1, 0))
		else:
			kept = lines.slice(maxi(lines.size() - count, 0)) if count > 0 else []
		out += _text(kept)
	return {"out": out}


static func _all_digits(text: String) -> bool:
	for i in text.length():
		if text[i] < "0" or text[i] > "9":
			return false
	return text != ""


static func _wc(flags: Dictionary, ops: Array, stdin: Variant, regular: bool, fs: Dictionary) -> Dictionary:
	var got := _inputs("wc", ops, stdin, fs, "wc: %s: " + NOT_FOUND)
	if got.has("error"):
		return got
	var want_l := flags.has("l")
	var want_w := flags.has("w")
	var want_c := flags.has("c") or flags.has("m")
	if not (want_l or want_w or want_c):
		want_l = true
		want_w = true
		want_c = true
	var shown := int(want_l) + int(want_w) + int(want_c)
	var inputs: Array = got.inputs
	# The width of the columns, as GNU wc works it out: one count of one file
	# stands alone; otherwise wide enough for the bytes of every file named,
	# and seven if anything comes down a pipe.
	var width := 1
	if not (inputs.size() == 1 and shown == 1):
		var bytes := 0
		var least := 1
		for pair: Array in inputs:
			if str(pair[0]) == "" and not regular:
				least = 7
			else:
				bytes += str(pair[1]).length()
		while bytes >= 10:
			bytes /= 10
			width += 1
		width = maxi(width, least)
	var totals := [0, 0, 0]
	var out := ""
	for pair: Array in inputs:
		var text := str(pair[1])
		var counts := [text.count("\n"), _words(text), text.length()]
		for k in 3:
			totals[k] += counts[k]
		out += _wc_row(counts, [want_l, want_w, want_c], width, str(pair[0]))
	if inputs.size() > 1:
		out += _wc_row(totals, [want_l, want_w, want_c], width, "total")
	return {"out": out}


static func _wc_row(counts: Array, want: Array, width: int, name: String) -> String:
	var cells := PackedStringArray()
	for k in 3:
		if want[k]:
			cells.append(str(counts[k]).lpad(width))
	var row := " ".join(cells)
	return row + (" " + name if name != "" else "") + "\n"


static func _words(text: String) -> int:
	var count := 0
	for line: String in text.split("\n"):
		count += line.split(" ", false).size()
	return count


static func _grep(flags: Dictionary, ops: Array, stdin: Variant, fs: Dictionary) -> Dictionary:
	if ops.is_empty():
		return _err("Usage: grep [OPTION]... PATTERNS [FILE]...", "real", "usage", "grep")
	var pattern := str(ops[0])
	var source := _grep_pattern(pattern)
	if source == "":
		return _err("", "unsupported", "unsupported", pattern)
	var regex := RegEx.new()
	if regex.compile(("(?i)" if flags.has("i") else "") + source) != OK:
		return _err("", "unsupported", "unsupported", pattern)
	var got := _inputs("grep", ops.slice(1), stdin, fs, "grep: %s: " + NOT_FOUND)
	if got.has("error"):
		return got
	var inputs: Array = got.inputs
	var out := ""
	for pair: Array in inputs:
		var prefix := "%s:" % pair[0] if inputs.size() > 1 else ""
		var lines := _lines(str(pair[1]))
		var hits := 0
		for i in lines.size():
			if (regex.search(lines[i]) != null) == flags.has("v"):
				continue
			hits += 1
			if not flags.has("c"):
				out += prefix + ("%d:" % (i + 1) if flags.has("n") else "") + lines[i] + "\n"
		if flags.has("c"):
			out += "%s%d\n" % [prefix, hits]
	return {"out": out}


## grep's pattern is a regular expression. Plain words, a dot, and ^ and $
## at the ends are read the way grep reads them; anything fancier is left
## to the regex game.
static func _grep_pattern(pattern: String) -> String:
	var out := ""
	for i in pattern.length():
		var c := pattern[i]
		if "*[]\\".contains(c):
			return ""
		if c == "." or (c == "^" and i == 0) or (c == "$" and i == pattern.length() - 1):
			out += c
		elif "^$+?(){}|/".contains(c):
			out += "\\" + c
		else:
			out += c
	return out


## The number a line starts with, the way sort -n reads it (0 if none).
static func _number(line: String) -> float:
	var text := line.lstrip(" \t")
	var end := 0
	if end < text.length() and text[end] == "-":
		end += 1
	var seen_dot := false
	while end < text.length():
		var c := text[end]
		if c == "." and not seen_dot:
			seen_dot = true
		elif c < "0" or c > "9":
			break
		end += 1
	var number := text.left(end)
	return float(number) if number.is_valid_float() else 0.0


static func _sort(flags: Dictionary, ops: Array, stdin: Variant, fs: Dictionary) -> Dictionary:
	var got := _inputs("sort", ops, stdin, fs, "sort: cannot read: %s: " + NOT_FOUND)
	if got.has("error"):
		return got
	var numeric := flags.has("n")
	var reverse := flags.has("r")
	var unique := flags.has("u")
	var rows: Array = []
	var lines := _lines(_joined(got.inputs))
	for i in lines.size():
		rows.append([lines[i], i])
	# By the key; then, unless -u, by the whole line, byte for byte (and -r
	# turns that round too); then by where it stood, so it is stable.
	var key := func(a: Array, b: Array) -> int:
		if numeric:
			var x := _number(a[0])
			var y := _number(b[0])
			return -1 if x < y else (1 if x > y else 0)
		return _bytes(a[0], b[0])
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		var order: int = key.call(a, b)
		if order == 0 and not unique and numeric:
			order = _bytes(a[0], b[0])
		if order != 0:
			return (order > 0) if reverse else (order < 0)
		return int(a[1]) < int(b[1]))
	var out: Array = []
	for i in rows.size():
		if unique and i > 0 and key.call(rows[i - 1], rows[i]) == 0:
			continue
		out.append(rows[i][0])
	return {"out": _text(out)}


## Compares two lines the way the C locale does: by the number of each byte.
static func _bytes(a: String, b: String) -> int:
	var n := mini(a.length(), b.length())
	for i in n:
		var x := a.unicode_at(i)
		var y := b.unicode_at(i)
		if x != y:
			return -1 if x < y else 1
	return -1 if a.length() < b.length() else (1 if a.length() > b.length() else 0)


static func _uniq(flags: Dictionary, ops: Array, stdin: Variant, fs: Dictionary) -> Dictionary:
	var got := _inputs("uniq", ops.slice(0, 1), stdin, fs, "uniq: %s: " + NOT_FOUND)
	if got.has("error"):
		return got
	var lines := _lines(_joined(got.inputs))
	var out := ""
	var i := 0
	while i < lines.size():
		var run := 1
		while i + run < lines.size() and lines[i + run] == lines[i]:
			run += 1
		var keep := true
		if flags.has("d") and flags.has("u"):
			keep = false
		elif flags.has("d"):
			keep = run > 1
		elif flags.has("u"):
			keep = run == 1
		if keep:
			out += ("%7d " % run if flags.has("c") else "") + lines[i] + "\n"
		i += run
	# A second name is where uniq writes, not something else to read.
	# (Written over the file it's reading, it has wiped it before it starts.)
	if ops.size() == 2:
		return {"out": "", "wrote": {str(ops[1]): "" if ops[1] == ops[0] else out}}
	return {"out": out}


## A cut list ("2", "1,3", "2-", "-2", "1-3") as [[from, to]...], to = 0 for
## "to the end". Or an error.
static func _list(text: String, what: String) -> Dictionary:
	var ranges: Array = []
	for part: String in text.split(","):
		var from := 1
		var to := 0
		if part.contains("-"):
			var ends := part.split("-")
			if ends.size() != 2 or (ends[0] == "" and ends[1] == ""):
				return _err("cut: invalid range with no endpoint: -", "real", "list", part)
			if (ends[0] != "" and not _all_digits(ends[0])) or (ends[1] != "" and not _all_digits(ends[1])):
				return _err("cut: invalid %s value '%s'" % [what, _first_bad(part)], "real", "list", part)
			from = int(ends[0]) if ends[0] != "" else 1
			to = int(ends[1]) if ends[1] != "" else 0
			if (ends[0] != "" and from == 0) or (ends[1] != "" and to == 0):
				return _err("cut: %ss are numbered from 1" % what, "real", "list", part)
			if to != 0 and to < from:
				return _err("cut: invalid decreasing range", "real", "list", part)
		else:
			if not _all_digits(part):
				return _err("cut: invalid %s value '%s'" % [what, _first_bad(part)], "real", "list", part)
			from = int(part)
			to = from
			if from == 0:
				return _err("cut: %ss are numbered from 1" % what, "real", "list", part)
		ranges.append([from, to])
	return {"ranges": ranges}


## What GNU cut quotes when a list won't read: from the first bad character on.
static func _first_bad(part: String) -> String:
	for i in part.length():
		if not ((part[i] >= "0" and part[i] <= "9") or part[i] == "-"):
			return part.substr(_run_start(part, i))
	return part


static func _run_start(part: String, at: int) -> int:
	var start := at
	while start > 0 and part[start - 1] >= "0" and part[start - 1] <= "9":
		start -= 1
	return start


static func _picked(index: int, ranges: Array) -> bool:
	for r: Array in ranges:
		if index >= int(r[0]) and (int(r[1]) == 0 or index <= int(r[1])):
			return true
	return false


static func _cut(flags: Dictionary, ops: Array, stdin: Variant, fs: Dictionary) -> Dictionary:
	if not flags.has("f") and not flags.has("c"):
		return _err("cut: you must specify a list of bytes, characters, or fields", "real", "nolist", "cut")
	var fields := flags.has("f")
	if not fields and flags.has("d"):
		return _err("cut: an input delimiter may be specified only when operating on fields", "real", "delimiter", "-d")
	if not fields and flags.has("s"):
		return _err("cut: suppressing non-delimited lines makes sense\n\tonly when operating on fields", "real", "delimiter", "-s")
	var delimiter := "\t"
	if flags.has("d"):
		delimiter = str(flags.d)
	var list := _list(str(flags.f if fields else flags.c), "field" if fields else "byte/character position")
	if list.has("error"):
		if not fields and str(list.error).contains("positions are numbered"):
			list.error = "cut: byte/character positions are numbered from 1"
		return list
	var got := _inputs("cut", ops, stdin, fs, "cut: %s: " + NOT_FOUND)
	if got.has("error"):
		return got
	var out := ""
	for line: String in _lines(_joined(got.inputs)):
		if not fields:
			var kept := ""
			for i in line.length():
				if _picked(i + 1, list.ranges):
					kept += line[i]
			out += kept + "\n"
			continue
		if not line.contains(delimiter):
			if not flags.has("s"):
				out += line + "\n"
			continue
		var parts := line.split(delimiter)
		var kept_parts := PackedStringArray()
		for i in parts.size():
			if _picked(i + 1, list.ranges):
				kept_parts.append(parts[i])
		out += delimiter.join(kept_parts) + "\n"
	return {"out": out}


## A tr set: letters, and ranges like a-z, spelled out.
static func _charset(text: String) -> Dictionary:
	if text.contains("\\") or text.contains("["):
		return _err("", "unsupported", "unsupported", text)
	var out := ""
	var i := 0
	while i < text.length():
		if i + 2 < text.length() and text[i + 1] == "-":
			var from := text.unicode_at(i)
			var to := text.unicode_at(i + 2)
			if to < from:
				return _err("tr: range-endpoints of '%s' are in reverse collating sequence order" % text.substr(i, 3), "real", "range", text)
			for code in range(from, to + 1):
				out += String.chr(code)
			i += 3
		else:
			out += text[i]
			i += 1
	return {"set": out}


static func _tr(flags: Dictionary, ops: Array, stdin: Variant) -> Dictionary:
	var deleting := flags.has("d")
	if ops.is_empty():
		return _err("tr: missing operand", "real", "tr_operand", "tr")
	if deleting and ops.size() > 1:
		return _err("tr: extra operand '%s'" % ops[1], "real", "tr_extra", str(ops[1]))
	if not deleting and ops.size() == 1:
		return _err("tr: missing operand after '%s'" % ops[0], "real", "tr_operand", str(ops[0]))
	if ops.size() > 2:
		return _err("tr: extra operand '%s'" % ops[2], "real", "tr_extra", str(ops[2]))
	var first := _charset(str(ops[0]))
	if first.has("error"):
		return first
	var from := str(first.set)
	var to := ""
	if not deleting:
		var second := _charset(str(ops[1]))
		if second.has("error"):
			return second
		to = str(second.set)
	if stdin == null:
		return _err("", "waiting", "waiting", "tr")
	var map := {}
	for i in from.length():
		map[from[i]] = "" if deleting else to[mini(i, to.length() - 1)]
	var out := ""
	var text := str(stdin)
	for i in text.length():
		out += str(map.get(text[i], text[i]))
	return {"out": out}
