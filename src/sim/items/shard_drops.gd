class_name ShardDrops
extends RefCounted
## Kill shards on the floor (v0.10.5 O7b, owner P6, 2026-11-01: "can we also make the shards stay on the floor instead
## of flying around"; "Pick and build"). Starting values, the lead's picks (OWNER_QUESTIONS):
## - Drop: a normal enemy's kill (not a boss, not a shards_by_floor kind) lays its shards at the body as one drop
##   (Rewards.on_kill, tick phase 9), the amount fixed then: the shrine, the shard-gain stat, the curse and the rune
##   affinity all apply at the kill, and Scavenger's crit bonus joins the same drop (RuleCards.on_kill). A drop
##   within MERGE_M of another adds to the nearest one instead (it keeps its spot). At most MAX_ON_FLOOR lie on a
##   floor: past it, the oldest drop merges into its nearest neighbour.
## - Pick-up: at tick phase 9 (after the item pickups) every drop within REACH_M × the pickup-range stat (Stats.reach)
##   of the live hero is taken: World.shards += its amount, with a SHARDS event at the drop (effect EFFECT). Hoarder
##   and the shop read World.shards, so they count only the shards taken.
## - The portal: RunState.finish_floor credits every drop left (collect_all) before the carry, so none are lost.
## - Instant as before: boss shards, chests, events, containers and the Overrun's bonus; the Overrun counts a kill's
##   shards at the kill.
## Drops never expire on their own. Integer amounts; no RNG.

const MERGE_M := 0.5
const MAX_ON_FLOOR := 24
const REACH_M := 1.2
const EFFECT := &"shard_pickup"


## Lays `amount` shards at `at` (merging into a drop within MERGE_M, then holding the cap).
static func drop(w: World, at: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var s := w.shard_drops
	var near := _nearest(s, at, -1)
	if near >= 0 and (s.pos(near) - at).length_squared() <= MERGE_M * MERGE_M:
		s.amounts[near] += amount
		return
	s.add(at, amount)
	while s.size() > MAX_ON_FLOOR:
		var into := _nearest(s, s.pos(0), 0)
		s.amounts[into] += s.amounts[0]
		s.remove_at(0)


## Tick phase 9 (after the item pickups): the live hero takes every drop in reach.
static func advance(w: World) -> void:
	var s := w.shard_drops
	if s.size() == 0 or w.player_dead():
		return
	var reach := Stats.reach(w, REACH_M)
	var p := w.player_pos()
	var me := w.actors.ids[0]
	var k := 0
	while k < s.size():
		if Kin.length(s.pos(k) - p) > reach:
			k += 1
			continue
		w.shards += s.amounts[k]
		var e := w.emit_event(SimEvent.Kind.SHARDS, me, me, me, s.pos(k))
		e.amount = s.amounts[k]
		e.effect_id = EFFECT
		s.remove_at(k)


## The portal (RunState.finish_floor): every drop left on the floor is credited, without events.
static func collect_all(w: World) -> void:
	var s := w.shard_drops
	w.shards += s.total()
	while s.size() > 0:
		s.remove_at(0)


## The drop nearest `at`, skipping index `skip` (-1 when none lies on the floor).
static func _nearest(s: ShardDropStore, at: Vector2, skip: int) -> int:
	var best := -1
	var best_d := INF
	for k in s.size():
		if k == skip:
			continue
		var d := (s.pos(k) - at).length_squared()
		if d < best_d:
			best = k
			best_d = d
	return best
