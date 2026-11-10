class_name NativeMove
extends RefCounted
## The move phase's collision passes run by a native mover (World.native_mover, the ZdMover class of the game's
## GDExtension, handed in by the app layer through World.mover_factory). The same rules as World._resolve_bodies:
## SimTick.COLLIDE_ITERS passes, each pushing the bodies out of the walls and the standing solids, then parting
## overlapping bodies half to each; a boss in the air or underground and a waiting Rock Lurker pass through both, and
## a boss on the ground shoves the other body the whole way, stopped at the first wall. The native side keeps its own
## wall grid (sent again when World._wall_rev changes) and its own body grid, so it is deterministic against itself
## but not bit for bit the GDScript passes (the pairs are visited in another order, in single precision).
## The columns cross as packed arrays: positions and radii in, positions out. The body grid the later phases read
## (World.actors_near, the projectile hits) is rebuilt here once, from the final positions.


static func resolve(w: World, through: PackedInt32Array, heavy: PackedInt32Array) -> void:
	var m: Object = w.native_mover
	var pp := w.phase_probe
	if pp != null:
		pp.end(&"move.walls")
		pp.begin(&"move.native")
	if int(m.get_meta(&"wall_rev", -1)) != w._wall_rev:
		m.set_walls(obb_floats(w.walls))
		m.set_meta(&"wall_rev", w._wall_rev)
	if not w.solids.is_empty():
		m.set_solids(_placed_solids(w.solids))
	elif m.get_meta(&"has_solids", false):
		m.set_solids(PackedFloat32Array())
	m.set_meta(&"has_solids", not w.solids.is_empty())
	var ghost := w.dash_ticks_left > 0 and ModifierRuntime.intangible(w)  # Phase Dash
	var a := w.actors
	m.resolve(a.pos_x, a.pos_y, a.radius, through, heavy, ghost, SimTick.COLLIDE_ITERS)
	a.pos_x = m.get_x()
	a.pos_y = m.get_y()
	if pp != null:
		pp.end(&"move.native")
		pp.begin(&"move.grid")
	# The later phases (projectile hits, area attacks) query the body grid as the passes leave it.
	w._actor_grid.build_circles(a.pos_x, a.pos_y, a.radius)
	if pp != null:
		pp.end(&"move.grid")
		pp.begin(&"move.walls")


## Oriented boxes as the native side reads them: 8 floats each (centre, axis u, axis v, half-extents).
static func obb_floats(list: Array[Obb]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(list.size() * 8)
	for k in list.size():
		var o := list[k]
		var j := k * 8
		out[j] = o.center.x
		out[j + 1] = o.center.y
		out[j + 2] = o.axis_u.x
		out[j + 3] = o.axis_u.y
		out[j + 4] = o.axis_v.x
		out[j + 5] = o.axis_v.y
		out[j + 6] = o.half.x
		out[j + 7] = o.half.y
	return out


## The solids that stand as walls now (Solids.placed).
static func _placed_solids(s: Solids) -> PackedFloat32Array:
	var list: Array[Obb] = []
	for i in s.size():
		if s.placed[i] == 1:
			list.append(s.obb(i))
	return obb_floats(list)
