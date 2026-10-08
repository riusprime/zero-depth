class_name CatchUp
extends RefCounted
## The hidden growth-matching difficulty (v0.5.5 Step DS; owner D3-D7, D10, B1: "regular scaling + multiplier based
## on how much you grew", "Yes, but hidden"; SIM_CONTRACTS §11). Regular scaling (the floor's tables, the danger tier,
## Deep) stays; on top of it:
## - power(w): the build's power P, per mille of a fresh build (1000), a pure function of the loadout and never of
##   how well it is played: weapon level × damage stat × Glass Cannon × (1 + Onrush) × expected crit (relative to the
##   base crit) × attack speed × (1 + ability levels besides the weapon, items and combos at their table weights).
##   The one place the build's power is read, so the modifier engine (Step MX: weapon + 6 modifier slots) adds its
##   terms here.
## - multiplier(P, E, cap): m = clamp(sqrt(P / E), 1, cap), per mille, integer square root (no float).
## - start_floor(w), at floor entry (after the carry, the abilities, the heat and the events are set up): reads P,
##   E(floor), cap(floor) + threat_cap × T and stores m in World.catch_up; m is fixed for the floor (no rubber band).
## - on_enemy(w, i): every enemy as it arrives (SpawnDirector.scale_arrival, the ambush): max HP × m, damage (its
##   ActorStore.power) × sqrt(m).
## - on_boss(w, i): a boss as it spawns: its own m from P now against the expected power at the floor's end and the
##   boss cap (cap + threat_cap × T); max HP × m, its attacks' damage × sqrt(m) (ActorStore.power, BossAi.powered).
## A world without World.catch_up_table (labs, kernel, arena) is untouched. Nothing here is shown to the player.


## The build's power P, per mille of a fresh build (see the class comment). 1000 for a world without a table.
static func power(w: World) -> int:
	var t := w.catch_up_table
	if t == null:
		return 1000
	var p := Abilities.weapon_permille(w)
	p = p * Stats.value(w, Stats.Stat.DAMAGE) / 1000
	p = p * Stats.value(w, Stats.Stat.GLASS_CANNON) / 1000
	p = p * (1000 + Stats.value(w, Stats.Stat.ONRUSH)) / 1000
	p = p * expected_crit(w, Stats.crit_chance(w), Stats.crit_mult(w)) / base_crit(w)
	p = p * Stats.value(w, Stats.Stat.ATTACK_SPEED) / 1000
	var levels := 0
	for s in w.ability_owned.size():
		if w.ability_tables[w.ability_owned[s]].start_weapon == 0:
			levels += w.ability_levels[s]
	var extra := (
		t.ability_level_permille * levels
		+ t.item_permille * w.items_owned.size()
		+ t.combo_permille * w.combos_owned.size()
	)
	return maxi(1, p * (1000 + extra) / 1000)


## A hit's expected multiplier with crit chance c and crit multiplier k (per mille): 1000 + c × (k − 1000) / 1000.
static func expected_crit(_w: World, c: int, k: int) -> int:
	return 1000 + clampi(c, 0, 1000) * maxi(0, k - 1000) / 1000


## The fresh build's expected crit multiplier (the player's base chance and multiplier), never under 1000.
static func base_crit(w: World) -> int:
	return maxi(1000, expected_crit(w, w.player.crit_chance_permille, w.player.crit_mult_permille))


## m = clamp(sqrt(P / E), 1000, cap) per mille.
static func multiplier(p: int, e: int, cap: int) -> int:
	return clampi(isqrt(p * 1000000 / maxi(1, e)), 1000, maxi(1000, cap))


## sqrt(m) per mille, for m per mille (the damage factor).
static func damage_permille(m: int) -> int:
	return isqrt(maxi(0, m) * 1000)


## The integer square root (floor) of n >= 0: Newton's method on ints, no float.
static func isqrt(n: int) -> int:
	if n <= 0:
		return 0
	var x := n
	var y := (x + 1) / 2
	while y < x:
		x = y
		y = (x + n / x) / 2
	return x


## The cap at threat T: the floor's cap + threat_cap × T.
static func cap_at(table: PackedInt32Array, t: CatchUpTable, f: int, threat: int) -> int:
	return CatchUpTable.at_floor(table, f) + t.threat_cap_permille * maxi(0, threat)


## At floor entry: reads P, E and the cap and fixes the floor's m (World.catch_up). No-op without a table.
static func start_floor(w: World) -> void:
	var t := w.catch_up_table
	if t == null:
		return
	var s := w.catch_up
	s.power = power(w)
	s.expected = CatchUpTable.at_floor(t.expected_permille, w.floor_index)
	s.cap = cap_at(t.cap_permille, t, w.floor_index, Curses.threat(w))
	s.enemy = multiplier(s.power, s.expected, s.cap)


## Enemy i just arrived (its tier, floor and Overrun scaling already applied): max HP × m, damage × sqrt(m).
static func on_enemy(w: World, i: int) -> void:
	if w.catch_up_table == null or w.catch_up.enemy == 1000:
		return
	var m := w.catch_up.enemy
	var a := w.actors
	var hp := maxi(1, a.max_hp[i] * m / 1000)
	a.max_hp[i] = hp
	a.hp[i] = hp
	a.power[i] = maxi(1, a.power[i]) * damage_permille(m) / 1000


## Boss i just spawned: its own m (P now, the expected power at the floor's end, the boss cap at T now), then max HP
## × m and its attacks' damage × sqrt(m) (ActorStore.power). No-op without a table.
static func on_boss(w: World, i: int) -> void:
	var t := w.catch_up_table
	if t == null:
		return
	var s := w.catch_up
	s.boss_power = power(w)
	s.boss_expected = CatchUpTable.at_floor(t.boss_expected_permille, w.floor_index)
	s.boss_cap = cap_at(t.boss_cap_permille, t, w.floor_index, Curses.threat(w))
	s.boss = multiplier(s.boss_power, s.boss_expected, s.boss_cap)
	var a := w.actors
	var hp := maxi(1, a.max_hp[i] * s.boss / 1000)
	a.max_hp[i] = hp
	a.hp[i] = hp
	a.power[i] = damage_permille(s.boss)
