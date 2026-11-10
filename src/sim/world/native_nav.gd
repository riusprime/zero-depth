class_name NativeNav
extends RefCounted
## The flow field's flood run by the native side (World.native, NativeWorld.NAV): NavField.flood's bucketed octile
## Dijkstra, whole in one call, giving the same distances cell for cell (integer steps, the same step and bucket
## order). With the kernel on, the world's periodic flood is that whole flood on its PERIOD tick instead of a build
## sliced over SLICES ticks, so the field the enemies follow is never older than its flood tick. NavField.dist stays
## the truth (a GDScript array, snapshotted); the native side keeps a cache of the field it floods last: its grid,
## extra cells and distances, sent again whenever the world floods another field or the field's grid or distances
## changed in GDScript (NavField.grid_rev, dist_rev).


## The native side's cache made current for `f`: the whole grid when it holds another field or this one was rebuilt
## (or its extra cells changed), else the distances alone when GDScript wrote them since.
static func sync(m: Object, f: NavField) -> void:
	var same := m.has_meta(&"nav_for") and is_same(m.get_meta(&"nav_for"), f)
	if same and int(m.get_meta(&"nav_grid", -1)) == f.grid_rev:
		if int(m.get_meta(&"nav_dist", -1)) != f.dist_rev:
			m.set_nav_dist(f.dist)
			m.set_meta(&"nav_dist", f.dist_rev)
		return
	m.set_nav_grid(f.origin, f.size, NavField.CELL, f.blocked, f._adj_start, f._adj, f._adj_w)
	m.set_nav_extra(f.extra)
	m.set_nav_dist(f.dist)
	m.set_meta(&"nav_for", f)
	m.set_meta(&"nav_grid", f.grid_rev)
	m.set_meta(&"nav_dist", f.dist_rev)


## The fill of NavField.flood from these seeds (NavField._seeds), bound and targets, on the native side's cache
## (sync first). Returns [work, stopped (1 when it stopped at its targets with cells still queued)]; the distances
## are the native side's nav_dist().
static func fill(
	m: Object, seeds: PackedInt32Array, max_steps: int, targets: PackedInt32Array
) -> PackedInt32Array:
	var r: int = m.nav_flood(seeds, max_steps, targets)
	if r < 0:
		return PackedInt32Array([-1 - r, 1])
	return PackedInt32Array([r, 0])
