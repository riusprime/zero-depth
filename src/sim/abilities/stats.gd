class_name Stats
extends RefCounted
## Stat cards and crit (v0.4.0 BS, owner F9). World.stat_values holds one integer per Stat (empty = no card yet:
## every stat at its base). Cards stack multiplicatively in per mille, rounded half up at each card:
## - MULT stats: value x (1000 + amount) / 1000, never over the cap (max HP, damage, attack speed, area, move speed,
##   shard gain, pickup range; base 1000 = x1);
## - CUT stats: value x (1000 - amount) / 1000, never under the cap (cooldowns, armour = damage taken);
## - ADD stats: value + amount (crit chance and crit damage in per mille points on top of the player's base, capped
##   in total; regen in per mille of max HP per second).
## Every hit the player owns goes through outgoing() in Damage.hit: x damage, then (direct hits only, never a DoT
## tick) a crit roll on the `crit` stream: chance = base + cards (capped at 75 %), crit = x crit damage (base x1.5,
## capped at x4) and TAG_CRIT. A DoT tick takes the damage stat but never crits. Hits the player takes go through
## armour. The other stats are read where the sim computes them (cooldowns, reach, move speed, shards, regen ...).

enum Stat {
	MAX_HP,
	DAMAGE,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	ATTACK_SPEED,
	AREA,
	COOLDOWNS,
	MOVE,
	REGEN,
	SHARDS,
	PICKUP,
	ARMOUR,
}
enum Rarity { COMMON, RARE, EPIC }

const COUNT := 12
const MULT := 0
const CUT := 1
const ADD := 2
const MODE: Array[int] = [MULT, MULT, ADD, ADD, MULT, MULT, CUT, MULT, ADD, MULT, MULT, CUT]
const BASE: Array[int] = [1000, 1000, 0, 0, 1000, 1000, 1000, 1000, 0, 1000, 1000, 1000]
## One HP of stat regen in the accumulator: per mille x ticks per second.
const REGEN_UNIT := 1000 * SimTick.TICKS_PER_SECOND


## Stat cards are part of this world's loadout (a run): offers include them and the gamble shrine pays in them.
static func enabled(w: World) -> bool:
	return not w.stat_tables.is_empty()


## The stat's raw value (BASE until a card raised it).
static func value(w: World, s: int) -> int:
	return w.stat_values[s] if s < w.stat_values.size() else BASE[s]


## The stat's table (null when the loadout has none for it).
static func table(w: World, s: int) -> StatTable:
	return w.stat_tables[s] if s < w.stat_tables.size() else null


## Adds one card of stat `s` at `rarity`: the value moves by the card's amount within the cap. Max HP rises at once
## and heals by as much. No-op without a table for the stat.
static func add_card(w: World, s: int, rarity: int) -> void:
	var t := table(w, s)
	if t != null:
		add_amount(w, s, t.amounts[clampi(rarity, 0, 2)])


## Moves stat `s` by `a` per mille (a card's amount, or a gamble win's) within its cap.
static func add_amount(w: World, s: int, a: int) -> void:
	var t := table(w, s)
	if t == null:
		return
	if w.stat_values.size() < COUNT:
		var old := w.stat_values
		w.stat_values = PackedInt32Array(BASE)
		for k in old.size():
			w.stat_values[k] = old[k]
	var before_hp := max_hp(w)
	var v := w.stat_values[s]
	match MODE[s]:
		MULT:
			v = (v * (1000 + a) + 500) / 1000
			v = mini(v, t.cap) if t.cap > 0 else v
		CUT:
			v = (v * (1000 - a) + 500) / 1000
			v = maxi(v, t.cap) if t.cap > 0 else v
		ADD:
			v += a
	w.stat_values[s] = v
	if s == Stat.MAX_HP:
		var gain := max_hp(w) - before_hp
		w.actors.max_hp[0] += gain
		w.actors.hp[0] = mini(w.actors.max_hp[0], w.actors.hp[0] + maxi(0, gain))


## True when another card of `s` would change nothing (offers skip it).
static func at_cap(w: World, s: int) -> bool:
	var t := table(w, s)
	if t == null:
		return true
	if t.cap <= 0:
		return false
	match MODE[s]:
		MULT:
			return value(w, s) >= t.cap
		CUT:
			return value(w, s) <= t.cap
	return total(w, s) >= t.cap


## An ADD stat's total with the player's base (crit chance and crit damage in per mille).
static func total(w: World, s: int) -> int:
	match s:
		Stat.CRIT_CHANCE:
			return w.player.crit_chance_permille + value(w, s)
		Stat.CRIT_DAMAGE:
			return w.player.crit_mult_permille + value(w, s)
	return value(w, s)


## The player's max HP: the table's, x the max HP stat, plus the gamble shrine's old-style wins (v0.3.0 L19) when
## the shrine doesn't pay in stats.
static func max_hp(w: World) -> int:
	var base := (w.player.hp * value(w, Stat.MAX_HP) + 500) / 1000
	return base + Gamble.hook_bonus(w, GambleTable.Stat.MAX_HP)


# --- Damage ----------------------------------------------------------------------------------------------------
## Crit chance now, per mille (base + cards, at most the cap).
static func crit_chance(w: World) -> int:
	var t := table(w, Stat.CRIT_CHANCE)
	var c := total(w, Stat.CRIT_CHANCE)
	return mini(c, t.cap) if t != null and t.cap > 0 else c


## A crit's multiplier now, per mille (base 1500 + cards, at most the cap).
static func crit_mult(w: World) -> int:
	var t := table(w, Stat.CRIT_DAMAGE)
	var c := total(w, Stat.CRIT_DAMAGE)
	return mini(c, t.cap) if t != null and t.cap > 0 else c


## A hit the player owns, before the target's multipliers (Damage.hit): x damage, then the crit roll. Returns
## [amount, extra tags]. The roll draws the `crit` stream only when the chance is above 0.
static func outgoing(w: World, amount: int, tags: int) -> Array[int]:
	var m := value(w, Stat.DAMAGE)
	if m != 1000:
		amount = (amount * m + 500) / 1000
	if tags & SimEvent.TAG_DOT:
		return [amount, 0]
	var chance := crit_chance(w)
	if chance <= 0 or w.rng_crit.range_int(0, 999) >= chance:
		return [amount, 0]
	return [(amount * crit_mult(w) + 500) / 1000, SimEvent.TAG_CRIT]


## A DoT tick the player owns: x damage only (DoT never crits).
static func dot(w: World, amount: int) -> int:
	var m := value(w, Stat.DAMAGE)
	return amount if m == 1000 else (amount * m + 500) / 1000


## Armour's multiplier on a hit the player takes, per mille.
static func armour_permille(w: World) -> int:
	return value(w, Stat.ARMOUR)


# --- Times, areas, speeds --------------------------------------------------------------------------------------
## A cooldown of `ticks` under the cooldowns stat (never under 1 tick when it was above 0).
static func cooldown(w: World, ticks: int) -> int:
	var m := value(w, Stat.COOLDOWNS)
	if m == 1000 or ticks <= 0:
		return ticks
	return maxi(1, (ticks * m + 500) / 1000)


## A firing period of `ticks` under attack speed (never under 1 tick).
static func period(w: World, ticks: int) -> int:
	var m := value(w, Stat.ATTACK_SPEED)
	if m == 1000:
		return ticks
	return maxi(1, (ticks * 1000 + m / 2) / m)


## The tick a swing of `step` ends: its recovery shortens under attack speed (its hit tick doesn't move).
static func swing_end(w: World, step: SwingStep) -> int:
	var m := value(w, Stat.ATTACK_SPEED)
	if m == 1000:
		return step.ticks
	var rec := step.ticks - step.active_tick
	return step.active_tick + maxi(1, (rec * 1000 + m / 2) / m)


static func area(w: World, metres: float) -> float:
	var m := value(w, Stat.AREA)
	return metres if m == 1000 else metres * m / 1000.0


static func move_permille(w: World) -> int:
	return value(w, Stat.MOVE)


static func shards(w: World, amount: int) -> int:
	var m := value(w, Stat.SHARDS)
	return amount if m == 1000 else (amount * m + 500) / 1000


## An interact or pickup reach under pickup range.
static func reach(w: World, metres: float) -> float:
	var m := value(w, Stat.PICKUP)
	return metres if m == 1000 else metres * m / 1000.0


## Tick phase 6 (Abilities.advance): regen heals regen per mille of max HP a second, in and out of combat.
static func advance_regen(w: World) -> void:
	var rate := value(w, Stat.REGEN)
	var a := w.actors
	if rate <= 0 or w.player_dead() or a.hp[0] >= a.max_hp[0]:
		w.ab.regen_acc = 0
		return
	w.ab.regen_acc += a.max_hp[0] * rate
	while w.ab.regen_acc >= REGEN_UNIT and a.hp[0] < a.max_hp[0]:
		a.hp[0] += 1
		w.ab.regen_acc -= REGEN_UNIT
		w.ab.regen_tick = w.tick


## The gamble shrine pays its overlapping stats into the same stat values (v0.4.0 BS), by its own amounts: the stat
## a shrine stat maps to, or -1 (heat, or a world without stat cards).
static func from_gamble(w: World, gamble_stat: int) -> int:
	if not enabled(w):
		return -1
	match gamble_stat:
		GambleTable.Stat.MAX_HP:
			return Stat.MAX_HP
		GambleTable.Stat.MELEE, GambleTable.Stat.SHOT:
			return Stat.DAMAGE
		GambleTable.Stat.MOVE:
			return Stat.MOVE
		GambleTable.Stat.DASH_CD:
			return Stat.COOLDOWNS
		GambleTable.Stat.REGEN:
			return Stat.REGEN
		GambleTable.Stat.SHARDS:
			return Stat.SHARDS
	return -1
