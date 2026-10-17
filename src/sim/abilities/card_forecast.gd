class_name CardForecast
extends RefCounted
## v0.8.0 N8 (owner O62, "below, what gets better, with the old value and the new one"): what taking card `code`
## changes, as one before → after pair, worked out by the same sim steps the take runs (EI-07: a forecast calls the
## outcome's own function), so the card's numbers are the numbers you get:
## - a stat card: the stat's shown value now and after one card (Stats.card_amount, Stats.stepped within the cap;
##   max HP in HP through Stats.max_hp_at, crit through Stats.total_at, the rest per mille);
## - an ability card: its level now (0: new) and after (Abilities.level_after);
## - a wand card: its level now (0: not held) and after (CardLevels.level_after, then the boss's altar's level-5 rule
##   BossReward.level_after);
## - any other card (a passive mod, a trigger, a curse): no number (KIND_NONE).
## Pure: it reads the world and writes nothing.

const KIND_NONE := 0
const KIND_LEVEL := 1
const KIND_PERMILLE := 2
const KIND_HP := 3


## {kind, old, new, stat (the Stats.Stat, or -1)} for card `code` taken from reward index `reward` (-1: not from
## a reward, e.g. the shop).
static func of(w: World, code: int, reward: int = -1) -> Dictionary:
	var out := {"kind": KIND_NONE, "old": 0, "new": 0, "stat": -1}
	match Offers.type_of(code):
		Offers.STAT:
			var s := Offers.stat_of(code)
			var t := Stats.table(w, s)
			if t == null:
				return out
			var v := Stats.value(w, s)
			var after := Stats.stepped(t, s, v, Stats.card_amount(w, s, Offers.rarity_of(code)))
			out["stat"] = s
			if s == Stats.Stat.MAX_HP:
				out["kind"] = KIND_HP
				out["old"] = Stats.max_hp(w)
				out["new"] = Stats.max_hp_at(w, after)
			else:
				out["kind"] = KIND_PERMILLE
				out["old"] = Stats.total_at(w, s, v)
				out["new"] = Stats.total_at(w, s, after)
		Offers.ABILITY:
			var idx := Offers.ability_of(code)
			out["kind"] = KIND_LEVEL
			out["old"] = Abilities.level_of(w, idx)
			out["new"] = Abilities.level_after(w, idx)
		Offers.MOD:
			if CardLevels.is_card(w, code):
				var held := CardLevels.level(w, code) if w.items_owned.has(code) else 0
				out["kind"] = KIND_LEVEL
				out["old"] = held
				out["new"] = BossReward.level_after(
					w, reward, code, CardLevels.level_after(w, code)
				)
	return out
