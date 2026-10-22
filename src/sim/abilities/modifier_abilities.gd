class_name ModifierAbilities
extends RefCounted
## The old abilities as weapon modifiers (v0.6.0 MX2; owner B7, docs/design/MODIFIER_ENGINE.md "The build"): when
## each one fires. What fires is the ability's compiled spec (Modifiers: the ability's v0.5 numbers at its level,
## carrying the weapon's statuses, elements and hooks), launched through Attacks; this file only says when and where.
## - Bomb Lobber: every `every_attacks`-th weapon attack (a combo step resolving, a shot) also lobs its bombs at the
##   densest clusters, once its cooldown is ready (the count waits for an enemy in range).
## - Arc Field: a weapon attack leaves a shock field where it ends (the Blade's arc tip; the Gun's aim point, at most
##   range_m away), at most once every level_cooldown.
## - Frost Nova: its modifier gives the weapon the frost element; `streak_kills` kills, each within streak_ticks of
##   the last, send a frost ring from the player (at most once every level_cooldown).
## - Flame Trail: a fire patch every ElementAbilities.TRAIL_SPACING_M of a dash, and one where a player projectile
##   ends (at most one every period_ticks).
## - Drone Buddy and Orbit Blades keep their own drivers (Abilities: the drones' timing, the orbit's turn).
## Also the RING runner (add_ring, advance_rings). No randomness here (EI-05).

## Where a Gun's field lands when the aim is closer than this (metres from the player).
const FIELD_MIN_M := 1.5


static func _slot(w: World, kind: int) -> int:
	for s in w.ability_owned.size():
		if w.ability_tables[w.ability_owned[s]].kind == kind:
			return s
	return -1


static func _ready(w: World, s: int) -> bool:
	return s >= 0 and (s >= w.ab.cd.size() or w.ab.cd[s] == 0)


static func _set_cd(w: World, s: int, ticks: int) -> void:
	if s < w.ab.cd.size():
		w.ab.cd[s] = Stats.auto_cooldown(w, ticks)  # Fast Hands applies


## A weapon attack just happened (PlayerKit: a combo step resolved, a shot fired), ending at `end`.
static func on_attack(w: World, end: Vector2) -> void:
	if w.ability_owned.is_empty() or w.player_dead():
		return
	var s := _slot(w, AbilityTable.Kind.BOMB_LOBBER)
	if s >= 0:
		var t := w.ability_tables[w.ability_owned[s]]
		w.ab.lob_count += 1
		if w.ab.lob_count >= t.every_attacks and _ready(w, s):
			if Abilities.throw_bombs(w, t, w.ability_levels[s]):
				w.ab.lob_count = 0
				_set_cd(w, s, t.cooldown_ticks)
	s = _slot(w, AbilityTable.Kind.ARC_FIELD)
	if s >= 0 and _ready(w, s):
		var t := w.ability_tables[w.ability_owned[s]]
		var spec := Modifiers.ability(w, t)
		if spec != null:
			var ctx := AttackContext.make(end, 0, spec.damage, 0, 0, spec.effect_id)
			Attacks.launch(w, spec, ctx)
			_set_cd(w, s, t.cooldown_at(w.ability_levels[s]))


## Where a shot's attack ends for the field: the aim point, between FIELD_MIN_M and `range_m` from the player.
static func shot_end(w: World, range_m: float) -> Vector2:
	var d := clampf(
		w.aim_dist_cm / 100.0, w.tuning.field_min_m, maxf(w.tuning.field_min_m, range_m)
	)
	return w.player_pos() + Kin.dir(w.aim_angle) * d


## The Arc Field's range (where a Gun's field may land), 0 without it.
static func field_range(w: World) -> float:
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.ARC_FIELD)
	return t.range_m if t != null else 0.0


## The player killed an enemy (Damage, a KILL): Frost Nova's streak.
static func on_kill(w: World) -> void:
	var s := _slot(w, AbilityTable.Kind.FROST_NOVA)
	if s < 0:
		return
	var t := w.ability_tables[w.ability_owned[s]]
	var st := w.ab
	if st.streak_last >= 0 and w.tick - st.streak_last <= t.streak_ticks:
		st.streak_n += 1
	else:
		st.streak_n = 1
	st.streak_last = w.tick
	if st.streak_n < t.streak_kills or not _ready(w, s):
		return
	var spec := Modifiers.ability(w, t)
	if spec == null:
		return
	st.streak_n = 0
	var at := w.player_pos()
	var ctx := AttackContext.make(at, 0, spec.damage, w.take_root(), 0, spec.effect_id)
	Attacks.launch(w, spec, ctx)
	st.nova_tick = w.tick
	st.nova_pos = at
	st.nova_r = Attacks.area_radius(w, spec)
	_set_cd(w, s, t.cooldown_at(w.ability_levels[s]))


## Tick phase 6 (Abilities.advance): Flame Trail's dash fire, then the rings grow.
static func advance(w: World) -> void:
	var s := _slot(w, AbilityTable.Kind.FLAME_TRAIL)
	if s >= 0:
		_dash_trail(w, w.ability_tables[w.ability_owned[s]])
	advance_rings(w)


## A patch once the dashing player is TRAIL_SPACING_M from the last one (the dash's first tick marks where it began).
static func _dash_trail(w: World, t: AbilityTable) -> void:
	var st := w.ab
	var p := w.player_pos()
	if not w.is_dashing():
		st.trail_tick = -1
		return
	if st.trail_tick < 0:
		st.trail_tick = w.tick
		st.trail_at = p
		return
	if Kin.length(p - st.trail_at) < w.tuning.fire_trail_spacing_m:
		return
	st.trail_tick = w.tick
	st.trail_at = p
	_fire(w, t, p)


static func _fire(w: World, t: AbilityTable, at: Vector2) -> void:
	var spec := Modifiers.ability(w, t)
	if spec != null:
		Attacks.launch(w, spec, AttackContext.make(at, 0, spec.damage, 0, 0, spec.effect_id))


## A player projectile ended at `at` (Attacks.on_projectile_end): Flame Trail leaves fire there, at most once every
## period_ticks.
static func on_projectile_end(w: World, at: Vector2) -> void:
	var s := _slot(w, AbilityTable.Kind.FLAME_TRAIL)
	if s < 0 or not _ready(w, s):
		return
	var t := w.ability_tables[w.ability_owned[s]]
	_fire(w, t, at)
	if s < w.ab.cd.size():
		w.ab.cd[s] = Stats.auto_cooldown(w, t.period_ticks)


# --- The RING runner ----------------------------------------------------------------------------------------------
## A ring of `spec` from `at` growing to `r` over the spec's life (Attacks.launch), dealing ctx.damage to each enemy
## its edge passes, at ctx's root and hook level. v0.8.0 AO: it starts growing `delay` ticks from now (WandRings: a
## pulse, a thrown ring; until then it waits, hitting nothing). v0.8.0 N3 (owner O47: "substituting the fireball for
## a shooting ring"): `travel` holds a travelling ring's flight (WandRings.launch: [velocity per tick, orbit radius,
## orbit start angle, pulses, life ticks, which ring of the launch]); empty: the plain ring that grows where it was
## cast, as before.
static func add_ring(
	w: World,
	at: Vector2,
	r: float,
	spec: AttackSpec,
	ctx: AttackContext,
	delay: int = 0,
	travel: Array = []
) -> void:
	var st := w.ab
	_pad_travel(st)
	var life := maxi(1, spec.life_ticks)
	if not travel.is_empty():
		life = maxi(1, int(travel[4]))
	st.ring_pos.append(at)
	st.ring_r.append(r)
	st.ring_start.append(w.tick + delay)
	st.ring_end.append(w.tick + delay + life)
	st.ring_dmg.append(ctx.damage)
	st.ring_root.append(ctx.root if ctx.root != 0 else w.take_root())
	st.ring_spec.append(spec.key)
	st.ring_depth.append(ctx.depth)
	st.ring_proc.append(ctx.proc_pct)
	st.ring_vel.append(travel[0] if not travel.is_empty() else Vector2.ZERO)
	st.ring_orb.append(float(travel[1]) if not travel.is_empty() else 0.0)
	st.ring_orb_a.append(int(travel[2]) if not travel.is_empty() else 0)
	st.ring_pulse.append(maxi(1, int(travel[3])) if not travel.is_empty() else 0)
	st.ring_k.append(int(travel[5]) if not travel.is_empty() else 0)


## v0.8.0 N3: a save from before N3 holds rings without the travel columns: they are plain rings (zeros).
static func _pad_travel(st: AbilityState) -> void:
	var n := st.ring_pos.size()
	if st.ring_pulse.size() == n and st.ring_k.size() == n:
		return
	st.ring_vel.resize(n)
	st.ring_orb.resize(n)
	st.ring_orb_a.resize(n)
	st.ring_pulse.resize(n)
	st.ring_k.resize(n)


## The radius ring k has grown to at tick `t` (a plain ring: linear from 0 over its life).
static func ring_radius(w: World, k: int, t: int) -> float:
	var st := w.ab
	if k < st.ring_pulse.size() and st.ring_pulse[k] > 0:
		return travel_radius(
			st.ring_r[k], st.ring_pulse[k], st.ring_end[k] - st.ring_start[k], t - st.ring_start[k]
		)
	var life := maxi(1, st.ring_end[k] - st.ring_start[k])
	return st.ring_r[k] * clampi(t - st.ring_start[k], 0, life) / life


## v0.8.0 N3: ring k's centre at tick `t` (a plain ring: where it was cast).
static func ring_centre(w: World, k: int, t: int) -> Vector2:
	var st := w.ab
	if k >= st.ring_pulse.size() or st.ring_pulse[k] <= 0:
		return st.ring_pos[k]
	return travel_centre(
		st.ring_pos[k], st.ring_vel[k], st.ring_orb[k], st.ring_orb_a[k], t - st.ring_start[k]
	)


## v0.8.0 N3 (WandRings, class doc): a travelling ring's radius `age` ticks after it left (fractional for the view):
## each of its `pulses` (its life split evenly) grows from WandRings.START_PERMILLE of `full` to `full` over at most
## WandRings.GROW_TICKS, so a pulsing ring's edge sweeps out again each pulse.
static func travel_radius(full: float, pulses: int, life: int, age: float) -> float:
	var seg := maxi(1, life / maxi(1, pulses))
	var grow := mini(WandRings.GROW_TICKS, seg)
	var a := maxf(0.0, age)
	var ph := fmod(a, float(seg)) if a < float(seg * maxi(1, pulses)) else float(seg)
	var f := clampf((ph + 1.0) / float(grow), 0.0, 1.0)
	var s := WandRings.START_PERMILLE / 1000.0
	return full * (s + (1.0 - s) * f)


## v0.8.0 N3: a travelling ring's centre `age` ticks after it left from `from` at `vel` per tick, circling its own
## travelling centre at `orb` metres (Swirl left of the Ring: the group spins as it flies), from angle `orb_a`.
static func travel_centre(
	from: Vector2, vel: Vector2, orb: float, orb_a: int, age: float
) -> Vector2:
	var a := maxf(0.0, age)
	var c := from + vel * a
	if orb > 0.0:
		c += Kin.dir((orb_a + int(a * WandRings.SPIN_PER_TICK)) & 4095) * orb
	return c


## Each ring grows one tick; an enemy whose near edge the ring's edge crossed this tick takes the hit (the first tick
## also hits what stands on the centre). A ring that reached its radius runs its ON_END hooks and goes. v0.8.0 N3: a
## travelling ring hits each enemy its disc passes over, once per pulse (_travel_step), and ends where its flight
## ends.
static func advance_rings(w: World) -> void:
	var st := w.ab
	if st.ring_pos.is_empty():
		return
	_pad_travel(st)
	var a := w.actors
	var book := Modifiers.book(w)
	var k := 0
	while k < st.ring_pos.size():
		if w.tick < st.ring_start[k]:  # v0.8.0 AO: a pulse or a thrown ring not started yet
			k += 1
			continue
		var at := st.ring_pos[k]
		var spec := book.find(st.ring_spec[k])
		if st.ring_pulse[k] > 0:  # v0.8.0 N3: a travelling ring
			at = _travel_step(w, k, spec)
		else:
			var now := ring_radius(w, k, w.tick)
			var before := ring_radius(w, k, w.tick - 1) if w.tick > st.ring_start[k] else -1.0
			if spec != null:
				var ctx := AttackContext.make(
					at,
					0,
					st.ring_dmg[k],
					st.ring_root[k],
					Attacks.lingering_tags(spec),
					spec.effect_id
				)
				ctx.depth = st.ring_depth[k]
				ctx.proc_pct = st.ring_proc[k]
				for i in w.enemies_near(at, now + 0.01):
					var edge := Kin.length(a.pos(i) - at) - a.radius[i]
					if a.invuln[i] == 0 and edge <= now and edge > before:
						Attacks.land(w, spec, ctx, i, at, a.pos(i))
		if w.tick >= st.ring_end[k]:
			if spec != null:
				var end_ctx := AttackContext.make(at, 0, st.ring_dmg[k], st.ring_root[k], 0, &"")
				end_ctx.depth = st.ring_depth[k]
				end_ctx.proc_pct = st.ring_proc[k]
				Attacks.run_on_end(w, spec, end_ctx, at)
			_remove_ring(st, k)
			continue
		k += 1


## v0.8.0 N3: one tick of travelling ring k: every enemy its disc covers now that this ring hasn't hit in this pulse
## takes the hit (once per ring and pulse: AbilityState.ring_seen). Returns its centre now.
static func _travel_step(w: World, k: int, spec: AttackSpec) -> Vector2:
	var st := w.ab
	var a := w.actors
	var c := ring_centre(w, k, w.tick)
	if spec == null:
		return c
	var now := ring_radius(w, k, w.tick)
	var pulses := maxi(1, st.ring_pulse[k])
	var seg := maxi(1, (st.ring_end[k] - st.ring_start[k]) / pulses)
	var tag := st.ring_k[k] * 8 + mini((w.tick - st.ring_start[k]) / seg, pulses - 1)
	var root := st.ring_root[k]
	var ctx := AttackContext.make(
		c, 0, st.ring_dmg[k], root, Attacks.lingering_tags(spec), spec.effect_id
	)
	ctx.depth = st.ring_depth[k]
	ctx.proc_pct = st.ring_proc[k]
	for i in w.enemies_near(c, now + 0.01):
		if a.invuln[i] != 0 or Kin.length(a.pos(i) - c) - a.radius[i] > now:
			continue
		if _seen(st, root, tag, a.ids[i]):
			continue
		st.ring_seen.append_array(PackedInt32Array([root, tag, a.ids[i]]))
		Attacks.land(w, spec, ctx, i, c, a.pos(i))
	return c


## v0.8.0 N3: whether the ring (root, tag) already hit actor id `id`.
static func _seen(st: AbilityState, root: int, tag: int, id: int) -> bool:
	var s := st.ring_seen
	var j := 0
	while j < s.size():
		if s[j] == root and s[j + 1] == tag and s[j + 2] == id:
			return true
		j += 3
	return false


## v0.8.0 N3: ring k is going; when no other ring of its root travels on, its hits are forgotten.
static func _forget(st: AbilityState, k: int) -> void:
	if st.ring_seen.is_empty():
		return
	var root := st.ring_root[k]
	for j in st.ring_root.size():
		if j != k and st.ring_root[j] == root and st.ring_pulse[j] > 0:
			return
	var kept := PackedInt32Array()
	var j := 0
	while j < st.ring_seen.size():
		if st.ring_seen[j] != root:
			kept.append_array(st.ring_seen.slice(j, j + 3))
		j += 3
	st.ring_seen = kept


static func _remove_ring(st: AbilityState, k: int) -> void:
	_forget(st, k)  # v0.8.0 N3
	st.ring_pos.remove_at(k)
	st.ring_r.remove_at(k)
	st.ring_start.remove_at(k)
	st.ring_end.remove_at(k)
	st.ring_dmg.remove_at(k)
	st.ring_root.remove_at(k)
	st.ring_spec.remove_at(k)
	st.ring_depth.remove_at(k)
	st.ring_proc.remove_at(k)
	st.ring_vel.remove_at(k)  # v0.8.0 N3 (advance_rings padded them first)
	st.ring_orb.remove_at(k)
	st.ring_orb_a.remove_at(k)
	st.ring_pulse.remove_at(k)
	st.ring_k.remove_at(k)


## The rings growing now, for the view: [centre, radius now] each (v0.8.0 N3: a travelling ring's centre now).
static func rings_now(w: World) -> Array:
	var out := []
	for k in w.ab.ring_pos.size():
		out.append([ring_centre(w, k, w.tick), ring_radius(w, k, w.tick)])
	return out
