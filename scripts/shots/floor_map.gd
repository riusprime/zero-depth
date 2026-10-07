extends SceneTree
## A top-down PNG of generated floors (v0.2.0 B, v0.3.0 A), to eyeball FloorGenerator. Works headless.
##   godot --headless --path . -s scripts/shots/floor_map.gd [-- <seed> <seed> ...]
## Writes build/floors/floor_layouts.png (floors side by side, in the order given) and prints a line per floor.
## Key: the floor's footprint in grey, room floors tinted by interior template (TEMPLATE_TINTS, printed as a
## legend), walls at their real thickness (dark), brown interior pieces, green
## start, yellow items, red spawn points, blue doorway centres in their passages, magenta gate with its clear front
## square outlined, and a 5 m scale bar (the blink range) under each floor.

const PX := 8  # pixels per metre
const GAP := 16
const OUT := "res://build/floors/floor_layouts.png"
const C_BG := Color(0.12, 0.12, 0.14)
const C_FLOOR := Color(0.78, 0.77, 0.74)
const C_WALL := Color(0.18, 0.18, 0.2)
const C_GROUND := Color(0.3, 0.3, 0.32)
const C_SLAB := Color(0.45, 0.3, 0.2)
const C_DOOR := Color(0.25, 0.5, 0.95)
const C_START := Color(0.1, 0.7, 0.2)
const C_ITEM := Color(0.95, 0.8, 0.1)
const C_SPAWN := Color(0.85, 0.15, 0.15)
const C_GATE := Color(0.85, 0.1, 0.85)
## Floor tint per template, in FloorLayout.Template order: open, scatter, pillars, centre, cross, lines, bunkers,
## colonnade, diagonals.
const TEMPLATE_TINTS: Array[Color] = [
	Color(0.85, 0.85, 0.82),
	Color(0.78, 0.74, 0.66),
	Color(0.66, 0.74, 0.82),
	Color(0.80, 0.68, 0.76),
	Color(0.70, 0.80, 0.68),
	Color(0.84, 0.80, 0.58),
	Color(0.62, 0.78, 0.78),
	Color(0.88, 0.70, 0.60),
	Color(0.72, 0.68, 0.86),
]
const TINT_NAMES := [
	"light grey", "sand", "blue", "pink", "green", "yellow", "teal", "salmon", "lavender"
]


func _initialize() -> void:
	var seeds := PackedInt32Array()
	for a in OS.get_cmdline_user_args():
		seeds.append(int(a))
	if seeds.is_empty():
		seeds = PackedInt32Array([1, 2, 3])
	var floors: Array[FloorLayout] = []
	for s in seeds:
		var t0 := Time.get_ticks_usec()
		var f := FloorGenerator.generate(s)
		var us := Time.get_ticks_usec() - t0
		floors.append(f)
		var spawns := 0
		for sp in f.spawn_points:
			spawns += sp.size()
		var names := PackedStringArray()
		var shapes := PackedStringArray()
		for room in f.room_count():
			names.append(FloorLayout.TEMPLATE_NAMES[f.room_template[room]])
			shapes.append("%dx%d" % [f.room_cells[room].size.x, f.room_cells[room].size.y])
		print(
			(
				(
					"seed %d: cell %.2f x %.2f m, %d rooms, %d doorways, %d walls, %d interior pieces, %.1f x %.1f m,"
					+ " portal room %d (%d hops), %d item spots, %d spawn points, generated in %.1f ms"
				)
				% [
					s,
					f.cell_size.x,
					f.cell_size.y,
					f.room_count(),
					f.door_rooms.size(),
					f.slab_first,
					f.walls.size() - f.slab_first,
					f.bounds.size.x,
					f.bounds.size.y,
					f.portal_room,
					f.hops[f.portal_room],
					f.item_spots.size(),
					spawns,
					us / 1000.0
				]
			)
		)
		print("  rooms (cells): %s" % ", ".join(shapes))
		print("  templates: %s" % ", ".join(names))
		var doors := PackedStringArray()
		for i in f.door_rooms.size():
			doors.append("%.2f x %.2f" % [f.door_widths[i], f.door_depths[i]])
		print("  doorways (width x wall thickness, m): %s" % ", ".join(doors))
	var legend := PackedStringArray()
	for t in FloorLayout.TEMPLATE_COUNT:
		legend.append("%s = %s" % [FloorLayout.TEMPLATE_NAMES[t], TINT_NAMES[t]])
	print("floor tints: %s" % ", ".join(legend))
	var w := 0
	var h := 0
	for f in floors:
		w = maxi(w, int(f.bounds.size.x * PX))
		h = maxi(h, int(f.bounds.size.y * PX))
	var img := Image.create(
		w * floors.size() + GAP * (floors.size() + 1), h + GAP * 3, false, Image.FORMAT_RGB8
	)
	img.fill(C_BG)
	for i in floors.size():
		var at := Vector2i(GAP + i * (w + GAP), GAP)
		_draw_floor(img, floors[i], at)
		for x in 5 * PX:
			for y in 4:
				img.set_pixel(at.x + x, h + GAP + GAP / 2 + y, C_FLOOR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/floors"))
	var err := img.save_png(OUT)
	print("wrote %s (%dx%d): %s" % [OUT, img.get_width(), img.get_height(), error_string(err)])
	quit(0 if err == OK else 1)


func _draw_floor(img: Image, f: FloorLayout, at: Vector2i) -> void:
	for g in f.ground:
		_fill_rect(img, f, at, g, C_GROUND)
	for room in f.room_count():
		_fill_rect(img, f, at, f.rooms[room], TEMPLATE_TINTS[f.room_template[room]])
	for i in f.door_centers.size():
		_fill_rect(img, f, at, f.door_rect(i), C_FLOOR)
	for i in f.walls.size():
		_fill_obb(img, f, at, f.walls[i], C_SLAB if i >= f.slab_first else C_WALL)
	for d in f.door_centers:
		_dot(img, f, at, d, 0.3, C_DOOR)
	var front := f.portal_front()
	_outline(img, f, at, front, C_GATE)
	var n := f.portal_facing()
	var gate := Obb.make(
		f.portal_pos, Vector2(FloorLayout.GATE_HALF_DEPTH, FloorLayout.GATE_WIDTH * 0.5), 0
	)
	if n.y != 0.0:
		gate = Obb.make(
			f.portal_pos, Vector2(FloorLayout.GATE_WIDTH * 0.5, FloorLayout.GATE_HALF_DEPTH), 0
		)
	_fill_obb(img, f, at, gate, C_GATE)
	_dot(img, f, at, f.portal_pos + n * 0.8, 0.2, C_GATE)
	_dot(img, f, at, f.start_pos, 0.6, C_START)
	for q in f.item_spots:
		_dot(img, f, at, q, 0.45, C_ITEM)
	for sp in f.spawn_points:
		for q in sp:
			_dot(img, f, at, q, 0.2, C_SPAWN)


func _px(f: FloorLayout, at: Vector2i, p: Vector2) -> Vector2i:
	return (
		at + Vector2i(int((p.x - f.bounds.position.x) * PX), int((p.y - f.bounds.position.y) * PX))
	)


func _world(f: FloorLayout, at: Vector2i, x: int, y: int) -> Vector2:
	return f.bounds.position + (Vector2(x - at.x, y - at.y) + Vector2(0.5, 0.5)) / PX


func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


func _fill_rect(img: Image, f: FloorLayout, at: Vector2i, r: Rect2, c: Color) -> void:
	var a := _px(f, at, r.position)
	var b := _px(f, at, r.end)
	for y in range(a.y, b.y):
		for x in range(a.x, b.x):
			_put(img, x, y, c)


func _outline(img: Image, f: FloorLayout, at: Vector2i, r: Rect2, c: Color) -> void:
	var a := _px(f, at, r.position)
	var b := _px(f, at, r.end)
	for x in range(a.x, b.x + 1):
		_put(img, x, a.y, c)
		_put(img, x, b.y, c)
	for y in range(a.y, b.y + 1):
		_put(img, a.x, y, c)
		_put(img, b.x, y, c)


func _fill_obb(img: Image, f: FloorLayout, at: Vector2i, o: Obb, c: Color) -> void:
	var r := o.bounds()
	var a := _px(f, at, r.position)
	var b := _px(f, at, r.end)
	for y in range(a.y - 1, b.y + 2):
		for x in range(a.x - 1, b.x + 2):
			var d := _world(f, at, x, y) - o.center
			if absf(d.dot(o.axis_u)) <= o.half.x and absf(d.dot(o.axis_v)) <= o.half.y:
				_put(img, x, y, c)


func _dot(img: Image, f: FloorLayout, at: Vector2i, p: Vector2, radius: float, c: Color) -> void:
	var a := _px(f, at, p - Vector2(radius, radius))
	var b := _px(f, at, p + Vector2(radius, radius))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			if _world(f, at, x, y).distance_to(p) <= radius:
				_put(img, x, y, c)
