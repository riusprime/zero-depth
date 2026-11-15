class_name FallenQuake
extends RefCounted
## The Gatekeeper's quake pillars as The Fallen remembers them (BossRemembered): the body's BossTable.quake holds
## their numbers, so BossQuake runs them as the Gatekeeper's. As it begins the pillars rise inside the round room
## (BossQuake.raise: placed as the Gatekeeper's, pillar_hero_m clear of the hero; its stun count starts again) and
## pulse in their rings; they stand pillar_ticks (or until the last one shatters).
## - The dash: every pillar_dash_ticks The Fallen asks for its dash between moves (BossNemesis._reposition), aimed at
##   the hero meanwhile (dash_spot: straight at the hero, stopping short of it). A lane that runs into a pillar stops
##   there; on the tick the body reaches it (on_dash: the sweep's share of the dash) the pillar shatters and, for the
##   table's first stuns_per_phase of this mechanic, the body is stunned (BossQuake.shatter: STAGGERED, taking
##   stun_permille). So the hero stands with a pillar between itself and The Fallen.
## Pure: the ai stream only (the pillars' spots, through BossQuake).

## A dash at the hero stops this far short of the hero's edge (m); a shorter dash than SHORT_M is not made.
const HERO_GAP_M := 1.0
const SHORT_M := 1.0


static func begin(w: World, i: int, t: BossTable, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	fs.fl_dash_at = w.tick + m.pillar_dash_ticks
	fs.fl_hit_at = -1
	return BossQuake.raise(w, i, t.quake, 0, BossRemembered.inner_of(w), m.pillar_hero_m) > 0


static func step(w: World, i: int, _t: BossTable, m: FallenRememberedTable) -> bool:
	var fs := w.boss_fight
	var f := w.final_fight
	var id := w.actors.ids[i]
	if fs.fl_hit_at >= 0 and w.tick >= fs.fl_hit_at:
		fs.fl_hit_at = -1
		var k := _pillar_at(w, id, Vector2(fs.fl_hit_x, fs.fl_hit_y))
		if k >= 0:
			f.dash_t = 0  # It crashes into the pillar
			BossQuake.shatter(w, i, PackedInt32Array([k]))
	if w.tick >= fs.fl_dash_at and w.actors.state[i] == EnemyAi.State.MOVE:
		if f.dash_t == 0 and f.rd_t == 0:
			f.rd_pending = 1
			fs.fl_dash_at = w.tick + m.pillar_dash_ticks
	return w.tick - fs.fl_from >= m.pillar_ticks or BossQuake.pillars_of(w, id).is_empty()


static func finish(w: World, i: int) -> void:
	finish_for(w, w.actors.ids[i])


## Its pillars sink and a dash under way no longer shatters anything.
static func finish_for(w: World, boss_id: int) -> void:
	var fs := w.boss_fight
	BossQuake.drop(w, boss_id)
	fs.fl_hit_at = -1
	fs.fl_dash_at = -1
	if w.final_fight != null and fs.fl_kind == BossRemembered.QUAKE:
		w.final_fight.rd_pending = 0


## The quake pillar of `boss_id` standing at `c`, or -1.
static func _pillar_at(w: World, boss_id: int, c: Vector2) -> int:
	var bs := w.bosses
	for k in BossQuake.pillars_of(w, boss_id):
		if Kin.length(BossQuake.center(bs, k) - c) < 0.01:
			return k
	return -1


## BossNemesis._reposition: true while its dash aims at the hero (the quake pillars run).
static func aims(w: World) -> bool:
	var fs := w.boss_fight
	return fs.fl_kind == BossRemembered.QUAKE and fs.fl_stage == BossRemembered.STAGE_RUN


## Where its dash at the hero ends: straight at the hero, at most dash_max_m and HERO_GAP_M short of the hero's
## edge; where a wall that is no quake pillar cuts it, its usual spot instead (BossNemesis.reposition_spot). A lane
## into a quake pillar ends at the far side of the hero's line: the pillar stops it (on_dash).
static func dash_spot(w: World, i: int, ip: FallenDashTable) -> Vector2:
	var a := w.actors
	var at := a.pos(i)
	var r: float = a.radius[i]
	var to := w.player_pos() - at
	var d := Kin.length(to)
	var len := minf(ip.dash_max_m, d - r - w.player.radius_m - HERO_GAP_M)
	if len < SHORT_M:
		return BossNemesis.reposition_spot(w, i, ip)
	var ang := Kin.angle_of(to)
	var end := at + Kin.dir(ang) * len
	if _pillar_on(w, i, at, end) < 0 and EnemyAi.clear_run(w, at, ang, len, r) < len - 0.01:
		return BossNemesis.reposition_spot(w, i, ip)
	return end


## The first quake pillar of boss i the body's sweep from `from` to `to` runs into: [its index, the share of the way
## at the touch], or [-1, 2.0].
static func _first_pillar(w: World, i: int, from: Vector2, to: Vector2) -> Array:
	var bs := w.bosses
	var r: float = w.actors.radius[i]
	var best := -1
	var at := 2.0
	for k in BossQuake.pillars_of(w, w.actors.ids[i]):
		var share := Collide.sweep_vs_obb(from, to, r, BossSignatures.pillar_obb(bs, k))
		if share >= 0.0 and share < at:
			best = k
			at = share
	return [best, at]


static func _pillar_on(w: World, i: int, from: Vector2, to: Vector2) -> int:
	return int(_first_pillar(w, i, from, to)[0])


## BossNemesis._reposition, as the dash leaves (its telegraph over): a lane into a quake pillar marks the tick the
## body reaches it.
static func on_dash(w: World, i: int, ip: FallenDashTable) -> void:
	if not aims(w):
		return
	var fs := w.boss_fight
	var hit := _first_pillar(w, i, w.actors.pos(i), w.final_fight.rd_to)
	var k := int(hit[0])
	if k < 0:
		return
	var c := BossQuake.center(w.bosses, k)
	fs.fl_hit_x = c.x
	fs.fl_hit_y = c.y
	fs.fl_hit_at = w.tick + maxi(1, ceili(float(hit[1]) * ip.dash_ticks))


## The dash shown while it aims at the hero: {} or {"from", "to", "through" (it runs into a pillar)}.
static func dash_state(w: World, i: int) -> Dictionary:
	var f := w.final_fight
	if not aims(w) or f == null or f.rd_t <= 0:
		return {}
	return {
		"from": w.actors.pos(i),
		"to": f.rd_to,
		"through": _pillar_on(w, i, w.actors.pos(i), f.rd_to) >= 0,
	}
