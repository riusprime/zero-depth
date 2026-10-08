class_name Curses
extends RefCounted
## Curses and threat T (v0.5.0 EV, PLAN R4; BLUEPRINT §H; PD-05). A curse is a lasting drawback that came with a
## strong reward the player chose: a cursed chest card or an event choice. World.curses_owned lists the curses held
## (indices into World.ev.curses, in the order taken; no curse twice) and lasts the run (RunCarry). T is the sum of
## the held curses' threat; World.threat_peak is the highest T the run reached (M-THREAT). cleanse() lifts one: the
## Cleansing Font calls it, and a shop may (PLAN R1).
## Each effect is read where the sim computes it, through one hook here (a no-op without curses):
## - ENEMY_SPEED: normal enemies' movement (EnemyAi.move) x (1 + amount);
## - REGEN: both regen sources (PlayerRegen, Stats regen) x (1 - amount);
## - HEAT_DECAY: Overclock heat's decay per tick x (1 + amount);
## - EXTRA_ENEMY: every spawn arrival brings `amount` more, under the alive cap (SpawnDirector);
## - PRICES: chest, gamble shrine and event shard prices (and shops') x (1 + amount), rounded half up;
## - ELITE_CHANCE: each spawned enemy rolls `amount` per mille on `ai:elite` to be an elite (+ elite HP).
## Cursed chests: when a chest's offer is first rolled, `loot:event` rolls rules.cursed_chest_permille; a cursed
## offer's first card becomes an epic stat card (a stat under its cap not already offered) carrying a curse you don't
## hold. Taking that card takes the curse; the other cards are clean.

enum Effect { ENEMY_SPEED, REGEN, HEAT_DECAY, EXTRA_ENEMY, PRICES, ELITE_CHANCE }

const CURSED_SLOT := 0


static func owned(w: World, c: int) -> bool:
	return w.curses_owned.has(c)


## Threat T now: the held curses' threat.
static func threat(w: World) -> int:
	var t := 0
	for c in w.curses_owned:
		t += w.ev.curses[c].threat if c < w.ev.curses.size() else 1
	return t


## The summed amount of every held curse with `effect` (per mille; a count for EXTRA_ENEMY).
static func total(w: World, effect: int) -> int:
	var n := 0
	for c in w.curses_owned:
		if c < w.ev.curses.size() and w.ev.curses[c].effect == effect:
			n += w.ev.curses[c].amount
	return n


## Takes curse c (no-op when already held). T and its peak follow.
static func add(w: World, c: int) -> bool:
	if c < 0 or c >= w.ev.curses.size() or owned(w, c):
		return false
	w.curses_owned.append(c)
	w.threat_peak = maxi(w.threat_peak, threat(w))
	w.ev.curse_tick = w.tick
	w.ev.curse_last = c
	return true


## Lifts a held curse: `c`, or the latest taken when c < 0. False when there is none to lift. The hook a shop
## calls (PLAN R1); the Cleansing Font uses it. T falls; its peak stays (M-THREAT counts what was chosen).
static func cleanse(w: World, c: int = -1) -> bool:
	if w.curses_owned.is_empty():
		return false
	var at := w.curses_owned.size() - 1 if c < 0 else w.curses_owned.find(c)
	if at < 0:
		return false
	w.ev.cleanse_last = w.curses_owned[at]
	w.ev.cleanse_tick = w.tick
	w.curses_owned.remove_at(at)
	return true


## A curse you don't hold and that isn't in `skip`, weighted (loot:event), or -1 when none is left.
static func roll(w: World, skip: PackedInt32Array = PackedInt32Array()) -> int:
	var weights := PackedInt32Array()
	for c in w.ev.curses.size():
		var ok := not owned(w, c) and not skip.has(c)
		weights.append(w.ev.curses[c].weight if ok else 0)
	return Offers.pick(w.ev.rng, weights)


# --- Hooks ------------------------------------------------------------------------------------------------------
static func enemy_speed_factor(w: World) -> float:
	var a := total(w, Effect.ENEMY_SPEED)
	return 1.0 if a == 0 else (1000 + a) / 1000.0


static func regen(w: World, rate_permille: int) -> int:
	var a := total(w, Effect.REGEN)
	return rate_permille if a == 0 else maxi(0, rate_permille * (1000 - a) / 1000)


static func heat_decay(w: World, per_tick: int) -> int:
	var a := total(w, Effect.HEAT_DECAY)
	return per_tick if a == 0 else per_tick * (1000 + a) / 1000


static func extra_enemies(w: World) -> int:
	return total(w, Effect.EXTRA_ENEMY)


## A shard price under the prices curse (shops call this too).
static func price(w: World, base: int) -> int:
	var a := total(w, Effect.PRICES)
	return base if a == 0 else (base * (1000 + a) + 500) / 1000


## Raises actor i to an elite: + rules.elite_hp_bonus_permille HP (and max HP), listed in World.ev.elite_ids.
static func make_elite(w: World, i: int) -> void:
	var a := w.actors
	var hp := maxi(1, a.max_hp[i] * (1000 + w.ev.rules.elite_hp_bonus_permille) / 1000)
	a.max_hp[i] = hp
	a.hp[i] = hp
	w.ev.elite_ids.append(a.ids[i])


## SpawnDirector, after a spawn of actor i: under an elite curse it rolls `ai:elite` and may become an elite.
static func maybe_elite(w: World, i: int) -> void:
	var chance := total(w, Effect.ELITE_CHANCE)
	if chance > 0 and w.ev.rng_elite != null and w.ev.rng_elite.chance_permille(chance):
		make_elite(w, i)


static func is_elite(w: World, id: int) -> bool:
	return w.ev.elite_ids.has(id)


# --- Cursed chest offers ----------------------------------------------------------------------------------------
## Rewards.interact, right after reward i's offer was rolled: a chest may turn cursed (see the class comment).
static func on_offer_rolled(w: World, i: int) -> void:
	var s := w.ev
	if s.rng == null or s.curses.is_empty() or not Stats.enabled(w):
		return
	if w.rewards.kind[i] != RewardStore.Kind.CHEST:
		return
	var forced := s.force_curse
	if not forced and not s.rng.chance_permille(s.rules.cursed_chest_permille):
		return
	var offer := w.rewards.offer_of(i)
	var stats := PackedInt32Array()
	var weights := PackedInt32Array()
	for st in w.stat_tables.size():
		var t := w.stat_tables[st]
		if t == null or t.weight <= 0 or Stats.at_cap(w, st):
			continue
		var taken := false
		for k in range(1, offer.size()):
			taken = (
				taken
				or (Offers.type_of(offer[k]) == Offers.STAT and Offers.stat_of(offer[k]) == st)
			)
		if not taken:
			stats.append(st)
			weights.append(t.weight)
	var pick := Offers.pick(s.rng, weights)
	var curse := roll(w) if pick >= 0 else -1
	if curse < 0:
		return
	s.force_curse = false
	var card := Offers.stat_code(stats[pick], Stats.Rarity.EPIC)
	if offer.is_empty():
		offer.append(card)
	else:
		offer[CURSED_SLOT] = card
	w.rewards.set_offer(i, offer)
	s.cursed_ids.append(w.rewards.ids[i])
	s.cursed_slot.append(CURSED_SLOT)
	s.cursed_curse.append(curse)


## The curse on card k of reward `reward_id`'s offer, or -1.
static func offer_curse(w: World, reward_id: int, k: int) -> int:
	var at := w.ev.cursed_ids.find(reward_id)
	if at < 0 or w.ev.cursed_slot[at] != k:
		return -1
	return w.ev.cursed_curse[at]


## Rewards.choose, as card k of reward `reward_id` is taken: the cursed card brings its curse; the reward is gone
## either way, so its entry goes too.
static func on_pick(w: World, reward_id: int, k: int) -> void:
	var at := w.ev.cursed_ids.find(reward_id)
	if at < 0:
		return
	if w.ev.cursed_slot[at] == k:
		add(w, w.ev.cursed_curse[at])
	w.ev.cursed_ids.remove_at(at)
	w.ev.cursed_slot.remove_at(at)
	w.ev.cursed_curse.remove_at(at)
