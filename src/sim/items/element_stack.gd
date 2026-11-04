class_name ElementStack
extends RefCounted
## v0.10.5 W3-P1 + W3-P2 (the progression audit, docs/roadmap/v0.10.5/W3_O4_PROGRESSION_G1.md P1, P2; owner approved
## 2026-11-04): what an element's own damage counts for.
## - P1, the falloff: each element's damage on an enemy that already carries k OTHER elements counts at
##   ElementPairTable.stack_falloff_permille[k] (data 1000 / 700 / 500 / 350 for k = 0 / 1 / 2 / 3+). An enemy carries
##   Fire while it burns, Venom while poisoned, Bleed while bleeding, Frost while it has frost stacks or is frozen, and
##   Lightning while shocked (the Storm card leaves no status of its own, so its chain and strike hits fall off on a
##   carrying enemy but never count against the others). The pair rules (X1-X10) are untouched; a pair's own damage
##   (bursts, Sepsis) is not an element's.
## - P2, the level shift: an element's damage at its card's level n counts at the card's el_level_permille[n - 1]
##   (ItemTable; empty = 1000 at every level), so part of Lv 1's power moves to Lv 2-3.
## An element's damage: its status ticks (burn, poison, bleed, Exsanguinate's burst), its hook hits (Fire's burning
## ground, Lightning's chain beam), Overcharge's strike and Shatter's shards (Damage.hit by effect id), and the bonus
## part of Heat sync and Frostbite (ElementLevelsFsf.attacker_mult). Only the hero's damage on an enemy, only with the
## pair table (World.pair_table: none, as before). Stateless: nothing to save or hash. Integers, rounded to nearest.

const NONE := -1
const FIRE := ElementPairs.FIRE
const STORM := ElementPairs.STORM
const FROST := ElementPairs.FROST
const VENOM := ElementPairs.VENOM
const BLEED := ElementPairs.BLEED


## The element of a status tick's matchup element (Damage.tick_dot) or of a hit's effect id (Damage.hit), or NONE.
static func of_id(id: StringName) -> int:
	match id:
		&"ember", &"ember_core":
			return FIRE
		&"venom":
			return VENOM
		&"bleed", &"exsanguinate":
			return BLEED
		&"storm_core", &"storm_strike":
			return STORM
		&"frost_shard":
			return FROST
	return NONE


## Element `e` is on enemy `i` now.
static func carries(w: World, i: int, e: int) -> bool:
	var a := w.actors
	match e:
		FIRE:
			return a.burn_stacks[i] > 0
		VENOM:
			return a.poison_stacks[i] > 0
		BLEED:
			return a.bleed_stacks[i] > 0
		FROST:
			return a.frost_stacks[i] > 0 or a.frozen_t[i] > 0
		STORM:
			return a.shock_stacks[i] > 0
	return false


## How many elements other than `e` enemy `i` carries.
static func others(w: World, i: int, e: int) -> int:
	var n := 0
	for x in 5:
		if x != e and carries(w, i, x):
			n += 1
	return n


## P1: the falloff for element `e`'s damage on enemy `i`, per mille (1000 without the table).
static func falloff_permille(w: World, i: int, e: int) -> int:
	var t := w.pair_table
	if t == null or t.stack_falloff_permille.is_empty():
		return 1000
	var k := mini(others(w, i, e), t.stack_falloff_permille.size() - 1)
	return t.stack_falloff_permille[k]


## P2: the held element `e` card's share at its level, per mille (1000 without the card or its row).
static func level_permille(w: World, e: int) -> int:
	if w.pair_table == null:
		return 1000
	var id := ElementPairs.CARDS[e]
	for idx in w.items_owned:
		var t := w.item_tables[idx]
		if t.id != id or not CardLevels.is_card(w, idx):
			continue
		var row := t.el_level_permille
		if row.is_empty():
			return 1000
		return row[clampi(CardLevels.level(w, idx), 1, row.size()) - 1]
	return 1000


## Both, for element `e`'s damage on enemy `i` (1000 = unchanged).
static func mult(w: World, i: int, e: int) -> int:
	if e == NONE or i <= 0 or w.pair_table == null:
		return 1000
	return falloff_permille(w, i, e) * level_permille(w, e) / 1000


## `amount` × `permille`, rounded to nearest; a hit that had damage keeps at least 1.
static func scale(amount: int, permille: int) -> int:
	if permille == 1000 or amount <= 0:
		return amount
	return maxi(1, (amount * permille + 500) / 1000)


## Element `e`'s bonus multiplier `bonus_mult` (per mille, e.g. Heat sync's 1150) on enemy `i`, its bonus part fallen
## off (P1); the level shift is not applied to a level's own bonus.
static func bonus(w: World, i: int, e: int, bonus_mult: int) -> int:
	if bonus_mult == 1000 or w.pair_table == null:
		return bonus_mult
	return 1000 + (bonus_mult - 1000) * falloff_permille(w, i, e) / 1000
