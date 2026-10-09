# gdlint: disable=max-public-methods
class_name Curses
extends RefCounted
## Curses and threat T (v0.5.0 EV, PLAN R4; BLUEPRINT §H; PD-05). A curse is a lasting drawback the player chose:
## an event choice's price, or (v0.6.0 CU, PLAN v0.5.5 S6, S7) a trade-off curse taken as a cursed chest's card,
## which brings its own upside. World.curses_owned lists the curses held (indices into World.ev.curses, in the order
## taken; no curse twice) and lasts the run (RunCarry). T is the sum of the held curses' threat; World.threat_peak is
## the highest T the run reached (M-THREAT). cleanse() lifts one, drawback and upside together: the Cleansing Font
## calls it, and the shop's cleanse.
## Each effect is read where the sim computes it, through one hook here (a no-op without curses); a curse may carry
## a second drawback (effect_2) and an upside (up_effect), all summed by total():
## - ENEMY_SPEED: normal enemies' movement (EnemyAi.move) x (1 + amount);
## - REGEN: both regen sources (PlayerRegen, Stats regen) x (1 - amount);
## - HEAT_DECAY: Overclock heat's decay per tick x (1 + amount);
## - EXTRA_ENEMY: every spawn arrival brings `amount` more, under the alive cap (SpawnDirector);
## - PRICES: chest, gamble shrine and event shard prices (and shops') x (1 + amount), rounded half up;
## - ELITE_CHANCE: each spawned enemy rolls `amount` per mille on `ai:elite` to be an elite (+ elite HP).
## v0.6.0 CU, the trade-off curses' effects (C1-C8):
## - NO_DASH: a dash press does nothing (World._advance_actions); DODGE: an enemy hit on the player is dodged with
##   `amount` per mille on the `combat` stream: no damage, the hurt i-frames, a STATUS_APPLY &"dodge" cue (Damage.hit);
## - ATTACK_SLOW: the attack speed stat x (1 - amount) (Stats.period, Stats.swing_end); FOURTH_HIT: the Blade combo's
##   4th step, and every 4th Gun shot (CurseState.shots), x (1 + amount) damage (PlayerKit);
## - MAX_HP_CUT: max HP x (1 - amount) (Stats.max_hp; taking or lifting it moves World.actors.max_hp[0] by the
##   difference); CRIT_CHANCE: + amount crit chance (Stats.crit_chance, under the card cap);
## - ABILITY_HP_COST: each Skill or Blink use costs `amount` per mille of max HP, never below 1 HP (on_ability_use);
##   ABILITY_DAMAGE: hits tagged TAG_SKILL or TAG_ABILITY x (1 + amount) (Stats.outgoing);
## - HEAT_LINGER: heat's decay x (1 - amount); OVERCLOCK_DAMAGE: + amount on Overclock's bonus (Heat.attacker_mult);
## - NO_MINIMAP: the minimap is off (WorldReader.minimap_blind); SHARD_GAIN: shards x (1 + amount) (Stats.shards);
## - HIT_STUN: an enemy hit that hurts stuns the player for `amount` ticks: no move, swing, shot, dash, skill or
##   blink (stunned); MOVE_SPEED: move speed x (1 + amount) (move_factor);
## - ELITE_HUNT: elites within the rules' hunt range move x (1 + amount) (EnemyAi.move); ELITE_RARE_DROP: a killed
##   elite drops a free rare card (CoreTheft.on_death).
## Cursed chests (v0.6.0 CU, owner S6: "curse was fun, but also gave me the god feeling too fast"): when a chest's
## offer is first rolled, `loot:event` rolls rules.cursed_chest_permille; a cursed offer's first card becomes a
## trade-off curse card (Offers.curse_code) for a trade-off curse you don't hold. Taking it takes the curse, upside
## and drawback; the other cards are clean. The epic stat card it used to carry is gone. Event choices' random curses
## draw plain curses only (Pool.PLAIN).

enum Effect {
	ENEMY_SPEED,
	REGEN,
	HEAT_DECAY,
	EXTRA_ENEMY,
	PRICES,
	ELITE_CHANCE,
	NO_DASH,
	DODGE,
	ATTACK_SLOW,
	FOURTH_HIT,
	MAX_HP_CUT,
	CRIT_CHANCE,
	ABILITY_HP_COST,
	ABILITY_DAMAGE,
	HEAT_LINGER,
	OVERCLOCK_DAMAGE,
	NO_MINIMAP,
	SHARD_GAIN,
	HIT_STUN,
	MOVE_SPEED,
	ELITE_HUNT,
	ELITE_RARE_DROP,
}
## Which curses roll() may draw: any, plain ones (no upside; event choices), trade-offs (cursed chests).
enum Pool { ANY, PLAIN, TRADE_OFF }

const CURSED_SLOT := 0
## Heavy Hands: the Blade combo step it boosts (the 4th), and every this-many Gun shots.
const FOURTH_STEP := 3
const FOURTH_SHOT := 4
## The dodge cue (STATUS_APPLY effect_id on the player).
const EFFECT_DODGE := &"dodge"


static func owned(w: World, c: int) -> bool:
	return w.curses_owned.has(c)


## Threat T now: the held curses' threat.
static func threat(w: World) -> int:
	var t := w.deep_threat  # v0.5.0 RT: each Deep floor taken adds 1
	for c in w.curses_owned:
		t += w.ev.curses[c].threat if c < w.ev.curses.size() else 1
	return t


## The summed amount of every held curse's drawbacks and upsides with `effect` (per mille; a count for the count
## effects, ticks for HIT_STUN).
static func total(w: World, effect: int) -> int:
	var n := 0
	for c in w.curses_owned:
		if c >= w.ev.curses.size():
			continue
		var t := w.ev.curses[c]
		if t.effect == effect:
			n += t.amount
		if t.effect_2 == effect:
			n += t.amount_2
		if t.up_effect == effect:
			n += t.up_amount
	return n


static func has(w: World, effect: int) -> bool:
	return not w.curses_owned.is_empty() and total(w, effect) > 0


## Takes curse c (no-op when already held). T and its peak follow; a max HP cut moves max HP (v0.6.0 CU).
static func add(w: World, c: int) -> bool:
	if c < 0 or c >= w.ev.curses.size() or owned(w, c):
		return false
	var hp_before := Stats.max_hp(w)
	w.curses_owned.append(c)
	_follow_max_hp(w, hp_before)
	w.threat_peak = maxi(w.threat_peak, threat(w))
	w.ev.curse_tick = w.tick
	w.ev.curse_last = c
	return true


## Lifts a held curse: `c`, or the latest taken when c < 0. False when there is none to lift. The hook a shop
## calls (PLAN R1); the Cleansing Font uses it. T falls; its peak stays (M-THREAT counts what was chosen). v0.6.0 CU:
## a trade-off curse goes whole (its upside too); lifting Glass Heart gives the max HP back, not the HP.
static func cleanse(w: World, c: int = -1) -> bool:
	if w.curses_owned.is_empty():
		return false
	var at := w.curses_owned.size() - 1 if c < 0 else w.curses_owned.find(c)
	if at < 0:
		return false
	w.ev.cleanse_last = w.curses_owned[at]
	w.ev.cleanse_tick = w.tick
	var hp_before := Stats.max_hp(w)
	w.curses_owned.remove_at(at)
	_follow_max_hp(w, hp_before)
	return true


## v0.6.0 CU: the player's max HP moves by what Stats.max_hp moved (Glass Heart taken or lifted); HP stays within.
static func _follow_max_hp(w: World, before: int) -> void:
	var gain := Stats.max_hp(w) - before
	if gain == 0:
		return
	var a := w.actors
	a.max_hp[0] = maxi(1, a.max_hp[0] + gain)
	a.hp[0] = clampi(a.hp[0], 1, a.max_hp[0])


## v0.6.0 CU, Events.setup: a floor's curse tables arrive after the carry restored max HP, so a held max HP cut is
## applied to the fresh floor's max HP here (no-op without one).
static func after_setup(w: World) -> void:
	if total(w, Effect.MAX_HP_CUT) == 0:
		return
	var a := w.actors
	a.max_hp[0] = maxi(1, Stats.max_hp(w))
	a.hp[0] = clampi(a.hp[0], 1, a.max_hp[0])


## A curse you don't hold, not in `skip` and in `pool` (Pool), weighted (loot:event), or -1 when none is left.
static func roll(
	w: World, skip: PackedInt32Array = PackedInt32Array(), pool: int = Pool.ANY
) -> int:
	var weights := PackedInt32Array()
	for c in w.ev.curses.size():
		var t := w.ev.curses[c]
		var ok := not owned(w, c) and not skip.has(c)
		ok = ok and (pool == Pool.ANY or t.is_trade_off() == (pool == Pool.TRADE_OFF))
		weights.append(t.weight if ok else 0)
	return Offers.pick(w.ev.rng, weights)


# --- Hooks ------------------------------------------------------------------------------------------------------
static func enemy_speed_factor(w: World) -> float:
	var a := total(w, Effect.ENEMY_SPEED)
	return 1.0 if a == 0 else (1000 + a) / 1000.0


static func regen(w: World, rate_permille: int) -> int:
	var a := total(w, Effect.REGEN)
	return rate_permille if a == 0 else maxi(0, rate_permille * (1000 - a) / 1000)


## Overclock heat's decay per tick: Leaky Core speeds it up, Fevered (v0.6.0 CU) slows it down.
static func heat_decay(w: World, per_tick: int) -> int:
	if w.curses_owned.is_empty():
		return per_tick
	var a := total(w, Effect.HEAT_DECAY)
	var d := per_tick if a == 0 else per_tick * (1000 + a) / 1000
	var linger := mini(total(w, Effect.HEAT_LINGER), 1000)
	return d if linger == 0 else d * (1000 - linger) / 1000


static func extra_enemies(w: World) -> int:
	return total(w, Effect.EXTRA_ENEMY)


## A shard price under the prices curse (shops call this too).
static func price(w: World, base: int) -> int:
	var a := total(w, Effect.PRICES)
	return base if a == 0 else (base * (1000 + a) + 500) / 1000


## Raises actor i to an elite: + rules.elite_hp_bonus_permille HP (and max HP), listed in World.ev.elite_ids. v0.6.0
## CU: it carries a core (CoreTheft.on_elite).
static func make_elite(w: World, i: int) -> void:
	var a := w.actors
	var hp := maxi(1, a.max_hp[i] * (1000 + w.ev.rules.elite_hp_bonus_permille) / 1000)
	a.max_hp[i] = hp
	a.hp[i] = hp
	w.ev.elite_ids.append(a.ids[i])
	CoreTheft.on_elite(w, i)


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
	var curse := roll(w, PackedInt32Array(), Pool.TRADE_OFF)
	if curse < 0:
		return
	s.force_curse = false
	var offer := w.rewards.offer_of(i)
	var card := Offers.curse_code(curse)
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


## Rewards.choose, as card k of reward `reward_id` is taken: the cursed card brings its curse (Offers.apply already
## took it: add is a no-op then); the reward is gone either way, so its entry goes too.
static func on_pick(w: World, reward_id: int, k: int) -> void:
	var at := w.ev.cursed_ids.find(reward_id)
	if at < 0:
		return
	if w.ev.cursed_slot[at] == k:
		add(w, w.ev.cursed_curse[at])
	w.ev.cursed_ids.remove_at(at)
	w.ev.cursed_slot.remove_at(at)
	w.ev.cursed_curse.remove_at(at)


# --- v0.6.0 CU: the trade-off curses' hooks ---------------------------------------------------------------------
## Rooted: the dash button does nothing.
static func no_dash(w: World) -> bool:
	return has(w, Effect.NO_DASH)


## Rooted (Damage.hit, before any damage): an enemy hit on the player is dodged. One draw on `combat` per hit that
## would land, only while a dodge chance is held. A dodge gives the hurt i-frames (one dodge negates one hit) and the
## cue (STATUS_APPLY effect &"dodge" on the player; CurseState.dodge_tick).
static func dodges(w: World, owner_id: int, at: Vector2) -> bool:
	var chance := total(w, Effect.DODGE) if not w.curses_owned.is_empty() else 0
	if chance <= 0 or not w.rng_combat.chance_permille(chance):
		return false
	var pid := w.actors.ids[0]
	w.actors.invuln[0] = w.player.hurt_iframe_ticks
	w.cs.dodge_tick = w.tick
	w.cs.dodges += 1
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, owner_id, owner_id, pid, at)
	e.effect_id = EFFECT_DODGE
	return true


## Heavy Hands: the attack speed stat's value (per mille) under its cut.
static func attack_speed(w: World, m: int) -> int:
	if w.curses_owned.is_empty():
		return m
	var cut := mini(total(w, Effect.ATTACK_SLOW), 900)
	return m if cut == 0 else maxi(1, (m * (1000 - cut) + 500) / 1000)


## Heavy Hands: a Blade swing's damage (PlayerKit._resolve_swing): the combo's 4th step deals + amount.
static func swing_damage(w: World, dmg: int) -> int:
	if w.curses_owned.is_empty() or w.combo_step != FOURTH_STEP:
		return dmg
	var a := total(w, Effect.FOURTH_HIT)
	if a == 0:
		return dmg
	w.cs.heavy_tick = w.tick
	return (dmg * (1000 + a) + 500) / 1000


## Heavy Hands: a Gun shot's damage per bolt (PlayerKit._fire_bolt): every 4th shot deals + amount.
static func shot_damage(w: World, dmg: int) -> int:
	if w.curses_owned.is_empty():
		return dmg
	var a := total(w, Effect.FOURTH_HIT)
	if a == 0:
		return dmg
	w.cs.shots += 1
	if w.cs.shots % FOURTH_SHOT != 0:
		return dmg
	w.cs.heavy_tick = w.tick
	return (dmg * (1000 + a) + 500) / 1000


## Glass Heart: the max HP multiplier, per mille.
static func max_hp_permille(w: World) -> int:
	if w.curses_owned.is_empty():
		return 1000
	return 1000 - mini(total(w, Effect.MAX_HP_CUT), 900)


## Glass Heart: + crit chance, per mille.
static func crit_chance(w: World) -> int:
	return 0 if w.curses_owned.is_empty() else total(w, Effect.CRIT_CHANCE)


## Blood Price: a hit's damage multiplier for its tags, per mille (skill and ability hits).
static func ability_damage_permille(w: World, tags: int) -> int:
	if w.curses_owned.is_empty() or not (tags & (SimEvent.TAG_SKILL | SimEvent.TAG_ABILITY)):
		return 1000
	return 1000 + total(w, Effect.ABILITY_DAMAGE)


## Blood Price: a Skill or Blink was used (PlayerSkill._start, PlayerKit.advance_utility): it costs `amount` per
## mille of max HP (at least 1), never below 1 HP. No DAMAGE event: it isn't a hit (CurseState.blood_tick).
static func on_ability_use(w: World) -> void:
	if w.curses_owned.is_empty():
		return
	var cost := total(w, Effect.ABILITY_HP_COST)
	if cost <= 0:
		return
	var a := w.actors
	var loss := maxi(1, a.max_hp[0] * cost / 1000)
	a.hp[0] = maxi(1, a.hp[0] - loss)
	w.cs.blood_tick = w.tick


## Fevered: + Overclock damage, per mille.
static func overclock_bonus(w: World) -> int:
	return 0 if w.curses_owned.is_empty() else total(w, Effect.OVERCLOCK_DAMAGE)


## Tunnel Vision: the minimap is off.
static func no_minimap(w: World) -> bool:
	return has(w, Effect.NO_MINIMAP)


## Tunnel Vision: the shard gain multiplier, per mille.
static func shard_permille(w: World) -> int:
	return 1000 if w.curses_owned.is_empty() else 1000 + total(w, Effect.SHARD_GAIN)


## Brittle (Damage._apply): an enemy's hit hurt the player (not a DoT tick): the stun starts (or restarts).
static func on_player_hit(w: World) -> void:
	if w.curses_owned.is_empty():
		return
	var t := total(w, Effect.HIT_STUN)
	if t <= 0:
		return
	w.cs.stun_t = t
	w.cs.stun_tick = w.tick


## Brittle: the stun holds the player.
static func stunned(w: World) -> bool:
	return w.cs.stun_t > 0


## Tick phase 4 (World._advance_actions): the stun runs down.
static func advance(w: World) -> void:
	if w.cs.stun_t > 0:
		w.cs.stun_t -= 1


## Brittle: the player's move speed factor: 0 while stunned, else x (1 + the move speed upside).
static func move_factor(w: World) -> float:
	if w.cs.stun_t > 0:
		return 0.0
	if w.curses_owned.is_empty():
		return 1.0
	var a := total(w, Effect.MOVE_SPEED)
	return 1.0 if a == 0 else (1000 + a) / 1000.0


## Marked: elite actor i's move factor: x (1 + amount) while within the hunt range of the player.
static func hunt_factor(w: World, i: int) -> float:
	if w.curses_owned.is_empty() or w.ev.elite_ids.is_empty():
		return 1.0
	var a := total(w, Effect.ELITE_HUNT)
	if a == 0 or not is_elite(w, w.actors.ids[i]):
		return 1.0
	if Kin.length(w.actors.pos(i) - w.player_pos()) > w.ev.rules.hunt_range_m:
		return 1.0
	return (1000 + a) / 1000.0


## Marked: a killed elite drops a free rare card.
static func elite_drops(w: World) -> bool:
	return has(w, Effect.ELITE_RARE_DROP)
