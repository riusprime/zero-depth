class_name HealOrbs
extends RefCounted
## Heal orbs (v0.4.0 TU, owner D8). v0.11.0 F3 (owner's playtest §6, "controlled, consistent healing"): every run earns
## them through kills, with no card (Lifesprout is disabled). Starting values in RewardTable (data/rewards/floor.tres):
## - At most heal_orbs_max (1) lie on the floor. A new orb never pushes out the old one: none appears while one lies.
## - A pickup starts heal_orb_cooldown_ticks (30 s, on World.tick). During it no orb may appear and kills earn nothing.
## - Earning: a normal enemy's kill (not a boss) adds points to the meter (tick phase 9, Rewards.on_kill): its kind's
##   base max HP (EnemyTable.base_hp, never scaled) × heal_orb_points_per_hp_permille / 1000, clamped to
##   heal_orb_points_min..max, so a horde of critters and a few big enemies earn about alike. When the meter reaches
##   heal_orb_meter, an orb drops where that kill fell and the meter resets. No points while an orb lies or during the
##   cooldown, so a hero at full HP keeps the one orb and nothing more. No loot draw: no randomness at all.
## - Pick-up: walking within heal_orb_reach_m (× the pickup-range stat, Stats.reach) of the orb takes it, only if hurt,
##   and heals heal_orb_heal_permille of max HP (never past it), with a HEAL event (effect heal_orb; amount the heal
##   asked for, amount_applied what it gave).
## So the fastest rate, by construction, is one pickup per cooldown: 2 a minute × 20 % = 40 % of max HP a minute.
## Orbs never expire on their own. The state is the floor's World's (HealOrbStore): the floor ends with it.

const MAX_ON_FLOOR := 1
const EFFECT := &"heal_orb"


## Whether an orb may appear now, from a kill or a broken prop: none lies at the limit and the cooldown is over.
static func may_appear(w: World) -> bool:
	return w.orbs.size() < w.tuning.heal_orbs_max and w.tick >= w.orbs.ready_tick


## An orb appears at `at` (callers ask may_appear first).
static func drop(w: World, at: Vector2) -> void:
	var id := w.take_id()
	w.orbs.add(id, at)
	w.emit_event(SimEvent.Kind.SPAWN, id, id, id, at)


## The points a kill of `kind` earns (class doc); 0 for a kind with no table.
static func points(w: World, kind: int) -> int:
	var e := w.enemy_table(kind)
	if e == null:
		return 0
	var t := w.reward_table
	return clampi(
		e.base_hp * t.heal_orb_points_per_hp_permille / 1000,
		t.heal_orb_points_min,
		t.heal_orb_points_max
	)


## Tick phase 9: actor i (an enemy) died. Earns points; a full meter drops an orb where it fell.
static func on_kill(w: World, i: int) -> void:
	var t := w.reward_table
	var kind := w.actors.kinds[i]
	if t == null or t.heal_orb_meter <= 0:
		return
	if BossAi.is_boss_kind(kind) or not EnemyAi.is_enemy_kind(kind) or not may_appear(w):
		return
	var s := w.orbs
	s.touched = true
	s.meter += points(w, kind)
	if s.meter >= t.heal_orb_meter:
		s.meter = 0
		drop(w, w.actors.pos(i))


## Tick phase 9 (after the pickups): the player takes the nearest orb in reach, if hurt, and the cooldown starts.
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
	w.orbs.ready_tick = w.tick + t.heal_orb_cooldown_ticks
