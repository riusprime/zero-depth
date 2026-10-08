extends GutTest
## Explore after the boss (v0.5.0 PB, owner D10: "You can go as soon as you want to the boss and then explore back"):
## the boss's death reopens the boss door both ways (its collider leaves the walls, blinks may cross the doorway),
## the boss's drops stay, the portal(s) stay open until walked into; normal spawns resume only while the player is
## outside the boss room, at the floor curve's level for the floor time (the clock never stopped), and never arrive
## inside it; re-entering never seals the door again, so the floor-1 heal (D9) is once. Same seed, same hash; a
## snapshot taken after the boss died (or during the fight, restored, then the boss killed) restores an open door.

const LONG := 1 << 24


func _repo() -> ContentRepository:
	return ContentRepository.load_all()


## Floor 1 of run `run_seed` as Main builds it (the floor's curve, the D9 heal, two gates), the player invulnerable.
func _world(run_seed: int) -> World:
	var w := RunLab.new(_repo(), run_seed, &"blade").floor_world()
	w.actors.invuln[0] = LONG
	return w


func _into(w: World) -> Vector2:
	return Kin.dir(w.floor_layout.boss_door_angle)


## Seals the door (one tick past the door line) and kills the boss and everything else; the next tick opens it.
func _beat_boss(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 4)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "the fight began")
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 9999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the boss is dead, the portal open")


func _events_of(w: World, kind: SimEvent.Kind, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind:
			out.append(e)
	return out


func _walk(w: World, dir: Vector2, ticks: int) -> void:
	var frame := InputFrame.new()
	frame.move = Vector2i(roundi(dir.x * SimTick.MOVE_MAX), roundi(dir.y * SimTick.MOVE_MAX))
	for k in ticks:
		w.step(frame)


## Steps n idle ticks; returns the normal enemies that arrived (SPAWN of a live non-boss actor), as actor ids.
func _spawned(w: World, n: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for k in n:
		var before := w.last_event_seq()
		w.step(InputFrame.new())
		for e in _events_of(w, SimEvent.Kind.SPAWN, before):
			var i := w.actors.index_of(e.target_id)
			if i >= 0 and EnemyAi.is_enemy_kind(w.actors.kinds[i]):
				out.append(e.target_id)
	return out


func test_the_boss_dying_reopens_the_door_both_ways() -> void:
	var w := _world(4101)
	var f := w.floor_layout
	var walls_open := w.walls.size()
	w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	CombatLab.idle(w, 1)
	assert_eq(w.walls.size(), walls_open + 1, "sealed: the door is a wall")
	assert_true(w.boss_flow.door_sealed())
	_beat_boss(w)
	assert_eq(w.walls.size(), walls_open, "v0.5.0 PB: the door's collider left the walls")
	assert_false(w.boss_flow.door_sealed(), "the door is open")
	assert_true(w.boss_flow.boss_reached(), "the boss was reached")
	var reader := WorldReader.new(w)
	assert_false(reader.boss_door_sealed())
	assert_true(reader.portal_active())
	# Walk out through the doorway into the host room, then back in.
	w.actors.set_pos(0, f.boss_door_inside(1.0))
	w.vel = Vector2.ZERO
	_walk(w, -_into(w), 90)
	assert_eq(f.room_of(w.player_pos()), f.boss_host_room, "out through the open door")
	_walk(w, _into(w), 90)
	assert_eq(f.room_of(w.player_pos()), f.boss_room, "and back in")
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "re-entering never seals it again")
	assert_eq(_events_of(w, SimEvent.Kind.BOSS_ROOM_SEALED).size(), 1, "sealed once")
	assert_eq(w.walls.size(), walls_open)


func test_the_floor_one_heal_is_once() -> void:
	var w := _world(4102)
	assert_eq(w.boss_room_heal_permille, 1000, "floor 1: the D9 heal")
	w.actors.hp[0] = 20
	_beat_boss(w)
	assert_eq(w.actors.hp[0], w.actors.max_hp[0], "the first entry healed")
	var heals := 0
	for e in _events_of(w, SimEvent.Kind.HEAL):
		if e.effect_id == &"boss_room_heal":
			heals += 1
	assert_eq(heals, 1)
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_outside(2.0))
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 2)
	w.actors.hp[0] = 20
	var seq := w.last_event_seq()
	w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 2)
	for e in _events_of(w, SimEvent.Kind.HEAL, seq):
		assert_ne(e.effect_id, &"boss_room_heal", "no second boss-room heal on re-entry")
	assert_lt(w.actors.hp[0], w.actors.max_hp[0] / 2, "re-entry restores nothing")


func test_blink_crosses_the_open_doorway_after_the_boss() -> void:
	var w: World = null
	for s in 40:
		var c := _world(4200 + s)
		if c.floor_layout.door_depths[c.floor_layout.boss_door_index] <= 3.2:
			w = c
			break
	assert_not_null(w, "a floor with a thin boss wall")
	if w == null:
		return
	w.player.utility = PlayerTable.Utility.BLINK
	var f := w.floor_layout
	_beat_boss(w)
	w.actors.set_pos(0, f.boss_door_inside(0.4))
	w.vel = Vector2.ZERO
	w.blink_cd = 0
	w.step(InputFrame.make(Vector2i.ZERO, Kin.angle_of(-_into(w)), 1000, 0, InputFrame.UTILITY))
	assert_false(f.boss_cells_rect.has_point(w.player_pos()), "a blink out through the open door")
	assert_true(w.blink_may_land(f.boss_door_outside(0.4), f.boss_door_inside(0.4)), "and in")


func test_spawns_resume_outside_the_boss_room_only() -> void:
	var w := _world(4103)
	var f := w.floor_layout
	_beat_boss(w)
	var t0 := w.run_ticks
	assert_eq(_spawned(w, 1200).size(), 0, "none in the boss room after the boss")
	assert_eq(w.run_ticks, t0 + 1200, "the floor's clock keeps running")
	w.actors.set_pos(0, f.boss_door_outside(2.5))
	w.vel = Vector2.ZERO
	var ids := _spawned(w, 1200)
	assert_gt(ids.size(), 0, "spawns resume once the player is out")
	for id in ids:
		var i := w.actors.index_of(id)
		if i >= 0:
			assert_ne(f.room_of(w.actors.pos(i)), f.boss_room, "never in the boss room")
	# Back in: spawning stops again (enemies already out may follow you in).
	w.actors.set_pos(0, f.boss_spawn)
	w.vel = Vector2.ZERO
	assert_eq(_spawned(w, 900).size(), 0, "none while you stand in the boss room")


func test_spawns_resume_at_the_curve_level_for_the_floor_time() -> void:
	var w := _world(4104)
	var f := w.floor_layout
	_beat_boss(w)
	CombatLab.idle(w, 600)
	w.actors.set_pos(0, f.boss_door_outside(2.5))
	w.vel = Vector2.ZERO
	var checked := 0
	for k in 1800:
		var before := w.last_event_seq()
		var ticks := w.run_ticks  # the tick's floor time, as SpawnDirector reads it (run_ticks - 1 after counting)
		w.step(InputFrame.new())
		for e in _events_of(w, SimEvent.Kind.SPAWN, before):
			var i := w.actors.index_of(e.target_id)
			if i < 0 or not EnemyAi.is_enemy_kind(w.actors.kinds[i]) or w.overrun.inside:
				continue
			var want := w.spawner.hp_now(w.enemy_table(w.actors.kinds[i]).hp, ticks)
			if w.actors.max_hp[i] == want * 2:
				continue  # an elite (Marked Hunt), not on a fresh run
			assert_eq(w.actors.max_hp[i], want, "the curve's HP at floor time %d" % ticks)
			checked += 1
		if checked >= 3:
			break
	assert_gt(checked, 0, "post-boss arrivals were checked")
	assert_gt(w.run_ticks, 600, "the floor time includes the fight and the wait")


func test_the_portals_stay_open_while_you_explore() -> void:
	var w := _world(4105)
	var f := w.floor_layout
	_beat_boss(w)
	var routes := w.boss_flow.routes
	w.actors.set_pos(0, f.boss_door_outside(2.5))
	w.vel = Vector2.ZERO
	CombatLab.idle(w, 1800)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "still open after half a minute away")
	assert_true(w.boss_flow.gate_open(Routes.Route.NORMAL))
	assert_eq(
		w.boss_flow.gate_open(Routes.Route.DEEP),
		routes,
		"the Deep gate too, when the floor has one"
	)
	assert_false(w.boss_flow.exited())
	assert_eq(_events_of(w, SimEvent.Kind.BOSS_DEFEATED).size(), 1, "the boss died once")


func test_same_seed_same_hash_after_the_boss() -> void:
	var hashes: Array[String] = []
	for k in 2:
		var w := _world(4106)
		_beat_boss(w)
		w.actors.set_pos(0, w.floor_layout.boss_door_outside(2.5))
		w.vel = Vector2.ZERO
		SaveLab.run(w, FightBot.new(8), 900)
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])


## Snapshot `w`, restore it into `base`, compare hashes, walls and the door; step both with twin bots and compare.
func _round_trip(w: World, base: World, label: String) -> World:
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "%s: every object is classified" % label)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "%s: the snapshot fits its base" % label)
	if restored == null:
		return null
	assert_eq(restored.state_hash(), w.state_hash(), "%s: restored hash" % label)
	assert_eq(restored.walls.size(), w.walls.size(), "%s: the same walls" % label)
	assert_eq(restored.boss_flow.door_sealed(), w.boss_flow.door_sealed(), "%s: the door" % label)
	assert_eq(
		restored.boss_flow.portal_active(), w.boss_flow.portal_active(), "%s: portals" % label
	)
	var b1 := FightBot.new(21)
	var b2 := FightBot.new(21)
	for i in 600:
		w.step(SaveLab.frame(w, b1))
		restored.step(SaveLab.frame(restored, b2))
	assert_eq(restored.state_hash(), w.state_hash(), "%s: equal 600 ticks later" % label)
	assert_eq(restored.walls.size(), w.walls.size(), "%s: walls 600 ticks later" % label)
	return restored


func test_a_save_after_the_boss_restores_an_open_door_and_portals() -> void:
	var w := _world(4107)
	var walls_open := w.walls.size()
	_beat_boss(w)
	var r := _round_trip(w, _world(4107), "in the boss room")
	if r != null:
		assert_eq(r.walls.size(), walls_open, "the door stays open")
	var w2 := _world(4108)
	_beat_boss(w2)
	w2.actors.set_pos(0, w2.floor_layout.boss_door_outside(2.5))
	w2.vel = Vector2.ZERO
	SaveLab.run(w2, FightBot.new(3), 900)
	var r2 := _round_trip(w2, _world(4108), "exploring after the boss")
	if r2 != null:
		assert_false(r2.boss_flow.door_sealed())
		assert_true(
			r2.boss_flow.gate_open(Routes.Route.NORMAL), "the portal is open after the restore"
		)


func test_a_save_in_the_fight_then_the_boss_dies_after_the_restore() -> void:
	var w := _world(4109)
	var walls_open := w.walls.size()
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	CombatLab.idle(w, 4)
	assert_true(w.boss_flow.door_sealed())
	var snap := WorldSnapshot.take(w, PackedStringArray())
	var r := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), _world(4109))
	assert_not_null(r)
	if r == null:
		return
	for x: World in [w, r]:
		var bi := x.actors.index_of(x.boss_id)
		x.actors.invuln[bi] = 0
		Damage.hit(x, bi, 9999999, 0, 0, 1, 0, x.actors.pos(bi), x.actors.pos(bi))
		CombatLab.idle(x, 2)
		assert_eq(x.walls.size(), walls_open, "the door opened")
		x.actors.set_pos(0, f.boss_door_outside(2.5))
		x.vel = Vector2.ZERO
		CombatLab.idle(x, 900)
	assert_eq(r.state_hash(), w.state_hash(), "the restored fight opens the door the same way")
