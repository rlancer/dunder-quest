class_name Trail
extends RefCounted

## The sand trail: the commit graph, drawn the way `git log --graph` would
## lay it on its side. One grain per commit, oldest on the left; each branch
## runs along its own row with its name at the end; HEAD's branch is bright
## and its grain is ringed. Commits a reset left behind (still reachable from
## ORIG_HEAD) hang on as pale ghosts. A hollow grain after HEAD is whatever
## hasn't been committed yet.

const AUTHOR_COLORS: Dictionary = {
	"prince": Palette.SAND, "vizier": Palette.VIOLET, "princess": Palette.GREEN, "palace": Palette.STEEL,
}


## Which row each commit sits on: main's first-parent line is row 0, then
## each branch's own commits, then the ghosts.
static func rows(repo: GitRepo) -> Dictionary:
	var out := {}
	var names: Array = repo.branches.keys()
	names.erase("main")
	names.push_front("main")
	for index in names.size():
		var sha: String = repo.branches.get(names[index], "")
		while sha != "" and not out.has(sha):
			out[sha] = index
			var parents: Array = repo.commits[sha].parents
			sha = parents[0] if not parents.is_empty() else ""
	for sha: String in repo.reachable():
		if not out.has(sha):
			out[sha] = names.size() if not _on_a_branch(repo, sha) else 0
	return out


static func _on_a_branch(repo: GitRepo, sha: String) -> bool:
	for name: String in repo.branches:
		if repo.ancestors(repo.branches[name]).has(sha):
			return true
	return false


static func paint(on: CanvasItem, repo: GitRepo, rect: Rect2, font: Font, big: bool, clock: float) -> void:
	var row_of := rows(repo)
	var names: Array = repo.branches.keys()
	names.erase("main")
	names.push_front("main")
	var deepest := 0
	var depth := {}
	for sha: String in row_of:
		depth[sha] = repo.depth(sha)
		deepest = maxi(deepest, depth[sha])
	var gap := 13.0 if big else 8.0
	var size := 10 if big else 8
	var radius := 3.5 if big else 2.5
	var step := minf(26.0 if big else 20.0, (rect.size.x - (70.0 if big else 54.0)) / float(deepest + 2))
	var at := func(sha: String) -> Vector2:
		return rect.position + Vector2(8.0 + depth[sha] * step, 6.0 + row_of[sha] * gap)
	var ghost_row := names.size()
	# Lines first, so grains sit on top.
	for sha: String in row_of:
		for parent: String in repo.commits[sha].parents:
			if not row_of.has(parent):
				continue
			var color: Color = Palette.LANES[row_of[sha] % Palette.LANES.size()]
			if row_of[sha] == ghost_row:
				color = Color(Palette.STEEL, 0.35)
			var a: Vector2 = at.call(parent)
			var b: Vector2 = at.call(sha)
			if a.y == b.y:
				on.draw_line(a, b, color, 1.0)
			else:
				var elbow := Vector2(a.x + step * 0.5, b.y) if row_of[sha] > row_of[parent] else Vector2(b.x - step * 0.5, a.y)
				on.draw_line(a, elbow, color, 1.0)
				on.draw_line(elbow, b, color, 1.0)
	var head := repo.head_sha()
	var last_x := {}
	for sha: String in row_of:
		var p: Vector2 = at.call(sha)
		var color: Color = AUTHOR_COLORS.get(repo.commits[sha].author, Palette.SAND)
		if row_of[sha] == ghost_row:
			color = Color(color, 0.35)
		on.draw_circle(p, radius, Palette.INK)
		on.draw_circle(p, radius - 1.0, color)
		last_x[row_of[sha]] = maxf(last_x.get(row_of[sha], 0.0), p.x)
		if sha == head:
			on.draw_arc(p, radius + 1.5, 0.0, TAU, 16, Palette.PAPER, 1.0)
	if not repo.merging.is_empty() or not repo.modified().is_empty():
		# Loose sand: changes not committed yet.
		var p: Vector2 = at.call(head) + Vector2(step * 0.7, 0)
		var pulse := 0.6 + 0.4 * sin(clock * 5.0)
		on.draw_dashed_line(at.call(head) + Vector2(radius + 2.0, 0), p - Vector2(radius, 0), Color(Palette.SAND_PALE, 0.7), 1.0, 2.0)
		on.draw_arc(p, radius - 0.5, 0.0, TAU, 12, Color(Palette.CRIMSON if not repo.merging.is_empty() else Palette.SAND_PALE, pulse), 1.0)
		last_x[row_of[head]] = maxf(last_x.get(row_of[head], 0.0), p.x)
	for index in names.size():
		var name: String = names[index]
		var tip: Vector2 = at.call(repo.branches[name])
		var x := maxf(tip.x, last_x.get(index, 0.0)) + radius + 4.0
		var y := rect.position.y + 6.0 + index * gap
		if row_of[repo.branches[name]] != index:
			# This branch has no commits of its own yet: tie its name to its tip.
			on.draw_dashed_line(tip + Vector2(0, radius), Vector2(x - 2.0, y), Color(Palette.LANES[index % Palette.LANES.size()], 0.6), 1.0, 2.0)
		var here := name == repo.head
		var label := ("HEAD > " + name if big else name) if here else name
		var color: Color = Palette.LANES[index % Palette.LANES.size()]
		on.draw_string(font, Vector2(x, y + size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color if here else Color(color, 0.6))
