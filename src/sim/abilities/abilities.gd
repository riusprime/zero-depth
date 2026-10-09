# gdlint: disable=max-public-methods
class_name Abilities
extends RefCounted
## The abilities (v0.4.0 BS, owner F8, F11; v0.6.0 MX2, owner B7). World.ability_owned holds the compiled ability
## indices held, in the order taken, and World.ability_levels their levels (1..5); both last the run (RunCarry). The
## first is the starting weapon (grant_start). MX2: the four ability slots are gone; the build is the weapon, one
## utility pick and six modifier slots (BuildSlots, World.mod_slots): the six auto abilities are weapon modifiers
## (each takes a slot; a card for one you hold levels it up), Blink and Aegis share the utility button outside the
## slots, so owning one keeps the other out of the offers. The auto abilities launch their attacks from their
## compiled specs (Modifiers: each carries the weapon's statuses, elements and hooks; Attacks runs them).
## - Manual: Combo Sword and Pulse Gun scale the build's weapon and skill (weapon_permille, reach, pierce, twin
##   bolts, the finisher's shockwave); Blink and Aegis turn the utility button on (utility()).
## - Auto (tick phase 6, after the projectile sweeps, so the uniform grid holds this tick's bodies): Bomb Lobber,
##   Drone Buddy and Orbit Blades pick targets by sim rules (densest cluster, nearest enemy, touch) through
##   World.enemies_near; the only randomness (a spare bomb's scatter) comes from the `ability` stream.
## Every hit is the player's, so stats and crit apply in Damage.hit; ability hits carry TAG_ABILITY and an effect id
## (never heat, never an on-hit "attack").
## v0.4.0 AB: Arc Field, Frost Nova and Flame Trail (ElementAbilities) and the eight ability combos (AbilityCombos);
## taking a card refreshes the build (World.refresh_build: the engines the abilities borrow, combos evolving).

const BLADE_R := 0.35
const BOLT_RADIUS_M := 0.12
## Twin bolts (Pulse Gun L5): each shot's bolts split this far either side of the aim (1/4096 turns).
const TWIN_SPREAD := 40
## A drone with no target looks again after this many ticks.
const DRONE_IDLE_TICKS := 6
## Drones trail this far behind the player, this far apart (1/4096 turns), closing this share of the gap a tick.
const DRONE_TRAIL_M := 1.1
const DRONE_SPREAD := 640
const DRONE_FOLLOW_PERMILLE := 150
## Bomb landings the view remembers.
const BLAST_LOG := 8
const EFFECT_BOMB := &"bomb_lobber"
const EFFECT_DRONE := &"drone_buddy"
const EFFECT_DRONE_CHAIN := &"drone_chain"
const EFFECT_ORBIT := &"orbit_blades"
const EFFECT_BLINK := &"blink_shock"
const EFFECT_SWORD_WAVE := &"combo_sword_wave"


# --- Ownership -------------------------------------------------------------------------------------------------
static func owned(w: World, idx: int) -> bool:
	return w.ability_owned.has(idx)


## The level of ability `idx` (0 = not owned).
static func level_of(w: World, idx: int) -> int:
	var s := w.ability_owned.find(idx)
	return w.ability_levels[s] if s >= 0 else 0


## The compiled index of the first ability of `kind`, or -1.
static func index_of_kind(w: World, kind: int) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].kind == kind:
			return k
	return -1


## The owned ability of `kind` (its table), or null.
static func owned_of_kind(w: World, kind: int) -> AbilityTable:
	for idx in w.ability_owned:
		if w.ability_tables[idx].kind == kind:
			return w.ability_tables[idx]
	return null


static func level_of_kind(w: World, kind: int) -> int:
	for s in w.ability_owned.size():
		if w.ability_tables[w.ability_owned[s]].kind == kind:
			return w.ability_levels[s]
	return 0


## A card for ability `idx` would do something now: a level-up of one you own below the top level, or a new one
## (never a starting weapon, never a second utility). v0.6.0 MX2: a new modifier is offered with the six slots full
## too: taking it opens the swap (BuildSlots).
static func can_take(w: World, idx: int) -> bool:
	var s := w.ability_owned.find(idx)
	if s >= 0:
		return w.ability_levels[s] < AbilityTable.MAX_LEVEL
	var t := w.ability_tables[idx]
	if t.start_weapon != 0:
		return false
	return not (t.is_utility() and utility(w) != PlayerTable.Utility.NONE)


## Takes an ability card: a level up of an owned ability, or a new one at level 1 (v0.6.0 MX2: a new modifier only
## while a modifier slot is free; BuildSlots.take swaps one out first). Returns false (and changes nothing) when the
## card can't apply.
static func grant(w: World, idx: int) -> bool:
	var t := w.ability_tables[idx]
	var s := w.ability_owned.find(idx)
	if s >= 0:
		if w.ability_levels[s] >= AbilityTable.MAX_LEVEL:
			return false
		w.ability_levels[s] += 1
	else:
		if t.is_modifier() and BuildSlots.full(w):
			return false
		if t.is_utility() and utility(w) != PlayerTable.Utility.NONE:
			return false
		w.ability_owned.append(idx)
		w.ability_levels.append(1)
		w.ab.cd.append(0)
	BuildSlots.sync(w)  # v0.6.0 MX2: a new modifier takes the next slot
	_sync_state(w)
	w.refresh_build(true)  # v0.4.0 AB: borrowed engines; a pair at L3 evolves (its combo card)
	if t.kind == AbilityTable.Kind.BLINK:
		w.ab.blink_charges = mini(w.ab.blink_charges + 1, t.extra(level_of(w, idx)))
	return true


## Slot 1 at the start of a run: the ability whose start weapon the build uses (none outside a build).
static func grant_start(w: World) -> void:
	if not w.ability_owned.is_empty():
		return
	for k in w.ability_tables.size():
		var t := w.ability_tables[k]
		if t.start_weapon != 0 and (t.start_weapon & w.player.weapons) == t.start_weapon:
			if w.player.weapons != PlayerTable.WEAPONS_ALL:
				grant(w, k)
				return


## v0.6.0 MX2: ability slot `s` (World.ability_owned order) leaves the build: its level, cooldown and its own floor
## state go; the combos it completed go too, and the build refreshes (BuildSlots.drop, Shop.salvage_ability).
static func remove_slot(w: World, s: int) -> void:
	var t := w.ability_tables[w.ability_owned[s]]
	w.ability_owned.remove_at(s)
	w.ability_levels.remove_at(s)
	if s < w.ab.cd.size():
		w.ab.cd.remove_at(s)
	match t.kind:
		AbilityTable.Kind.DRONE_BUDDY:
			w.ab.drone_pos = PackedVector2Array()
			w.ab.drone_cd = PackedInt32Array()
			w.ab.drone_fire = PackedInt32Array()
		AbilityTable.Kind.BLINK:
			w.ab.blink_charges = 0
			w.blink_cd = 0
		AbilityTable.Kind.ORBIT_BLADES:
			w.ab.orbit_ids = PackedInt32Array()
			w.ab.orbit_next = PackedInt32Array()
	var keep := PackedInt32Array()
	var earned := Engines.combos_for(w.combo_tables, w.items_owned)
	earned.append_array(AbilityCombos.earned(w))
	for c in w.combos_owned:
		if earned.has(c):
			keep.append(c)
	w.combos_owned = keep
	BuildSlots.sync(w)
	w.refresh_build(false)


## A fresh floor (after the carry restored the slots and levels): cooldowns, drones and the blink's charges start
## over.
static func start_floor(w: World) -> void:
	if w.migrate_slots:  # v0.6.0 MX2: a carry from before the slots (RunCarry.apply)
		w.migrate_slots = false
		BuildSlots.migrate(w)
	else:
		BuildSlots.sync(w)
	w.ab = AbilityState.new()
	for s in w.ability_owned.size():
		w.ab.cd.append(0)
	_sync_state(w)
	var blink := owned_of_kind(w, AbilityTable.Kind.BLINK)
	if blink != null:
		w.ab.blink_charges = blink.extra(level_of_kind(w, AbilityTable.Kind.BLINK))
	w.refresh_build(false)  # v0.4.0 AB: after the carry restored the slots


## Keeps the drones in step with Drone Buddy's level (a new drone starts beside the player, half a period late).
static func _sync_state(w: World) -> void:
	var t := owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	var n := t.count(level_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)) if t != null else 0
	while w.ab.drone_pos.size() < n:
		w.ab.drone_pos.append(w.player_pos())
		w.ab.drone_cd.append(drone_period(w, t) * w.ab.drone_pos.size() / 2)
		w.ab.drone_fire.append(-1)


# --- The utility button (Blink, Aegis) -------------------------------------------------------------------------
## The utility the player has now: the forced loadout's (PlayerTable.utility: tests, the dev runs of old), else an
## owned Blink or Aegis (v0.4.0 F11: none at the start of a run).
static func utility(w: World) -> int:
	if w.player.utility != PlayerTable.Utility.NONE:
		return w.player.utility
	for idx in w.ability_owned:
		match w.ability_tables[idx].kind:
			AbilityTable.Kind.BLINK:
				return PlayerTable.Utility.BLINK
			AbilityTable.Kind.AEGIS:
				return PlayerTable.Utility.GUARD
	return PlayerTable.Utility.NONE


## The Blink ability when it drives the blink (the forced loadout's blink keeps the player table's numbers).
static func _blink(w: World) -> AbilityTable:
	if w.player.utility != PlayerTable.Utility.NONE:
		return null
	return owned_of_kind(w, AbilityTable.Kind.BLINK)


static func blink_range_m(w: World) -> float:
	var t := _blink(w)
	return t.range_m if t != null else w.player.blink_range_m


static func blink_iframes(w: World) -> int:
	var t := _blink(w)
	return t.duration_ticks if t != null else w.player.blink_iframe_ticks


## The blink's cooldown in ticks (per charge for the ability), under the cooldowns stat.
static func blink_cooldown(w: World) -> int:
	var t := _blink(w)
	if t == null:
		return Stats.cooldown(w, w.player.blink_cooldown_ticks)
	return Stats.cooldown(w, t.cooldown_at(level_of_kind(w, AbilityTable.Kind.BLINK)))


static func blink_charge_max(w: World) -> int:
	var t := _blink(w)
	return t.extra(level_of_kind(w, AbilityTable.Kind.BLINK)) if t != null else 1


## A blink may start now (the cooldown or, for the ability, a charge).
static func blink_ready(w: World) -> bool:
	return w.ab.blink_charges > 0 if _blink(w) != null else w.blink_cd == 0


## Phase 4, before the blink: the cooldown runs; the ability's charge comes back as it ends (and the next starts).
static func recharge_blink(w: World) -> void:
	if w.blink_cd > 0:
		w.blink_cd -= 1
		if w.blink_cd == 0 and _blink(w) != null:
			w.ab.blink_charges = mini(w.ab.blink_charges + 1, blink_charge_max(w))
			if w.ab.blink_charges < blink_charge_max(w):
				w.blink_cd = blink_cooldown(w)


## A blink just landed: spend the cooldown or a charge, and arm the ability's landing shock (phase 6).
static func on_blink(w: World) -> void:
	if _blink(w) == null:
		w.blink_cd = blink_cooldown(w)
		return
	w.ab.blink_charges -= 1
	if w.blink_cd == 0:
		w.blink_cd = blink_cooldown(w)
	w.ab.shock_pending = w.tick
	AbilityMods.on_blink(w)  # v0.5.0 CP: Afterimage
	ModifierRuntime.on_blink(w)  # v0.6.0 MX4: the blink spec's other hooks
	AbilityCombos.on_blink(w)  # v0.4.0 AB: Blink Charge


## Aegis: the most guard charges the guard stores, and each one's bonus to the next swing (per mille); a Bulwark
## item's numbers when they are higher.
static func charge_max(w: World) -> int:
	var t := owned_of_kind(w, AbilityTable.Kind.AEGIS)
	var n := t.extra(level_of_kind(w, AbilityTable.Kind.AEGIS)) if t != null else 0
	return maxi(w.item_mods.charge_max, n)


static func charge_bonus(w: World) -> int:
	var t := owned_of_kind(w, AbilityTable.Kind.AEGIS)
	return maxi(w.item_mods.charge_bonus_permille, t.damage if t != null else 0)


# --- The starting weapons (Combo Sword, Pulse Gun) -------------------------------------------------------------
## The build weapon's ability (slot 1) and its level, or null.
static func _weapon(w: World) -> AbilityTable:
	for idx in w.ability_owned:
		var t := w.ability_tables[idx]
		if t.start_weapon != 0 and (t.start_weapon & w.player.weapons) != 0:
			return t
	return null


static func _weapon_level(w: World) -> int:
	var t := _weapon(w)
	return level_of(w, w.ability_tables.find(t)) if t != null else 0


## The weapon ability's damage factor (per mille) on the build's swings, bolts and skill.
static func weapon_permille(w: World) -> int:
	var t := _weapon(w)
	return t.damage_permille(_weapon_level(w)) if t != null else 1000


## Combo Sword's reach factor (per mille) on the swings.
static func reach_permille(w: World) -> int:
	var t := _weapon(w)
	if t == null or t.kind != AbilityTable.Kind.COMBO_SWORD:
		return 1000
	return t.radius_permille(_weapon_level(w))


## Pulse Gun L3+: its bolts pierce one enemy.
static func bolt_tags(w: World) -> int:
	var t := _weapon(w)
	if t == null or t.kind != AbilityTable.Kind.PULSE_GUN or t.extra(_weapon_level(w)) <= 0:
		return 0
	return SimEvent.TAG_PIERCE


## Pulse Gun L5: each bolt of a shot becomes two, TWIN_SPREAD either side.
static func shot_offsets(w: World, offsets: PackedInt32Array) -> PackedInt32Array:
	var t := _weapon(w)
	if t == null or t.kind != AbilityTable.Kind.PULSE_GUN or t.count(_weapon_level(w)) < 2:
		return offsets
	var out := PackedInt32Array()
	for o in offsets:
		out.append(o - TWIN_SPREAD)
		out.append(o + TWIN_SPREAD)
	return out


## Combo Sword L5: a landed finisher sends a shockwave (radius_m, `damage` x the level's factor) around the player.
static func after_swing(w: World, landed: bool) -> void:
	AbilityCombos.after_swing(w, landed)  # v0.4.0 AB: Blade Dance
	var t := _weapon(w)
	if not landed or t == null or t.kind != AbilityTable.Kind.COMBO_SWORD:
		return
	var lvl := _weapon_level(w)
	if t.extra(lvl) <= 0 or not PlayerKit.is_finisher(w, w.combo_step):
		return
	var dmg := _damage(t, lvl)
	var r := Stats.area(w, t.radius_m)
	var a := w.actors
	var center := w.player_pos()
	for i in range(1, a.size()):
		if a.teams[i] == ActorStore.TEAM_PLAYER or a.dead[i] == 1:
			continue
		if AttackShapes.disc_touches(center, r, a.pos(i), a.radius[i]):
			var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
			Damage.hit(
				w,
				i,
				dmg,
				a.ids[0],
				a.ids[0],
				w.swing_root,
				tags,
				center,
				a.pos(i),
				EFFECT_SWORD_WAVE
			)
	w.ab.shock_tick = w.tick
	w.ab.shock_pos = center
	w.ab.shock_r = r


# --- Auto abilities (phase 6) ----------------------------------------------------------------------------------
## v0.6.0 MX2: every auto ability's cooldown runs down here; the drones and the orbit move and strike; Bomb Lobber,
## Arc Field and Frost Nova fire from the weapon's attacks and kills (ModifierAbilities), Flame Trail from the dash
## and the projectiles; bombs land, patches burn and rings grow.
static func advance(w: World) -> void:
	if w.player_dead():
		return
	Stats.advance_regen(w)
	if w.ab.shock_pending >= 0:
		w.ab.shock_pending = -1
		_blink_shock(w)
	_land_bombs(w)
	AbilityMods.advance(w)  # v0.5.0 CP: Afterimage's echo
	for s in w.ability_owned.size():
		var t := w.ability_tables[w.ability_owned[s]]
		if not t.auto:
			continue
		if s < w.ab.cd.size() and w.ab.cd[s] > 0:
			w.ab.cd[s] -= 1
		match t.kind:
			AbilityTable.Kind.DRONE_BUDDY:
				_drones(w, t)
			AbilityTable.Kind.ORBIT_BLADES:
				_orbit(w, t, w.ability_levels[s])
	ModifierAbilities.advance(w)  # v0.6.0 MX2: Flame Trail's dash fire, the rings
	ElementAbilities.advance_fire(w)
	ModifierRuntime.advance(w)  # v0.6.0 MX4: the queued launches (Twin Cast, delayed hooks), the walk's trail


## An ability's damage at `level`, rounded half up (v0.4.0 AB: public for ElementAbilities, AbilityCombos).
static func damage_at(t: AbilityTable, level: int) -> int:
	return _damage(t, level)


static func _damage(t: AbilityTable, level: int) -> int:
	return maxi(1, (t.damage * t.damage_permille(level) + 500) / 1000)


static func _blink_shock(w: World) -> void:
	var t := owned_of_kind(w, AbilityTable.Kind.BLINK)
	if t == null:
		return
	var lvl := level_of_kind(w, AbilityTable.Kind.BLINK)
	var r := Stats.area(w, t.radius_m * t.radius_permille(lvl) / 1000.0)
	var center := w.player_pos()
	w.ab.shock_tick = w.tick
	w.ab.shock_pos = center
	w.ab.shock_r = r
	hit_disc(w, center, r, _damage(t, lvl), w.take_root(), EFFECT_BLINK)


static func hit_disc(
	w: World, center: Vector2, r: float, dmg: int, root: int, effect: StringName
) -> void:
	var a := w.actors
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
	for i in w.enemies_near(center, r):
		Damage.hit(w, i, dmg, a.ids[0], a.ids[0], root, tags, center, a.pos(i), effect)


# Bomb Lobber -----------------------------------------------------------------------------------------------------
## The bomb's radius at `level` (area applied): the same number the landing and its ground circle use (EI-07).
static func bomb_radius(w: World, t: AbilityTable, level: int) -> float:
	return Stats.area(w, t.radius_m * t.radius_permille(level) / 1000.0)


## The densest cluster within range: the enemy (alive, not spawning in) with the most other such enemies touching a
## bomb-sized disc around it; ties go to the one nearest the player, then the lower index. `skip` are centres already
## chosen this throw (enemies they cover don't count again). -1 when no enemy is in range.
static func densest(
	w: World, from: Vector2, range_m: float, r: float, skip: PackedVector2Array
) -> int:
	var a := w.actors
	var cands := PackedInt32Array()
	for i in w.enemies_near(from, range_m):
		var covered := false
		for c in skip:
			covered = covered or AttackShapes.disc_touches(c, r, a.pos(i), a.radius[i])
		if a.invuln[i] == 0 and not covered:
			cands.append(i)
	var best := -1
	var best_n := 0
	var best_d := 0.0
	for i in cands:
		var n := 0
		for j in cands:
			if AttackShapes.disc_touches(a.pos(i), r, a.pos(j), a.radius[j]):
				n += 1
		var d := Kin.length(a.pos(i) - from)
		if best < 0 or n > best_n or (n == best_n and d < best_d):
			best = i
			best_n = n
			best_d = d
	return best


## Throws the spec's `count` bombs (form LOB): the first at the densest cluster, the next at the densest one left, or
## (none left) scattered around the first from the `ability` stream. False (nothing thrown) when no enemy is in range.
static func throw_bombs(w: World, t: AbilityTable, level: int) -> bool:
	var spec := Modifiers.ability(w, t)
	if spec == null:
		return false
	var a := w.actors
	var from := w.player_pos()
	var r := bomb_radius(w, t, level)
	var centres := PackedVector2Array()
	for k in spec.count:
		var i := densest(w, from, spec.reach_m, r, centres)
		var at := Vector2.ZERO
		if i >= 0:
			at = a.pos(i)
		elif centres.is_empty():
			return false
		else:
			var ang := w.rng_ability.range_int(0, SimTick.ANGLE_UNITS - 1)
			at = centres[0] + Kin.dir(ang) * (r * w.rng_ability.range_int(400, 900) / 1000.0)
		centres.append(at)
		var ctx := AttackContext.make(from, 0, spec.damage, 0, 0, spec.effect_id)
		ctx.target = at
		ctx.has_target = true
		Attacks.launch(w, spec, ctx)
	return true


## A bomb in flight from `from` to `at`, landing `flight` ticks from now (a throw, a hook's lob, or Blink Charge's
## drop), running spec `key` at the hook level of `ctx` (none: a root bomb). v0.6.0 MX4: only a root bomb counts as
## a thrown one (bomb_split 1: Storm Bombs chains from it); a hook's (Cluster Payload's bomblets, Bomb Rounds) is 0.
static func drop_bomb(
	w: World,
	at: Vector2,
	from: Vector2,
	r: float,
	dmg: int,
	flight: int,
	key: String = "",
	ctx: AttackContext = null
) -> void:
	var s := w.ab
	s.bomb_pos.append(at)
	s.bomb_from.append(from)
	s.bomb_throw.append(w.tick)
	s.bomb_land.append(w.tick + flight)
	s.bomb_root.append(w.take_root() if ctx == null or ctx.depth == 0 else ctx.root)
	s.bomb_r.append(r)
	s.bomb_dmg.append(dmg)
	s.bomb_split.append(1 if ctx == null or ctx.depth == 0 else 0)  # v0.6.0 MX4: a hook's bomb is 0
	s.bomb_spec.append(key)  # v0.6.0 MX2
	s.bomb_depth.append(ctx.depth if ctx != null else 0)
	s.bomb_proc.append(ctx.proc_pct if ctx != null else 100)


## The bomb spec key Bomb Lobber's bombs run ("" without it).
static func bomb_key(w: World) -> String:
	var spec := Modifiers.ability(w, owned_of_kind(w, AbilityTable.Kind.BOMB_LOBBER))
	return spec.key if spec != null else ""


static func _land_bombs(w: World) -> void:
	var s := w.ab
	for k in range(s.bomb_pos.size() - 1, -1, -1):
		if w.tick < s.bomb_land[k]:
			continue
		var split := s.bomb_split[k] == 1
		var at := s.bomb_pos[k]
		var r := s.bomb_r[k]
		var dmg := s.bomb_dmg[k]
		var root := s.bomb_root[k]
		var key := s.bomb_spec[k] if k < s.bomb_spec.size() else ""
		var depth := s.bomb_depth[k] if k < s.bomb_depth.size() else 0
		var proc := s.bomb_proc[k] if k < s.bomb_proc.size() else 100
		var spec := Modifiers.book(w).find(key) if key != "" else null
		var bomb := spec == null or spec.has_tag(&"bomb")
		var effect := EFFECT_BOMB if split else AbilityMods.EFFECT_CLUSTER
		if spec != null and (not spec.has_tag(&"bomb") or not split) and spec.effect_id != &"":
			effect = spec.effect_id  # v0.6.0 MX4: a hook's bomb names its own (Bomb Rounds, the bomblets)
		elif spec != null and not spec.has_tag(&"bomb"):
			effect = spec.effect_id
		if spec != null:
			Attacks.land_lob(w, spec, at, r, dmg, root, depth, proc, effect)
		else:
			hit_disc(w, at, r, dmg, root, effect)
		if split and bomb:  # v0.4.0 AB: Storm Bombs chains from a bomb, never from its bomblets (they share its root)
			AbilityCombos.on_blast(w, at, root)
		s.blast_pos.append(s.bomb_pos[k])
		s.blast_tick.append(w.tick)
		s.blast_r.append(s.bomb_r[k])
		if s.blast_tick.size() > BLAST_LOG:
			s.blast_pos.remove_at(0)
			s.blast_tick.remove_at(0)
			s.blast_r.remove_at(0)
		_remove_bomb(s, k)


## Packed arrays are values: each is removed from in place, by name.
static func _remove_bomb(s: AbilityState, k: int) -> void:
	s.bomb_pos.remove_at(k)
	s.bomb_from.remove_at(k)
	s.bomb_throw.remove_at(k)
	s.bomb_land.remove_at(k)
	s.bomb_root.remove_at(k)
	s.bomb_r.remove_at(k)
	s.bomb_dmg.remove_at(k)
	s.bomb_split.remove_at(k)
	if k < s.bomb_spec.size():
		s.bomb_spec.remove_at(k)
		s.bomb_depth.remove_at(k)
		s.bomb_proc.remove_at(k)


# Drone Buddy -----------------------------------------------------------------------------------------------------
## Ticks between one drone's shots: the period / the level's rate, under attack speed.
static func drone_period(w: World, t: AbilityTable) -> int:
	var lvl := level_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	var base := maxi(1, t.period_ticks * 1000 / t.rate_permille(lvl))
	return Stats.auto_period(w, AbilityMods.drone_period(w, base))  # v0.5.0 CP: Overclocked Drone, Fast Hands


## Where drone k of n hovers: behind the player's facing, the drones fanned DRONE_SPREAD apart.
static func drone_slot(w: World, k: int, n: int) -> Vector2:
	var back := PlayerBuild.melee_angle(w) + SimTick.ANGLE_UNITS / 2
	var off := (2 * k - (n - 1)) * DRONE_SPREAD / 2
	return w.player_pos() + Kin.dir((back + off) & 4095) * DRONE_TRAIL_M


## v0.6.0 MX2: each drone fires its spec (a copy of the weapon's attack: the drone's bolt with the weapon's pattern,
## payload and hooks; Modifiers) at the nearest enemy in range, from where it hovers.
static func _drones(w: World, t: AbilityTable) -> void:
	var s := w.ab
	var a := w.actors
	var spec := Modifiers.ability(w, t)
	var n := s.drone_pos.size()
	for k in n:
		var p := s.drone_pos[k]
		p += (drone_slot(w, k, n) - p) * (DRONE_FOLLOW_PERMILLE / 1000.0)
		s.drone_pos[k] = p
		if s.drone_cd[k] > 0:
			s.drone_cd[k] -= 1
			continue
		var best := -1
		var best_d := 0.0
		for i in w.enemies_near(p, t.range_m):
			var d := Kin.length(a.pos(i) - p)
			if a.invuln[i] == 0 and (best < 0 or d < best_d):
				best = i
				best_d = d
		if best < 0 or spec == null:
			s.drone_cd[k] = DRONE_IDLE_TICKS
			continue
		var tags := SimEvent.TAG_PROJECTILE | SimEvent.TAG_ABILITY
		var ctx := AttackContext.make(
			p, Kin.angle_of(a.pos(best) - p), Attacks.bolt_base_damage(spec), 0, tags, &""
		)
		ctx.muzzle_m = 0.0
		Attacks.launch(w, spec, ctx)
		s.drone_cd[k] = drone_period(w, t)
		s.drone_fire[k] = w.tick


## World._projectile_hits: a drone bolt landed on actor `i`; at L5 it chains once to the nearest other enemy within
## radius_m of the hit.
static func on_bolt_hit(w: World, i: int, pi: int, got: int, at: Vector2) -> void:
	var p := w.projectiles
	if got <= 0 or p.team[pi] != ActorStore.TEAM_PLAYER or not (p.tags[pi] & SimEvent.TAG_ABILITY):
		return
	AbilityCombos.on_drone_bolt(w, pi, got, at)  # v0.4.0 AB: Napalm Drone
	var t := owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	if t == null or t.extra(level_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)) <= 0:
		return
	var a := w.actors
	var best := -1
	var best_d := 0.0
	for j in w.enemies_near(at, t.radius_m):
		var d := Kin.length(a.pos(j) - at)
		if j != i and a.invuln[j] == 0 and (best < 0 or d < best_d):
			best = j
			best_d = d
	if best < 0:
		return
	w.ab.chain_tick = w.tick
	w.ab.chain_from = at
	w.ab.chain_to = a.pos(best)
	var tags := SimEvent.TAG_CHAIN | SimEvent.TAG_ABILITY
	var dmg := p.damage[pi]
	Damage.hit(
		w, best, dmg, a.ids[0], a.ids[0], p.root_id[pi], tags, at, a.pos(best), EFFECT_DRONE_CHAIN
	)


# Orbit Blades ----------------------------------------------------------------------------------------------------
## The blades' ring radius at `level` (area applied; v0.4.0 AB: wider while Blade Dance is on).
static func orbit_radius(w: World, t: AbilityTable, level: int) -> float:
	var r := t.radius_m * t.radius_permille(level) / 1000.0 + AbilityCombos.dance_radius(w)
	return Stats.area(w, r)


## Where blade k of n is now: the same points the hits test and the view draws (EI-07).
static func blade_pos(w: World, k: int, n: int, r: float) -> Vector2:
	var ang := (w.ab.orbit_angle + k * SimTick.ANGLE_UNITS / n) & 4095
	return w.player_pos() + Kin.dir(ang) * r


## v0.6.0 MX2: the blades are copies of your attack (form ORBITER): a touch is a hit of the orbit spec, carrying the
## weapon's statuses and hooks (Attacks.land).
static func _orbit(w: World, t: AbilityTable, level: int) -> void:
	var s := w.ab
	var a := w.actors
	s.orbit_angle = (s.orbit_angle + maxi(1, SimTick.ANGLE_UNITS / t.period_ticks)) & 4095
	for k in range(s.orbit_ids.size() - 1, -1, -1):
		if s.orbit_next[k] <= w.tick:
			s.orbit_ids.remove_at(k)
			s.orbit_next.remove_at(k)
	var spec := Modifiers.ability(w, t)
	if spec == null:
		return
	var n := spec.count
	var r := orbit_radius(w, t, level)
	var dmg := spec.damage * AbilityCombos.dance_permille(w) / 1000  # v0.4.0 AB: Blade Dance
	var effect := AbilityCombos.EFFECT_DANCE if AbilityCombos.dancing(w) else EFFECT_ORBIT
	var tags := Attacks.lingering_tags(spec)
	for i in w.enemies_near(w.player_pos(), r + BLADE_R):
		if a.invuln[i] > 0 or s.orbit_ids.has(a.ids[i]):
			continue
		for k in n:
			var b := blade_pos(w, k, n, r)
			if not AttackShapes.disc_touches(b, spec.radius_m, a.pos(i), a.radius[i]):
				continue
			s.orbit_ids.append(a.ids[i])
			s.orbit_next.append(w.tick + Stats.auto_cooldown(w, t.hit_ticks))  # v0.5.0 CP: Fast Hands
			s.orbit_hit_tick = w.tick
			var root := w.take_root()
			var ctx := AttackContext.make(b, 0, dmg, root, tags, effect)
			var got := Attacks.land(w, spec, ctx, i, b, a.pos(i))
			AbilityCombos.on_blade_hit(w, i, root, got)  # v0.4.0 AB: Glacier Ring
			break


# --- State hash and reads --------------------------------------------------------------------------------------
static func touched(w: World) -> bool:
	return (
		not w.ability_owned.is_empty()
		or not w.stat_values.is_empty()
		or w.player.crit_chance_permille > 0
		or w.ab.touched()
	)


static func hash_into(w: World, h: StateHasher) -> void:
	if not touched(w):
		return
	h.add_ints(w.ability_owned)
	h.add_ints(w.ability_levels)
	h.add_ints(w.stat_values)
	h.add_ints(w.stat_cards)  # v0.5.0 SH
	h.add_int(w.rng_crit.state)
	h.add_int(w.rng_ability.state)
	w.ab.hash_into(h)
	if w.item_tables.is_empty() and w.ab.touched_ab():  # v0.4.0 AB: a world without items (_hash_engines)
		h.add_ints(w.combos_owned)
		w.actors.hash_statuses(h)


## Per slot (in slot order): the ability's id, name key, kind, auto, button, level, cooldown left and total, ready,
## and for Blink its charges (WorldReader.abilities).
static func read(w: World) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in w.ability_owned.size():
		var t := w.ability_tables[w.ability_owned[s]]
		var lvl := w.ability_levels[s]
		var left := 0
		var total := 1
		var ready := true
		match t.kind:
			AbilityTable.Kind.BOMB_LOBBER:
				left = w.ab.cd[s] if s < w.ab.cd.size() else 0
				total = Stats.auto_cooldown(w, t.cooldown_ticks)
			AbilityTable.Kind.ARC_FIELD, AbilityTable.Kind.FROST_NOVA:  # v0.4.0 AB
				left = w.ab.cd[s] if s < w.ab.cd.size() else 0
				total = Stats.auto_cooldown(w, t.cooldown_at(lvl))
			AbilityTable.Kind.DRONE_BUDDY:
				left = w.ab.drone_cd[0] if not w.ab.drone_cd.is_empty() else 0
				total = drone_period(w, t)
			AbilityTable.Kind.BLINK:
				left = w.blink_cd
				total = blink_cooldown(w)
				ready = blink_ready(w)
			AbilityTable.Kind.COMBO_SWORD, AbilityTable.Kind.PULSE_GUN:
				var sk := PlayerSkill.read(w)
				if not sk.is_empty():
					left = sk["cooldown"]
					total = sk["cooldown_total"]
		ready = ready and left == 0
		(
			out
			. append(
				{
					"id": t.id,
					"name_key": t.name_key,
					"kind": t.kind,
					"auto": t.auto,
					"button": t.button,
					"level": lvl,
					"cooldown": left,
					"cooldown_total": maxi(1, total),
					"ready": ready,
					"charges": w.ab.blink_charges if t.kind == AbilityTable.Kind.BLINK else 0,
				}
			)
		)
	return out


## What the views draw (WorldReader.ability_fx): bombs in flight and their ground circles, the last landings, the
## drones, the orbit blades and the last blink shock or sword wave.
static func fx(w: World) -> Dictionary:
	var s := w.ab
	var blades := PackedVector2Array()
	var orbit := owned_of_kind(w, AbilityTable.Kind.ORBIT_BLADES)
	if orbit != null and not w.player_dead():
		var lvl := level_of_kind(w, AbilityTable.Kind.ORBIT_BLADES)
		var n := orbit.count(lvl)
		for k in n:
			blades.append(blade_pos(w, k, n, orbit_radius(w, orbit, lvl)))
	return {
		"bomb_pos": s.bomb_pos,
		"bomb_from": s.bomb_from,
		"bomb_throw": s.bomb_throw,
		"bomb_land": s.bomb_land,
		"bomb_r": s.bomb_r,
		"blast_pos": s.blast_pos,
		"blast_tick": s.blast_tick,
		"blast_r": s.blast_r,
		"drones": s.drone_pos,
		"drone_fire": s.drone_fire,
		"blades": blades,
		"blade_r": BLADE_R,
		"orbit_hit_tick": s.orbit_hit_tick,
		"shock_tick": s.shock_tick,
		"shock_pos": s.shock_pos,
		"shock_r": s.shock_r,
		"chain_tick": s.chain_tick,
		"chain_from": s.chain_from,
		"chain_to": s.chain_to,
		"echo_at": s.echo_at,  # v0.5.0 CP: Afterimage (waiting: echo_pos; the last burst: tick, where, radius)
		"echo_pos": s.echo_pos,
		"echo_tick": s.echo_tick,
		"echo_burst_pos": s.echo_burst_pos,
		"echo_r": s.echo_r,
	}
