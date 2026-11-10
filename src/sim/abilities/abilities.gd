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
## - Auto (tick phase 6, after the projectile sweeps): the cooldowns count down, the bombs in flight land (a hook's
##   lob, the Bomb Rounds' bomblets) and the echo, fire and rings run.
## The six old abilities (Bomb Lobber, Drone Buddy, Orbit Blades, Arc Field, Frost Nova,
## Flame Trail) and the eight ability combos are gone; their tables are stubs (CardOrder.RETIRED_ABILITIES) that keep
## a save's indices, and AbilityState keeps their fields (hashed) empty.
## Every hit is the player's, so stats and crit apply in Damage.hit; ability hits carry TAG_ABILITY and an effect id
## (never heat, never an on-hit "attack").
## Taking a card refreshes the build (World.refresh_build: the engines the abilities borrow, the combos).

const BLADE_R := 0.35
const BOLT_RADIUS_M := 0.12
## Twin bolts (Pulse Gun L5): each shot's bolts split this far either side of the aim (1/4096 turns).
const TWIN_SPREAD := 40
## Bomb landings the view remembers.
const BLAST_LOG := 8
const EFFECT_BOMB := &"bomb_lobber"
const EFFECT_BLINK := &"blink_shock"
const EFFECT_SWORD_WAVE := &"combo_sword_wave"


# --- Ownership -------------------------------------------------------------------------------------------------
static func owned(w: World, idx: int) -> bool:
	return w.ability_owned.has(idx)


## The level of ability `idx` (0 = not owned).
static func level_of(w: World, idx: int) -> int:
	var s := w.ability_owned.find(idx)
	return w.ability_levels[s] if s >= 0 else 0


## Ability `idx`'s level after one more card (1 when new; grant's step, Offers.info and CardForecast).
static func level_after(w: World, idx: int) -> int:
	return mini(level_of(w, idx) + 1, AbilityTable.MAX_LEVEL)


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
## (never a starting weapon, never a second utility). a new modifier is offered with the six slots full
## too: taking it opens the swap (BuildSlots).
static func can_take(w: World, idx: int) -> bool:
	if w.ability_tables[idx].retired:
		return false  # A retired ability modifier is never offered (Abilities.grant still takes it)
	if not w.ability_tables[idx].offered:
		return false  # The Pulse Gun never comes back as a card, held at any level or not
	var s := w.ability_owned.find(idx)
	if s >= 0:
		return w.ability_levels[s] < AbilityTable.MAX_LEVEL
	var t := w.ability_tables[idx]
	if t.start_weapon != 0:
		return false
	return not (t.is_utility() and utility(w) != PlayerTable.Utility.NONE)


## Takes an ability card: a level up of an owned ability, or a new one at level 1 (a new modifier only
## while a modifier slot is free; BuildSlots.take swaps one out first). Returns false (and changes nothing) when the
## card can't apply.
static func grant(w: World, idx: int) -> bool:
	var t := w.ability_tables[idx]
	var s := w.ability_owned.find(idx)
	if s >= 0:
		if w.ability_levels[s] >= AbilityTable.MAX_LEVEL:
			return false
		w.ability_levels[s] = level_after(w, idx)
	else:
		if t.is_modifier() and BuildSlots.full(w):
			return false
		if t.is_utility() and utility(w) != PlayerTable.Utility.NONE:
			return false
		w.ability_owned.append(idx)
		w.ability_levels.append(1)
		w.ab.cd.append(0)
	BuildSlots.sync(w)  # A new modifier takes the next slot
	w.refresh_build(true)  # Borrowed engines; a pair at L3 evolves (its combo card)
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


## Ability slot `s` (World.ability_owned order) leaves the build: its level, cooldown and its own floor
## state go; the combos it completed go too, and the build refreshes (BuildSlots.drop, Shop.sell).
static func remove_slot(w: World, s: int) -> void:
	var t := w.ability_tables[w.ability_owned[s]]
	w.ability_owned.remove_at(s)
	w.ability_levels.remove_at(s)
	if s < w.ab.cd.size():
		w.ab.cd.remove_at(s)
	if t.kind == AbilityTable.Kind.BLINK:
		w.ab.blink_charges = 0
		w.blink_cd = 0
	var keep := PackedInt32Array()
	var earned := Engines.combos_for(w.combo_tables, w.items_owned)
	for c in w.combos_owned:
		if earned.has(c):
			keep.append(c)
	w.combos_owned = keep
	BuildSlots.sync(w)
	w.refresh_build(false)


## A fresh floor (after the carry restored the slots and levels): cooldowns, drones and the blink's charges start
## over.
static func start_floor(w: World) -> void:
	if w.migrate_slots:  # A carry from before the slots (RunCarry.apply)
		w.migrate_slots = false
		BuildSlots.migrate(w)
	else:
		BuildSlots.sync(w)
	WandMigration.run(w)  # An old save's retired cards become their wand cards (or shards)
	AttackSlots.trim(w)  # An old save's over-full slot categories (the leftmost stay, the rest shards)
	Stats.migrate_rules(w)  # A carry from before SG (RunCarry.apply) rebuilds damage and attack speed
	w.ab = AbilityState.new()
	for s in w.ability_owned.size():
		w.ab.cd.append(0)
	var blink := owned_of_kind(w, AbilityTable.Kind.BLINK)
	if blink != null:
		w.ab.blink_charges = blink.extra(level_of_kind(w, AbilityTable.Kind.BLINK))
	w.refresh_build(false)  # After the carry restored the slots


# --- The utility button (Blink, Aegis) -------------------------------------------------------------------------
## The utility the player has now: the forced loadout's (PlayerTable.utility: tests, the dev runs of old), else an
## owned Blink or Aegis (none at the start of a run).
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
	AbilityMods.on_blink(w)  # Afterimage
	ModifierRuntime.on_blink(w)  # The blink spec's other hooks


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
## Every auto ability's cooldown runs down here; the drones and the orbit move and strike; Bomb Lobber,
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
	AbilityMods.advance(w)  # Afterimage's echo
	for s in w.ability_owned.size():
		var t := w.ability_tables[w.ability_owned[s]]
		if not t.auto:
			continue
		if s < w.ab.cd.size() and w.ab.cd[s] > 0:
			w.ab.cd[s] -= 1
	ModifierAbilities.advance(w)  # Flame Trail's dash fire, the rings
	ElementAbilities.advance_fire(w)
	ModifierRuntime.advance(w)  # The queued launches (Twin Cast, delayed hooks), the walk's trail


## An ability's damage at `level`, rounded half up.
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


# Bombs in flight (a hook's lob, Attacks._lob) ----------------------------------------------------------------------


## A bomb in flight from `from` to `at`, landing `flight` ticks from now (a throw, a hook's lob, or Blink Charge's
## drop), running spec `key` at the hook level of `ctx` (none: a root bomb). only a root bomb counts as
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
	s.bomb_split.append(1 if ctx == null or ctx.depth == 0 else 0)  # A hook's bomb is 0
	s.bomb_spec.append(key)  # v0.6.0 MX2
	s.bomb_depth.append(ctx.depth if ctx != null else 0)
	s.bomb_proc.append(ctx.proc_pct if ctx != null else 100)


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
		var effect := EFFECT_BOMB if split else AbilityMods.EFFECT_CLUSTER
		# A hook's bomb names its own (Bomb Rounds, the bomblets): any non-bomb spec's (even none), or a
		# bomb spec's own when it isn't splitting.
		if spec != null and (not spec.has_tag(&"bomb") or (not split and spec.effect_id != &"")):
			effect = spec.effect_id
		if spec != null:
			Attacks.land_lob(w, spec, at, r, dmg, root, depth, proc, effect)
		else:
			hit_disc(w, at, r, dmg, root, effect)
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
	if w.item_tables.is_empty() and w.ab.touched_ab():  # A world without items (_hash_engines)
		h.add_ints(w.combos_owned)
		w.actors.hash_statuses(h)
	if w.ab.touched_rc():  # The rule cards' state
		w.ab.hash_rc(h)


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
## the last blink shock or sword wave and the blink echo.
static func fx(w: World) -> Dictionary:
	var s := w.ab
	return {
		"bomb_pos": s.bomb_pos,
		"bomb_from": s.bomb_from,
		"bomb_throw": s.bomb_throw,
		"bomb_land": s.bomb_land,
		"bomb_r": s.bomb_r,
		"blast_pos": s.blast_pos,
		"blast_tick": s.blast_tick,
		"blast_r": s.blast_r,
		"shock_tick": s.shock_tick,
		"shock_pos": s.shock_pos,
		"shock_r": s.shock_r,
		"echo_at": s.echo_at,  # Afterimage (waiting: echo_pos; the last burst: tick, where, radius)
		"echo_pos": s.echo_pos,
		"echo_tick": s.echo_tick,
		"echo_burst_pos": s.echo_burst_pos,
		"echo_r": s.echo_r,
	}
