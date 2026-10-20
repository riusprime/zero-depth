class_name Stats
extends RefCounted
## Stat cards and crit (v0.4.0 BS, owner F9). World.stat_values holds one integer per Stat (empty = no card yet:
## every stat at its base). Cards stack multiplicatively in per mille, rounded half up at each card:
## - MULT stats: value x (1000 + amount) / 1000, never over the cap (max HP, area, move speed, shard gain, pickup
##   range; base 1000 = x1); v0.8.0 SG (owner O91): an additive table (StatTable.additive: damage, attack speed, Glass
##   Cannon) adds instead, value + amount within the cap;
## - CUT stats: value x (1000 - amount) / 1000, never under the cap (cooldowns, armour = damage taken);
## - ADD stats: value + amount (crit chance and crit damage in per mille points on top of the player's base, capped
##   in total; regen in per mille of max HP per second).
## Every hit the player owns goes through outgoing() in Damage.hit: x damage, then (direct hits only, never a DoT
## tick) a crit roll on the `crit` stream: chance = base + cards (capped at 75 %), crit = x crit damage (base x1.5,
## capped at x4) and TAG_CRIT. A DoT tick takes the damage stat but never crits. Hits the player takes go through
## armour. The other stats are read where the sim computes them (cooldowns, reach, move speed, shards, regen ...).
## v0.5.0 CP, five rule cards that make a decision rather than a flat gain (StatTable.side and limit_permille):
## - GLASS_CANNON (MULT): x damage; each card also cuts the max HP stat by its side amount, never under the limit
##   (offers stop once either end is reached);
## - ONRUSH (ADD): + damage while the player moves (InputFrame move held);
## - OVERKILL (ADD): a direct hit that kills splashes this share of its excess damage onto the nearest other enemy
##   within the limit's metres (once; the splash never splashes, never re-rolls crit or the damage stats);
## - HOARDER (ADD): + damage per full 100 shards held (at most the limit's shards count); each card also raises
##   the shard gain stat by its side amount, so spending at a chest trades power for a card;
## - FAST_HANDS (CUT): the auto abilities' cooldowns and periods only (auto_cooldown, auto_period).
## v0.5.5 EC (owner D9): LIFESPROUT (ADD), the heal-orb card: the first card sets the kill's heal-orb drop chance to
## its amount, each further card adds its side amount; the chance is read capped (heal_orb_chance). Without the card
## no orb drops (HealOrbs.on_kill).
## Damage stats fold into one multiplier (damage_permille). v0.8.0 SG (owner O91): one additive bucket, (damage +
## onrush while moving + hoarder) x glass cannon; the curses stay explicit multipliers. Attack speed reads one curve
## with the attack's wand bonus (AttackRate).

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
	GLASS_CANNON,
	ONRUSH,
	OVERKILL,
	HOARDER,
	FAST_HANDS,
	LIFESPROUT,
}
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }  # v0.5.5 AR: LEGENDARY, the boss's tier (X1b)

const COUNT := 18
const MULT := 0
const CUT := 1
const ADD := 2
const MODE: Array[int] = [
	MULT, MULT, ADD, ADD, MULT, MULT, CUT, MULT, ADD, MULT, MULT, CUT, MULT, ADD, ADD, ADD, CUT, ADD
]
const BASE: Array[int] = [
	1000, 1000, 0, 0, 1000, 1000, 1000, 1000, 0, 1000, 1000, 1000, 1000, 0, 0, 0, 1000, 0
]
## v0.8.0 SG (owner O91): the stat rules a world's values follow (World.stat_rules): 0 before SG (damage, attack
## speed and Glass Cannon compounded), 1 since (their cards add). An older save rebuilds them (migrate_rules).
const RULES := 1
const ADDITIVE_STATS: Array[int] = [Stat.DAMAGE, Stat.ATTACK_SPEED, Stat.GLASS_CANNON]
## Hoarder counts shards in steps of this many.
const HOARD_STEP := 100
const EFFECT_OVERKILL := &"overkill"
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
		var r := clampi(rarity, 0, t.amounts.size() - 1)
		w.stat_cards.append(Offers.stat_code(s, r))  # v0.5.0 SH: the shop can sell it back
		add_amount(w, s, card_amount(w, s, r))
		if s != Stat.LIFESPROUT:
			_side(w, t, s, t.side[r] if r < t.side.size() else 0)


## What a card of stat `s` at `rarity` adds now: its amount, but for Lifesprout (v0.5.5 D9) only the first card
## adds the amount and every further card its side amount.
static func card_amount(w: World, s: int, rarity: int) -> int:
	var t := table(w, s)
	if t == null:
		return 0
	var r := clampi(rarity, 0, t.amounts.size() - 1)
	if s == Stat.LIFESPROUT and value(w, s) > 0:
		return t.side[r] if r < t.side.size() else 0
	return t.amounts[r]


## v0.5.0 CP: a rule card's second number: Glass Cannon cuts the max HP stat (never under its limit), Hoarder raises
## shard gain. Both move the other stat's value directly, so they work without that stat's own card table.
static func _side(w: World, t: StatTable, s: int, a: int) -> void:
	if a <= 0:
		return
	match s:
		Stat.GLASS_CANNON:
			var before := max_hp(w)
			var v := (w.stat_values[Stat.MAX_HP] * (1000 - a) + 500) / 1000
			w.stat_values[Stat.MAX_HP] = maxi(v, t.limit_permille)
			var gain := max_hp(w) - before
			# The max-HP push, twin of add_amount's: this one floors max HP at 1 and keeps HP at least 1; that one
			# doesn't floor. They have drifted, so they stay apart: merging would change one call site (audit G-17).
			w.actors.max_hp[0] = maxi(1, w.actors.max_hp[0] + gain)
			w.actors.hp[0] = clampi(w.actors.hp[0], 1, w.actors.max_hp[0])
		Stat.HOARDER:
			w.stat_values[Stat.SHARDS] = (w.stat_values[Stat.SHARDS] * (1000 + a) + 500) / 1000


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
	w.stat_values[s] = stepped(t, s, w.stat_values[s], a)
	if s == Stat.MAX_HP:
		var gain := max_hp(w) - before_hp
		# Twin of _side's Glass Cannon push, without its floor of 1 (see there; audit G-17).
		w.actors.max_hp[0] += gain
		w.actors.hp[0] = mini(w.actors.max_hp[0], w.actors.hp[0] + maxi(0, gain))


## v0.8.0 N8: stat `s`'s raw value `v` moved by `a` per mille within table `t`'s cap (add_amount's step, and the
## pick card's forecast: CardForecast). Pure.
static func stepped(t: StatTable, s: int, v: int, a: int) -> int:
	match MODE[s]:
		MULT:
			v = v + a if t.additive else (v * (1000 + a) + 500) / 1000
			return mini(v, t.cap) if t.cap > 0 else v
		CUT:
			v = (v * (1000 - a) + 500) / 1000
			return maxi(v, t.cap) if t.cap > 0 else v
	return v + a


## True when another card of `s` would change nothing (offers skip it).
static func at_cap(w: World, s: int) -> bool:
	var t := table(w, s)
	if t == null:
		return true
	if s == Stat.GLASS_CANNON and value(w, Stat.MAX_HP) <= t.limit_permille:
		return true  # v0.5.0 CP: no more HP to trade
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
	return total_at(w, s, value(w, s))


## v0.8.0 N8: total() for a raw value `v` of stat `s` (CardForecast's after-card number).
static func total_at(w: World, s: int, v: int) -> int:
	match s:
		Stat.CRIT_CHANCE:
			return w.player.crit_chance_permille + v
		Stat.CRIT_DAMAGE:
			return w.player.crit_mult_permille + v
	return v


## The player's max HP: the table's, x the max HP stat, plus the gamble shrine's old-style wins (v0.3.0 L19) when
## the shrine doesn't pay in stats.
static func max_hp(w: World) -> int:
	return max_hp_at(w, value(w, Stat.MAX_HP))


## v0.8.0 N8: max_hp() with the max HP stat at `v` (CardForecast's after-card number).
static func max_hp_at(w: World, v: int) -> int:
	var base := (w.player.hp * v + 500) / 1000
	var cut := Curses.max_hp_permille(w)  # v0.6.0 CU: Glass Heart
	if cut != 1000:
		base = maxi(1, (base * cut + 500) / 1000)
	return base + Gamble.hook_bonus(w, GambleTable.Stat.MAX_HP)


# --- Damage ----------------------------------------------------------------------------------------------------
## Crit chance now, per mille (base + cards, at most the cap).
static func crit_chance(w: World) -> int:
	var t := table(w, Stat.CRIT_CHANCE)
	var c := total(w, Stat.CRIT_CHANCE) + Curses.crit_chance(w)  # v0.6.0 CU: Glass Heart
	return mini(c, t.cap) if t != null and t.cap > 0 else c


## A crit's multiplier now, per mille (base 1500 + cards, at most the cap).
static func crit_mult(w: World) -> int:
	var t := table(w, Stat.CRIT_DAMAGE)
	var c := total(w, Stat.CRIT_DAMAGE)
	return mini(c, t.cap) if t != null and t.cap > 0 else c


## A hit the player owns, before the target's multipliers (Damage.hit): x damage, then the crit roll. Returns
## [amount, extra tags]. The roll draws the `crit` stream only when the chance is above 0.
static func outgoing(w: World, amount: int, tags: int) -> Array[int]:
	var m := damage_permille(w)
	var ab := Curses.ability_damage_permille(w, tags)  # v0.6.0 CU: Blood Price
	if ab != 1000:
		m = (m * ab + 500) / 1000
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
	var m := damage_permille(w)
	return amount if m == 1000 else (amount * m + 500) / 1000


## The player's damage multiplier now, per mille (v0.8.0 SG, owner O91): the bucket (damage_bucket: the damage stat
## + Onrush while moving + Hoarder per 100 shards held) x glass cannon.
static func damage_permille(w: World) -> int:
	return damage_at(w, damage_bucket(w, w.move_intent != Vector2i.ZERO))


## v0.8.0 SG: the additive damage bucket, per mille: the damage stat (its cards and the gamble's wins add) + Hoarder's
## bonus now + Onrush when `moving`.
static func damage_bucket(w: World, moving: bool) -> int:
	return bucket_at(w, value(w, Stat.DAMAGE), moving)


## damage_bucket() with the damage stat at raw value `v` (CardForecast's after-card number).
static func bucket_at(w: World, v: int, moving: bool) -> int:
	var b := v + hoard_bonus(w)
	return b + value(w, Stat.ONRUSH) if moving else b


## Bucket `b` x glass cannon, per mille.
static func damage_at(w: World, b: int) -> int:
	var g := value(w, Stat.GLASS_CANNON)
	return b if g == 1000 else (b * g + 500) / 1000


## Hoarder's bonus now, per mille: per full 100 shards held, at most the limit's shards counted.
static func hoard_bonus(w: World) -> int:
	var rate := value(w, Stat.HOARDER)
	var t := table(w, Stat.HOARDER)
	if rate <= 0 or t == null:
		return 0
	return mini(w.shards, t.limit_permille / 1000) / HOARD_STEP * rate


## Overkill (Damage.hit): a direct player hit killed enemy `target` with `excess` damage left over; the share
## splashes onto the nearest other live enemy within the limit's reach. No-op without the card.
static func overkill(w: World, target: int, excess: int, root: int) -> void:
	var share := value(w, Stat.OVERKILL)
	var t := table(w, Stat.OVERKILL)
	if share <= 0 or excess <= 0 or t == null:
		return
	var amount := (excess * share + 500) / 1000
	if amount <= 0:
		return  # before the scan (audit G-16)
	var a := w.actors
	var at := a.pos(target)
	var near := Engines.nearest_enemies(w, target, at, t.limit_permille / 1000.0, 1)
	if near.is_empty():
		return
	var best := near[0]
	var pid := a.ids[0]
	Damage.hit(w, best, amount, pid, pid, root, SimEvent.TAG_AREA, at, a.pos(best), EFFECT_OVERKILL)


## Armour's multiplier on a hit the player takes, per mille.
static func armour_permille(w: World) -> int:
	return value(w, Stat.ARMOUR)


## v0.5.5 D9: a kill's heal-orb drop chance from Lifesprout, per mille (0 without the card; at most its cap).
static func heal_orb_chance(w: World) -> int:
	var t := table(w, Stat.LIFESPROUT)
	var c := value(w, Stat.LIFESPROUT)
	return mini(c, t.cap) if t != null and t.cap > 0 else c


# --- Times, areas, speeds --------------------------------------------------------------------------------------
## A cooldown of `ticks` under the cooldowns stat (never under 1 tick when it was above 0).
static func cooldown(w: World, ticks: int) -> int:
	return _scaled_ticks(w, Stat.COOLDOWNS, ticks)


## `ticks` x stat `s` per mille, rounded half up, never under 1 tick when it was above 0 (Cooldowns and Fast Hands'
## one rule; audit G-17).
static func _scaled_ticks(w: World, s: int, ticks: int) -> int:
	var m := value(w, s)
	if m == 1000 or ticks <= 0:
		return ticks
	return maxi(1, (ticks * m + 500) / 1000)


## v0.5.0 CP: an auto ability's cooldown: the cooldowns stat, then Fast Hands (never under 1 tick).
static func auto_cooldown(w: World, ticks: int) -> int:
	return _fast(w, cooldown(w, ticks))


## v0.5.0 CP: an auto ability's firing period: attack speed (the curve, the stat alone), then Fast Hands (never
## under 1 tick).
static func auto_period(w: World, ticks: int) -> int:
	return _fast(w, period(w, ticks))


static func _fast(w: World, ticks: int) -> int:
	return _scaled_ticks(w, Stat.FAST_HANDS, ticks)


## A firing period of `ticks` under attack speed without a wand bonus (AttackRate: the stat through the curve, then
## Heavy Hands; never under 1 tick). v0.8.0 SG: the Gun's period and the Blade's swing read AttackRate with their
## wand bonus (ItemEffects.shot_period_ticks, BladeForms.step); the old recovery-only swing_end folded into the
## Blade's one rate.
static func period(w: World, ticks: int) -> int:
	var m := AttackRate.rate(w, 0)
	if m == 1000:
		return ticks
	return maxi(1, AttackRate.scaled(ticks, m))


static func area(w: World, metres: float) -> float:
	return _scaled_m(w, Stat.AREA, metres)


## `metres` x stat `s` per mille (Area and Pickup range's one rule; audit G-17).
static func _scaled_m(w: World, s: int, metres: float) -> float:
	var m := value(w, s)
	return metres if m == 1000 else metres * m / 1000.0


## v0.8.0 N2 (owner O42): in The Fallen's mimic window the move speed is at most the base (FinalPace.move_cap).
static func move_permille(w: World) -> int:
	return FinalPace.move_cap(w, value(w, Stat.MOVE))


static func shards(w: World, amount: int) -> int:
	var m := value(w, Stat.SHARDS)
	var c := Curses.shard_permille(w)  # v0.6.0 CU: Tunnel Vision
	if c != 1000:
		m = (m * c + 500) / 1000
	return amount if m == 1000 else (amount * m + 500) / 1000


## An interact or pickup reach under pickup range.
static func reach(w: World, metres: float) -> float:
	return _scaled_m(w, Stat.PICKUP, metres)


## Tick phase 6 (Abilities.advance): regen heals regen per mille of max HP a second, in and out of combat.
static func advance_regen(w: World) -> void:
	var rate := Curses.regen(w, value(w, Stat.REGEN))  # v0.5.0 EV curse
	var a := w.actors
	if rate <= 0 or w.player_dead() or a.hp[0] >= a.max_hp[0]:
		w.ab.regen_acc = 0
		return
	w.ab.regen_acc += a.max_hp[0] * rate
	while w.ab.regen_acc >= REGEN_UNIT and a.hp[0] < a.max_hp[0]:
		a.hp[0] += 1
		w.ab.regen_acc -= REGEN_UNIT
		w.ab.regen_tick = w.tick


## v0.8.0 SG: a world restored from before SG (World.stat_rules 0: WorldSnapshot.apply, or a carry through
## Abilities.start_floor) rebuilds damage, attack speed and Glass Cannon from its stat cards and the gamble shrine's
## stacks under today's rules (Shop.rebuild_stats' replay, limited to those stats). The other stats keep their stored
## values (an event's max HP cut isn't recorded anywhere to replay). Then stat_rules = RULES.
static func migrate_rules(w: World) -> void:
	if w.stat_rules >= RULES:
		return
	w.stat_rules = RULES
	if w.stat_values.size() < COUNT:
		return  # no card and no win yet: every stat at its base
	var redo := []
	for s in ADDITIVE_STATS:
		var t := table(w, s)
		if t != null and t.additive:
			redo.append(s)
			w.stat_values[s] = BASE[s]
	for c in w.stat_cards:
		var s := Offers.stat_of(c)
		if redo.has(s):
			var t := table(w, s)
			var r := clampi(Offers.rarity_of(c), 0, t.amounts.size() - 1)
			w.stat_values[s] = stepped(t, s, w.stat_values[s], t.amounts[r])
	var wins := w.gamble_stacks.size() if w.gamble_table != null else 0
	for g in wins:
		var s := from_gamble(w, g)
		if not redo.has(s):
			continue
		for k in w.gamble_stacks[g]:
			w.stat_values[s] = stepped(
				table(w, s), s, w.stat_values[s], Gamble.gamble_permille(w, g)
			)


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
