extends GutTest
## v0.4.0 SV (PLAN "Saves (SV)", ROADMAP R3): the canonical World snapshot. A snapshot written into a world built from
## the same generation inputs gives the same state hash, and stepping both 600 ticks with the same inputs keeps the
## hashes equal: on many seeds, floors and ticks, and in worlds with abilities, stat cards and crit, heat, the kit,
## items and combos, a boss fight behind the sealed door, horde enemies and mines. The guard tests walk every store
## the hash reads, so state a later workstream adds can't be hashed without being saved.

const K := ActorStore.Kind
const A := AbilityTable.Kind
const STEPS_AFTER := 600


## Snapshot `w`, restore into `base`, compare; then step both STEPS_AFTER ticks with twin bots and compare again.
func _round_trip(w: World, base: World, label: String, bot_seed: int = 99) -> void:
	var errors := PackedStringArray()
	var snap := WorldSnapshot.take(w, errors)
	assert_eq(errors, PackedStringArray(), "%s: every object is classified" % label)
	var bytes := var_to_bytes(snap)  # the save writes these bytes; restore from them, not from the live dictionary
	var restored := World.from_snapshot(bytes_to_var(bytes), base)
	assert_not_null(
		restored, "%s: the snapshot fits its base (%s)" % [label, WorldSnapshot.apply(base, snap)]
	)
	if restored == null:
		return
	assert_eq(
		restored.state_hash(),
		w.state_hash(),
		"%s: restored hash equals at tick %d" % [label, w.tick]
	)
	var b1 := FightBot.new(bot_seed)
	var b2 := FightBot.new(bot_seed)
	for i in STEPS_AFTER:
		w.step(SaveLab.frame(w, b1))
		restored.step(SaveLab.frame(restored, b2))
	assert_eq(
		restored.state_hash(),
		w.state_hash(),
		"%s: equal after %d more ticks (tick %d)" % [label, STEPS_AFTER, w.tick]
	)


func _rich(w: World) -> void:
	SaveLab.grant_abilities(w, [A.BOMB_LOBBER, A.DRONE_BUDDY, A.ORBIT_BLADES], 3)
	SaveLab.add_stats(
		w, [Stats.Stat.DAMAGE, Stats.Stat.CRIT_CHANCE, Stats.Stat.CRIT_DAMAGE, Stats.Stat.MAX_HP], 2
	)


func _rich_floor(run_seed: int, floor_index: int, build: StringName = &"blade") -> World:
	var w := SaveLab.floor_world(run_seed, floor_index, build)
	_rich(w)
	return w


func test_round_trip_on_many_seeds_floors_and_ticks() -> void:
	var cases := [
		[1, 1, 0, &"blade"],
		[7, 1, 400, &"gun"],
		[42, 2, 900, &"blade"],
		[1001, 3, 250, &"gun"],
		[20261006, 1, 1500, &"blade"],
		[555, 2, 60, &"gun"],
		[31337, 3, 1100, &"blade"],
		[8, 1, 2400, &"gun"],
	]
	for c: Array in cases:
		var w := _rich_floor(c[0], c[1], c[3])
		SaveLab.run(w, FightBot.new(c[0] + 5), c[2])
		_round_trip(
			w,
			_rich_floor(c[0], c[1], c[3]),
			"seed %d floor %d tick %d %s" % [c[0], c[1], c[2], c[3]]
		)


## The plain start of a floor (the save at floor start): only the starting weapon.
func test_round_trip_at_floor_start_without_extras() -> void:
	for f in [1, 2, 3]:
		_round_trip(SaveLab.floor_world(77, f), SaveLab.floor_world(77, f), "floor %d start" % f)


## v0.5.0 RT: a Deep floor (its epic altar, extra chest and scaled tables) and a floor whose Deep gate was taken.
func test_round_trip_on_a_deep_floor_and_after_the_deep_gate() -> void:
	var d := SaveLab.build_floor(SaveLab.run_state(88, 2, &"blade", Routes.Route.DEEP))
	assert_true(Routes.is_deep(d))
	assert_gte(d.boss_flow.epic_altar_id, 0)
	var b := FightBot.new(5)
	SaveLab.run(d, b, 300)
	_round_trip(
		d,
		SaveLab.build_floor(SaveLab.run_state(88, 2, &"blade", Routes.Route.DEEP)),
		"Deep floor 2"
	)
	var w := SaveLab.floor_world(88, 1)
	w.actors.invuln[0] = 1 << 24
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 999999, 1, 1, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 2)
	w.actors.set_pos(0, Routes.deep_front(f).get_center())
	var n := Kin.dir(f.deep_portal_angle)
	var into := InputFrame.new()
	into.move = Vector2i(roundi(-n.x * SimTick.MOVE_MAX), roundi(-n.y * SimTick.MOVE_MAX))
	for k in 120:
		w.step(into)
		if w.boss_flow.route_taken >= 0:
			break
	assert_eq(w.boss_flow.route_taken, Routes.Route.DEEP)
	var snap := WorldSnapshot.take(w, PackedStringArray())
	var restored := World.from_snapshot(
		bytes_to_var(var_to_bytes(snap)), SaveLab.floor_world(88, 1)
	)
	assert_not_null(restored)
	if restored != null:
		assert_eq(restored.boss_flow.route_taken, Routes.Route.DEEP, "the route taken is saved")
		assert_eq(restored.state_hash(), w.state_hash())


## Items and combos (engines, statuses): every item owned.
func test_round_trip_with_items_and_combos() -> void:
	var w := SaveLab.floor_world(12, 2)
	for k in mini(8, w.item_tables.size()):
		w.add_item(k)
	SaveLab.run(w, FightBot.new(4), 700)
	assert_gt(w.items_owned.size(), 0)
	var base := SaveLab.floor_world(12, 2)
	for k in mini(8, base.item_tables.size()):
		base.add_item(k)
	_round_trip(w, base, "items")


## A boss fight: the door sealed behind the player (a wall added in play, its flow field swapped in), the boss mid
## attack pattern.
func test_round_trip_in_a_boss_fight() -> void:
	for f in [1, 2, 3]:
		var w := _rich_floor(500 + f, f)
		w.actors.hp[0] = 100000
		w.actors.max_hp[0] = 100000
		FightLab.enter_boss_room(w)
		SaveLab.run(w, FightBot.new(3), 400)
		assert_true(
			w.boss_alive() or w.boss_id >= 0 or not w.bosses.ids.is_empty(), "floor %d boss" % f
		)
		assert_gt(w.walls.size(), _rich_floor(500 + f, f).walls.size(), "the door sealed")
		_round_trip(w, _rich_floor(500 + f, f), "boss floor %d" % f)


## Horde enemies (v0.4.0 EN) and Mine Layer mines mid fuse.
func test_round_trip_with_horde_enemies_and_mines() -> void:
	var w := _rich_floor(64, 2)
	w.actors.hp[0] = 100000
	w.actors.max_hp[0] = 100000
	var p := w.player_pos()
	var kinds := [K.SWARMER, K.SPLITTER, K.SHIELD_BEARER, K.MENDER, K.MINE_LAYER, K.SNIPER]
	for i in kinds.size():
		var at := p + Vector2(4.0 + i, -3.0 + i)
		if w.enemy_table(kinds[i]) != null:
			w.add_enemy(kinds[i], at)
			w.add_enemy(kinds[i], at + Vector2(0.0, 1.5))
	var base_kinds := kinds
	var t := 0
	while not w.mines.touched and t < 1800:
		w.step(SaveLab.frame(w, FightBot.new(t)))
		t += 1
	assert_true(w.mines.touched, "a Mine Layer dropped a mine")
	var base := _rich_floor(64, 2)
	_round_trip(w, base, "horde + mines")
	assert_eq(base_kinds.size(), 6)


## A long floor-3 run: the danger tiers raise the spawn caps, so the crowd is large.
func test_round_trip_in_a_crowd() -> void:
	var w := _rich_floor(9, 3)
	w.actors.hp[0] = 1000000
	w.actors.max_hp[0] = 1000000
	SaveLab.run(w, FightBot.new(2), 1800)
	var p := w.player_pos()
	var kinds := [K.SWARMER, K.CHARGER, K.NEEDLE, K.SPLITTER, K.ARC_CASTER, K.SNIPER]
	for i in 90:  # a horde on top of the spawner's: rings around the player
		var at := p + Kin.dir((i * 4096 / 90) & 4095) * (5.0 + float(i % 5))
		if w.enemy_table(kinds[i % kinds.size()]) != null:
			w.add_enemy(kinds[i % kinds.size()], at)
	SaveLab.run(w, FightBot.new(2), 120)
	gut.p(
		(
			"crowd: %d actors, %d projectiles at tick %d"
			% [w.actors.size(), w.projectiles.size(), w.tick]
		)
	)
	assert_gt(w.actors.size(), 80, "a crowd")
	_round_trip(w, _rich_floor(9, 3), "crowd")


## The snapshot is a copy: stepping the world after take() doesn't change it.
func test_the_snapshot_does_not_alias_the_world() -> void:
	var w := _rich_floor(3, 1)
	SaveLab.run(w, FightBot.new(1), 500)
	var h := w.state_hash()
	var snap := WorldSnapshot.take(w)
	SaveLab.run(w, FightBot.new(1), 300)
	assert_ne(w.state_hash(), h, "the world moved on")
	var base := _rich_floor(3, 1)
	assert_not_null(World.from_snapshot(snap, base))
	assert_eq(base.state_hash(), h, "the snapshot kept the state at take()")
	var again := _rich_floor(3, 1)
	assert_not_null(World.from_snapshot(snap, again), "a snapshot restores more than once")
	assert_eq(again.state_hash(), h)


## A snapshot for another floor or another run doesn't fit, and says so.
func test_a_snapshot_of_another_floor_is_refused() -> void:
	var snap := WorldSnapshot.take(SaveLab.floor_world(5, 1))
	assert_string_contains(WorldSnapshot.apply(SaveLab.floor_world(6, 1), snap), "floor differs")
	assert_ne(WorldSnapshot.apply(SaveLab.floor_world(5, 1), {"format": 999}), "")
	assert_ne(WorldSnapshot.apply(SaveLab.floor_world(5, 1), {}), "")


# --- The guard: hashed implies snapshotted ------------------------------------------------------------------


## Every object reachable from World (as [path, object]), loadout tables included.
func _reachable(w: World) -> Array:
	var out := []
	var seen := {}
	var todo := [["World", w]]
	while not todo.is_empty():
		var item: Array = todo.pop_back()
		var obj: Object = item[1]
		if seen.has(obj.get_instance_id()):
			continue
		seen[obj.get_instance_id()] = true
		out.append(item)
		for f in WorldSnapshot.script_fields(obj):
			for pair: Array in _objects_in(obj.get(f), "%s.%s" % [item[0], f]):
				todo.append(pair)
	return out


## [path, object] for every script object in `v` (arrays and dictionaries walked, the path indexed).
func _objects_in(v: Variant, path: String) -> Array:
	match typeof(v):
		TYPE_OBJECT:
			return [[path, v]] if v != null and (v as Object).get_script() != null else []
		TYPE_ARRAY:
			var out := []
			var arr: Array = v
			for i in arr.size():
				out.append_array(_objects_in(arr[i], "%s[%d]" % [path, i]))
			return out
		TYPE_DICTIONARY:
			var out := []
			for k: Variant in v:
				out.append_array(_objects_in(v[k], "%s[%s]" % [path, str(k)]))
			return out
	return []


func _guard_worlds() -> Array[World]:
	var a := _rich_floor(21, 1)
	SaveLab.run(a, FightBot.new(21), 900)
	var b := _rich_floor(22, 3, &"gun")
	b.actors.hp[0] = 100000
	FightLab.enter_boss_room(b)
	SaveLab.run(b, FightBot.new(22), 300)
	var out: Array[World] = [a, b]
	return out


## Every store the state hash reads (each object with hash_into, and every World field) is either copied field by
## field or kept from the base with a reason. A new store class fails here with its path until it is classified.
func test_every_hashed_store_is_snapshotted() -> void:
	for w in _guard_worlds():
		var errors := PackedStringArray()
		var snap := WorldSnapshot.take(w, errors)
		assert_eq(errors, PackedStringArray(), "no unclassified object")
		var data: Dictionary = snap["world"]
		for f in WorldSnapshot.script_fields(w):
			assert_true(
				data.has(f) or WorldSnapshot.WORLD_KEPT.has(f),
				"World.%s is in the snapshot or kept with a reason" % f
			)
		for item: Array in _reachable(w):
			var cls := WorldSnapshot.class_of(item[1])
			var classified := (
				WorldSnapshot.STATE_CLASSES.has(cls)
				or WorldSnapshot.LOADOUT_CLASSES.has(cls)
				or cls in [&"World", &"SimEvent", &"NavField"]
			)  # NavField: World.nav and _nav_next, kept
			assert_true(
				classified,
				(
					"%s is a %s: add it to WorldSnapshot.STATE_CLASSES or LOADOUT_CLASSES"
					% [item[0], cls]
				)
			)
			if (item[1] as Object).has_method(&"hash_into"):
				assert_true(
					WorldSnapshot.STATE_CLASSES.has(cls),
					"%s (%s) is hashed (hash_into), so its fields are copied" % [item[0], cls]
				)


## The fields kept from the base are real World fields (no stale names), and the only non-loadout ones (the event
## log, the derived grid and field, the pending door) don't move the hash: clearing the log changes nothing.
func test_kept_fields_are_world_fields_and_the_event_log_is_not_hashed() -> void:
	var w := _rich_floor(30, 1)
	SaveLab.run(w, FightBot.new(30), 400)
	var fields := WorldSnapshot.script_fields(w)
	for f: StringName in WorldSnapshot.WORLD_KEPT:
		assert_true(fields.has(f), "World.%s exists" % f)
	var h := w.state_hash()
	w.set(&"_events", [] as Array[SimEvent])
	assert_eq(w.state_hash(), h, "the event log is not hashed")


## Plain data of every script field under `obj`, objects included (a deep dump for comparing loadout tables).
func _dump(v: Variant, depth: int = 0) -> Variant:
	if depth > 8:
		return null
	match typeof(v):
		TYPE_OBJECT:
			if v == null or (v as Object).get_script() == null:
				return null
			var out := {}
			for f in WorldSnapshot.script_fields(v):
				out[f] = _dump((v as Object).get(f), depth + 1)
			return out
		TYPE_ARRAY:
			var out := []
			for x: Variant in v:
				out.append(_dump(x, depth + 1))
			return out
		TYPE_DICTIONARY:
			var out := {}
			for k: Variant in v:
				out[k] = _dump(v[k], depth + 1)
			return out
	return v


## Loadout tables are kept from the base, so play must never write them: dump every loadout object at the start and
## after a long rich run (a boss fight included) and compare.
func test_loadout_tables_are_not_written_in_play() -> void:
	var w := _rich_floor(40, 2)
	w.actors.hp[0] = 100000
	var before := {}
	for item: Array in _reachable(w):
		if WorldSnapshot.LOADOUT_CLASSES.has(WorldSnapshot.class_of(item[1])):
			before[item[0]] = var_to_bytes(_dump(item[1]))
	assert_gt(before.size(), 5, "found the loadout tables")
	SaveLab.run(w, FightBot.new(40), 900)
	FightLab.enter_boss_room(w)
	SaveLab.run(w, FightBot.new(41), 600)
	for item: Array in _reachable(w):
		if before.has(item[0]):
			assert_eq(
				var_to_bytes(_dump(item[1])),
				before[item[0]],
				"%s (loadout) unchanged by play" % item[0]
			)


## The guard names the place of an unclassified object.
func test_an_unclassified_object_is_reported_with_its_path() -> void:
	var errors := PackedStringArray()
	WorldSnapshot._encode([FightBot.new(1)], "World.planted", errors)
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "World.planted[0] holds a FightBot")
