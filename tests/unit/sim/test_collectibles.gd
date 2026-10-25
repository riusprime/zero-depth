extends GutTest
## v0.9.0 CL (owner: "collectibles are fine", COLLECTIBLES.md as drafted): the 16 collectibles' content, where a run's
## floors arm them (CollectibleBook.arm, over seeds: how often each can appear in a run), each source showing its
## pickup and the hero taking it (Collectibles: the COLLECTIBLE event, the state hashed and snapshotted), found once
## per profile (a run never arms a found one again; one Stone a run), the run's save keeping what it collected, the
## profile's section (version 3, an older profile has none found), the hub's runes and gate counting them.

const SEEDS := 30

var _repo: ContentRepository
var _defs: Array[CollectibleDefinition] = []


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_defs = CollectibleBook.defs(_repo)


func _def(id: StringName) -> CollectibleDefinition:
	for d in _defs:
		if d.id == id:
			return d
	return null


func _armed(w: World) -> Array[StringName]:
	var out: Array[StringName] = []
	if w.collect != null:
		for s in w.collect.ids:
			out.append(StringName(s))
	return out


func _entry(w: World, id: StringName) -> int:
	return w.collect.ids.find(String(id)) if w.collect != null else -1


## Floor `f` of run `run_seed` (route `route` into every floor after the first), built as Main builds it.
func _floor(run_seed: int, f: int, route: int = 0) -> World:
	return SaveLab.build_floor(SaveLab.run_state(run_seed, f, &"blade", route, _repo), &"", _repo)


## The first floor over seeds 1.. whose world satisfies `ok` (floors `floors`), or null.
func _find(ok: Callable, floors: Array, route: int = 0, limit: int = 120) -> World:
	for s in range(1, limit + 1):
		for f: int in floors:
			var w := _floor(s, f, route)
			if ok.call(w):
				w.set_meta(&"run_seed", s)
				return w
	return null


## Shows entry `id`'s source by `trigger`, then walks the hero onto its pickup: it is taken, one COLLECTIBLE event.
func _show_and_take(w: World, id: StringName, trigger: Callable) -> void:
	var k := _entry(w, id)
	assert_gte(k, 0, "%s is armed" % id)
	if k < 0:
		return
	Collectibles.advance(w)
	assert_eq(w.collect.shown_tick[k], -1, "%s doesn't show before its source gives it" % id)
	trigger.call(w)
	Collectibles.advance(w)
	assert_gte(w.collect.shown_tick[k], 0, "%s shows once its source gives it" % id)
	var at := w.collect.pos[k]
	var seq := w.last_event_seq()
	w.actors.set_pos(0, at)
	Collectibles.advance(w)
	assert_gte(w.collect.taken_tick[k], 0, "walking over %s takes it" % id)
	var events := w.events_since(seq).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.COLLECTIBLE
	)
	assert_eq(events.size(), 1, "one COLLECTIBLE event")
	if not events.is_empty():
		assert_eq(StringName((events[0] as SimEvent).effect_id), id, "naming %s" % id)
	assert_eq(WorldReader.new(w).collectibles_taken(), PackedStringArray([String(id)]))


func test_the_sixteen_are_the_doc() -> void:
	assert_eq(_defs.size(), 16, "16 collectibles")
	var orders := {}
	for d in _defs:
		assert_eq(d.validate().size(), 0, "%s is valid" % d.id)
		orders[d.order] = true
		assert_ne(tr(d.name_key), String(d.name_key), "%s has a name" % d.id)
		assert_ne(tr(d.lore_key), String(d.lore_key), "%s has a lore line" % d.id)
	assert_eq(orders.size(), 16, "each in its own place")
	var shelves := {}
	for d in _defs:
		shelves[d.shelf] = int(shelves.get(d.shelf, 0)) + 1
	assert_eq(shelves, {&"stone": 5, &"sealed": 7, &"crown": 3, &"hub": 1}, "the four shelves")
	var biomes: Array = []
	for d in _defs:
		if d.source == &"hidden_room":
			biomes.append(d.biome)
			assert_not_null(_repo.get_def(&"biomes", d.biome), "%s's biome exists" % d.id)
	assert_eq(biomes.size(), 5, "one Stone per biome")
	var run_def := _repo.get_def(&"run", RunSaver.RUN_ID) as RunDefinition
	for d in _defs:
		if d.source == &"final_body":
			assert_true(run_def.final_bosses.has(d.body), "%s is a body of the final boss" % d.id)


func test_how_often_each_can_appear_in_a_run() -> void:
	var floors := SaveLab.floors()
	var runs := {}
	for d in _defs:
		runs[d.id] = 0
	var purple_runs := 0
	for s in range(1, SEEDS + 1):
		var seen := {}
		var purple := false
		for f in range(1, floors + 1):
			var w := _floor(s, f)
			for id in _armed(w):
				seen[id] = true
			purple = purple or w.purple != null
		for id: StringName in seen:
			runs[id] += 1
		purple_runs += 1 if purple else 0
	var lines := PackedStringArray()
	for d in _defs:
		lines.append("%s=%d/%d" % [d.id, runs[d.id], SEEDS])
	gut.p("CL_ARMED| %s" % " ".join(lines))
	gut.p("CL_ARMED| purple_room_runs=%d/%d" % [purple_runs, SEEDS])
	for d in _defs:
		if d.source in [&"purple_portal", &"final_body", &"hub_keystone"]:
			assert_eq(runs[d.id], 0, "%s isn't on a normal floor" % d.id)
		else:
			assert_gt(
				runs[d.id], 0, "%s can appear in a run (%d of %d)" % [d.id, runs[d.id], SEEDS]
			)
	assert_gt(purple_runs, 0, "a run can reach the Purple Portal")


func test_a_found_one_never_arms_again_and_one_stone_a_run() -> void:
	var w := _find(func(x: World) -> bool: return _armed(x).size() >= 2, [2, 3, 4, 5])
	assert_not_null(w, "a floor arms two")
	if w == null:
		return
	var ids := _armed(w)
	var run := SaveLab.run_state(int(w.get_meta(&"run_seed")), w.floor_index, &"blade", 0, _repo)
	run.collected = [ids[0]]
	var w2 := SaveLab.build_floor(run, &"", _repo)
	assert_false(_armed(w2).has(ids[0]), "a collected one isn't armed again")
	assert_true(_armed(w2).has(ids[1]), "the others still are")
	var stone := _find(
		func(x: World) -> bool:
			for id in _armed(x):
				if _def(id).source == &"hidden_room":
					return true
			return false,
		[1, 2, 3, 4, 5]
	)
	assert_not_null(stone, "a floor arms a Stone")
	if stone == null:
		return
	var other: StringName = (
		&"cold_lantern" if not _armed(stone).has(&"cold_lantern") else &"frozen_bell"
	)
	var r2 := SaveLab.run_state(1, stone.floor_index, &"blade", 0, _repo)
	r2.collected_run = [other]
	var t := World.new(0, PlayerTable.new(), Vector2.ZERO)
	t.breakables = stone.breakables
	t.floor_layout = stone.floor_layout
	CollectibleBook.arm(t, r2, _defs, _stone_biome(stone))
	assert_false(
		_armed(t).any(func(id: StringName) -> bool: return _def(id).source == &"hidden_room"),
		"a run that took a Stone arms no other"
	)


func _stone_biome(w: World) -> StringName:
	for id in _armed(w):
		if _def(id).source == &"hidden_room":
			return _def(id).biome
	return &""


func test_the_hidden_room_gives_its_stone() -> void:
	var w := _find(
		func(x: World) -> bool:
			return _armed(x).any(
				func(id: StringName) -> bool: return _def(id).source == &"hidden_room"
			),
		[1, 2, 3, 4, 5]
	)
	assert_not_null(w)
	if w == null:
		return
	var id: StringName = _armed(w).filter(func(i: StringName) -> bool: return _def(i).source == &"hidden_room")[0]
	_show_and_take(w, id, func(x: World) -> void: x.breakables.crack_broken = 1)
	var k := _entry(w, id)
	assert_eq(w.floor_layout.room_of(w.collect.pos[k]), w.floor_layout.crack_room, "in the room")


func test_the_rune_puzzle_gives_the_aligned_key_on_floor_4_or_5() -> void:
	var w := _find(func(x: World) -> bool: return x.runes != null, [4, 5])
	assert_not_null(w)
	if w == null:
		return
	_show_and_take(w, &"aligned_key", func(x: World) -> void: x.runes.solved = 1)
	var early := _find(func(x: World) -> bool: return x.runes != null, [1, 2, 3])
	if early != null:
		assert_false(_armed(early).has(&"aligned_key"), "not before floor 4")


func test_the_timed_door_gives_the_sand_shell_from_floor_3() -> void:
	var w := _find(func(x: World) -> bool: return x.timed != null, [3, 4, 5])
	assert_not_null(w)
	if w == null:
		return
	_show_and_take(w, &"sand_shell", func(x: World) -> void: x.timed.opened = 1)
	var k := _entry(w, &"sand_shell")
	assert_eq(w.floor_layout.room_of(w.collect.pos[k]), w.floor_layout.timed_room, "in its room")


func test_a_hazard_lockdown_gives_the_broken_shackle() -> void:
	var w := _find(func(x: World) -> bool: return _armed(x).has(&"broken_shackle"), [1, 2, 3, 4, 5])
	assert_not_null(w)
	if w == null:
		return
	var f := w.floor_layout
	var room := f.lockdown_rooms[f.lockdown_kinds.find(LockdownTable.Kind.HAZARD)]
	var k := _entry(w, &"broken_shackle")
	w.lockdown.cleared.append(room)
	w.lockdown.forced.append(room)
	Collectibles.advance(w)
	assert_eq(w.collect.shown_tick[k], -1, "a Lockdown its cap opened gives none")
	w.lockdown.cleared.clear()
	w.lockdown.forced.clear()
	_show_and_take(w, &"broken_shackle", func(x: World) -> void: x.lockdown.cleared.append(room))


func test_a_blood_shrine_gives_the_blood_coin() -> void:
	var w := _find(func(x: World) -> bool: return _armed(x).has(&"blood_coin"), [1, 2, 3, 4, 5])
	assert_not_null(w)
	if w == null:
		return
	_show_and_take(w, &"blood_coin", func(x: World) -> void: x.shrine.used_tick = x.tick)


func test_the_last_floors_fountain_gives_the_dry_chalice() -> void:
	var last := SaveLab.floors()
	var w := _find(
		func(x: World) -> bool: return x.shrine != null and x.shrine.fountain_entry >= 0, [last]
	)
	assert_not_null(w, "a last floor with a fountain")
	if w == null:
		return
	_show_and_take(w, &"dry_chalice", func(x: World) -> void: x.shrine.fountain_tick = x.tick)
	var early := _find(
		func(x: World) -> bool: return x.shrine != null and x.shrine.fountain_entry >= 0, [2, 3]
	)
	if early != null:
		assert_false(_armed(early).has(&"dry_chalice"), "not before the last floor")


func test_three_marked_secrets_in_a_run_give_the_rune_rubbing() -> void:
	var w := _find(func(x: World) -> bool: return x.timed != null, [1, 2])  # before the Sand Shell's floors
	assert_not_null(w)
	if w == null:
		return
	var k := _entry(w, &"rune_rubbing")
	w.collect.marked_before = 1
	w.timed.opened = 1
	Collectibles.advance(w)
	assert_eq(w.collect.shown_tick[k], -1, "two of three found: not yet")
	w.timed.opened = 0
	w.collect.marked_before = 2
	_show_and_take(w, &"rune_rubbing", func(x: World) -> void: x.timed.opened = 1)
	var run := SaveLab.run_state(1, 1, &"blade", 0, _repo)
	run.finish_floor(w)
	assert_eq(run.marked_done, 1, "a finished floor adds its marked secrets to the run")


func test_the_purple_portals_floor_gives_the_violet_eye() -> void:
	var w := _floor(7, 3, Routes.Route.DEEP)
	assert_true(_armed(w).has(&"violet_eye"), "a floor reached through the Purple Portal arms it")
	assert_false(_armed(_floor(7, 3)).has(&"violet_eye"), "a normal floor doesn't")
	var k := _entry(w, &"violet_eye")
	if w.boss_flow != null:
		w.boss_flow.arrive_left = 5
	Collectibles.advance(w)
	assert_eq(w.collect.shown_tick[k], -1, "not while the hero arrives")
	_show_and_take(w, &"violet_eye", func(x: World) -> void: x.boss_flow.arrive_left = 0)


func test_each_final_body_gives_its_piece_as_it_falls() -> void:
	var run := SaveLab.run_state(1, SaveLab.floors(), &"blade", 0, _repo)
	run.final_fight = true
	var w := World.new(0, PlayerTable.new(), Vector2.ZERO)
	CollectibleBook.arm(w, run, _defs, &"")
	assert_eq(
		_armed(w), [&"colossus_tooth", &"prism_shard", &"mirror_mask"] as Array[StringName], "three"
	)
	var f := FinalFight.new()
	f.tables = PackedInt32Array([0, 1, 2])
	w.final_fight = f
	Collectibles.advance(w)
	assert_eq(w.collect.taken_tick[0], -1, "nothing before a body falls")
	f.phase = 1
	Collectibles.advance(w)
	assert_gte(w.collect.taken_tick[0], 0, "the Colossus fell: its tooth comes to the hero")
	assert_eq(w.collect.taken_tick[1], -1)
	f.phase = 2
	f.won = true
	Collectibles.advance(w)
	assert_gte(w.collect.taken_tick[1], 0, "the Prism")
	assert_gte(w.collect.taken_tick[2], 0, "and the Fallen, the fight won")


func test_the_state_is_hashed_and_snapshotted() -> void:
	var w := _find(func(x: World) -> bool: return x.timed != null, [3, 4, 5])
	assert_not_null(w)
	if w == null:
		return
	var h0 := w.state_hash()
	w.timed.opened = 1
	Collectibles.advance(w)
	var h1 := w.state_hash()
	assert_ne(h0, h1, "a pickup shown changes the hash")
	var snap := w.to_snapshot()
	var base := _floor(int(w.get_meta(&"run_seed")), w.floor_index)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(base.collect.shown_tick, w.collect.shown_tick, "restored")
	assert_eq(base.state_hash(), w.state_hash(), "the same hash")
	var bare := World.new(0, PlayerTable.new(), Vector2.ZERO)
	assert_null(bare.collect, "a world nobody armed holds none (goldens hash as before)")


func test_the_run_save_keeps_what_the_run_collected() -> void:
	var run := SaveLab.run_state(5, 2, &"blade", 0, _repo)
	run.collected = [&"cold_lantern", &"blood_coin"]
	run.collected_run = [&"blood_coin"]
	run.marked_done = 2
	var w := SaveLab.build_floor(run, &"", _repo)
	var back := SaveLab.run_from(RunSaver.payload_of(w, run, 5, PackedByteArray()))
	assert_eq(back.collected, run.collected)
	assert_eq(back.collected_run, run.collected_run)
	assert_eq(back.marked_done, 2)
	var plain := SaveLab.run_state(5, 2, &"blade", 0, _repo)
	var p := RunSaver.payload_of(
		SaveLab.build_floor(plain, &"", _repo), plain, 5, PackedByteArray()
	)
	assert_false((p["run"] as Dictionary).has("collected"), "none collected: no key, as before")
	assert_eq(SaveLab.run_from(p).collected.size(), 0, "an older payload found none")


func test_the_profile_records_each_once_and_an_old_one_has_none() -> void:
	var p := ProfileStore.new("")
	assert_eq(int(p.data["profile_version"]), 3)
	assert_eq(CollectibleBook.count(p), 0)
	assert_true(CollectibleBook.record(p, &"blood_coin", 77))
	assert_false(CollectibleBook.record(p, &"blood_coin", 78), "once per profile")
	assert_true(CollectibleBook.found(p, &"blood_coin"))
	assert_eq(CollectibleBook.found_ids(p), [&"blood_coin"] as Array[StringName])
	var path := "user://cl_old_profile.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(
		JSON.stringify({"profile_version": 2, "settings": {}, "progress": {"fragments": 4}})
	)
	f.close()
	var old := ProfileStore.open(path)
	assert_eq(CollectibleBook.count(old), 0, "a version-2 profile has none found")
	assert_eq(MetaProgress.fragments(old), 4, "and keeps the rest")
	assert_eq(int(old.data["profile_version"]), 3)
	DirAccess.remove_absolute(path)


func test_the_hub_counts_them_for_the_runes_and_the_gate() -> void:
	var p := ProfileStore.new("")
	var hub: HubDefinition = _repo.get_def(&"hub", HubSession.HUB_ID)
	var flags := HubFlags.new(p, null, null)
	assert_false(flags.states(hub)[&"gate_open"], "sealed with none")
	for k in 11:
		CollectibleBook.record(p, _defs[k].id)
	var s := flags.states(hub)
	assert_eq((s[&"runes"] as Array).count(true), 11, "one rune lit per collectible")
	assert_false(s[&"gate_open"], "11: still sealed")
	CollectibleBook.record(p, _defs[11].id)
	assert_true(flags.states(hub)[&"gate_open"], "12: the north gate opens")
