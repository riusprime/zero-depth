class_name CardForecast
extends RefCounted
## v0.8.0 N8 (owner O62, "below, what gets better, with the old value and the new one"): what taking card `code`
## changes, as one before → after pair, worked out by the same sim steps the take runs (EI-07: a forecast calls the
## outcome's own function), so the card's numbers are the numbers you get:
## - a stat card: the stat's shown value now and after one card (Stats.card_amount, Stats.stepped within the cap;
##   max HP in HP through Stats.max_hp_at, crit through Stats.total_at, the rest per mille). v0.8.0 SG (owner O91,
##   "Show actual marginal gains on cards"): damage shows the additive bucket (Stats.bucket_at: the damage stat and
##   Hoarder's bonus now, Onrush's movement left out), attack speed the weapon attack's rate after the curve with its
##   wand bonus and Heavy Hands counted (AttackRate.rate_at); v0.10.5 W3-P10a: the step within the loop's cap
##   (Stats.cap_of), and an attack-speed card past the curve's top (loop 2 on) also gives the damage bucket now and
##   after ("dmg_old", "dmg_new": Stats.bucket_at with the stat's overflow);
## - an ability card: its level now (0: new) and after (Abilities.level_after);
## - a wand card: its level now (0: not held) and after (CardLevels.level_after; v0.8.0 FL: the boss's altar's
##   level-5 rule is gone, so every source takes it one level up); v0.10.5 W3-P3: and its overlevel multiplier now and
##   after ("over_old", "over_new", per mille: CardLevels.overlevel_permille, the compile's own; 1000 below its max);
## - any other card (a passive mod, a trigger, a curse): no number (KIND_NONE).
## gain(): a stat card's shown amount, the forecast's new − old for attack speed (what the card really adds after
## the curve), else the card's amount (Offers.info's "amount", the card's sentence).
## Pure: it reads the world and writes nothing.

const KIND_NONE := 0
const KIND_LEVEL := 1
const KIND_PERMILLE := 2
const KIND_HP := 3


## {kind, old, new, stat (the Stats.Stat, or -1)} for card `code` taken from reward index `_reward` (-1: not from
## a reward, e.g. the shop; v0.8.0 FL: no source changes the forecast any more, the argument stays for the callers).
static func of(w: World, code: int, _reward: int = -1) -> Dictionary:
	var out := {"kind": KIND_NONE, "old": 0, "new": 0, "stat": -1}
	match Offers.type_of(code):
		Offers.STAT:
			var s := Offers.stat_of(code)
			var t := Stats.table(w, s)
			if t == null:
				return out
			var v := Stats.value(w, s)
			var amount := Stats.card_amount(w, s, Offers.rarity_of(code))
			var after := Stats.stepped(t, s, v, amount, Stats.cap_of(w, s, t))  # v0.10.5 W3-P10a: the loop's cap
			out["stat"] = s
			if s == Stats.Stat.MAX_HP:
				out["kind"] = KIND_HP
				out["old"] = Stats.max_hp(w)
				out["new"] = Stats.max_hp_at(w, after)
			elif s == Stats.Stat.DAMAGE:  # v0.8.0 SG: the bucket (without Onrush's movement)
				out["kind"] = KIND_PERMILLE
				out["old"] = Stats.bucket_at(w, v, false)
				out["new"] = Stats.bucket_at(w, after, false)
			elif s == Stats.Stat.ATTACK_SPEED:  # v0.8.0 SG: the weapon attack's rate after the curve
				var wand := AttackRate.weapon_bonus(w)
				out["kind"] = KIND_PERMILLE
				out["old"] = AttackRate.rate_at(w, v, wand)
				out["new"] = AttackRate.rate_at(w, after, wand)
				if AttackRate.overflow_at(w, after) > 0:  # v0.10.5 W3-P10a: past the curve's top, the damage bucket
					var d := Stats.value(w, Stats.Stat.DAMAGE)
					out["dmg_old"] = Stats.bucket_at(w, d, false, v)
					out["dmg_new"] = Stats.bucket_at(w, d, false, after)
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
				out["new"] = CardLevels.level_after(w, code)
				# v0.10.5 W3-P3: past its max a level is an overlevel: its main number now and after, per mille (the
				# compile's own CardLevels.overlevel_permille)
				var base := CardLevels.max_level(w, code)
				out["over_old"] = CardLevels.overlevel_permille(w, code, maxi(0, held - base))
				out["over_new"] = CardLevels.overlevel_permille(
					w, code, maxi(0, int(out["new"]) - base)
				)
	return out


## v0.8.0 SG: what stat card `code` really adds, per mille (the sentence's number: Offers.info "amount"): attack
## speed the rate's rise after the curve, any other stat its amount (Stats.card_amount).
static func gain(w: World, code: int) -> int:
	var s := Offers.stat_of(code)
	if s != Stats.Stat.ATTACK_SPEED or Stats.table(w, s) == null:
		return Stats.table(w, s).amounts[Offers.rarity_of(code)] if Stats.table(w, s) != null else 0
	var f := of(w, code)
	return int(f["new"]) - int(f["old"])
