class_name BossShadowSwords
extends RefCounted
## The violet Warden's Shadow Swords (`shadow_swords`; its numbers are BossWardensTable.sword_*). As the attack
## starts, sword_count blades appear on a fan sword_fan wide and sword_ring_m from where the hero stands, the fan's
## middle on the caster's side. Each shows its lane for the telegraph: from its spot through where the hero stood,
## sword_len_m long and sword_half_m each side. Then they cut one after another, sword_gap_ticks apart, in fan order:
## a hero touching the lane as it is cut takes the attack's damage (each cut may land; the hurt i-frames apply).
## A lane that was cut leaves a rift at its far end: one of the boss's arena hazards (BossHazard: a disc that warns,
## then burns; its cap and its doorway rule), pulled back along the lane until it lies clear of walls.
## The spots are the boss's locked points 0 .. count - 1 and their centre the last one. Pure: no stream is drawn.

const S := EnemyAi.State
## The locked point that holds the centre the lanes cross.
const CENTRE_SLOT := BossStore.MAX_PTS - 1
## STATUS_APPLY, source the violet Warden: a blade cut (pos = its spot, amount = its index, amount_applied = the HP it
## cost).
const CUT := &"warden_sword_cut"


## BossTwin.on_start: the blades' spots round where the hero stands now.
static func lock(w: World, i: int) -> void:
	var wt := BossAi.table_of(w, i).wardens
	var b := BossAi.entry_of(w, i)
	var c := w.player_pos()
	var base := Kin.angle_of(w.actors.pos(i) - c)
	var n := wt.sword_count
	w.bosses.set_pt(b, CENTRE_SLOT, c)
	for k in n:
		var off := 0 if n < 2 else (2 * k - (n - 1)) * wt.sword_fan / (2 * (n - 1))
		w.bosses.set_pt(b, k, c + Kin.dir((base + off) & 4095) * wt.sword_ring_m)


## [start, angle] of blade k's lane.
static func _line(w: World, i: int, k: int) -> Array:
	var b := BossAi.entry_of(w, i)
	var from := w.bosses.pt(b, k)
	return [from, Kin.angle_of(w.bosses.pt(b, CENTRE_SLOT) - from)]


## Blade k's lane (the view draws it, the cut hits with it).
static func lane(w: World, i: int, k: int) -> Obb:
	var wt := BossAi.table_of(w, i).wardens
	var l := _line(w, i, k)
	return AttackShapes.lane(l[0], l[1], wt.sword_len_m, wt.sword_half_m)


## The active tick blade k cuts on.
static func cut_tick(wt: BossWardensTable, k: int) -> int:
	return k * wt.sword_gap_ticks


## Tick phase 6 (BossTwin.resolve): the blade due cuts its lane and leaves its rift.
static func resolve(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	var wt := BossAi.table_of(w, i).wardens
	if st % wt.sword_gap_ticks != 0 or st / wt.sword_gap_ticks >= wt.sword_count:
		return
	var k := st / wt.sword_gap_ticks
	var a := w.actors
	var id := a.ids[i]
	var l := _line(w, i, k)
	var p := w.player_pos()
	var cost := 0
	if Collide.circle_vs_obb(p, w.player.radius_m, lane(w, i, k)) != Vector2.ZERO:
		var dmg := BossAi.powered(w, i, atk.damage)
		cost = Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, l[0], p)
		if w.player_dead() and w.killer_attack < 0:
			w.killer_attack = w.bosses.attack[BossAi.entry_of(w, i)]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, l[0])
	e.effect_id = CUT
	e.amount = k
	e.amount_applied = cost
	_leave_rift(w, i, l[0], l[1], wt.sword_len_m)


## The rift at a cut lane's far end: the first of the end, three quarters and half way along it that lies clear of
## walls and inside the boss room.
static func _leave_rift(w: World, i: int, from: Vector2, angle: int, length: float) -> void:
	var h := BossAi.table_of(w, i).hazard
	if h == null:
		return
	var room := w.bosses.arena
	for f: float in [1.0, 0.75, 0.5]:
		var c := from + Kin.dir(angle) * (length * f)
		if room.has_area() and not room.grow(-h.radius_m).has_point(c):
			continue
		if EnemyAi.clear_of_walls(w, c, h.radius_m):
			BossHazard.place(w, i, c)
			return


## BossTwin.telegraph: the lanes not cut yet, as &"lanes", through the telegraph and the cuts.
static func telegraph(w: World, i: int, atk: BossAttackTable, progress: int) -> Dictionary:
	var a := w.actors
	var wt := BossAi.table_of(w, i).wardens
	var obbs: Array[Obb] = []
	for k in wt.sword_count:
		if a.state[i] == S.WINDUP or a.state_t[i] < cut_tick(wt, k):
			obbs.append(lane(w, i, k))
	if obbs.is_empty():
		return {}
	return {
		"shape": &"lanes",
		"obbs": obbs,
		"progress": progress if a.state[i] == S.WINDUP else 1000,
		"move": atk.move,
	}


## BossWardens.state: the blades of the Shadow Swords running, each {"from", "to", "half_width", "cut" (it has cut),
## "cut_in" (ticks until it cuts, 0 once it has)}; [] with none.
static func rows(w: World, violet: int) -> Array:
	var out := []
	var a := w.actors
	var atk := BossAi.attack_of(w, violet)
	var busy := a.state[violet] == S.WINDUP or a.state[violet] == S.ACTIVE
	if atk == null or atk.move != BossAttackTable.Move.SHADOW_SWORDS or not busy:
		return out
	var wt := BossAi.table_of(w, violet).wardens
	var t := a.state_t[violet] - (atk.windup_ticks if a.state[violet] == S.WINDUP else 0)
	for k in wt.sword_count:
		var l := _line(w, violet, k)
		var left := cut_tick(wt, k) - t
		(
			out
			. append(
				{
					"from": l[0],
					"to": l[0] + Kin.dir(l[1]) * wt.sword_len_m,
					"half_width": wt.sword_half_m,
					"cut": left <= 0,
					"cut_in": maxi(0, left),
				}
			)
		)
	return out
