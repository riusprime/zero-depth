class_name AbilityCombos
extends RefCounted
## The eight ability combos (v0.4.0 AB, owner F13; PLAN "Ability combos"). They reuse the v0.3.0 combo framework: a
## ComboDefinition naming two abilities (ability_a, ability_b) compiles to a ComboTable, and owning both at its
## min_level (3) or higher evolves the pair: World.refresh_build owns it (COMBO_UNLOCKED, so the combo card shows,
## the HUD badge and the unlock sound follow), and Engines.combo / has_combo answer for it like any combo.
## - Storm Bombs (Bomb Lobber + Arc Field): a bomb's blast sends lightning to the `count` nearest enemies within
##   radius_m of it: `damage` and `stacks` shock each.
## - Napalm Drone (Drone Buddy + Flame Trail): a drone bolt that lands leaves a fire patch (radius_m, window_ticks,
##   `damage` per fire hit, `stacks` burn).
## - Glacier Ring (Orbit Blades + Frost Nova): each blade touch adds `stacks` frost.
## - Blink Charge (Blink + Bomb Lobber): a blink leaves `count` of Bomb Lobber's bombs where you left.
## - Blade Dance (Combo Sword + Orbit Blades): a landed swing spreads the blades radius_m wider and raises their damage
##   by share_permille for window_ticks.
## - Wingman (Pulse Gun + Drone Buddy): your shot makes every drone fire along your aim (share_permille of a drone
##   bolt), at most once every window_ticks.
## - Superconductor (Arc Field + Frost Nova): an Arc Field strike on a chilled or frozen enemy deals +share_permille.
## - Ember Ward (Flame Trail + Aegis): a guard block bursts fire around you (radius_m: `damage` and `stacks` burn), at
##   most once every window_ticks.
## Loop rules (SIM_CONTRACTS §7-§8): every payoff that deals damage runs between Engines.begin and Engines.end (the
## ancestry guard and the watchdog), the root-keyed ones fire once per root (ProcLedger codes below), and the rest
## are rate-limited by their window. None of these hits feeds an item's stacks (TAG_ABILITY, no melee/bolt source).

const EFFECT_STORM := &"storm_bombs"
const EFFECT_NAPALM := &"napalm_drone"
const EFFECT_GLACIER := &"glacier_ring"
const EFFECT_CHARGE := &"blink_charge"
const EFFECT_DANCE := &"blade_dance"
const EFFECT_WINGMAN := &"wingman"
const EFFECT_SUPER := &"superconductor"
const EFFECT_WARD := &"ember_ward"
## ProcLedger codes (appended after Engines' codes, never renumbered: hashed).
const CODE_STORM := 64
const CODE_NAPALM := 65
const CODE_GLACIER := 66


## Ability combos whose two abilities are both owned at min_level or higher, in combo-table order.
static func earned(w: World) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in w.combo_tables.size():
		var t := w.combo_tables[c]
		if t.ability_a < 0 or t.ability_b < 0:
			continue
		if t.ability_a >= w.ability_tables.size() or t.ability_b >= w.ability_tables.size():
			continue
		if (
			Abilities.level_of(w, t.ability_a) >= t.min_level
			and Abilities.level_of(w, t.ability_b) >= t.min_level
		):
			out.append(c)
	return out


## Storm Bombs: a bomb (root `root`) landed at `at`.
static func on_blast(w: World, at: Vector2, root: int) -> void:
	var c := Engines.combo(w, ComboTable.Effect.STORM_BOMBS)
	if c == null or not w.proc_ledger.try_mark(root, CODE_STORM, 0, w.tick):
		return
	var to := Engines.nearest_enemies(w, 0, at, c.radius_m, c.count)
	if to.is_empty() or not Engines.begin(w, EFFECT_STORM):
		return
	var a := w.actors
	var pid := a.ids[0]
	w.ab.storm_tick = w.tick
	w.ab.storm_from = at
	w.ab.storm_to = PackedVector2Array()
	for j in to:
		w.ab.storm_to.append(a.pos(j))
		var tags := SimEvent.TAG_ABILITY
		if Damage.hit(w, j, c.damage, pid, pid, root, tags, at, a.pos(j), EFFECT_STORM) > 0:
			Engines.add_shock(w, j, c.stacks, root)
	Engines.end(w)


## Napalm Drone: drone bolt `pi` landed `got` damage at `at`.
static func on_drone_bolt(w: World, pi: int, got: int, at: Vector2) -> void:
	var c := Engines.combo(w, ComboTable.Effect.NAPALM_DRONE)
	if c == null or got <= 0:
		return
	if not w.proc_ledger.try_mark(w.projectiles.root_id[pi], CODE_NAPALM, 0, w.tick):
		return
	ElementAbilities.add_fire(
		w,
		at,
		Stats.area(w, c.radius_m),
		w.tick + c.window_ticks,
		c.damage,
		c.stacks,
		ElementAbilities.FIRE_NAPALM
	)


## Glacier Ring: an orbit blade (root `root`) hit enemy `i` for `got`.
static func on_blade_hit(w: World, i: int, root: int, got: int) -> void:
	var c := Engines.combo(w, ComboTable.Effect.GLACIER_RING)
	if c == null or got <= 0 or w.actors.dead[i] == 1:
		return
	if not w.proc_ledger.try_mark(root, CODE_GLACIER, w.actors.ids[i], w.tick):
		return
	if Engines.begin(w, EFFECT_GLACIER):
		w.ab.glacier_tick = w.tick
		Engines.add_frost(w, i, c.stacks, root, EFFECT_GLACIER)
		Engines.end(w)


## Blink Charge: the ability's blink just left w.blink_from.
static func on_blink(w: World) -> void:
	var c := Engines.combo(w, ComboTable.Effect.BLINK_CHARGE)
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.BOMB_LOBBER)
	if c == null or t == null:
		return
	var lvl := Abilities.level_of_kind(w, AbilityTable.Kind.BOMB_LOBBER)
	var r := Abilities.bomb_radius(w, t, lvl)
	var dmg := Abilities.damage_at(t, lvl)
	for k in c.count:
		var off := Vector2.ZERO if k == 0 else Kin.dir(k * 4096 / c.count) * (r * 0.6)
		Abilities.drop_bomb(w, w.blink_from + off, w.blink_from, r, dmg, t.duration_ticks)
	w.ab.charge_tick = w.tick
	w.ab.charge_pos = w.blink_from


## Blade Dance: a swing ended (`landed`: it hit something).
static func after_swing(w: World, landed: bool) -> void:
	var c := Engines.combo(w, ComboTable.Effect.BLADE_DANCE)
	if c != null and landed:
		w.ab.dance_until = w.tick + c.window_ticks


## Blade Dance is on now.
static func dancing(w: World) -> bool:
	return w.tick < w.ab.dance_until and Engines.has_combo(w, ComboTable.Effect.BLADE_DANCE)


## The blades' extra ring radius (metres) and their damage factor (per mille) now.
static func dance_radius(w: World) -> float:
	return Engines.combo(w, ComboTable.Effect.BLADE_DANCE).radius_m if dancing(w) else 0.0


static func dance_permille(w: World) -> int:
	if not dancing(w):
		return 1000
	return 1000 + Engines.combo(w, ComboTable.Effect.BLADE_DANCE).share_permille


## Wingman: the player just fired a shot.
static func on_shot(w: World) -> void:
	var c := Engines.combo(w, ComboTable.Effect.WINGMAN)
	var t := Abilities.owned_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	if c == null or t == null or w.tick < w.ab.wing_next or w.ab.drone_pos.is_empty():
		return
	var lvl := Abilities.level_of_kind(w, AbilityTable.Kind.DRONE_BUDDY)
	var dmg := maxi(1, Abilities.damage_at(t, lvl) * c.share_permille / 1000)
	var dir := Kin.dir(w.aim_angle)
	var life := int(ceil(t.range_m / t.speed)) + 2
	var tags := SimEvent.TAG_PROJECTILE | SimEvent.TAG_ABILITY
	for p in w.ab.drone_pos:
		w.queue_projectile(
			w.actors.ids[0],
			ActorStore.TEAM_PLAYER,
			p,
			dir * t.speed,
			dmg,
			Abilities.BOLT_RADIUS_M,
			life,
			tags
		)
	w.ab.wing_next = w.tick + c.window_ticks
	w.ab.wing_tick = w.tick


## Superconductor: an Arc Field strike's damage on enemy `i` (raised when it is chilled or frozen).
static func arc_damage(w: World, i: int, dmg: int) -> int:
	var c := Engines.combo(w, ComboTable.Effect.SUPERCONDUCTOR)
	var a := w.actors
	if c == null or (a.frost_stacks[i] <= 0 and a.frozen_t[i] <= 0):
		return dmg
	return maxi(1, dmg * (1000 + c.share_permille) / 1000)


## Ember Ward: the guard blocked a hit (root `root`).
static func on_guard_block(w: World, root: int) -> void:
	var c := Engines.combo(w, ComboTable.Effect.EMBER_WARD)
	if c == null or w.player_dead() or w.tick < w.ab.ward_next:
		return
	if not Engines.begin(w, EFFECT_WARD):
		return
	var a := w.actors
	var pid := a.ids[0]
	var center := w.player_pos()
	var r := Stats.area(w, c.radius_m)
	w.ab.ward_next = w.tick + c.window_ticks
	w.ab.ward_tick = w.tick
	w.ab.ward_pos = center
	w.ab.ward_r = r
	var tags := SimEvent.TAG_AREA | SimEvent.TAG_ABILITY
	for i in w.enemies_near(center, r):
		if Damage.hit(w, i, c.damage, pid, pid, root, tags, center, a.pos(i), EFFECT_WARD) > 0:
			Engines.add_burn(w, i, c.stacks, root, EFFECT_WARD)
	Engines.end(w)
