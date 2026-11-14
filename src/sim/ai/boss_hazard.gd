class_name BossHazard
extends RefCounted
## v0.11.0 F8 (owner 4.2: "environmental hazards that progressively occupy parts of the arena instead of shrinking the
## entire room ... These hazards should accumulate during the fight but have a strict maximum cap, preventing the entire
## arena from becoming unusable"; picked: Foundry lava pools, Brood Mother venom pools, Siege Engine falling rocks):
## the shared arena hazards, one disc each: BossStore.hz_* {kind, centre, radius, ends_at, arm_tick}.
## - A hazard is placed, shows its warning for warn_ticks (the content rules hold it to the telegraph minimum; never
##   armed on the tick it lands, so a hazard on the hero's feet is always telegraphed first), arms, stays life_ticks,
##   and goes with its boss. DAMAGE burns the hero's centre inside it once every burn_ticks (Damage.tick_dot, the
##   player's iframes apply; one burn at a time, however many pools overlap, and not on the tick a molten lane has just
##   burned). Any hazard may also drag the hero (HazardTable.slow_permille, World's walk; the strongest applies) and
##   land on a hit (impact_damage, at the tick it arms: the falling rock).
## - It touches the hero only: never enemies, walls, shots or the flow field.
## - The strict cap (make_room): at most max_count per boss, and the discs' areas (summed in integer cm², overlaps
##   counted fully) at most max_cover_permille of the arena's rectangle; a new one that would break either removes the
##   oldest first. Never placed in the boss room's doorway (DOOR_CLEAR_M past its radius).
## Hooks (data: HazardTable.attacks): BossLava.lay (the Foundry's molten_flood lanes), BossSignatures (the Egg Storm:
## its first egg to land is its storm's chosen one, leaving a pool when it hatches or bursts; broken first, no pool),
## BossDodge.resolve_marks / resolve_grid (the Siege Engine's Barrage and Mortar Grid: on the last strike, a rock falls
## where the hero stands). Pure: no stream is drawn; the choices follow from the clock and the strikes.

## World.killer_attack for a hazard that kills (BossCauses.key).
const ATTACK := -4
## The DAMAGE effect of a burn and of a rock's landing (ReadableCause, the views).
const EFFECT := &"boss_hazard"
const IMPACT_EFFECT := &"boss_hazard_impact"
## Clear floor between a hazard's edge and the boss room's door point (BossLava.exits).
const DOOR_CLEAR_M := 1.5
const CM := 100.0
## Pi in thousandths: the disc's area in integer maths.
const PI_MILLI := 3142


## True when boss table t leaves hazards on attack a.
static func lays_on(t: BossTable, a: int) -> bool:
	return t != null and t.hazard != null and t.hazard.attacks.has(a)


# --- the cap -----------------------------------------------------------------------------------------------------


## A disc's area in cm² (integer).
static func disc_cm2(radius_m: float) -> int:
	var cm := roundi(radius_m * CM)
	return cm * cm * PI_MILLI / 1000


## The arena's area in cm² (the sealed room; BossLava.OPEN_REACH_M's box without one).
static func arena_cm2(w: World) -> int:
	var r := w.bosses.arena
	if not r.has_area():
		var side := roundi(BossLava.OPEN_REACH_M * 2.0 * CM)
		return side * side
	return roundi(r.size.x * CM) * roundi(r.size.y * CM)


## The floor share boss `boss_id`'s hazards cover now, per mille of the arena (overlaps counted fully).
static func cover_permille(w: World, boss_id: int) -> int:
	return _covered_cm2(w, boss_id) * 1000 / maxi(1, arena_cm2(w))


static func _covered_cm2(w: World, boss_id: int) -> int:
	var bs := w.bosses
	var sum := 0
	for k in bs.hz_x.size():
		if bs.hz_boss[k] == boss_id:
			sum += disc_cm2(bs.hz_r[k])
	return sum


## How many hazards boss `boss_id` has down.
static func count_of(w: World, boss_id: int) -> int:
	return w.bosses.hz_boss.count(boss_id)


## Removes boss `boss_id`'s oldest hazards until one more of table h keeps both caps. False when it never could.
static func make_room(w: World, boss_id: int, h: HazardTable) -> bool:
	var area := disc_cm2(h.radius_m)
	var arena := arena_cm2(w)
	if area * 1000 > h.max_cover_permille * arena:
		return false
	var bs := w.bosses
	while (
		count_of(w, boss_id) + 1 > h.max_count
		or (_covered_cm2(w, boss_id) + area) * 1000 > h.max_cover_permille * arena
	):
		var oldest := bs.hz_boss.find(boss_id)
		if oldest < 0:
			return false
		bs.remove_hazard(oldest)
	return true


# --- placing ------------------------------------------------------------------------------------------------------


## True when a hazard of radius r at c would lie in the boss room's doorway.
static func in_doorway(w: World, c: Vector2, r: float) -> bool:
	for e: Vector2 in BossLava.exits(w):
		if Kin.length(c - e) < r + DOOR_CLEAR_M:
			return true
	return false


## Places one of boss i's hazards at c, warning first. False when its table has none, or it would lie in the doorway,
## or it could never fit.
static func place(w: World, i: int, c: Vector2) -> bool:
	var h := BossAi.table_of(w, i).hazard
	if h == null or in_doorway(w, c, h.radius_m):
		return false
	var id := w.actors.ids[i]
	if not make_room(w, id, h):
		return false
	var bs := w.bosses
	bs.hz_id.append(bs.hz_next)
	bs.hz_next += 1
	bs.hz_boss.append(id)
	bs.hz_kind.append(h.kind)
	bs.hz_x.append(c.x)
	bs.hz_y.append(c.y)
	bs.hz_r.append(h.radius_m)
	bs.hz_from.append(w.tick)
	bs.hz_arm.append(w.tick + maxi(1, h.warn_ticks))
	bs.hz_until.append(w.tick + maxi(1, h.warn_ticks) + h.life_ticks)
	bs.hz_slow.append(h.slow_permille)
	return true


## BossLava.lay: boss i's molten lanes `pieces` were laid: pools stay on them, up to per_attack, on the lanes' middles,
## each clear of the fords (a piece at least the pool wide, so the disc stays between them) and of its other pools.
## The first piece looked at turns with the tick (no stream drawn).
static func on_lanes(w: World, i: int, pieces: Array[Rect2]) -> void:
	var t := BossAi.table_of(w, i)
	if not lays_on(t, w.bosses.attack[BossAi.entry_of(w, i)]) or pieces.is_empty():
		return
	var h := t.hazard
	var n := pieces.size()
	var done := 0
	for step in n:
		var r: Rect2 = pieces[(w.tick + step) % n]
		var c := r.get_center()
		if done < h.per_attack and r.size.x * 0.5 >= h.radius_m and not _stacked(w, c, h.radius_m):
			if place(w, i, c):
				done += 1


## True when a pool at c would sit on another (centre within its radius).
static func _stacked(w: World, c: Vector2, r: float) -> bool:
	var bs := w.bosses
	for k in bs.hz_x.size():
		if Kin.length(Vector2(bs.hz_x[k], bs.hz_y[k]) - c) < r:
			return true
	return false


## BossSignatures.lay_egg, an Egg Storm's first strike: the storm has not yet chosen its egg; eggs left over from an
## older storm that were broken are forgotten. Nothing without hazards.
static func storm_begins(w: World, b: int) -> void:
	var bs := w.bosses
	var i := w.actors.index_of(bs.ids[b])
	if i < 0 or not lays_on(BossAi.table_of(w, i), bs.attack[b]):
		return
	bs.hz_storm = 1
	for k in range(bs.hz_egg.size() - 1, -1, -1):
		var e := w.actors.index_of(bs.hz_egg[k])
		if e < 0 or w.actors.dead[e] == 1:
			bs.hz_egg.remove_at(k)


## BossSignatures.lay_egg: true for the storm's first egg to land (at most one a storm).
static func takes_pool(w: World) -> bool:
	if w.bosses.hz_storm == 0:
		return false
	w.bosses.hz_storm = 0
	return true


## BossSignatures.egg_think, an egg's time up (it hatches or bursts): the storm's chosen egg leaves a pool where it lay.
static func on_egg_done(w: World, i: int, boss: int) -> void:
	var bs := w.bosses
	var k := bs.hz_egg.find(w.actors.ids[i])
	if k >= 0:
		bs.hz_egg.remove_at(k)
		place(w, boss, w.actors.pos(i))


## BossDodge: the last strike of boss entry b's attack: a rock starts to fall where the hero stands, if its table has
## rocks and this attack brings one.
static func rock_stage(w: World, i: int, b: int) -> void:
	var t := BossAi.table_of(w, i)
	if lays_on(t, w.bosses.attack[b]) and t.hazard.impact_damage > 0 and not w.player_dead():
		place(w, i, w.player_pos())


# --- the tick (tick phase 6, BossSignatures.advance) --------------------------------------------------------------


## Hazards past their end go; a rock lands on the tick it arms; the hero inside an armed one burns.
static func advance(w: World) -> void:
	var bs := w.bosses
	if bs.hz_x.is_empty():
		bs.hz_burn_cd = 0
		return
	if bs.hz_burn_cd > 0:
		bs.hz_burn_cd -= 1
	for k in range(bs.hz_x.size() - 1, -1, -1):
		if bs.hz_until[k] <= w.tick:
			bs.remove_hazard(k)
	if w.player_dead():
		return
	_impacts(w)
	_burn(w)


static func _impacts(w: World) -> void:
	var bs := w.bosses
	var p := w.player_pos()
	for k in bs.hz_x.size():
		if bs.hz_arm[k] != w.tick:
			continue
		var bi := w.actors.index_of(bs.hz_boss[k])
		var h: HazardTable = BossAi.table_of(w, bi).hazard if bi >= 0 else null
		if h == null or h.impact_damage <= 0:
			continue
		var c := Vector2(bs.hz_x[k], bs.hz_y[k])
		if AttackShapes.disc_touches(c, bs.hz_r[k], p, w.player.radius_m):
			var id := w.actors.ids[bi]
			var dmg := BossAi.powered(w, bi, h.impact_damage)
			Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, c, p, IMPACT_EFFECT)
			if w.player_dead() and w.killer_attack < 0:
				w.killer_attack = ATTACK


## One burn per its period however many overlap, and none on the molten lane's own burn (BossStore.burn_cd).
static func _burn(w: World) -> void:
	var bs := w.bosses
	if bs.hz_burn_cd > 0 or bs.burn_cd > 0:
		return
	var p := w.player_pos()
	for k in bs.hz_x.size():
		if bs.hz_arm[k] > w.tick or bs.hz_kind[k] != HazardTable.Kind.DAMAGE:
			continue
		if Kin.length(Vector2(bs.hz_x[k], bs.hz_y[k]) - p) > bs.hz_r[k]:
			continue
		var bi := w.actors.index_of(bs.hz_boss[k])
		var h: HazardTable = BossAi.table_of(w, bi).hazard if bi >= 0 else null
		if h == null or h.damage <= 0:
			continue
		bs.hz_burn_cd = maxi(1, h.burn_ticks)
		var id := w.actors.ids[bi]
		Damage.tick_dot(w, 0, BossAi.powered(w, bi, h.damage), id, id, EFFECT)
		if w.player_dead() and w.killer_attack < 0:
			w.killer_attack = ATTACK
		return


## World's walk: the factor on the hero's speed: the strongest armed drag under its feet (1.0 when none).
static func move_factor(w: World) -> float:
	var bs := w.bosses
	if bs.hz_x.is_empty():
		return 1.0
	var slow := 1000
	var p := w.player_pos()
	for k in bs.hz_x.size():
		if bs.hz_arm[k] <= w.tick and bs.hz_slow[k] < slow:
			if Kin.length(Vector2(bs.hz_x[k], bs.hz_y[k]) - p) <= bs.hz_r[k]:
				slow = bs.hz_slow[k]
	return slow / 1000.0


## BossSignatures.on_boss_gone: its hazards go at once.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.bosses
	for k in range(bs.hz_x.size() - 1, -1, -1):
		if bs.hz_boss[k] == boss_id:
			bs.remove_hazard(k)
	bs.hz_egg.clear()
	bs.hz_storm = 0
	if bs.hz_x.is_empty():
		bs.hz_burn_cd = 0


# --- the view (WorldReader.boss_hazards, EI-07) ----------------------------------------------------------------------


## The hazards for the view: see WorldReader.boss_hazards.
static func rows(w: World) -> Array:
	var out := []
	var bs := w.bosses
	for k in bs.hz_x.size():
		var bi := w.actors.index_of(bs.hz_boss[k])
		var h: HazardTable = BossAi.table_of(w, bi).hazard if bi >= 0 else null
		if h == null:
			continue
		var armed := bs.hz_arm[k] <= w.tick
		var span := maxi(1, bs.hz_arm[k] - bs.hz_from[k])
		(
			out
			. append(
				{
					"id": bs.hz_id[k],
					"look": h.look,
					"centre": Vector2(bs.hz_x[k], bs.hz_y[k]),
					"radius": bs.hz_r[k],
					"armed": armed,
					"warn": clampi((w.tick - bs.hz_from[k]) * 1000 / span, 0, 1000),
					"armed_ticks": maxi(0, w.tick - bs.hz_arm[k]),
					"left": bs.hz_until[k] - w.tick,
				}
			)
		)
	return out
