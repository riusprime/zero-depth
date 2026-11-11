class_name NativeStrike
extends RefCounted
## The enemies' strikes (tick phase 6's per-enemy loop), run by the native side (World.native): ZdWorld.strike
## (native/src/zd_strike.cpp) tests every table row's hit shape on its tick against the hero (contact, the locked disc,
## the bash lane, the snipe lane, the rune, a lobbed burst's landing), with the sight test, and counts the Needle's
## burst and a pattern's waves, for the rows whose kind the per-kind table runs (NativeKindTable: NATIVE and HOOKED,
## the critters' touch too). It reads the store and writes nothing: it hands back a list, ascending by row and then by
## code, applied below in that order: the damage, the counters that spend a hit or a shot (fire_cd, a critter's cd),
## the bolts, the pattern waves and the hooked kinds' own rules (EnemyAi._fire, fire_wave, _resolve_horde). Every
## random draw stays here.
## The order: the table rows' strikes, then the rows GDScript runs (bosses, elites, signatures, eggs:
## ZdWorld.rows_for_script; BossAi.resolve, EnemyAi.resolve), then every critter's touch. A row's entries wait on the
## hero alive, the row alive and not frozen when they are applied, as the per-enemy checks do.
## No local here holds a store column across a native call: each read goes through the store again.

## The list's codes (zd_strike.h StrikeOut).
enum Out {
	HIT = 1,  # a = damage, b = tags; (f0, f1) the origin when f2 is 1, else the body
	CONTACT = 2,  # fire_cd = 1, then the hit when b (seen) is 1
	TOUCH = 3,  # a critter's touch: cd = contact_cd_ticks, then the hit when b (seen) is 1
	BOLT = 4,  # a = the shot's angle, b = its index in the burst
	WAVE = 5,  # a = the wave, b = the pattern slot
	ACTIVE_HOOK = 6,  # EnemyAi._resolve_horde runs the kind's own rule
}
const STRIDE := 4


## Phase 6's enemy strikes for world w.
static func resolve(w: World) -> void:
	if not NativeAi.ready(w):
		return
	var a := w.actors
	var m: Object = w.native
	var n: int = m.strike(a, NativeAi.hero_of(w))
	if n < 0:
		push_error("NativeStrike: the native side refused strike")
		return
	var ii := PackedInt32Array()
	var ff := PackedFloat32Array()
	if n > 0:
		ii = m.strike_out_i()
		ff = m.strike_out_f()
		_apply(w, ii, ff, false)
	for i in m.rows_for_script(a):
		if a.dead[i] != 0:
			continue
		match EnemyAi.role_of(a.kinds[i]):
			EnemyAi.Role.BOSS:
				BossAi.resolve(w, i)
			EnemyAi.Role.ENEMY, EnemyAi.Role.CRITTER:
				EnemyAi.resolve(w, i)
	if n > 0:
		_apply(w, ii, ff, true)


## The list's entries: the critters' touches only (touches) or every other entry.
static func _apply(w: World, ii: PackedInt32Array, ff: PackedFloat32Array, touches: bool) -> void:
	var a := w.actors
	var row := -1
	var skip := false
	for k in range(0, ii.size(), STRIDE):
		var code := ii[k]
		if (code == Out.TOUCH) != touches:
			continue
		var i := ii[k + 1]
		if i != row:
			row = i
			if w.player_dead():
				return
			skip = a.dead[i] != 0 or Engines.frozen(w, i)
		if skip:
			continue
		match code:
			Out.HIT:
				var from := Vector2(ff[k], ff[k + 1]) if ff[k + 2] != 0.0 else a.pos(i)
				_hit(w, i, ii[k + 2], ii[k + 3], from)
			Out.CONTACT:
				a.fire_cd[i] = 1
				if ii[k + 3] != 0:
					_hit(w, i, ii[k + 2], SimEvent.TAG_MELEE, a.pos(i))
			Out.TOUCH:
				a.cd[i] = w.enemy_table(a.kinds[i]).contact_cd_ticks
				if ii[k + 3] != 0:
					_hit(w, i, ii[k + 2], SimEvent.TAG_MELEE, a.pos(i))
			Out.BOLT:
				var t := w.enemy_table(a.kinds[i])
				a.fire_cd[i] += 1
				EnemyAi._fire(
					w, i, ii[k + 2], t.bolt_speed, t.bolt_radius_m, t.bolt_life_ticks, t.damage
				)
				if a.kinds[i] == ActorStore.Kind.DIM_NEEDLE:  # Dark until near (Variants)
					w.set_pending_look(Variants.DIM_LOOK)
				BossRicochet.arm_turret(w, i)  # Phase 3's turrets ricochet too
			Out.WAVE:
				var t := w.enemy_table(a.kinds[i])
				var pat := EnemyAi.pattern_of(w, i)
				if pat != null:
					EnemyAi.fire_wave(w, i, t, pat, ii[k + 2])
			Out.ACTIVE_HOOK:
				var t := w.enemy_table(a.kinds[i])
				EnemyAi._resolve_horde(w, i, t, w.player_pos(), w.player.radius_m)


## EnemyAi._hit_player after its sight test (the native side ran it from the same origin).
static func _hit(w: World, i: int, amount: int, tags: int, from: Vector2) -> void:
	var a := w.actors
	Damage.hit(
		w,
		0,
		EnemyAi.powered(w, i, amount),
		a.ids[i],
		a.ids[i],
		w.take_root(),
		tags,
		from,
		w.player_pos()
	)
