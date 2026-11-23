class_name BossWard
extends RefCounted
## The violet Warden's wards (BossWardensTable; state in BossFightStore wd_*).
## - The Mirror Ward (`mirror_ward`, a cast): as the cast ends a ward stands mirror_ticks on the arc mirror_half_arc
##   each side of the way to the hero then (it does not turn afterwards; it stays on the Warden wherever it goes).
##   A hit from the hero that comes from inside the arc does nothing. A hero's projectile that reaches the Warden
##   through the arc is sent back instead (ProjectileContacts asks `reflect`): it ends there, with its end hooks, and
##   a hostile shot leaves the same point along its reversed velocity at its own speed, dealing mirror_permille of
##   its own damage (the number the shot carries, before the hero's damage stats and crit), at most
##   mirror_cap_permille of the hero's max HP. A melee swing into the arc also pushes the hero mirror_push_m back
##   (once a tick). The Laser, the Void and Wave shots and area hits are blocked and not returned. Hits from outside
##   the arc land as ever; damage over time is not turned.
## - The whole ward, from ward_phase: the violet Warden takes nothing from anywhere (hits and ticks spark off). The
##   amber Warden's charge breaks it when the lane its body has swept touches the violet Warden: she is stunned
##   stun_ticks (taking stun_permille), he is staggered stagger_ticks, and the ward is back return_ticks after the
##   break. With the table's ward_attack the whole ward is cast, seen: ward_first_ticks into its phase (none stands
##   at the phase's start), and after a break so that it stands again return_ticks after it. While he winds a
##   charge up with the ward standing, ObjectiveMarkers.TWINS_WARD follows her.
## Pure: no stream is drawn.

const S := EnemyAi.State
const M := BossAttackTable.Move
## World.killer_attack and a returned shot's cause (BossCauses.key: BossWardensTable.mirror_cause_key): past every
## attack index and every late part (BossSignatures.LATE_CAUSE + an index), so a projectile can carry it.
const MIRROR_CAUSE := 2 * BossSignatures.LATE_CAUSE
## STATUS_APPLY effects, source the violet Warden unless said. UP: a ward stands (amount = its ticks, 0 for the whole
## ward; amount_applied = 1 for the whole ward). DOWN: it is gone. BREAK: the charge broke it (source the amber
## Warden, target the violet one; amount = her stun's ticks). REFLECT: a shot was sent back (pos = where, amount = the
## damage it now carries). BLOCK: a swing was pushed back (target the hero, amount = mm pushed).
const UP := &"warden_ward_up"
const DOWN := &"warden_ward_down"
const BREAK := &"warden_ward_break"
const REFLECT := &"warden_reflect"
const BLOCK := &"warden_block"


## The violet Warden's actor index when actor i is her and the pair runs its mechanics, else -1.
static func _violet(w: World, i: int) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	if fs.wd_boss < 0 or i <= 0 or bs.twin_lead.is_empty():
		return -1
	var k := bs.twin_lead.find(fs.wd_boss)
	return i if k >= 0 and bs.twin_body[k] == w.actors.ids[i] else -1


## True while the Mirror Ward stands.
static func mirror_up(w: World) -> bool:
	return w.boss_fight.wd_mirror_until > w.tick


## True while actor i is the violet Warden under her whole ward.
static func full(w: World, i: int) -> bool:
	if _violet(w, i) < 0:
		return false
	var bs := w.bosses
	var fs := w.boss_fight
	var wt := BossAi.table_of(w, i).wardens
	if bs.twin_phase[bs.twin_lead.find(fs.wd_boss)] < wt.ward_phase:
		return false
	if wt.ward_attack >= 0:  # Cast: it stands from the cast's end to the break
		return fs.wd_full == 1
	return fs.wd_break_at < 0 or w.tick >= fs.wd_break_at + wt.return_ticks


## Tick phase 3 (BossTwin.think), the violet Warden free: true when she starts the whole ward's cast now (its due
## tick reached, the ward down, the set piece not holding her, her turn with the amber Warden not attacking).
static func cast_think(w: World, i: int) -> bool:
	var fs := w.boss_fight
	var wt := BossAi.table_of(w, i).wardens
	if _violet(w, i) < 0 or wt.ward_attack < 0 or fs.wd_full == 1 or fs.wd_ward_due < 0:
		return false
	if w.tick < fs.wd_ward_due or BossRift.holds(w):
		return false
	if not BossTwin.may_start(w, i, BossTwin.pair_of(w, i)):
		return false  # Her turn, his attack over: the two alternate and never overlap
	fs.wd_ward_due = -1
	BossAi.start_attack(w, i, wt.ward_attack)
	return true


## True while body i casts the whole ward (its windup).
static func casting(w: World, i: int) -> bool:
	var wt := BossAi.table_of(w, i).wardens
	if _violet(w, i) < 0 or wt.ward_attack < 0:
		return false
	var b := BossAi.entry_of(w, i)
	return w.bosses.attack[b] == wt.ward_attack and w.actors.state[i] == S.WINDUP


## Tick phase 6 (BossTwin.resolve), as the whole ward's cast ends: it stands (a Mirror Ward still up gives way).
static func raise(w: World, i: int) -> void:
	var fs := w.boss_fight
	fs.wd_full = 1
	fs.wd_ward_due = -1
	fs.wd_mirror_on = 0
	fs.wd_mirror_until = -1
	_tell(w, i, UP, 0, 1)


## Tick phase 6 (advance): the whole ward's next cast is set due once it is down in its phase: ward_first_ticks after
## the phase is first seen, or so that the cast ends return_ticks after a break.
static func _schedule(w: World, violet: int) -> void:
	var fs := w.boss_fight
	var bs := w.bosses
	var wt := BossAi.table_of(w, violet).wardens
	if wt.ward_attack < 0 or fs.wd_full == 1 or fs.wd_ward_due >= 0 or casting(w, violet):
		return
	if bs.twin_phase[bs.twin_lead.find(fs.wd_boss)] < wt.ward_phase:
		return
	if fs.wd_break_at < 0:
		fs.wd_ward_due = w.tick + wt.ward_first_ticks
		return
	var cast := BossAi.table_of(w, violet).attacks[wt.ward_attack].windup_ticks
	fs.wd_ward_due = maxi(w.tick, fs.wd_break_at + wt.return_ticks - cast)


## True while actor i is the violet Warden stunned by her broken ward.
static func stunned(w: World, i: int) -> bool:
	if _violet(w, i) < 0 or w.boss_fight.wd_break_at < 0:
		return false
	return w.tick < w.boss_fight.wd_break_at + BossAi.table_of(w, i).wardens.stun_ticks


## True when a hit from `from` meets the Mirror Ward of actor i.
static func faces(w: World, i: int, from: Vector2) -> bool:
	if not mirror_up(w) or _violet(w, i) < 0:
		return false
	var at := w.actors.pos(i)
	if from == at:
		return false
	var off := Kin.angle_diff(Kin.angle_of(from - at), w.boss_fight.wd_mirror_a)
	return off <= BossAi.table_of(w, i).wardens.mirror_half_arc


## Damage.hit: true when the hero's hit on `target` from `from` is turned by the Mirror Ward (it does nothing). A
## melee swing is also pushed back.
static func turns(w: World, target: int, from: Vector2, tags: int, owner_id: int) -> bool:
	if owner_id != w.actors.ids[0] or not faces(w, target, from):
		return false
	var bs := w.boss_fight
	if tags & SimEvent.TAG_MELEE and bs.wd_push_tick != w.tick:
		bs.wd_push_tick = w.tick
		var away := w.player_pos() - w.actors.pos(target)
		var d := Kin.length(away)
		var push := BossAi.table_of(w, target).wardens.mirror_push_m
		var moved := BossTide.shift(w, away / d * push) if d > 0.0001 else Vector2.ZERO
		var id := w.actors.ids[target]
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, owner_id, w.player_pos())
		e.effect_id = BLOCK
		e.amount = int(Kin.length(moved) * 1000.0)
	return true


## ProjectileContacts.apply: projectile `pi`, swept from `a` by `v`, meets `actor` at fraction `t`. True when the
## Mirror Ward sends it back: the hostile shot is queued and the caller ends the hero's without a hit.
static func reflect(w: World, pi: int, actor: int, a: Vector2, v: Vector2, t: float) -> bool:
	var ps := w.projectiles
	if ps.team[pi] != ActorStore.TEAM_PLAYER or not faces(w, actor, a):
		return false
	var wt := BossAi.table_of(w, actor).wardens
	var speed := Kin.length(v)
	if speed <= 0.0001:
		return false
	var cap := maxi(1, w.actors.max_hp[0] * wt.mirror_cap_permille / 1000)
	var dmg := clampi(ps.damage[pi] * wt.mirror_permille / 1000, 1, cap)
	var at := a + v * t
	var id := w.actors.ids[actor]
	var life := maxi(1, int(wt.mirror_range_m / speed))
	w.queue_projectile(
		id, ActorStore.TEAM_ENEMY, at, -v, dmg, ps.radius[pi], life, SimEvent.TAG_PROJECTILE
	)
	if wt.mirror_look != &"":
		w.set_pending_look(wt.mirror_look)
	w.set_pending_cause(MIRROR_CAUSE)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, w.actors.ids[0], at)
	e.effect_id = REFLECT
	e.amount = dmg
	return true


## Tick phase 6 (BossTwin.resolve), as the Mirror Ward's cast ends: the ward stands, facing the hero (the whole
## ward's cast raises the whole ward instead).
static func cast(w: World, i: int) -> void:
	var bs := w.boss_fight
	var wt := BossAi.table_of(w, i).wardens
	if wt.ward_attack >= 0 and w.bosses.attack[BossAi.entry_of(w, i)] == wt.ward_attack:
		raise(w, i)
		return
	bs.wd_mirror_until = w.tick + wt.mirror_ticks
	bs.wd_mirror_a = Kin.angle_of(w.player_pos() - w.actors.pos(i))
	bs.wd_mirror_on = 1
	_tell(w, i, UP, wt.mirror_ticks, 0)


## Tick phase 6 (BossTwin.resolve, the amber Warden's turn): its charge's swept lane against the warded violet one.
static func charge_check(w: World, i: int, j: int) -> void:
	var a := w.actors
	var atk := BossAi.attack_of(w, i)
	if a.state[i] != S.ACTIVE or atk == null or atk.move != M.CHARGE or j < 0 or not full(w, j):
		return
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	# Within a contact slop: phase 5 has already pushed the two bodies exactly apart
	var reach := a.radius[i] + EnemyAi.CONTACT_SLOP_M
	var run := maxf((a.pos(i) - from).dot(Kin.dir(a.lock_a[i])), 0.0) + reach
	var lane := AttackShapes.lane(from, a.lock_a[i], run, reach)
	if Collide.circle_vs_obb(a.pos(j), a.radius[j], lane) != Vector2.ZERO:
		_break(w, i, j)


static func _break(w: World, i: int, j: int) -> void:
	var a := w.actors
	var bs := w.boss_fight
	var wt := BossAi.table_of(w, i).wardens
	bs.wd_break_at = w.tick
	bs.wd_full = 0
	_reel(w, i, wt.stagger_ticks)
	_reel(w, j, wt.stun_ticks)
	BossChargeBurst.on_boss_gone(w, a.ids[i])  # The charge ended on her: no burst
	w.objectives.clear(ObjectiveMarkers.TWINS_WARD)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[i], a.ids[j], a.pos(j))
	e.effect_id = BREAK
	e.amount = wt.stun_ticks


## Body i's attack ends and it stands still for `ticks` (BossAi.think counts it down, then it walks again).
static func _reel(w: World, i: int, ticks: int) -> void:
	var a := w.actors
	var b := BossAi.entry_of(w, i)
	w.bosses.attack[b] = -1
	w.bosses.stagger_t[b] = ticks
	a.lock_len[i] = 0.0
	a.invuln[i] = 0
	a.state[i] = BossAi.STAGGERED
	a.state_t[i] = 0


## Tick phase 6 (BossWardens.advance): the wards' beginnings and ends are told once; the hint follows the violet
## Warden while the amber one winds up a charge at her standing ward.
static func advance(w: World, lead: int, violet: int) -> void:
	var bs := w.boss_fight
	_schedule(w, violet)
	if bs.wd_mirror_on == 1 and not mirror_up(w):
		bs.wd_mirror_on = 0
		bs.wd_mirror_until = -1
		_tell(w, violet, DOWN, 0, 0)
	var whole := full(w, violet)
	if whole != (bs.wd_full == 1):
		bs.wd_full = 1 if whole else 0
		if whole:  # A whole ward replaces the Mirror Ward
			bs.wd_mirror_on = 0
			bs.wd_mirror_until = -1
		_tell(w, violet, UP if whole else DOWN, 0, 1)
	var atk := BossAi.attack_of(w, lead)
	var aimed := whole and atk != null and atk.move == M.CHARGE and w.actors.state[lead] == S.WINDUP
	if aimed != w.objectives.has(ObjectiveMarkers.TWINS_WARD):
		w.objectives.clear(ObjectiveMarkers.TWINS_WARD)
		if aimed:
			w.objectives.follow(ObjectiveMarkers.TWINS_WARD, w.actors.ids[violet])


static func _tell(w: World, i: int, effect: StringName, ticks: int, whole: int) -> void:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(i))
	e.effect_id = effect
	e.amount = ticks
	e.amount_applied = whole


## BossWardens.state: the ward for the view: "who" (the violet Warden's index), "kind" (&"" none, &"mirror",
## &"full"), "centre" and "half_arc" (the arc, 1/4096 turns; the whole ward 2048 each side), "left" (the Mirror
## Ward's ticks, -1 otherwise), "broken" (the whole ward is down), "stun_left" and "return_in" (ticks, 0 when not),
## "raising" (the violet Warden casts the whole ward now).
static func state(w: World, violet: int) -> Dictionary:
	var bs := w.boss_fight
	var wt := BossAi.table_of(w, violet).wardens
	var whole := full(w, violet)
	var mirror := mirror_up(w) and not whole
	var broken := bs.wd_break_at >= 0 and w.tick < bs.wd_break_at + wt.return_ticks
	return {
		"who": violet,
		"kind": &"full" if whole else (&"mirror" if mirror else &""),
		"centre": bs.wd_mirror_a if mirror else w.actors.facing[violet],
		"half_arc": 2048 if whole else (wt.mirror_half_arc if mirror else 0),
		"left": bs.wd_mirror_until - w.tick if mirror else -1,
		"broken": broken,
		"stun_left": maxi(0, bs.wd_break_at + wt.stun_ticks - w.tick) if broken else 0,
		"return_in": bs.wd_break_at + wt.return_ticks - w.tick if broken else 0,
		"raising": casting(w, violet),
	}
