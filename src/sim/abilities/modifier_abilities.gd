class_name ModifierAbilities
extends RefCounted
## The RING runner (add_ring, advance_rings), the form every ring attack runs.
## the old abilities that fired as weapon modifiers (Bomb Lobber, Arc Field, Frost Nova, Flame Trail) are gone, and
## their triggers with them. No randomness here (EI-05).

## Where a Gun's field lands when the aim is closer than this (metres from the player; SimTuning.field_min_m).
const FIELD_MIN_M := 1.5


## Tick phase 6 (Abilities.advance): the rings grow.
static func advance(w: World) -> void:
	advance_rings(w)


# --- The RING runner ----------------------------------------------------------------------------------------------
## A ring of `spec` from `at` growing to `r` over the spec's life (Attacks.launch), dealing ctx.damage to each enemy
## its edge passes, at ctx's root and hook level. it starts growing `delay` ticks from now (WandRings: a
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


## A save from before N3 holds rings without the travel columns: they are plain rings (zeros).
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


## Ring k's centre at tick `t` (a plain ring: where it was cast).
static func ring_centre(w: World, k: int, t: int) -> Vector2:
	var st := w.ab
	if k >= st.ring_pulse.size() or st.ring_pulse[k] <= 0:
		return st.ring_pos[k]
	return travel_centre(
		st.ring_pos[k], st.ring_vel[k], st.ring_orb[k], st.ring_orb_a[k], t - st.ring_start[k]
	)


## WandRings, class doc: a travelling ring's radius `age` ticks after it left (fractional for the view):
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


## A travelling ring's centre `age` ticks after it left from `from` at `vel` per tick, circling its own
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
## also hits what stands on the centre). A ring that reached its radius runs its ON_END hooks and goes. a
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
		if w.tick < st.ring_start[k]:  # A pulse or a thrown ring not started yet
			k += 1
			continue
		var at := st.ring_pos[k]
		var spec := book.find(st.ring_spec[k])
		if st.ring_pulse[k] > 0:  # A travelling ring
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


## One tick of travelling ring k: every enemy its disc covers now that this ring hasn't hit in this pulse
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


## Whether the ring (root, tag) already hit actor id `id`.
static func _seen(st: AbilityState, root: int, tag: int, id: int) -> bool:
	var s := st.ring_seen
	var j := 0
	while j < s.size():
		if s[j] == root and s[j + 1] == tag and s[j + 2] == id:
			return true
		j += 3
	return false


## Ring k is going; when no other ring of its root travels on, its hits are forgotten.
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


## The rings growing now, for the view: [centre, radius now] each (a travelling ring's centre now).
static func rings_now(w: World) -> Array:
	var out := []
	for k in w.ab.ring_pos.size():
		out.append([ring_centre(w, k, w.tick), ring_radius(w, k, w.tick)])
	return out
