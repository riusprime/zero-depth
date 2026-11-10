class_name SurfaceSoak
extends RefCounted
## v0.11.1 Step 4: the seed loop test_ice_patches.gd (v0.7.5 NB1, Frozen Shore's ice) and test_starglow_patches.gd
## (v0.7.5 NB2, Starfall's pools) share: IcePatches lays a surface on many floors, each with a real boss's arena as
## the game builds a floor, and every rule a patch breaks is counted. Test-side only.


## A floor's layout as FloorScenario.build lays it (boss room, Overrun room, shop) and its walls with the gate:
## [layout, walls].
static func layout(seed_value: int, spec: BossArenaSpec) -> Array:
	var f := FloorGenerator.generate(seed_value)
	BossRoomBuilder.attach(f, spec)
	OverrunRooms.mark(f)
	ShopPlacement.pick(f)
	var walls: Array[Obb] = f.walls.duplicate()
	walls.append(FloorScenario.gate_collider(f))
	return [f, walls]


## Lays a `fresh` surface (a Callable returning a new IceField) on `seeds` floors (seed `base + s * 7919`, the bosses'
## arenas `specs` in turn) and checks each against `rules` (its clearance and sizes): {"total": patches,
## "floors_with": floors with at least one, "broken": rule -> first seed breaking it, "ms": time taken}.
static func soak(
	seeds: int, base: int, specs: Array[BossArenaSpec], fresh: Callable, rules: IceField
) -> Dictionary:
	var total := 0
	var floors_with := 0
	var broken := {}
	var t0 := Time.get_ticks_msec()
	for s in seeds:
		var seed_value := base + s * 7919
		var lw := layout(seed_value, specs[s % specs.size()])
		var field: IceField = fresh.call()
		IcePatches.lay(lw[0], lw[1], seed_value, field)
		total += field.rects.size()
		floors_with += 1 if not field.rects.is_empty() else 0
		for why in broken_rules(lw[0], lw[1], field.rects, rules):
			if not broken.has(why):
				broken[why] = "seed %d" % seed_value
	return {
		"total": total,
		"floors_with": floors_with,
		"broken": broken,
		"ms": Time.get_ticks_msec() - t0,
	}


## The rules one floor's patches break, as short strings (empty: none). Counted, not asserted one by one, so many
## floors stay quick.
static func broken_rules(
	f: FloorLayout, walls: Array[Obb], rects: Array[Rect2], rules: IceField
) -> PackedStringArray:
	var out := PackedStringArray()
	var c := rules.clearance_m - 0.001
	for r in rects:
		var room := f.room_of(r.get_center())
		if room < 0:
			out.append("outside every room")
			continue
		if room in [f.start_room, f.boss_room, f.portal_room, f.shop_room]:
			out.append("in the start, boss, portal or shop room")
		if not f.rooms[room].grow(-c).encloses(r):
			out.append("too close to its room's walls")
		var grown := r.grow(c)
		for i in f.door_centers.size():
			if grown.intersects(f.door_rect(i)):
				out.append("on a doorway")
		for o in walls:
			if grown.intersects(o.bounds()):
				out.append("on a wall or cover")
		for p in [f.start_pos, f.portal_pos]:
			if grown.has_point(p):
				out.append("on the start or the gate")
		for p in f.item_spots:
			if grown.has_point(p):
				out.append("on an item spot")
		if minf(r.size.x, r.size.y) < rules.size_min_dm / 10.0 - 0.001:
			out.append("too small")
		if maxf(r.size.x, r.size.y) > rules.size_max_dm / 10.0 + 0.001:
			out.append("too big")
	for i in rects.size():
		for j in range(i + 1, rects.size()):
			if rects[i].intersects(rects[j]):
				out.append("overlapping")
	return out
