extends SceneTree
## v0.10.5 S13 (theory audit P8, Swink's spatial context): how cramped or empty each room template plays. MEASURE ONLY,
## no room is changed. For every generated room, grouped by its designed layout (or `rule_tN`: the rule-built
## interior of the start hall, the portal room and the sizes without a layout), over SEEDS floors for each of
## FLOORS floor numbers (the floor generator has no floor input, so the floors differ by seed only).
## Per room: area (m2), the share of it that is open at the player's radius (a point is blocked when it is within
## 0.35 m of any wall or piece, the room's own walls included), and the largest open circle (m, the largest
## distance from any wall or piece). Writes build/room_density.txt.
##   godot --headless --path . -s scripts/checks/room_density.gd
## Starting thresholds (not measurements): cramped = open share < 55 % or largest circle < 2.5 m; empty = open
## share > 92 % and no cover.

const SEEDS := 50
const FLOORS := 3
const STEP := 0.25
const PLAYER_RADIUS := 0.35
const CRAMPED_OPEN := 55.0
const CRAMPED_CIRCLE := 2.5
const EMPTY_OPEN := 92.0
const OUT := "res://build/room_density.txt"


func _init() -> void:
	var repo := ContentRepository.load_all()
	var map: FloorParams = RunSaver.floor_tables(null, repo)[&"map"]
	var weights := {}
	for key: Vector2i in map.room_layouts:
		for t: RoomLayoutTable in map.room_layouts[key]:
			weights[t.id] = [t.weight, key]
	var rows := {}  # name -> Array of [area, open %, circle, cover count, cells]
	for fl in range(1, FLOORS + 1):
		for s in SEEDS:
			var f := FloorGenerator.generate(9001 + s * 7919 + fl * 1000003, map)
			for room in f.room_count():
				var name := String(f.room_layout[room])
				if name.is_empty():
					name = "rule_t%d" % f.room_template[room]
				var m := _measure(f, room)
				m.append(f.room_cells[room].size)
				if not rows.has(name):
					rows[name] = []
				(rows[name] as Array).append(m)
	var table: Array = []
	for name: String in rows:
		var list: Array = rows[name]
		var area := 0.0
		var open := 0.0
		var circle := 0.0
		var min_open := 1000.0
		var min_circle := 1000.0
		var cover := 0
		var bad := 0
		for m: Array in list:
			area += m[0]
			open += m[1]
			circle += m[2]
			min_open = minf(min_open, m[1])
			min_circle = minf(min_circle, m[2])
			cover += m[3]
			if m[1] < CRAMPED_OPEN or m[2] < CRAMPED_CIRCLE:
				bad += 1
		var n := float(list.size())
		var mean_open := open / n
		var mean_circle := circle / n
		var flag := ""
		if mean_open < CRAMPED_OPEN or mean_circle < CRAMPED_CIRCLE:
			flag = "cramped"
		elif mean_open > EMPTY_OPEN and cover == 0:
			flag = "empty"
		var w: Array = weights.get(name, [0, Vector2i.ZERO])
		var size := "%dx%d" % [(list[0] as Array)[4].x, (list[0] as Array)[4].y]
		table.append(
			[
				name,
				size,
				int(w[0]),
				list.size(),
				area / n,
				mean_open,
				min_open,
				mean_circle,
				min_circle,
				float(cover) / n,
				bad,
				flag
			]
		)
	table.sort_custom(func(a: Array, b: Array) -> bool: return a[5] < b[5])
	var lines := PackedStringArray()
	lines.append(
		(
			"room density: %d seeds x %d floor numbers, step %.2f m, player radius %.2f m"
			% [SEEDS, FLOORS, STEP, PLAYER_RADIUS]
		)
	)
	(
		lines
		. append(
			(
				"thresholds (starting values): cramped = open < %.0f %% or circle < %.1f m; empty = open > %.0f %% and no cover"
				% [CRAMPED_OPEN, CRAMPED_CIRCLE, EMPTY_OPEN]
			)
		)
	)
	(
		lines
		. append(
			"floor range: all floors (the generator takes no floor number); weight = draw weight among its size"
		)
	)
	lines.append(
		(
			"%-12s %-4s %3s %5s %8s %7s %7s %8s %8s %6s %5s  %s"
			% [
				"template",
				"size",
				"wgt",
				"rooms",
				"area_m2",
				"open%",
				"minopen",
				"circle_m",
				"mincirc",
				"cover",
				"bad",
				"flag"
			]
		)
	)
	for r: Array in table:
		lines.append(
			(
				"%-12s %-4s %3d %5d %8.1f %7.1f %7.1f %8.2f %8.2f %6.1f %5d  %s"
				% [r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11]]
			)
		)
	lines.append("templates: %d" % table.size())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build"))
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	quit()


## [area, open %, largest circle, cover count] of one room.
func _measure(f: FloorLayout, room: int) -> Array:
	var r := f.rooms[room]
	var walls: Array[Obb] = []
	var cover := 0
	var near := r.grow(PLAYER_RADIUS + 12.0)
	for i in f.walls.size():
		var w := f.walls[i]
		if w.bounds().intersects(near):
			walls.append(w)
			if i >= f.slab_first and w.bounds().intersects(r):
				cover += 1
	var total := 0
	var open := 0
	var best := 0.0
	var y := r.position.y + STEP * 0.5
	while y < r.end.y:
		var x := r.position.x + STEP * 0.5
		while x < r.end.x:
			var p := Vector2(x, y)
			var d := 1000.0
			for w in walls:
				var l := p - w.center
				var qx := maxf(absf(l.dot(w.axis_u)) - w.half.x, 0.0)
				var qy := maxf(absf(l.dot(w.axis_v)) - w.half.y, 0.0)
				d = minf(d, sqrt(qx * qx + qy * qy))
				if d < PLAYER_RADIUS:
					break
			total += 1
			if d >= PLAYER_RADIUS:
				open += 1
				best = maxf(best, d)
			x += STEP
		y += STEP
	# Outside the room's own faces the walls bound d; a room edge is a wall face, so d is already clipped there.
	return [r.get_area(), 100.0 * open / maxf(1.0, total), best, cover]
