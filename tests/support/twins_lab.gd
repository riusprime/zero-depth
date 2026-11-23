class_name TwinsLab
extends RefCounted
## Test helpers for the Twin Wardens' own mechanics: the pair in JudgeLab's walled boss room (24 m a side round the
## origin, BossStore.arena set), and the reads the tests share.

const S := EnemyAi.State
const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG


## The Wardens risen with the amber one at `boss_at`, acting, the hero at `hero_at` and too tough to die. Returns
## [world, the amber Warden's id, the violet Warden's id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	w.actors.set_pos(0, hero_at)
	var i := BossLab.ready_boss(w, &"twin_wardens", boss_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i], w.actors.ids[BossTwin.partner_of(w, i)]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func wardens(w: World, aid: int) -> BossWardensTable:
	return table(w, aid).wardens


## The Wardens start nothing on their own: no pick, no punish, no gap-closer, no standing-back bolt, no side dash,
## no set piece; with `still` they also stand where they are.
static func hush(w: World, aid: int, still := true) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
		t.phase_entry[k] = -1
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.twin_bolt = -1
	t.wardens.dash_every_ticks = LONG
	t.wardens.rift_hp_permille = 0
	w.boss_fight.wd_dash_cd = LONG
	if still:
		t.speed = 0.0


## Puts the pair in phase `phase` (an index) without its gate, with one HP less than the phase's full bar.
static func set_phase(w: World, aid: int, phase: int) -> void:
	var i := w.actors.index_of(aid)
	var j := BossTwin.partner_of(w, i)
	var t := BossAi.table_of(w, i)
	var hp := maxi(1, t.phase_threshold[phase] * w.actors.max_hp[i] / 1000 - 1)
	for body: int in [i, j]:
		w.bosses.phase[BossAi.entry_of(w, body)] = phase
		w.bosses.entry[BossAi.entry_of(w, body)] = -1
		w.actors.hp[body] = hp
	w.bosses.twin_phase[0] = phase
	w.bosses.twin_clock[0] = 0
	w.bosses.twin_turn[0] = 0


## The pair's shared HP set to `permille` of its max.
static func set_hp(w: World, aid: int, permille: int) -> void:
	var i := w.actors.index_of(aid)
	var hp := maxi(1, w.actors.max_hp[i] * permille / 1000)
	w.actors.hp[i] = hp
	w.actors.hp[BossTwin.partner_of(w, i)] = hp


## The HP the hero has lost since it was last refilled; refills it.
static func take_lost(w: World) -> int:
	var lost := w.actors.max_hp[0] - w.actors.hp[0]
	w.actors.hp[0] = w.actors.max_hp[0]
	return lost


## A hit of `amount` from the hero on body `target_id`, coming from `from`, with `tags`. Returns the HP removed.
static func hit(w: World, target_id: int, amount: int, from: Vector2, tags: int = 0) -> int:
	var me := w.actors.ids[0]
	var i := w.actors.index_of(target_id)
	return Damage.hit(w, i, amount, me, me, w.take_root(), tags, from, w.actors.pos(i))


## Steps `ticks` ticks with the hero idle.
static func idle(w: World, ticks: int) -> void:
	for k in ticks:
		w.step(InputFrame.new())


## The STATUS_APPLY events with `effect` after event `seq`.
static func effects(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return JudgeLab.effects(w, effect, seq)


## Steps (the hero idle) until an event with `effect` exists, at most `limit` ticks. Returns it, or null.
static func until_effect(w: World, effect: StringName, limit: int, seq: int = 0) -> SimEvent:
	return JudgeLab.until_effect(w, effect, limit, seq)


## The newest event's seq (events after it are new).
static func mark(w: World) -> int:
	return w.last_event_seq()


## The violet Warden's whole ward stands now, as the end of her cast raises it (phase 3).
static func raise_ward(w: World, aid: int) -> void:
	BossWard.raise(w, BossTwin.partner_of(w, w.actors.index_of(aid)))
