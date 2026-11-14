class_name CatchUp
extends RefCounted
## The hidden growth-matching difficulty (v0.5.5 Step DS; owner D3-D7, D10, B1: "regular scaling + multiplier based
## on how much you grew", "Yes, but hidden"; SIM_CONTRACTS §11). Regular scaling (the floor's tables, the danger tier,
## Deep) stays; on top of it:
## - power(w): the build's power P, per mille of a fresh build (1000), a pure function of the loadout and never of
##   how well it is played: weapon level × (damage stat + Onrush: v0.8.0 SG's additive bucket, Hoarder left out) ×
##   Glass Cannon × expected crit (relative to the base crit) × the attack rate (the attack speed stat
##   plus the held cards' rate bonus, order-free, through AttackRate's curve) × (1 + the modifier slots' levels and
##   the utility's level, the items without a slot and the combos, at their table weights). The one place the build's
##   power is read (the weapon, the utility and the modifier slots, BuildSlots; the wand's
##   slots).
## - multiplier(P, E, cap): m = clamp(sqrt(P / E), 1, cap), per mille, integer square root (no float).
## - v0.7.5 AP: past the first loop both caps get World.loop_cap_permille more (and the loop's threat raises them
##   through threat_cap like any T).
## - start_floor(w), at floor entry (after the carry, the abilities, the heat and the events are set up): reads P,
##   E(floor), cap(floor) + threat_cap × T and stores m in World.catch_up; m is fixed for the floor (no rubber band).
## - on_enemy(w, i): every enemy as it arrives (SpawnDirector.scale_arrival, the ambush): max HP × m, damage (its
##   ActorStore.power) × sqrt(m).
## - on_boss(w, i): a boss as it spawns: its own m from P now against the expected power at the floor's end and the
##   boss cap (cap + threat_cap × T); max HP × m, its attacks' damage × sqrt(m) (ActorStore.power, BossAi.powered).
## The boss's m is read when its door starts to open (read_boss) and held to the spawn, its cap
## is 2.5 / 3.0 / 3.5 / 4.0 / 4.5 by floor, and a +-8 % spread is drawn once per boss fight.
## v0.10.5 O2b (owner D38 (a): "fights should last 1-2 minutes", a one-shot "on very very rare ocassions"): with the
## table's boss_pace_permille set, a floor boss's HP no longer takes m but the paced multiplier (pace_multiplier: the
## floor's pace × P / E, P capped at boss_pace_cap_permille × E, at least boss_pace_min_permille), times the same
## spread, so the fight lasts about as long at any power up to the cap and a far stronger build is quicker. Its
## damage keeps × sqrt(m). The final boss's bodies keep m (FinalPace paces them).
## A world without World.catch_up_table (labs, kernel, arena) is untouched. Nothing here is shown to the player.

## The named stream of a boss fight's HP spread (see spread_stream).
const BOSS_SPREAD_STREAM := "boss:hp_spread"


## The build's power P, per mille of a fresh build (see the class comment). 1000 for a world without a table.
static func power(w: World) -> int:
	var t := w.catch_up_table
	if t == null:
		return 1000
	var p := Abilities.weapon_permille(w)
	# The additive bucket (damage + Onrush, always counted; Hoarder not), x Glass Cannon
	p = p * (Stats.value(w, Stats.Stat.DAMAGE) + Stats.value(w, Stats.Stat.ONRUSH)) / 1000
	p = p * Stats.value(w, Stats.Stat.GLASS_CANNON) / 1000
	# The loadout's crit damage, without Rising Edge's room count (how it is played; Fervour's haste
	# never reaches rate_permille)
	var crit_m := Stats.crit_mult(w) - Starbound.crit_bonus(w)
	p = p * expected_crit(w, Stats.crit_chance(w), crit_m) / base_crit(w)
	# The effective rate, the stat and the wand's rate bonus through the curve (no curse: the curses were
	# never counted)
	p = p * rate_permille(w) / 1000
	# Per modifier level (each slot's card: an ability modifier's level, an attack item 1) and the
	# utility's level at the table's per-level weight; the items without a slot at the item weight. the
	# wand's cards (its slots, whatever their order: a reorder never changes P), a trigger card 1.
	var levels := 0
	for s in Wand.size(w):
		levels += power_level(w, s)
	for s in w.ability_owned.size():
		if w.ability_tables[w.ability_owned[s]].is_utility():
			levels += w.ability_levels[s]
	var plain := 0
	for idx in w.items_owned:
		if not BuildSlots.is_modifier(w, idx):
			plain += 1
	var extra := (
		t.ability_level_permille * levels
		+ t.item_permille * plain
		+ t.combo_permille * w.combos_owned.size()
	)
	return maxi(1, p * (1000 + extra) / 1000)


## The attack rate P counts, per mille: 1000 + the curve of the attack speed stat's bonus and the wand's
## rate bonus (AttackRate.curve; Heavy Hands left out, as P never read the curses).
static func rate_permille(w: World) -> int:
	return maxi(1, 1000 + AttackRate.curve(w.tuning, AttackRate.stat_bonus(w) + wand_rate_bonus(w)))


## The rate bonus the held cards add to an attack, per mille, whatever their order (SIM_CONTRACTS: a
## reorder never changes P): every card's own rate_bonus_permille ADD ops at its level (Rapid Fire, Rapid Coil,
## Flurry, Heavy ...), not the ones a trigger or hook passes on. It equals the compiled weapon attack's bonus
## (AttackRate.weapon_bonus) while those cards sit before any trigger.
static func wand_rate_bonus(w: World) -> int:
	var sum := 0
	for code in w.items_owned:
		if code < 0 or code >= w.item_tables.size():
			continue
		var lvl := CardLevels.base_level(w, code)  # Overlevels never shift the catch-up
		for m in w.item_tables[code].modifiers:
			for o in m.ops:
				if o.op == ModifierOp.Op.ADD and o.field == &"rate_bonus_permille":
					sum += int(o.at_level(lvl).value)
	return sum


## What slot `s`'s card counts in levels: an ability modifier its level; a v0.5 item 1; an M-list card
## 1, a rare one (the trinkets, the ability merges) 2, a legendary one (the boss's tier) 3; a wand card
## (CardLevels) one more per level past the first.
static func power_level(w: World, s: int) -> int:
	var code := w.mod_slots[s]
	if Offers.type_of(code) != Offers.MOD or code >= w.item_tables.size():
		return BuildSlots.level_at(w, s)
	var t := w.item_tables[code]
	var up := CardLevels.base_level(w, code) - 1  # v0.6.5 WN3 (W3-P3: overlevels not counted: the catch-up as before)
	if t.kind != ItemTable.Kind.MODIFIER and t.kind != ItemTable.Kind.WAND:
		return 1
	match t.rarity:
		ItemTable.RARE, ItemTable.EPIC:  # An epic card counts as a rare one
			return 2 + up
		ItemTable.LEGENDARY:
			return 3 + up
	return 1 + up


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
	s.cap = cap_at(t.cap_permille, t, w.floor_index, Curses.threat(w)) + w.loop_cap_permille  # v0.7.5 AP
	s.enemy = multiplier(s.power, s.expected, s.cap)
	s.boss_read = 0  # The floor's boss is read again at its door


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


## Reads the boss's own m now: P now, the expected power at the floor's end, the boss cap (the
## floor's entry of boss_cap_permille + threat_cap × T now + the loops'), then the boss's spread (BOSS_SPREAD_STREAM:
## one draw per boss fight, uniform in ±BOSS_SPREAD_PERMILLE per mille, applied after the cap). BossFlow.interact calls
## it as the boss door starts to open; on_boss reads it at the spawn when none was stored. No-op without a table.
static func read_boss(w: World) -> void:
	var t := w.catch_up_table
	if t == null:
		return
	var s := w.catch_up
	s.boss_power = power(w)
	s.boss_expected = CatchUpTable.at_floor(t.boss_expected_permille, w.floor_index)
	s.boss_cap = (
		cap_at(t.boss_cap_permille, t, w.floor_index, Curses.threat(w)) + w.loop_cap_permille
	)  # Each loop past the first raises the caps
	var m := multiplier(s.boss_power, s.boss_expected, s.boss_cap)
	s.boss = maxi(1, m * spread_permille(w) / 1000)
	s.boss_read = 1


## The boss fight's HP spread, per mille: 1000 + one draw uniform in ±boss_spread_permille from its stream
## (spread_stream; a fresh stream each call, so the same value for the same fight).
static func spread_permille(w: World) -> int:
	var sp := w.catch_up_table.boss_spread_permille
	return 1000 + RngStream.derive(w.seed_value, spread_stream(w)).range_int(-sp, sp)


## v0.10.5 O2b (owner D38 (a)): a floor boss's paced HP multiplier, per mille: pace × min(P, E × cap / 1000) / E, at
## least lo. pace is the multiplier at P = E (data: boss_pace_permille); past cap × E the HP stops growing, so the
## fight shortens in step with the extra power (a phase can melt only that far past the expected build).
static func pace_multiplier(p: int, e: int, pace: int, cap: int, lo: int) -> int:
	var ee := maxi(1, e)
	var capped := mini(maxi(0, p), ee * maxi(1000, cap) / 1000)
	return maxi(maxi(1, lo), pace * capped / ee)


## The HP multiplier, per mille, of the boss read at the door (World.catch_up): the paced one × the spread when the
## table paces bosses (and this is not the final fight), else the catch-up m (spread included). 1000 without a table.
static func boss_hp_permille(w: World) -> int:
	var t := w.catch_up_table
	if t == null:
		return 1000
	var s := w.catch_up
	if t.boss_pace_permille.is_empty() or w.final_fight != null:
		return s.boss
	var pace := CatchUpTable.at_floor(t.boss_pace_permille, w.floor_index)
	var m := pace_multiplier(
		s.boss_power, s.boss_expected, pace, t.boss_pace_cap_permille, t.boss_pace_min_permille
	)
	return maxi(1, m * spread_permille(w) / 1000)


## The named stream of a boss fight's HP spread: `boss:hp_spread`, keyed by the floor, the loop and (a final fight) the
## body, so each fight draws its own value, the same for the same seed.
static func spread_stream(w: World) -> String:
	var body := w.final_fight.phase if w.final_fight != null else 0
	return "%s:%d:%d:%d" % [BOSS_SPREAD_STREAM, w.floor_index, w.loop, body]


## Boss i just spawned: its m (read at the door when BossFlow stored one, else read now), then max HP × the paced
## multiplier (boss_hp_permille; v0.10.5 O2b) and its attacks' damage × sqrt(m) (ActorStore.power). No-op without a
## table.
static func on_boss(w: World, i: int) -> void:
	var t := w.catch_up_table
	if t == null:
		return
	var s := w.catch_up
	if s.boss_read == 0:
		read_boss(w)
	s.boss_read = 0
	var a := w.actors
	var hp := maxi(1, a.max_hp[i] * boss_hp_permille(w) / 1000)  # Paced
	a.max_hp[i] = hp
	a.hp[i] = hp
	a.power[i] = damage_permille(s.boss)
