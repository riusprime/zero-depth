class_name BossGears
extends RefCounted
## The Clockwork Judge's stopped gears: with a Time Wave, walls across the straight lines from the hero to the hour
## orbs, so the way to an orb goes round (BossFightStore.gear_*; BossTimeTable.gear_*).
## - Each is a wall while it stands (World.add_barrier: bodies, both sides' shots, sight; the flow field goes round
##   it, BossSignatures.set_nav_extra), long across its line and thin along it.
## - Where: gear g crosses the line to orb g (the fourth, the first orb's line again), half-way along it or, when it
##   does not fit there, at the next spot of SPOTS (SPOTS_2 for a line's second gear); one that fits nowhere is left
##   out.
## - Fair (fits): it keeps the hero's width plus PASS_SLACK_M from every wall and every other gear, so each is an
##   island in the free floor and none closes a way or seals an orb in; it keeps BODY_MARGIN_M from every living
##   body (never on the hero or the Judge) and never covers an orb.
## - It goes when its time is up, with its boss, with the next wave and when the fight ends (BossTime.advance).
## Pure: no stream is drawn; everything follows from the positions.

## A gear keeps this much clear of every living body's edge.
const BODY_MARGIN_M := 0.5
## A gear keeps the hero's width plus this from every wall and other gear.
const PASS_SLACK_M := 0.15
## The gap to the walls is tested with circles this far apart along the gear; SCALLOP_M covers what they miss
## between two of them.
const SAMPLE_M := 0.5
const SCALLOP_M := 0.05
## Where along the line from the hero to an orb a gear may cross it, per mille, tried in order: a line's first gear,
## then its second.
const SPOTS: Array[int] = [500, 400, 600, 300, 700]
const SPOTS_2: Array[int] = [250, 750, 350, 650]
## drop(): the gears whose time is up, or every gear.
const DUE := -1
const ALL := -2


## Gear k as the wall it is.
static func obb(bs: BossFightStore, k: int) -> Obb:
	return Obb.make(
		Vector2(bs.gear_x[k], bs.gear_y[k]), Vector2(bs.gear_hx[k], bs.gear_hy[k]), bs.gear_a[k]
	)


## Every standing gear as a wall.
static func obbs(w: World) -> Array[Obb]:
	var out: Array[Obb] = []
	for k in w.boss_fight.gear_x.size():
		out.append(obb(w.boss_fight, k))
	return out


## BossTime.resolve_wave: boss i's wave has placed `orbs`; its gears rise across the hero's lines to them. Returns
## how many rose.
static func raise(w: World, i: int, tt: BossTimeTable, orbs: PackedVector2Array) -> int:
	if orbs.is_empty() or tt.gear_count <= 0:
		return 0
	var hero := w.player_pos()
	var n := 0
	for g in tt.gear_count:
		var orb := orbs[g % orbs.size()]
		var along := (Kin.angle_of(orb - hero) + 1024) & 4095
		for s: int in SPOTS if g < orbs.size() else SPOTS_2:
			var c := hero + (orb - hero) * (s / 1000.0)
			if fits(w, c, tt.gear_half, along, orbs):
				_add(w, w.actors.ids[i], c, tt.gear_half, along, tt.gear_ticks)
				n += 1
				break
	if n > 0:
		BossSignatures.set_nav_extra(w)
	return n


## True when a gear (half its length and width `half`, lying along angle `along`) fits at c: the rule in the class
## comment. The gap to the walls is the gear's middle line grown by its half width and the gap, tested as circles
## along it: that capsule holds the whole box grown by the gap.
static func fits(w: World, c: Vector2, half: Vector2, along: int, orbs: PackedVector2Array) -> bool:
	var u := Kin.dir(along)
	var a := c - u * half.x
	var b := c + u * half.x
	var room := w.bosses.arena
	if room.has_area() and not (room.has_point(a) and room.has_point(b)):
		return false
	var actors := w.actors
	for j in actors.size():
		if actors.dead[j] == 0:
			if seg_dist(actors.pos(j), a, b) < actors.radius[j] + half.y + BODY_MARGIN_M:
				return false
	var pr := w.player.radius_m
	var bs := w.bosses
	for k in bs.pk_x.size():
		if seg_dist(Vector2(bs.pk_x[k], bs.pk_y[k]), a, b) < half.y + maxf(bs.pk_r[k], pr * 2.0):
			return false
	for p: Vector2 in orbs:
		if seg_dist(p, a, b) < half.y + pr * 2.0:
			return false
	var reach := half.y + pr * 2.0 + PASS_SLACK_M + SCALLOP_M
	var steps := int(half.x * 2.0 / SAMPLE_M) + 1
	for s in steps + 1:
		if not EnemyAi.clear_of_walls(w, a + (b - a) * (float(s) / steps), reach):
			return false
	return true


## How far p is from the segment a-b.
static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.dot(ab)
	if len2 <= 0.0:
		return Kin.length(p - a)
	return Kin.length(p - (a + ab * clampf((p - a).dot(ab) / len2, 0.0, 1.0)))


static func _add(w: World, boss_id: int, c: Vector2, half: Vector2, along: int, ticks: int) -> void:
	var bs := w.boss_fight
	bs.gear_x.append(c.x)
	bs.gear_y.append(c.y)
	bs.gear_hx.append(half.x)
	bs.gear_hy.append(half.y)
	bs.gear_a.append(along)
	bs.gear_from.append(w.tick)
	bs.gear_until.append(w.tick + ticks)
	bs.gear_boss.append(boss_id)
	w.add_barrier(obb(bs, bs.gear_x.size() - 1))


## Removes the gears whose time is up (DUE), every gear (ALL) or every gear of boss `which`, walls and all.
static func drop(w: World, which: int = DUE) -> void:
	var bs := w.boss_fight
	var gone: Array[Obb] = []
	for k in range(bs.gear_x.size() - 1, -1, -1):
		var due := bs.gear_until[k] <= w.tick
		if which == ALL or bs.gear_boss[k] == which or (which == DUE and due):
			gone.append(obb(bs, k))
			bs.remove_gear(k)
	if not gone.is_empty():
		w.remove_barriers(gone)
		BossSignatures.set_nav_extra(w)


## The gears for the view (WorldReader.boss_time's "gears"): each {"centre", "half" (half its length, half its
## width), "angle" (1/4096 turns, along its length), "age" (ticks since it rose), "left" (ticks until it goes)}.
static func rows(w: World) -> Array:
	var out := []
	var bs := w.boss_fight
	for k in bs.gear_x.size():
		(
			out
			. append(
				{
					"centre": Vector2(bs.gear_x[k], bs.gear_y[k]),
					"half": Vector2(bs.gear_hx[k], bs.gear_hy[k]),
					"angle": bs.gear_a[k],
					"age": w.tick - bs.gear_from[k],
					"left": bs.gear_until[k] - w.tick,
				}
			)
		)
	return out
