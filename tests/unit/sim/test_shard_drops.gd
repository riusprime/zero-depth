extends GutTest
## v0.10.5 O7b (owner P6, 2026-11-01: "can we also make the shards stay on the floor instead of flying around"): a
## normal kill's shards lie at the body (ShardDrops) until the hero comes within pickup range; merged within 0.5 m,
## at most 24 on a floor (the oldest merged into its nearest), taken with you at the portal, saved with the world.

const KIND := ActorStore.Kind


func _world() -> World:
	var w := CombatLab.world()
	w.reward_table = ContentCompiler.compile_rewards(
		ContentRepository.load_all().get_def(&"rewards", &"floor")
	)
	return w


func _kill(w: World, at: Vector2, kind: int = KIND.CHARGER) -> void:
	var id := w.add_enemy(kind, at)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 999999, 0, 0, w.take_root(), 0, at, at)
	w.step(InputFrame.new())


func _shard_events(w: World) -> Array:
	return w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.SHARDS
	)


func test_a_kill_out_of_reach_lies_on_the_floor_unpaid() -> void:
	var w := _world()
	var pays := Rewards.shards_for_kill(w, KIND.CHARGER)
	assert_gt(pays, 0)
	_kill(w, w.player_pos() + Vector2(6, 0))
	assert_eq(w.shards, 0, "not paid yet")
	assert_eq(w.shard_drops.size(), 1, "one drop")
	assert_eq(w.shard_drops.amounts[0], pays, "holding the kill's shards")
	assert_eq(w.shard_drops.pos(0), w.player_pos() + Vector2(6, 0), "at the body")
	assert_eq(_shard_events(w).size(), 0, "no SHARDS event yet")
	assert_eq(w.kills, 1, "the kill counts at once")


func test_walking_into_pickup_range_takes_it() -> void:
	var w := _world()
	var at := w.player_pos() + Vector2(6, 0)
	_kill(w, at)
	var held := w.shard_drops.amounts[0]
	w.actors.set_pos(0, at + Vector2(ShardDrops.REACH_M + 0.1, 0))
	w.step(InputFrame.new())
	assert_eq(w.shards, 0, "just outside reach: still lying")
	w.actors.set_pos(0, at + Vector2(ShardDrops.REACH_M - 0.1, 0))
	w.step(InputFrame.new())
	assert_eq(w.shards, held, "inside reach: paid")
	assert_eq(w.shard_drops.size(), 0)
	var ev := _shard_events(w)
	assert_eq(ev.size(), 1, "one SHARDS event, at the pickup")
	assert_eq(ev[0].amount, held)
	assert_eq(ev[0].pos, at, "at the drop")
	assert_eq(ev[0].effect_id, ShardDrops.EFFECT)


func test_the_pickup_range_stat_widens_the_reach() -> void:
	var w := _world()
	w.stat_tables = ContentCompiler.compile_stat_cards(ContentRepository.load_all())
	var at := w.player_pos() + Vector2(6, 0)
	_kill(w, at)
	w.actors.set_pos(0, at + Vector2(ShardDrops.REACH_M + 0.05, 0))
	Stats.add_card(w, Stats.Stat.PICKUP, Stats.Rarity.EPIC)
	assert_gt(Stats.reach(w, ShardDrops.REACH_M), ShardDrops.REACH_M + 0.05)
	w.step(InputFrame.new())
	assert_gt(w.shards, 0, "the stat reaches it")


func test_a_kill_beside_the_hero_pays_the_same_tick() -> void:
	var w := _world()
	_kill(w, w.player_pos() + Vector2(0.5, 0))
	assert_eq(w.shards, Rewards.shards_for_kill(w, KIND.CHARGER))
	assert_eq(w.shard_drops.size(), 0)


func test_drops_within_half_a_metre_merge() -> void:
	var w := _world()
	var at := w.player_pos() + Vector2(6, 0)
	_kill(w, at)
	_kill(w, at + Vector2(0.4, 0))
	assert_eq(w.shard_drops.size(), 1, "merged")
	assert_eq(w.shard_drops.amounts[0], 2 * Rewards.shards_for_kill(w, KIND.CHARGER))
	assert_eq(w.shard_drops.pos(0), at, "the first keeps its spot")
	_kill(w, at + Vector2(0, 1.0))
	assert_eq(w.shard_drops.size(), 2, "a metre away: its own drop")


func test_the_floor_holds_at_most_the_cap_and_loses_nothing() -> void:
	var w := CombatLab.world()
	for k in ShardDrops.MAX_ON_FLOOR + 3:
		ShardDrops.drop(w, Vector2(10 + k, 0), 1 + k)
	var want := 0
	for k in ShardDrops.MAX_ON_FLOOR + 3:
		want += 1 + k
	assert_eq(w.shard_drops.size(), ShardDrops.MAX_ON_FLOOR, "capped")
	assert_eq(w.shard_drops.total(), want, "the oldest merged in, none lost")
	assert_eq(w.shard_drops.pos(0), Vector2(13, 0), "the three oldest went")
	assert_eq(w.shard_drops.amounts[0], 1 + 2 + 3 + 4, "into their nearest, in turn")


func test_a_boss_kill_still_pays_at_once() -> void:
	var w := _world()
	for kind in [KIND.CHARGER, KIND.NEEDLE, KIND.WARDEN]:
		assert_true(Rewards.lies_on_floor(w, kind), "a normal enemy's shards lie")
	assert_false(Rewards.lies_on_floor(w, KIND.GATEKEEPER), "a boss's are paid")


func test_the_portal_takes_what_lies_on_the_floor() -> void:
	var w := CombatLab.world()
	w.shards = 5
	ShardDrops.drop(w, Vector2(10, 0), 7)
	ShardDrops.drop(w, Vector2(20, 0), 3)
	ShardDrops.collect_all(w)
	assert_eq(w.shards, 15, "every drop credited")
	assert_eq(w.shard_drops.size(), 0)


func test_finish_floor_carries_the_shards_left_lying() -> void:
	var run := SaveLab.run_state(5, 1)
	var w := SaveLab.build_floor(run)
	w.shards = 10
	ShardDrops.drop(w, w.player_pos() + Vector2(30, 0), 8)
	run.finish_floor(w)
	var kept: int = run.carry[&"shards"] + run.carry[RunCarry.LEFT]
	assert_eq(kept, 18, "the carry holds the 8 lying too (before the run's carry share)")


func test_no_drop_no_hash_change() -> void:
	var a := CombatLab.world()
	var b := CombatLab.world()
	b.shard_drops = ShardDropStore.new()
	assert_eq(a.state_hash(), b.state_hash())
	ShardDrops.drop(b, Vector2(9, 0), 2)
	assert_ne(a.state_hash(), b.state_hash(), "a drop is state")


func test_a_save_keeps_the_drops() -> void:
	var w := SaveLab.floor_world(77, 1)
	ShardDrops.drop(w, w.player_pos() + Vector2(20, 0), 6)
	ShardDrops.drop(w, w.player_pos() + Vector2(-20, 0), 4)
	var base := SaveLab.floor_world(77, 1)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(WorldSnapshot.take(w))), base)
	assert_not_null(restored, "the snapshot fits its base")
	if restored == null:
		return
	assert_eq(restored.shard_drops.amounts, PackedInt32Array([6, 4]), "the drops round-trip")
	assert_eq(restored.shard_drops.seqs, w.shard_drops.seqs)
	assert_eq(restored.shard_drops.next_seq, w.shard_drops.next_seq)
	assert_eq(restored.state_hash(), w.state_hash(), "hash equal")


func test_an_older_save_starts_with_none_lying() -> void:
	var w := SaveLab.floor_world(77, 1)
	var snap := WorldSnapshot.take(w)
	(snap["world"] as Dictionary).erase(&"shard_drops")
	var base := SaveLab.floor_world(77, 1)
	assert_eq(WorldSnapshot.apply(base, snap), "", "an old snapshot fits")
	assert_eq(base.shard_drops.size(), 0, "none lying")
	assert_eq(base.state_hash(), w.state_hash(), "same state")
