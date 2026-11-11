extends GutTest
## The views that wake only when something of their kind is on the floor, and read the sim in bulk: the bulk reads
## equal the per-actor reads they replace, a view does no work while nothing of its kind happens, and it wakes on
## the frame something does. The flying shard gems are instances, never nodes.

const MIX := [
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.CHARGER,
	ActorStore.Kind.WARDEN,
	ActorStore.Kind.ARC_CASTER,
	ActorStore.Kind.MINE_LAYER,
	ActorStore.Kind.SWARMER,
	ActorStore.Kind.SNIPER,
	ActorStore.Kind.SWARMER,
]


## A seeded fight: the hero who cannot die among a ring of mixed enemies.
func _fight() -> World:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 24
	w.actors.max_hp[0] = 1 << 24
	for k in 24:
		var a := TAU * k / 24.0
		w.add_enemy(MIX[k % MIX.size()], Vector2(cos(a), sin(a)) * (4.0 + (k % 5)))
	return w


static func _brute(r: WorldReader, keep: Callable) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in range(1, r.actor_count()):
		if keep.call(i):
			out.append(i)
	return out


func test_the_bulk_reads_equal_the_per_actor_reads_over_a_seeded_fight() -> void:
	var w := _fight()
	var r := WorldReader.new(w)
	var a := w.actors
	var windups := 0
	var statuses := 0
	for t in 600:
		if t % 37 == 0:  # Statuses come and go on some enemies (written straight into the columns)
			for i in range(1, a.size()):
				a.burn_stacks[i] = (i * 7 + t) % 5 if i % 3 == 0 else 0
				a.frozen_t[i] = 20 if (i + t) % 11 == 0 else 0
				a.bleed_stacks[i] = 2 if (i + t) % 7 == 0 else 0
		w.step(InputFrame.new())
		var before := w.state_hash()
		var tg := r.telegraph_indices()
		for i in r.actor_count():
			if not tg.has(i):
				assert_true(r.telegraph(i).is_empty(), "an actor left out has no telegraph")
		var want_tg := PackedInt32Array()
		for i in r.actor_count():
			var st := a.state[i]
			if (
				st == EnemyAi.State.WINDUP
				or st == EnemyAi.State.ACTIVE
				or a.kinds[i] == ActorStore.Kind.MINE_LAYER
			):
				want_tg.append(i)
		assert_eq(tg, want_tg, "the windups, the acting and the Mine Layers, ascending")
		windups += tg.size()
		var st_i := r.status_indices()
		assert_eq(st_i, _brute(r, r.any_status), "the status carriers")
		statuses += st_i.size()
		assert_eq(
			r.burn_or_frozen_indices(),
			_brute(r, func(i: int) -> bool: return r.burn_stacks(i) > 0 or r.actor_frozen(i))
		)
		var kinds := [ActorStore.Kind.SWARMER, ActorStore.Kind.SNIPER]
		assert_eq(
			r.indices_of_kinds(kinds),
			_brute(r, func(i: int) -> bool: return kinds.has(r.actor_kind(i)))
		)
		assert_eq(r.core_indices(), _brute(r, func(i: int) -> bool: return r.actor_core(i) >= 0))
		var active := PackedInt32Array()
		for i in r.actor_count():
			if r.actor_state(i) == WorldReader.STATE_ACTIVE:
				active.append(i)
		assert_eq(r.indices_in_state(WorldReader.STATE_ACTIVE), active)
		var ids := r.actor_ids()
		var xs := r.actor_xs()
		var ys := r.actor_ys()
		for i in r.actor_count():
			assert_eq(ids[i], r.actor_id(i))
			assert_eq(Vector2(xs[i], ys[i]), r.actor_pos(i))
		var pids := r.projectile_ids()
		var pxs := r.projectile_xs()
		var pys := r.projectile_ys()
		assert_eq(pids.size(), r.projectile_count())
		for i in r.projectile_count():
			assert_eq(pids[i], r.projectile_id(i))
			assert_eq(Vector2(pxs[i], pys[i]), r.projectile_pos(i))
		assert_eq(w.state_hash(), before, "reading in bulk changes nothing in the sim")
		if is_failing():
			return
	assert_gt(windups, 0, "the fight had windups to compare")
	assert_gt(statuses, 0, "and statuses")


func test_the_bulk_copies_are_the_callers_own() -> void:
	var w := _fight()
	var r := WorldReader.new(w)
	var ids := r.actor_ids()
	var xs := r.actor_xs()
	ids[1] = -5
	xs[1] = 999.0
	assert_ne(w.actors.ids[1], -5, "a copy: the sim's column is untouched")
	assert_ne(w.actors.pos_x[1], 999.0)


func test_the_telegraphs_rest_while_nothing_winds_up_and_wake_on_the_windup() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 24
	var far := w.add_enemy(ActorStore.Kind.WARDEN, Vector2(30, 0))
	var r := WorldReader.new(w)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	for k in 60:  # It walks in from far away: nothing winds up
		w.step(InputFrame.new())
		tv.sync(r)
	assert_eq(tv.worked, 0, "60 frames without a windup: no work")
	assert_eq(tv.threats, 0)
	var i := w.actors.index_of(far)
	w.actors.set_pos(i, Vector2(1.2, 0))
	var ticks := CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[i] == EnemyAi.State.WINDUP
	)
	assert_gte(ticks, 0, "the Warden winds up its slam")
	tv.sync(r)
	assert_eq(tv.worked, 1, "awake on the windup's frame")
	assert_eq(tv.threats, 1)
	assert_true(tv._nodes.has(far), "its circle is on the ground that frame")
	assert_true((tv._nodes[far] as Node3D).visible)
	CombatLab.until(w, func(x: World) -> bool: return r.telegraph_indices().is_empty())
	tv.sync(r)
	assert_true(tv._nodes.is_empty(), "the circle goes the frame the windup ends")
	var worked := tv.worked
	w.actors.set_pos(i, Vector2(30, 0))
	for k in 60:
		tv.sync(r)
		if not r.telegraph_indices().is_empty():
			worked = -1
			break
	if worked >= 0:
		assert_eq(tv.worked, worked, "back at rest")


func test_the_statuses_rest_with_none_on_the_floor_and_wake_on_the_first() -> void:
	var w := World.new(3, PlayerTable.starting_values())
	w.add_dummy(Vector2(1.2, 0), 0.35, 500)
	w.add_dummy(Vector2(-2, 0), 0.35, 500)
	var r := WorldReader.new(w)
	var actors: ActorViews = add_child_autofree(ActorViews.new())
	var fx: StatusVisuals = add_child_autofree(StatusVisuals.new(actors))
	actors.sync(r)
	for k in 60:
		w.step(InputFrame.new())
		actors.sync(r)
		fx.sync(r)
	assert_eq(fx.worked, 0, "60 frames without a status: no actor visited")
	var id := w.actors.ids[2]
	w.actors.burn_stacks[2] = 4
	fx.sync(r)
	assert_eq(fx.worked, 1, "awake on the burn's frame")
	assert_eq(fx.badge(id, &"burn"), 4, "its badge shows that frame")
	w.actors.burn_stacks[2] = 0
	fx.sync(r)
	assert_eq(fx.view_count(), 0, "gone the frame the burn ends")
	var worked := fx.worked
	for k in 60:
		fx.sync(r)
	assert_eq(fx.worked, worked, "back at rest")
	w.guard_charges = 2
	fx.sync(r)
	assert_eq(fx.shown(w.actors.ids[0], &"orbs"), 2, "the hero's guard charges wake it too")


func test_a_shard_burst_makes_no_node_a_gem() -> void:
	var s := ShardViews.new()
	add_child_autofree(s)
	s._burst(Vector2.ZERO, 4, 3)  # The first burst makes the two batches
	var nodes := s.get_child_count()
	for k in 8:
		s._burst(Vector2(k, 0), ShardViews.MAX_PER_KILL, 11 + k)
	assert_eq(s.count(), ShardViews.MAX_ALIVE, "a mass payout fills the gems up to the cap")
	assert_eq(s.get_child_count(), nodes, "no node per gem")
	var batches := s.gem_batches()
	assert_eq(batches[0].multimesh.visible_instance_count, ShardViews.MAX_ALIVE)
	assert_eq(batches[1].multimesh.visible_instance_count, ShardViews.MAX_ALIVE)
	assert_true(batches[0].visible)
	for k in 240:
		s._process(1.0 / 60.0)
	assert_eq(s.count(), 0, "every gem reached the hero")
	assert_eq(batches[0].multimesh.visible_instance_count, 0, "nothing left drawn")
	assert_false(batches[0].visible)
	assert_false(batches[1].visible)


func test_the_shard_drops_rest_while_none_change() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var s := ShardViews.new()
	add_child_autofree(s)
	ShardDrops.drop(w, Vector2(5, 0), 6)
	s.sync(r)
	assert_eq(s.drop_count(), 1)
	var node: Node3D = s._drops.values()[0][0]
	node.position = Vector3(99, 0, 99)  # Moved by hand: a sync that laid the drops out again would put it back
	for k in 60:
		s.sync(r)
	assert_eq(node.position, Vector3(99, 0, 99), "60 frames with the same drops: nothing laid out")
	ShardDrops.drop(w, Vector2(-5, 0), 6)
	s.sync(r)
	assert_eq(s.drop_count(), 2, "a new drop shows the frame it lands")
	assert_eq(node.position, SimPlane.to_3d(Vector2(5, 0)), "and the drops are laid out that frame")
