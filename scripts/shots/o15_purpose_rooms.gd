extends SceneTree
## v0.11.0 O15 (G2 only, PLAN P1, Q26 (a)): mockups of large rooms with a purpose, for the owner to pick from before
## any generator change. Each purpose is an authored template (like the shops) with seeded variation, laid into a real
## 3 x 3 room of a run floor and drawn by the game's own WorldViewRoot (the biome's mood, look, kit, dresser) from the
## game's iso camera. Not the feature: the generator is untouched; this script rewrites one room of a built floor.
## Needs a renderer (not --headless):
##   godot --path . --position -10000,-10000 --resolution 1920x1080 -s scripts/shots/o15_purpose_rooms.gd -- biome=ruins
## Options after `--`: biome=<id> (default ruins), seed=<first run seed searched> (default 20261014).
## SHOT CHOICE (labelled): the first run seed from `seed` whose floor 1 has a 3 x 3 room that is no special room
## (start, portal, shop, curse, boss, arena, overrun); the same room for every biome and purpose.
## SHOT STAGING (labelled): the room's interior pieces are replaced by the template's; in the template shots the
## biome's cover pools are switched off so the template's named pieces are drawn as named (its decoration pools stay);
## the hero stands at the room's first doorway for scale. The world is never stepped (no enemies).
## How a template varies by seed: a mirror (either axis; the one that keeps the focal piece and most solids clear of
## the doorways wins, tried from the drawn one), optional groups, counts, small shifts and turns, the per-biome pieces.
## Solids in a doorway's box, outside the room or on an item spot are dropped.
## Writes build/shots/v0.11.0/o15/{today_<biome>,<purpose>_<biome>_s<n>}.png. Quits on every path.

const OUT := "res://build/shots/v0.11.0/o15/"
const SETTLE := 24
const SEARCH := 40
const SEEDS := [1, 2]
const DOOR_DEPTH := 3.4
const DOOR_SIDE := 1.0
const ITEM_CLEAR := 1.6
## The purposes each biome shows (two biomes per purpose).
const SHOWS := {
	&"ruins": [&"camp", &"hall"],
	&"frozen_shore": [&"camp"],
	&"starfall": [&"hall"],
	&"red_canyon": [&"quarry"],
	&"night_rocks": [&"quarry"],
}
## Per purpose and biome: token -> [piece, length (m), depth (m), height (m; 0 = the kit's own), solid]. A biome
## piece (KitModels role &"biome") always keeps the kit's own height, so tall pieces are cover pieces.
const PALETTES := {
	&"camp":
	{
		&"ruins":
		{
			&"fire": [&"fire_barrel", 1.0, 1.0, 1.0, true],
			&"stone": [&"boulder_small", 0.6, 0.5, 0.0, false],
			&"seat": [&"tire_stack", 1.0, 1.0, 0.55, true],
			&"shelter": [&"car_wreck", 5.0, 2.3, 1.5, true],
			&"lean": [&"barricade", 2.6, 0.6, 0.0, true],
			&"rack": [&"ladder_frame", 1.2, 0.5, 0.0, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"pile": [&"crate_stack", 1.4, 1.4, 1.3, true],
			&"grass": [&"grass_tuft", 0.6, 0.6, 0.0, false],
			&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
			&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
		},
		&"frozen_shore":
		{
			&"fire": [&"fire_barrel", 1.0, 1.0, 1.0, true],
			&"stone": [&"boulder_small", 0.6, 0.5, 0.0, false],
			&"seat": [&"crate_stack", 1.0, 1.0, 0.55, true],
			&"shelter": [&"boat_wreck", 4.6, 2.2, 0.0, true],
			&"lean": [&"fish_rack", 1.6, 0.7, 0.0, true],
			&"rack": [&"fish_rack", 1.6, 0.7, 0.0, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"pile": [&"crate_stack", 1.4, 1.4, 1.3, true],
			&"grass": [&"snow_drift", 0.9, 0.6, 0.0, false],
			&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
			&"rubble": [&"ice_shard", 0.5, 0.5, 0.0, false],
		},
	},
	&"hall":
	{
		&"ruins":
		{
			&"focal": [&"stone_arch", 3.0, 1.0, 0.0, true],
			&"tower": [&"wall_pillar", 1.6, 1.6, 3.4, true],
			&"flank": [&"building_corner", 2.6, 2.6, 0.0, true],
			&"column": [&"wall_pillar", 1.3, 1.3, 3.2, true],
			&"stump": [&"column_broken", 1.1, 1.1, 0.0, true],
			&"fallen": [&"slab_wide", 4.2, 1.2, 0.9, true],
			&"low_wall": [&"wall_broken", 3.6, 0.7, 1.1, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"grass": [&"grass_tuft", 0.6, 0.6, 0.0, false],
			&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
			&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
		},
		&"starfall":
		{
			&"focal": [&"ruined_observatory", 2.6, 2.6, 0.0, true],
			&"tower": [&"star_monolith", 1.4, 1.4, 0.0, true],
			&"flank": [&"rock_large", 2.6, 2.6, 2.6, true],
			&"column": [&"star_monolith", 1.2, 1.2, 0.0, true],
			&"stump": [&"rock_large", 1.2, 1.2, 0.9, true],
			&"fallen": [&"rock_large", 4.2, 1.2, 0.8, true],
			&"low_wall": [&"rock_large", 3.6, 0.9, 1.0, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"grass": [&"star_crystal", 0.5, 0.5, 0.0, false],
			&"debris": [&"meteorite", 0.6, 0.5, 0.0, false],
			&"rubble": [&"meteorite", 0.6, 0.5, 0.0, false],
		},
	},
	&"quarry":
	{
		&"red_canyon":
		{
			&"face": [&"rock_large", 3.6, 3.0, 3.2, true],
			&"face_small": [&"mesa_chunk", 2.2, 2.2, 0.0, true],
			&"block": [&"slab_concrete", 1.5, 1.5, 1.0, true],
			&"cart": [&"wagon_wreck", 2.4, 1.4, 0.0, true],
			&"scaffold": [&"ladder_frame", 1.2, 0.5, 0.0, true],
			&"marker": [&"cattle_skull_post", 0.4, 0.4, 0.0, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"grass": [&"dry_shrub", 0.5, 0.5, 0.0, false],
			&"debris": [&"debris_low", 1.0, 0.5, 0.0, false],
			&"rubble": [&"rubble_small", 0.6, 0.6, 0.0, false],
		},
		&"night_rocks":
		{
			&"face": [&"rock_large", 3.6, 3.0, 3.2, true],
			&"face_small": [&"rock_spire", 1.3, 1.3, 0.0, true],
			&"block": [&"slab_concrete", 1.5, 1.5, 1.0, true],
			&"cart": [&"wagon_wreck", 2.4, 1.4, 0.0, true],
			&"scaffold": [&"ladder_frame", 1.2, 0.5, 0.0, true],
			&"marker": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"post": [&"brazier_pole", 0.7, 0.7, 0.0, true],
			&"grass": [&"mushroom_cluster", 0.6, 0.6, 0.0, false],
			&"debris": [&"bone_pile", 0.8, 0.6, 0.0, false],
			&"rubble": [&"boulder_small", 0.5, 0.45, 0.0, false],
		},
	},
}

var _biome_id := &"ruins"
var _seed := 20261014
var _repo: ContentRepository
var _biome: BiomeDefinition
var _run_seed := -1
var _room := -1
var _targets: Array = []  # [stem, purpose (&"" = today's room), variation seed]
var _target := -1
var _view: WorldViewRoot
var _reader: WorldReader
var _shots: Array = []
var _step := -1
var _wait := 0
var _frame := 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("biome="):
			_biome_id = StringName(a.trim_prefix("biome="))
		elif a.begins_with("seed="):
			_seed = int(a.trim_prefix("seed="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_repo = ContentRepository.load_all()
	_biome = _repo.get_def(&"biomes", _biome_id)
	if _biome == null or not SHOWS.has(_biome_id):
		print("o15_purpose_rooms: no biome or no purpose for ", _biome_id)
		quit(1)
		return
	for s in SEARCH:
		var w := _world(_seed + s)
		var room := _big_room(w.floor_layout)
		if room >= 0:
			_run_seed = _seed + s
			_room = room
			break
	print(
		(
			"o15_purpose_rooms: renderer=%s device=%s window=%s biome=%s run_seed=%d room=%d"
			% [
				RenderingServer.get_current_rendering_method(),
				RenderingServer.get_video_adapter_name(),
				DisplayServer.window_get_size(),
				_biome_id,
				_run_seed,
				_room
			]
		)
	)
	if _room < 0:
		quit(1)
		return
	_targets.append(["today_%s" % _biome_id, &"", 0])
	for purpose: StringName in SHOWS[_biome_id]:
		for v: int in SEEDS:
			_targets.append(["%s_%s_s%d" % [purpose, _biome_id, v], purpose, v])


func _world(run_seed: int) -> World:
	var run := SaveLab.run_state(run_seed, 1, &"blade", 0, _repo)
	var w := SaveLab.build_floor(run, _biome_id, _repo)
	IcePatches.place(w, BiomeCompiler.compile_surface(_biome))  # as Main
	return w


## The first 3 x 3 room that is no special room, or -1.
static func _big_room(f: FloorLayout) -> int:
	var special := [
		f.start_room,
		f.portal_room,
		f.shop_room,
		f.curse_room,
		f.boss_room,
		f.boss_host_room,
		f.overrun_room
	]
	for room in f.room_count():
		if room in special or room in f.arena_rooms:
			continue
		if f.room_cells[room].size == Vector2i(3, 3):
			return room
	return -1


func _next_target() -> bool:
	if _view != null:
		_view.queue_free()
		_view = null
	_target += 1
	if _target >= _targets.size():
		return false
	var t: Array = _targets[_target]
	var w := _world(_run_seed)
	var f := w.floor_layout
	var look: BiomeLook = _biome.look
	var note := "today's interior"
	if t[1] != &"":
		note = _furnish(w, _room, t[1], int(t[2]))
		look = _template_look(_biome.look)
	var r := f.rooms[_room]
	var doors := f.door_approaches(_room, 1.6)
	if not doors.is_empty():  # SHOT STAGING (labelled): the hero at the first doorway, for scale
		w.actors.pos_x[0] = doors[0].x
		w.actors.pos_y[0] = doors[0].y
	_reader = WorldReader.new(w)
	_view = WorldViewRoot.new()
	_view.stage.mood = _biome.mood
	_view.stage.prop_style = _biome.id
	_view.stage.look = look
	if _biome.look != null:
		_view.actors.enemy_tint = _biome.look.enemy_tint
	_view.rig.dead_zone_m = 1000.0
	root.add_child(_view)
	_view.setup(_reader, _biome.palette, 60.0)
	print(
		(
			"o15_purpose_rooms: %s run_seed=%d floor=1 room=%d cells=%s size=%.1fx%.1f m doors=%d %s"
			% [
				t[0],
				_run_seed,
				_room,
				f.room_cells[_room].size,
				r.size.x,
				r.size.y,
				doors.size(),
				note
			]
		)
	)
	_shots = [[t[0], r.get_center(), maxf(r.size.x, r.size.y) * 0.72]]
	_step = -1
	return true


## SHOT STAGING (labelled): the biome's look with its cover pools off (decoration, wall props and the void stay), so
## a template's named pieces are drawn as named.
static func _template_look(base: BiomeLook) -> BiomeLook:
	if base == null:
		return null
	var look: BiomeLook = base.duplicate()
	var pools := {}
	for role: Variant in base.pools:
		if not String(role).begins_with("cover_") and String(role) != "landmark":
			pools[role] = base.pools[role]
	look.pools = pools
	look.square_cover = {}
	return look


## Replaces room `room`'s interior pieces with purpose `purpose`'s template drawn with variation seed `v`.
## Returns a log note.
func _furnish(w: World, room: int, purpose: StringName, v: int) -> String:
	var f := w.floor_layout
	var r := f.rooms[room]
	var gone := {}
	var kept: Array[Obb] = []
	for i in f.walls.size():
		var o := f.walls[i]
		if i >= f.slab_first and r.grow(0.01).encloses(o.bounds()):
			gone[FloorLayout.piece_key(o)] = true
			f.piece_tags.erase(FloorLayout.piece_key(o))
			f.piece_heights.erase(FloorLayout.piece_key(o))
			continue
		kept.append(o)
	f.walls = kept
	var props: Array = []
	for p: Array in f.layout_props:
		if not r.has_point(p[1]):
			props.append(p)
	f.layout_props = props
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([purpose, v, room])
	var portrait := r.size.y > r.size.x
	var half := Vector2(maxf(r.size.x, r.size.y), minf(r.size.x, r.size.y)) * 0.5
	var parts: Array = call("_" + String(purpose), rng, half)
	var pal: Dictionary = PALETTES[purpose][_biome_id]
	var boxes := _door_boxes(f, room)
	var start := rng.randi_range(0, 3)
	var best: Array = []
	var best_cost := -1
	var best_m := start
	for k in 4:
		var m := (start + k) % 4
		var placed := _place(parts, pal, r, portrait, m, boxes, f, room)
		var cost: int = placed[1]
		if best_cost < 0 or cost < best_cost:
			best = placed[0]
			best_cost = cost
			best_m = m
	var walls: Array[Obb] = []
	for o in w.walls:
		if not gone.has(FloorLayout.piece_key(o)):
			walls.append(o)
	var solids := 0
	for p: Array in best:
		if p[4]:
			var o: Obb = Obb.make(p[1], p[3] * 0.5, p[2])
			f.walls.append(o)
			walls.append(o)
			f.piece_tags[FloorLayout.piece_key(o)] = p[0]
			f.piece_heights[FloorLayout.piece_key(o)] = p[5]
			solids += 1
		else:
			f.layout_props.append([p[0], p[1], p[2], p[3], p[5], ""])
	w.set_walls(walls)
	f.room_layout[room] = StringName("o15_" + String(purpose))
	return (
		"purpose=%s v=%d mirror=%d solids=%d drawn_only=%d dropped_cost=%d"
		% [purpose, v, best_m, solids, best.size() - solids, best_cost]
	)


## Each doorway's box into the room (its width plus DOOR_SIDE each side, DOOR_DEPTH deep), as Rect2s.
static func _door_boxes(f: FloorLayout, room: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var r := f.rooms[room]
	for d in f.door_rooms.size():
		if f.door_rooms[d].x != room and f.door_rooms[d].y != room:
			continue
		var c := f.door_centers[d]
		var wd := f.door_widths[d] * 0.5 + DOOR_SIDE
		var box := Rect2(c - Vector2(wd, wd), Vector2(wd, wd) * 2.0)
		if absf(c.x - r.position.x) < 1.5 or absf(c.x - r.end.x) < 1.5:
			box = Rect2(c - Vector2(DOOR_DEPTH, wd), Vector2(DOOR_DEPTH, wd) * 2.0)
		else:
			box = Rect2(c - Vector2(wd, DOOR_DEPTH), Vector2(wd, DOOR_DEPTH) * 2.0)
		out.append(box)
	return out


## The template's parts in room coordinates for mirror `m` (bit 0 flips the long axis, bit 1 the short): [[piece,
## centre, angle (1/4096), size, solid, height]], and the cost of the drops (a focal piece 1000, a solid 1).
func _place(
	parts: Array,
	pal: Dictionary,
	r: Rect2,
	portrait: bool,
	m: int,
	boxes: Array[Rect2],
	f: FloorLayout,
	room: int
) -> Array:
	var out: Array = []
	var cost := 0
	var c := r.get_center()
	var inner := r.grow(-0.05)
	var items := PackedVector2Array()
	for i in f.item_spots.size():
		if f.item_rooms[i] == room:
			items.append(f.item_spots[i])
	for part: Array in parts:
		var e: Array = pal[part[0]]
		var lp: Vector2 = part[1]
		var deg: float = part[2]
		if m & 1:
			lp.x = -lp.x
			deg = 180.0 - deg
		if m & 2:
			lp.y = -lp.y
			deg = -deg
		if portrait:
			lp = Vector2(lp.y, lp.x)
			deg = 90.0 - deg
		var at := c + lp
		var angle := posmod(roundi(deg / 360.0 * 4096.0), 4096)
		var size := Vector2(e[1], e[2])
		var solid: bool = e[4]
		if solid:
			var b := Obb.make(at, size * 0.5, angle).bounds()
			var bad := not inner.encloses(b)
			for box in boxes:
				bad = bad or box.intersects(b)
			for q in items:
				bad = bad or b.grow(ITEM_CLEAR).has_point(q)
			if bad:
				cost += 1000 if part[3] else 1
				continue
		var hs: float = part[4] if part.size() > 4 else 1.0
		out.append([e[0], at, angle, size, solid, float(e[3]) * hs])
	return [out, cost]


## --- The templates: [token, local centre (m; long axis x), yaw (deg), focal, height scale (optional)] in a frame of
## half-size `h` (long side first). Authored positions; the seed picks the optional parts, the counts, the shifts.


## A camp: a fire pit ringed by stones, seats and drying racks (the focal piece); five shelters on a ring round it, each
## turned to face the fire with its lean-to, its crates and maybe a light; two supply piles in the corners; worn paths
## of stones from the fire out to each shelter.
func _camp(rng: RandomNumberGenerator, h: Vector2) -> Array:
	var out: Array = [[&"fire", Vector2.ZERO, 0.0, true]]
	for k in 9:
		var a := deg_to_rad(k * 40.0 + rng.randf_range(-8.0, 8.0))
		out.append([&"stone", Vector2(cos(a), sin(a)) * 1.2, rad_to_deg(a), false])
	var seats := rng.randi_range(4, 5)
	var a0 := rng.randf_range(0.0, 90.0)
	for k in seats:
		var a := deg_to_rad(a0 + k * 360.0 / seats + rng.randf_range(-10.0, 10.0))
		out.append([&"seat", Vector2(cos(a), sin(a)) * 3.0, rad_to_deg(a), false])
	for k in 2:
		var ar := deg_to_rad(a0 + 180.0 / seats + k * 180.0)
		out.append([&"rack", Vector2(cos(ar), sin(ar)) * 4.8, rad_to_deg(ar) + 90.0, false])
	var skip := rng.randi_range(0, 5)
	for k in 6:
		if k == skip:
			continue
		var a := deg_to_rad(30.0 + k * 60.0 + rng.randf_range(-8.0, 8.0))
		var p := Vector2(cos(a) * h.x * 0.6, sin(a) * h.y * 0.6)
		var d := -p.normalized()
		var t := Vector2(-d.y, d.x)
		var yaw := rad_to_deg(t.angle()) + rng.randf_range(-10.0, 10.0)
		out.append([&"shelter", p, yaw, false])
		var flip := 1.0 if rng.randf() < 0.5 else -1.0
		out.append(
			[&"lean", p + t * flip * 3.9 + d * 0.2, yaw + flip * rng.randf_range(15.0, 35.0), false]
		)
		out.append([&"pile", p - t * flip * 3.4 - d * 0.2, rng.randf_range(-10, 10), false, 1.0])
		out.append([&"pile", p - t * flip * 3.4 - d * 1.7, rng.randf_range(-10, 10), false, 1.7])
		if rng.randf() < 0.6:
			out.append([&"post", p + d * 2.2 - t * flip * 1.5, 0.0, false])
		for s in 3:
			out.append(
				[
					&"debris",
					p - d * 1.9 + t * rng.randf_range(-2.5, 2.5),
					rng.randf_range(0, 360),
					false
				]
			)
		var steps := int((p.length() - 7.0) / 1.6)
		for s in steps:
			if rng.randf() < 0.7:
				var q := -d * (5.6 + s * 1.6) + t * rng.randf_range(-0.4, 0.4)
				out.append([&"rubble", q, rng.randf_range(0, 360), false])
	for corner: Vector2 in (
		[Vector2(-1, 1), Vector2(1, -1)] if rng.randf() < 0.5 else [Vector2(1, 1), Vector2(-1, -1)]
	):
		var c := Vector2(corner.x * (h.x - 2.4), corner.y * (h.y - 2.4))
		for q: Vector2 in [
			Vector2(0, 0), Vector2(-1.45, 0), Vector2(0, -1.45), Vector2(-1.45, -1.45)
		]:
			if rng.randf() < 0.85:
				var at := c + Vector2(q.x * corner.x, q.y * corner.y)
				out.append([&"pile", at, rng.randf_range(-6, 6), false, rng.randf_range(0.8, 1.9)])
	for s in 14:
		var a := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(0.3, 0.95)
		out.append(
			[&"grass", Vector2(cos(a) * rad * h.x, sin(a) * rad * h.y), rad_to_deg(a), false]
		)
	return out


## A collapsed hall: two colonnades down the long axis (each column standing, broken to a stump, or fallen across the
## aisle), broken walls in the side aisles; at one end the focal ruin (an arch or the observatory) between two towers,
## two masses behind them and two braziers before it; one great fallen piece across the nave; rubble spilt from every
## fall.
func _hall(rng: RandomNumberGenerator, h: Vector2) -> Array:
	var out: Array = []
	var fx := h.x - 3.4
	out.append([&"focal", Vector2(fx, 0.0), 90.0, true])
	for side: float in [-1.0, 1.0]:
		out.append([&"tower", Vector2(fx, side * 4.4), rng.randf_range(-5, 5), false])
		out.append([&"flank", Vector2(fx + 0.6, side * 8.6), rng.randf_range(-8, 8), false])
		out.append([&"post", Vector2(fx - 3.4, side * 2.6), 0.0, false])
	for s in 8:
		out.append(
			[
				&"rubble",
				Vector2(fx - rng.randf_range(1.0, 2.6), rng.randf_range(-3.8, 3.8)),
				0.0,
				false
			]
		)
	var line := h.y * 0.38
	var u := -h.x + 3.4
	while u < fx - 4.8:
		for side: float in [-1.0, 1.0]:
			var r := rng.randf()
			var at := Vector2(u, side * line)
			if r < 0.62:
				out.append(
					[&"column", at, rng.randf_range(-6, 6), false, rng.randf_range(0.8, 1.15)]
				)
			elif r < 0.82:
				out.append([&"stump", at, rng.randf_range(-20, 20), false])
				out.append([&"rubble", at + Vector2(0.9, -side * 0.9), 0.0, false])
			else:
				out.append([&"stump", at, rng.randf_range(-20, 20), false])
				var lie := at + Vector2(rng.randf_range(-0.6, 0.6), -side * 2.9)
				out.append([&"fallen", lie, 90.0 + rng.randf_range(-25, 25), false])
				for s in 3:
					var q := lie + Vector2(rng.randf_range(-1.6, 1.6), -side * (2.4 + s * 0.8))
					out.append([&"rubble", q, rng.randf_range(0, 360), false])
		u += 3.7
	for side: float in [-1.0, 1.0]:
		var wu := -h.x + 4.5
		while wu < fx - 6.0:
			if rng.randf() < 0.55:
				var wv := side * (h.y - rng.randf_range(2.6, 3.4))
				out.append([&"low_wall", Vector2(wu, wv), rng.randf_range(-10, 10), false])
				out.append(
					[&"debris", Vector2(wu + 2.4, wv + side * 0.6), rng.randf_range(0, 360), false]
				)
			wu += 6.5
	var nave := rng.randi_range(1, 2)
	for k in nave:
		var cu := (-0.5 + k * 0.45 + rng.randf_range(-0.08, 0.08)) * h.x
		var cv := rng.randf_range(-2.0, 2.0)
		out.append([&"fallen", Vector2(cu, cv), rng.randf_range(-30, 30), false])
		for s in 4:
			out.append(
				[
					&"rubble",
					Vector2(cu + rng.randf_range(-2.4, 2.4), cv + rng.randf_range(-1.8, 1.8)),
					0.0,
					false
				]
			)
	for s in 16:
		var gu := rng.randf_range(-h.x + 1.5, fx - 3.0)
		var gv := rng.randf_range(-h.y + 1.0, h.y - 1.0)
		out.append(
			[
				&"grass" if rng.randf() < 0.6 else &"debris",
				Vector2(gu, gv),
				rng.randf_range(0, 360),
				false
			]
		)
	return out


## A quarry: the cut rock face against a long wall (the focal piece, its middle mass the tallest), scaffolds and lights
## at its foot, the cart where the stone is loaded, a yard of cut-block stacks (stepped heights) with lanes between
## them, and a haul road edged with rubble from the cart to the far wall, two markers at its end. The face's three
## middle masses count as focal, so the mirror puts the face on the long wall where a doorway breaks none of them.
func _quarry(rng: RandomNumberGenerator, h: Vector2) -> Array:
	var out: Array = []
	var face_y := h.y - 2.0
	var n := 7
	var span := h.x * 0.62
	for k in n:
		var x := -span + k * span * 2.0 / (n - 1) + rng.randf_range(-0.4, 0.4)
		var big := k % 2 == 1 or rng.randf() < 0.35
		var mid := k == n / 2
		var tok := &"face" if big or mid else &"face_small"
		var dy := 0.0 if tok == &"face" else -0.6
		var hs := 1.35 if mid else rng.randf_range(0.75, 1.1)
		out.append(
			[tok, Vector2(x, face_y + dy), rng.randf_range(-10, 10), absi(k - n / 2) <= 1, hs]
		)
	for s in 16:
		out.append(
			[
				&"rubble",
				Vector2(rng.randf_range(-span, span), face_y - rng.randf_range(2.2, 3.6)),
				0.0,
				false
			]
		)
	var cart_side := 1.0 if rng.randf() < 0.5 else -1.0
	var cart := Vector2(cart_side * rng.randf_range(3.0, 5.0), face_y - 5.6)
	out.append([&"cart", cart, rng.randf_range(-15, 15), false])
	out.append([&"block", cart + Vector2(cart_side * 2.3, 0.4), rng.randf_range(-8, 8), false, 0.8])
	for k in rng.randi_range(2, 3):
		var sx := (-0.45 + k * 0.45) * span + rng.randf_range(-0.8, 0.8)
		out.append([&"scaffold", Vector2(sx, face_y - 2.4), 0.0, false])
	for side: float in [-1.0, 1.0]:
		out.append([&"post", Vector2(side * (span + 2.6), face_y - 1.2), 0.0, false])
	var road := cart.x * 0.5
	var y := cart.y - 2.6
	while y > -h.y + 2.0:
		for edge: float in [-2.3, 2.3]:
			if rng.randf() < 0.75:
				out.append(
					[&"rubble", Vector2(road + edge + rng.randf_range(-0.3, 0.3), y), 0.0, false]
				)
		y -= 1.4
	var yard := [
		Vector2(-0.72, -0.05),
		Vector2(-0.6, -0.62),
		Vector2(-0.3, -0.25),
		Vector2(0.32, -0.25),
		Vector2(0.6, -0.62),
		Vector2(0.72, -0.05),
	]
	var skip := rng.randi_range(0, 7)  # 6, 7: all six stacks
	for k in yard.size():
		if k == skip:
			continue
		var p: Vector2 = yard[k] * h
		if absf(p.x - road) < 5.0:
			p.x = road + signf(p.x - road + 0.01) * 5.0
		var cells := [
			Vector2(-0.78, -0.78), Vector2(0.78, -0.78), Vector2(-0.78, 0.78), Vector2(0.78, 0.78)
		]
		for c in rng.randi_range(3, 4):
			var hs: float = [1.0, 1.8, 1.0, 2.5][c] * rng.randf_range(0.9, 1.1)
			out.append([&"block", p + cells[c], rng.randf_range(-4, 4), false, hs])
		out.append(
			[
				&"debris",
				p + Vector2(2.3, rng.randf_range(-1.0, 1.0)),
				rng.randf_range(0, 360),
				false
			]
		)
	out.append([&"marker", Vector2(road - 3.0, -h.y + 2.2), 0.0, false])
	out.append([&"marker", Vector2(road + 3.0, -h.y + 2.2), 0.0, false])
	for s in 12:
		var gu := rng.randf_range(-h.x + 1.5, h.x - 1.5)
		var gv := rng.randf_range(-h.y + 1.0, h.y * 0.3)
		out.append([&"grass", Vector2(gu, gv), rng.randf_range(0, 360), false])
	return out


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame > 6000:
		print("o15_purpose_rooms: gave up")
		quit(1)
		return false
	if _target < 0 or _step >= _shots.size():
		if not _next_target():
			quit(0)
			return false
	if _wait > 0:
		_wait -= 1
		if _wait == 0:
			var shot: Array = _shots[_step]
			var path: String = OUT + "%s.png" % shot[0]
			var img := root.get_texture().get_image()
			if img == null or img.save_png(path) != OK:
				push_error("o15_purpose_rooms: could not save %s" % path)
				quit(1)
				return false
			print("o15_purpose_rooms: ", path)
		return false
	_step += 1
	if _step >= _shots.size():
		return false
	var s: Array = _shots[_step]
	_view.rig.view_size = s[2]
	_view.rig.snap_to(SimPlane.to_3d(s[1]))
	_wait = SETTLE
	return false
