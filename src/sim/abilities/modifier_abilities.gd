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
	var d := clampf(w.aim_dist_cm / 100.0, FIELD_MIN_M, maxf(FIELD_MIN_M, range_m))
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
	if Kin.length(p - st.trail_at) < ElementAbilities.TRAIL_SPACING_M:
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
## its edge passes, at ctx's root and hook level.
static func add_ring(w: World, at: Vector2, r: float, spec: AttackSpec, ctx: AttackContext) -> void:
	var st := w.ab
	st.ring_pos.append(at)
	st.ring_r.append(r)
	st.ring_start.append(w.tick)
	st.ring_end.append(w.tick + maxi(1, spec.life_ticks))
	st.ring_dmg.append(ctx.damage)
	st.ring_root.append(ctx.root if ctx.root != 0 else w.take_root())
	st.ring_spec.append(spec.key)
	st.ring_depth.append(ctx.depth)
	st.ring_proc.append(ctx.proc_pct)


## The radius ring k has grown to at tick `t`.
static func ring_radius(w: World, k: int, t: int) -> float:
	var st := w.ab
	var life := maxi(1, st.ring_end[k] - st.ring_start[k])
	return st.ring_r[k] * clampi(t - st.ring_start[k], 0, life) / life


## Each ring grows one tick; an enemy whose near edge the ring's edge crossed this tick takes the hit (the first tick
## also hits what stands on the centre). A ring that reached its radius runs its ON_END hooks and goes.
static func advance_rings(w: World) -> void:
	var st := w.ab
	if st.ring_pos.is_empty():
		return
	var a := w.actors
	var book := Modifiers.book(w)
	var k := 0
	while k < st.ring_pos.size():
		var at := st.ring_pos[k]
		var spec := book.find(st.ring_spec[k])
		var now := ring_radius(w, k, w.tick)
		var before := ring_radius(w, k, w.tick - 1) if w.tick > st.ring_start[k] else -1.0
		if spec != null:
			var ctx := AttackContext.make(
				at, 0, st.ring_dmg[k], st.ring_root[k], Attacks.lingering_tags(spec), spec.effect_id
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


static func _remove_ring(st: AbilityState, k: int) -> void:
	st.ring_pos.remove_at(k)
	st.ring_r.remove_at(k)
	st.ring_start.remove_at(k)
	st.ring_end.remove_at(k)
	st.ring_dmg.remove_at(k)
	st.ring_root.remove_at(k)
	st.ring_spec.remove_at(k)
	st.ring_depth.remove_at(k)
	st.ring_proc.remove_at(k)


## The rings growing now, for the view: [centre, radius now] each.
static func rings_now(w: World) -> Array:
	var out := []
	for k in w.ab.ring_pos.size():
		out.append([w.ab.ring_pos[k], ring_radius(w, k, w.tick)])
	return out
