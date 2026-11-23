class_name BossMaelstrom
extends RefCounted
## The Tidecaller's Maelstrom (BossDanceTable.mael_*; BossFightStore.dance_spin, dance_grace, dance_throw): from
## mael_phase to the end of the fight the whole room is a whirlpool round the boss, and no Pull is cast (its phase's
## rhythm has none: BossTideBeats.order).
## - Each tick the hero is carried round the boss (mael_spin per mille of its own run speed now, along the
##   perpendicular of the line to the boss; one way for the whole fight, drawn once from the ai stream) and toward it
##   (mael_in per mille, stopping BossTide.BODY_GAP_M short of its body), through BossTide.shift's wall rule. A
##   dashing or dead hero isn't moved, and nothing turns while the boss kneels at a phase change.
## - The eye: a hero whose centre is within mael_eye_m of the boss's edge loses mael_hit per mille of max HP once
##   (SafeArea.hurt: armour and the dash's invulnerability apply) and is thrown mael_throw_m straight out over
##   mael_throw_ticks (the wall rule again; the whirlpool does not carry it meanwhile); the eye then leaves it alone
##   until mael_grace_ticks after the hit.
## - The anchor: from mael_phase on the boss walks (at its own speed, attacking as it goes: it attacks too often to
##   walk only between attacks) straight to the room's centre and from there never moves (holds), so the eye stays
##   where the High Tide's dry circle was placed away from: a whirlpool round a boss walking at the hero carried its
##   eye onto the dry circle.
## Pure: one draw from the ai stream (the way it turns).

## STATUS_APPLY effects (source the boss). BEGIN: the whirlpool starts (amount = the way it turns, 1 or -1). THROW:
## the eye hit (target the hero, pos = where it stood, amount = the HP it cost).
const BEGIN := &"maelstrom"
const THROW := &"maelstrom_throw"
## The eye's damage effect id (the HIT and DAMAGE events).
const EFFECT := &"boss_maelstrom"


## Tick phase 6 (BossDance.advance), boss i in `phase`.
static func advance(w: World, i: int, d: BossDanceTable, phase: int) -> void:
	var bs := w.boss_fight
	var a := w.actors
	if phase < d.mael_phase or a.state[i] == BossAi.GATE:
		return
	var id := a.ids[i]
	if bs.dance_spin == 0:
		bs.dance_spin = 1 if w.rng_ai.range_int(0, 1) == 0 else -1
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, a.pos(i))
		e.effect_id = BEGIN
		e.amount = bs.dance_spin
	if w.player_dead():
		return
	var hero := w.player_pos()
	var to := a.pos(i) - hero
	var dist := Kin.length(to)
	if dist <= 0.0001:
		return
	var inward := to / dist
	if bs.dance_throw > 0:
		bs.dance_throw -= 1
		if not w.is_dashing():
			BossTide.shift(w, -inward * (d.mael_throw_m / d.mael_throw_ticks))
		return
	if w.is_dashing():
		return
	if w.tick >= bs.dance_grace and dist <= a.radius[i] + d.mael_eye_m:
		var got := SafeArea.hurt(w, i, d.mael_hit, SafeArea.Mode.ONCE, d.tide_cause, EFFECT)
		if got > 0:
			bs.dance_grace = w.tick + d.mael_grace_ticks
			bs.dance_throw = d.mael_throw_ticks
			var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, a.ids[0], hero)
			e.effect_id = THROW
			e.amount = got
		return
	BossTide.shift(w, drift_of(w, i, d))


## True when the table's dance holds a Maelstrom its fight reaches (mael_phase is one of its phases).
static func in_fight(t: BossTable) -> bool:
	return t.dance != null and t.dance.mael_phase < t.phase_speed_permille.size()


## Where boss i stands through its Maelstrom: the room's centre (BossDance.room_of; without a room, where it is).
static func anchor(w: World, i: int) -> Vector2:
	return BossDance.room_of(w, i).get_center()


## Tick phase 5 (BossAi.move, before anything else moves it): true from mael_phase on, when boss i moves itself.
## Each tick, whatever it does but kneel at a phase gate, it steps its phase's speed straight toward the anchor,
## landing on it exactly, never past it; once there nothing it does moves it. Also true (no step) while the Warlord
## casts its banner or its duel: it stands for them.
static func holds(w: World, i: int, slow: float) -> bool:
	if BossWarlord.stands(w, i):
		return true
	var t := BossAi.table_of(w, i)
	if t.dance == null:
		return false
	var phase := w.bosses.phase[BossAi.entry_of(w, i)]
	if phase < t.dance.mael_phase:
		return false
	var a := w.actors
	if a.state[i] == BossAi.GATE or a.dead[i] == 1:
		return true
	var at := a.pos(i)
	var home := anchor(w, i)
	var dist := Kin.length(home - at)
	var speed := t.speed * t.phase_speed_permille[phase] / 1000.0 * slow
	if dist <= 0.0 or speed <= 0.0:
		return true
	a.set_pos(i, home if dist <= speed else at + (home - at) * (speed / dist))
	return true


## The whirlpool's drift on the hero this tick (metres), before the wall rule.
static func drift_of(w: World, i: int, d: BossDanceTable) -> Vector2:
	var a := w.actors
	var to := a.pos(i) - w.player_pos()
	var dist := Kin.length(to)
	if dist <= 0.0001 or w.boss_fight.dance_spin == 0:
		return Vector2.ZERO
	var inward := to / dist
	var side := Vector2(-inward.y, inward.x) * float(w.boss_fight.dance_spin)
	var speed := BossTide.run_speed(w)
	var gap := maxf(dist - a.radius[i] - w.player.radius_m - BossTide.BODY_GAP_M, 0.0)
	return side * (speed * d.mael_spin / 1000.0) + inward * minf(speed * d.mael_in / 1000.0, gap)


## The view's read (BossDance.state's "maelstrom"): {} before it begins; else "centre" (the boss), "spin" (1 or -1:
## the hero is carried along the perpendicular (-y, x) of its line to the boss times this), "around" and "inward"
## (m/s on the hero now), "eye" (its radius from the boss's centre, m), "grace" (ticks until the eye may hurt again)
## and "thrown" (ticks left of a throw), "anchor" (the room's centre, where the boss walks to and then stands) and
## "anchored" (it stands there: "centre" equals "anchor").
static func state(w: World, i: int, d: BossDanceTable) -> Dictionary:
	var bs := w.boss_fight
	if bs.dance_spin == 0:
		return {}
	var speed := BossTide.run_speed(w) * SimTick.TICKS_PER_SECOND
	return {
		"centre": w.actors.pos(i),
		"spin": bs.dance_spin,
		"around": speed * d.mael_spin / 1000.0,
		"inward": speed * d.mael_in / 1000.0,
		"eye": w.actors.radius[i] + d.mael_eye_m,
		"grace": maxi(0, bs.dance_grace - w.tick),
		"thrown": bs.dance_throw,
		"anchor": anchor(w, i),
		"anchored": w.actors.pos(i) == anchor(w, i),
	}
