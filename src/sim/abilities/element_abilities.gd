class_name ElementAbilities
extends RefCounted
## Arc Field, Frost Nova and Flame Trail (v0.4.0 AB, PLAN "Abilities"): three auto abilities that feed the v0.3.0
## status engines (Engines): shock stacks discharge at the threshold, frost stacks freeze, burn stacks tick as DoT.
## Each borrows its engine's numbers (threshold, how long stacks last, the discharge, the freeze, the burn) from an
## item (AbilityTable.engine): fold_engines folds them into World.item_mods, the stronger value winning, so an owned
## item of the same engine still counts and the engine code stays the one place a status works.
## v0.6.0 MX2 (owner B7): they are weapon modifiers now, launched from their specs (ModifierAbilities says when):
## - Arc Field: your weapon attacks leave a shock field (form ZONE) where they end.
## - Frost Nova: the frost element on your weapon, and a frost ring (form RING) on a kill streak.
## - Flame Trail: your dash and your projectiles leave fire (form ZONE).
## This file keeps the patches (the ZONE form's runner): add_zone lights one for a spec, add_fire for Napalm Drone
## (the combo's own numbers); advance_fire puts them out and burns what stands in them. An enemy in a patch is hit
## at most once every period_ticks of that patch's spec (Flame Trail's hit_ticks; FIRE_HIT_TICKS without one), per
## patch kind, whatever patch of that kind it stands in; a field hits at most its spec's `count` enemies a tick. Each
## patch hit is its own root, the player's (TAG_AREA | TAG_ABILITY for an ability's: stats and crit apply, never
## heat), and runs its spec (statuses, hooks: Attacks.land).

const EFFECT_ARC := &"arc_field"
const EFFECT_NOVA := &"frost_nova"
const EFFECT_FLAME := &"flame_trail"
## Fire patch kinds (AbilityState.fire_kind): Flame Trail's, Napalm Drone's, v0.6.0 MX2 Arc Field's shock field and
## any other spec's patch (a hook's zone).
const FIRE_TRAIL := 0
const FIRE_NAPALM := 1
const FIRE_FIELD := 2
const FIRE_ZONE := 3
## A trail patch falls once the player is this far from the last one.
const TRAIL_SPACING_M := 0.8
## The most patches burning at once (the oldest goes out first).
const FIRE_CAP := 48
## Ticks between patch hits on one enemy when the patch's spec names none (Napalm Drone always comes with Flame
## Trail).
const FIRE_HIT_TICKS := 30


## World.item_mods after the items: the engine numbers each owned ability borrows (ItemMods.fold_engine).
static func fold_engines(w: World, m: ItemMods) -> void:
	for idx in w.ability_owned:
		if idx < w.ability_tables.size() and w.ability_tables[idx].engine != null:
			ItemMods.fold_engine(m, w.ability_tables[idx].engine)


## The kind a patch of `spec` is (the view's colour, the hit gap's key).
static func kind_of(spec: AttackSpec) -> int:
	if spec.has_tag(&"trail"):
		return FIRE_TRAIL
	if spec.has_tag(&"field"):
		return FIRE_FIELD
	return FIRE_ZONE


## v0.6.0 MX2, the ZONE runner (Attacks): a patch of `spec` at `at` (radius `r`, `life` ticks) dealing ctx.damage a
## hit, at ctx's hook level.
static func add_zone(
	w: World, at: Vector2, r: float, life: int, spec: AttackSpec, ctx: AttackContext
) -> void:
	add_fire(w, at, r, w.tick + life, ctx.damage, 0, kind_of(spec))
	var s := w.ab
	var k := s.fire_pos.size() - 1
	s.fire_spec[k] = spec.key
	s.fire_depth[k] = ctx.depth
	s.fire_proc[k] = ctx.proc_pct
	s.fire_cap[k] = spec.count if spec.has_tag(&"field") else 0


## Lights a fire patch (Flame Trail, Napalm Drone); past FIRE_CAP the oldest goes out.
static func add_fire(
	w: World, at: Vector2, r: float, end_tick: int, dmg: int, stacks: int, kind: int
) -> void:
	var s := w.ab
	if s.fire_pos.size() >= FIRE_CAP:
		_remove_fire(s, 0)
	s.fire_pos.append(at)
	s.fire_r.append(r)
	s.fire_end.append(end_tick)
	s.fire_dmg.append(dmg)
	s.fire_stacks.append(stacks)
	s.fire_kind.append(kind)
	s.fire_spec.append("")  # v0.6.0 MX2: add_zone names the spec
	s.fire_depth.append(0)
	s.fire_proc.append(100)
	s.fire_cap.append(0)


static func _remove_fire(s: AbilityState, k: int) -> void:
	s.fire_pos.remove_at(k)
	s.fire_r.remove_at(k)
	s.fire_end.remove_at(k)
	s.fire_dmg.remove_at(k)
	s.fire_stacks.remove_at(k)
	s.fire_kind.remove_at(k)
	if k < s.fire_spec.size():
		s.fire_spec.remove_at(k)
		s.fire_depth.remove_at(k)
		s.fire_proc.remove_at(k)
		s.fire_cap.remove_at(k)


## Tick phase 6: patches go out, then each hits the enemies standing in it (oldest patch first; an enemy is hit once
## per its patch's gap per patch kind, whatever patch of that kind it stands in; a field at most its cap a tick).
static func advance_fire(w: World) -> void:
	var s := w.ab
	if s.fire_pos.is_empty() and s.fire_ids.is_empty():
		return
	for k in range(s.fire_pos.size() - 1, -1, -1):
		if s.fire_end[k] <= w.tick:
			_remove_fire(s, k)
	for k in range(s.fire_ids.size() - 1, -1, -1):
		if s.fire_next[k] <= w.tick:
			s.fire_ids.remove_at(k)
			s.fire_next.remove_at(k)
	var a := w.actors
	var pid := a.ids[0]
	var book := Modifiers.book(w) if not s.fire_spec.is_empty() else null
	for k in s.fire_pos.size():
		var at := s.fire_pos[k]
		var key := s.fire_spec[k] if k < s.fire_spec.size() else ""
		var spec := book.find(key) if key != "" else null
		var kind := s.fire_kind[k]
		var gap := fire_hit_ticks(w)
		if spec != null and spec.period_ticks > 0:
			gap = spec.period_ticks
		var cap := s.fire_cap[k] if k < s.fire_cap.size() else 0
		var hit := 0
		for i in w.enemies_near(at, s.fire_r[k]):
			var mark := a.ids[i] * 4 + kind
			if a.invuln[i] > 0 or a.dead[i] == 1 or s.fire_ids.has(mark):
				continue
			if cap > 0 and hit >= cap:
				break
			hit += 1
			s.fire_ids.append(mark)
			s.fire_next.append(w.tick + gap)
			var root := w.take_root()
			if spec == null:  # Napalm Drone: the combo's numbers
				var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
				var effect := EFFECT_FLAME if kind == FIRE_TRAIL else AbilityCombos.EFFECT_NAPALM
				if Damage.hit(w, i, s.fire_dmg[k], pid, pid, root, tags, at, a.pos(i), effect) > 0:
					Engines.add_burn(w, i, s.fire_stacks[k], root, effect)
				continue
			var dmg := s.fire_dmg[k]
			var effect := spec.effect_id
			if kind == FIRE_FIELD:  # v0.4.0 AB: Superconductor raises a field's hit on a chilled enemy
				var up := AbilityCombos.arc_damage(w, i, dmg)
				if up != dmg:
					effect = AbilityCombos.EFFECT_SUPER
					s.arc_super = 1
				dmg = up
			var ctx := AttackContext.make(at, 0, dmg, root, Attacks.lingering_tags(spec), effect)
			ctx.depth = s.fire_depth[k]
			ctx.proc_pct = s.fire_proc[k]
			Attacks.land(w, spec, ctx, i, at, a.pos(i))


## Ticks between two fire hits on one enemy without a spec gap: Flame Trail's hit_ticks.
static func fire_hit_ticks(w: World) -> int:
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.FLAME_TRAIL)
	return t.hit_ticks if t != null and t.hit_ticks > 0 else FIRE_HIT_TICKS


# --- Reads --------------------------------------------------------------------------------------------------------
## What the views draw (WorldReader.element_fx): the last arc strike (none since MX2), the last nova, the patches
## (with their kind and how much of their life is left, 0..1000), the rings growing now and the combos' last moments.
static func fx(w: World) -> Dictionary:
	var s := w.ab
	var left := PackedInt32Array()
	for k in s.fire_pos.size():
		left.append(clampi((s.fire_end[k] - w.tick) * 1000 / maxi(1, _fire_life(w, k)), 0, 1000))
	return {
		"arc_tick": s.arc_tick,
		"arc_from": s.arc_from,
		"arc_to": s.arc_to,
		"arc_super": s.arc_super == 1,
		"nova_tick": s.nova_tick,
		"nova_pos": s.nova_pos,
		"nova_r": s.nova_r,
		"fire_pos": s.fire_pos,
		"fire_r": s.fire_r,
		"fire_kind": s.fire_kind,
		"fire_left": left,
		"rings": ModifierAbilities.rings_now(w),  # v0.6.0 MX2: [centre, radius now] per ring
		"storm_tick": s.storm_tick,
		"storm_from": s.storm_from,
		"storm_to": s.storm_to,
		"ward_tick": s.ward_tick,
		"ward_pos": s.ward_pos,
		"ward_r": s.ward_r,
		"charge_tick": s.charge_tick,
		"charge_pos": s.charge_pos,
		"glacier_tick": s.glacier_tick,
		"wing_tick": s.wing_tick,
		"dancing": AbilityCombos.dancing(w),
		"glacier": Engines.has_combo(w, ComboTable.Effect.GLACIER_RING),
	}


## A patch's full life (for the fade): its spec's, or Napalm Drone's.
static func _fire_life(w: World, k: int) -> int:
	if w.ab.fire_kind[k] == FIRE_NAPALM:
		var c := Engines.combo(w, ComboTable.Effect.NAPALM_DRONE)
		return c.window_ticks if c != null else 1
	var key := w.ab.fire_spec[k] if k < w.ab.fire_spec.size() else ""
	var spec := Modifiers.book(w).find(key) if key != "" else null
	if spec != null and spec.life_ticks > 0:
		return spec.life_ticks
	return Modifiers.HOOK_ZONE_TICKS
