class_name HealOrbs
extends RefCounted
## Heal orbs (v0.4.0 TU, owner D8: "healing orb heals more, but is more rare maybe 10% rate appearence but heals 25%
## … I know this healing orb is coming sooner or later"). Starting values in RewardTable (data/rewards/floor.tres):
## - Drop: a normal enemy's kill (not a boss) drops an orb where it fell with heal_orb_chance_permille, one roll on
##   the loot stream per kill (tick phase 9, Rewards.on_kill). At most MAX_ON_FLOOR lie on the floor: a new one
##   pushes out the oldest.
## - Pick-up: walking within heal_orb_reach_m (× the pickup-range stat, Stats.reach) of an orb takes it, nearest
##   first, one a tick, and heals heal_orb_heal_permille of max HP (never past it), with a HEAL event (effect
##   heal_orb; amount the heal asked for, amount_applied what it gave). An orb at full HP stays on the floor.
## Orbs never expire on their own: the floor ends with them.
## v0.5.5 EC (owner D9, "Too common, we should add them as a card"): the drop chance is the reward table's base
## (0 in the shipped data) plus the Lifesprout stat card's (Stats.heal_orb_chance): no card, no orbs. The loot
## stream is drawn only when the chance is above 0.

const MAX_ON_FLOOR := 16
const EFFECT := &"heal_orb"


## Tick phase 9: actor i (an enemy) died. Maybe drops an orb.
static func on_kill(w: World, i: int) -> void:
	var t := w.reward_table
	var kind := w.actors.kinds[i]
	if t == null or BossAi.is_boss_kind(kind) or not EnemyAi.is_enemy_kind(kind):
		return
	var chance := mini(1000, t.heal_orb_chance_permille + Stats.heal_orb_chance(w))
	if chance <= 0:
		return
	if not w.rng_loot.chance_permille(chance):
		return
	if w.orbs.size() >= MAX_ON_FLOOR:
		w.orbs.remove_at(0)
	var id := w.take_id()
	w.orbs.add(id, w.actors.pos(i))
	w.emit_event(SimEvent.Kind.SPAWN, id, id, id, w.actors.pos(i))


## Tick phase 9 (after the pickups): the player takes the nearest orb in reach, if hurt.
static func advance(w: World) -> void:
	if w.orbs.size() == 0 or w.player_dead():
		return
	var a := w.actors
	if a.hp[0] >= a.max_hp[0]:
		return
	var t := w.reward_table
	var reach := Stats.reach(w, t.heal_orb_reach_m)
	var p := w.player_pos()
	var best := -1
	var best_d := reach
	for k in w.orbs.size():
		var d := Kin.length(w.orbs.pos(k) - p)
		if d <= best_d:
			best = k
			best_d = d
	if best < 0:
		return
	var want := a.max_hp[0] * t.heal_orb_heal_permille / 1000
	var applied := maxi(0, mini(want, a.max_hp[0] - a.hp[0]))
	a.hp[0] += applied
	var e := w.emit_event(
		SimEvent.Kind.HEAL, w.orbs.ids[best], a.ids[0], a.ids[0], w.orbs.pos(best)
	)
	e.amount = want
	e.amount_applied = applied
	e.effect_id = EFFECT
	w.orbs.remove_at(best)
