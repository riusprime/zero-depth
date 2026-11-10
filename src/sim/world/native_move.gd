class_name NativeMove
extends RefCounted
## The move phase's collision passes run by the native side (World.native, NativeWorld.MOVE). The same rules as
## World._resolve_bodies: SimTick.COLLIDE_ITERS passes, each pushing the bodies out of the walls and the standing
## solids, then parting overlapping bodies half to each; a boss in the air or underground and a waiting Rock Lurker
## pass through both, and a boss on the ground shoves the other body the whole way, stopped at the first wall. The
## native side keeps its own wall grid (NativeWorld.sync_walls) and its own body grid, so it is deterministic against
## itself but not bit for bit the GDScript passes (the pairs are visited in another order, in single precision).
## The kernel reads pos_x, pos_y and radius from the store by name and sets pos_x and pos_y as new arrays. The body
## grid the later phases read (World.actors_near, the projectile hits) is rebuilt here once, from the final positions.


static func resolve(w: World, through: PackedInt32Array, heavy: PackedInt32Array) -> void:
	var pp := w.phase_probe
	if pp != null:
		pp.end(&"move.walls")
		pp.begin(&"move.native")
	NativeWorld.sync_walls(w)
	var ghost := w.dash_ticks_left > 0 and ModifierRuntime.intangible(w)  # Phase Dash
	var a := w.actors
	w.native.resolve_actors(a, through, heavy, ghost, SimTick.COLLIDE_ITERS)
	if pp != null:
		pp.end(&"move.native")
		pp.begin(&"move.grid")
	# The later phases (projectile hits, area attacks) query the body grid as the passes leave it.
	w._actor_grid.build_circles(a.pos_x, a.pos_y, a.radius)
	if pp != null:
		pp.end(&"move.grid")
		pp.begin(&"move.walls")
