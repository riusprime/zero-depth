extends GutTest
## v0.9.0 FV (owner Q24, "we are gonna be making the game 5 floors … we need to adjust difficulty scaling and loot to 5
## floors"; PD-03 changed): a run is five floors of about 10, 13, 15, 17 and 19 rooms plus the boss room; today's
## curve stretched so floor 5 ends where floor 3 ended; wand slots 4, 5, 6, 7, 8; all five biomes once each; altars and
## chests by the floor's rooms; floors 4 and 5 meet a boss the run has not met yet; the Ascension portal on floor 5.
## v0.11.1 Step 2: the generation and loot seed loops are in test_five_floors_soak.gd (not a seam; GitHub runs it).
## The v0.8.0 shape (three_floors) stays loadable for old saves (test_old_saves).

const FULL_SEEDS := 1000
const LONG := 1 << 24
const ROOMS_MIN := [9, 12, 14, 16, 18]
const ROOMS_MAX := [11, 14, 16, 18, 19]

var _seeds := Seeds.count(FULL_SEEDS)  # v0.11.1 Step 4: 200 here, 1,000 in the GitHub full suite
var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _table(id: StringName = RunSaver.RUN_ID) -> RunTable:
	return ContentCompiler.compile_run(_repo.get_def(&"run", id))


func test_the_run_is_five_floors_with_the_stretched_curve() -> void:
	var t := _table()
	assert_eq(t.id, &"five_floors")
	assert_eq(t.floors, 5)
	assert_eq(t.enemy_hp_floor_permille, PackedInt32Array([850, 1380, 1900, 2620, 3610]))
	assert_eq(t.enemy_damage_floor_permille, PackedInt32Array([850, 1180, 1400, 1660, 1960]))
	assert_eq(t.boss_hp_per_floor_permille, 200, "boss +20 % HP a floor: 1.8 on floor 5")
	assert_eq(t.boss_damage_per_floor_permille, 100, "boss +10 % damage a floor: 1.4 on 5")
	assert_eq(t.rooms_min_by_floor, PackedInt32Array(ROOMS_MIN))
	assert_eq(t.rooms_max_by_floor, PackedInt32Array(ROOMS_MAX))
	assert_eq(t.heal_permille, 600, "v0.9.0 SV: 60 % between floors (was 40 %)")
	assert_eq(t.shard_carry_permille, 500)
	assert_eq(t.final_arena, &"hollow_arena", "the final arena stays")
	var old := _table(RunSaver.LEGACY_RUN_ID)
	assert_eq(old.floors, 3, "the v0.8.0 shape stays loadable for old saves")
	assert_eq(old.enemy_hp_floor_permille, PackedInt32Array([1000, 1900, 3610]))
	assert_true(old.rooms_min_by_floor.is_empty(), "its floors keep data/map's 15-19 rooms")


## Floor 5 ends where floor 3 ended: an enemy of 1000 HP and 1000 damage on floors 2-5 (v0.9.5 EP3: floor 1 is
## x0.85); a boss +20 % HP and +10 % damage a floor, floor 1's boss eased to 800 per mille.
func test_enemies_and_bosses_scale_per_floor() -> void:
	var hp := [850, 1380, 1900, 2620, 3610]
	var dmg := [850, 1180, 1400, 1660, 1960]
	for f in range(1, 6):
		var r := RunState.start(3, _table())
		r.floor_index = f
		var e := EnemyTable.new()
		e.hp = 1000
		e.damage = 1000
		var list: Array[EnemyTable] = [e]
		r.scale_enemies(list)
		assert_eq(e.hp, hp[f - 1], "floor %d enemy HP" % f)
		assert_eq(e.damage, dmg[f - 1], "floor %d enemy damage" % f)
		var bosses := ContentCompiler.compile_bosses(_repo)
		var base := ContentCompiler.compile_bosses(_repo)
		r.scale_bosses(bosses)
		var ease := 800 if f == 1 else 1000
		var hp_pm := (1000 + 200 * (f - 1)) * ease / 1000
		var dmg_pm := (1000 + 100 * (f - 1)) * ease / 1000
		for k in bosses.size():
			if base[k].mimic:
				continue
			assert_eq(bosses[k].hp, maxi(1, base[k].hp * hp_pm / 1000), "floor %d boss HP" % f)
			if not base[k].attacks.is_empty():
				var want := base[k].attacks[0].damage * dmg_pm / 1000
				assert_eq(bosses[k].attacks[0].damage, want, "floor %d boss damage" % f)
	var last := RunState.start(3, _table())
	last.floor_index = 5
	var old := RunState.start(3, _table(RunSaver.LEGACY_RUN_ID))
	old.floor_index = 3
	var a := EnemyTable.new()
	a.hp = 1000
	var b := EnemyTable.new()
	b.hp = 1000
	var la: Array[EnemyTable] = [a]
	var lb: Array[EnemyTable] = [b]
	last.scale_enemies(la)
	old.scale_enemies(lb)
	assert_eq(a.hp, b.hp, "floor 5 now is floor 3 then")


func test_the_wand_grows_one_slot_a_floor() -> void:
	var w := WandCompiler.for_run(_repo, _table())
	for f in range(1, 6):
		assert_eq(w.slots_at(f), 3 + f, "floor %d: %d slots" % [f, 3 + f])
	assert_eq(w.slots_at(6), 8, "a loop's floors keep the last count")
	var old := WandCompiler.for_run(_repo, _table(RunSaver.LEGACY_RUN_ID))
	assert_eq([old.slots_at(1), old.slots_at(2), old.slots_at(3)], [4, 6, 8], "the 3-floor shape")


func test_every_run_visits_all_five_biomes_once() -> void:
	var seen_first := {}
	for s in 200:
		var r := RunState.start(1000 + s, _table())
		var order := {}
		for f in range(1, 6):
			order[r.biome_of(f)] = true
		assert_eq(order.size(), 5, "seed %d: five different biomes" % s)
		seen_first[r.biome_of(1)] = true
		r.loop = 2
		r._draw_loop_biomes()
		var loop := {}
		for f in range(6, 11):
			loop[r.biome_of(f)] = true
		assert_eq(loop.size(), 5, "seed %d: the next loop visits all five again" % s)
	assert_eq(seen_first.size(), 5, "any biome can come first (random order)")


## Floors 1-3 draw from their own pools as before; floors 4 and 5 (no pool yet) draw a boss not met on the run's
## floors before, so the five bosses of a run are all different.
func test_a_run_never_meets_a_boss_twice() -> void:
	var pools := RunContentCompiler.compile_boss_pools(_repo, 5)
	assert_eq(pools.size(), 5)
	# v0.9.0 NB: floors 4 and 5 have their own pools now (the Tidecaller and the Twin Wardens; the Clockwork Judge and
	# the Lantern Shade), so every floor draws from its own.
	assert_false(pools[3].is_empty() or pools[4].is_empty(), "floors 4 and 5 have their pools")
	var on_four := {}
	for s in 300:
		var r := RunState.start(50 + s, _table())
		var met := []
		for f in range(1, 6):
			var b := FloorShape.boss(r, pools, f)
			assert_gte(b, 0, "seed %d floor %d has a boss" % [s, f])
			assert_true(pools[f - 1].has(b), "floor %d: its own pool" % f)
			# v0.10.5 W3-O11: floor 2 draws as before unless floor 1 took the Brood Mother they share
			if f == 1 or f == 3 or (f == 2 and not pools[1].has(met[0])):
				assert_eq(b, r.pick_boss(pools[f - 1], f), "floor %d: the same draw as before" % f)
			assert_false(b in met, "seed %d floor %d: not met before" % [s, f])
			met.append(b)
		on_four[met[3]] = true
	assert_eq(on_four.size(), pools[3].size(), "floor 4 can meet any boss of its pool")


## A whole run in the sim, floor by floor as Main builds them (RunLab): floors 1 to 5 of their sizes, the Deep gate
## offered before the last floor, each boss beaten and its portal taken; floor 5 has the Ascension portal and the
## Loop device, and its portal leads to the final arena.
func test_a_run_goes_through_five_floors_to_the_ascension_portal() -> void:
	var lab := RunLab.new(_repo, 4242, &"blade")
	for f in range(1, 6):
		assert_eq(lab.run.floor_index, f)
		var w := lab.floor_world()
		w.actors.invuln[0] = LONG
		var layout := w.floor_layout
		assert_between(
			layout.room_count() - 1, ROOMS_MIN[f - 1], ROOMS_MAX[f - 1], "floor %d rooms" % f
		)
		assert_eq(w.floor_count, 5)
		assert_eq(w.boss_flow.ascension, f == 5, "floor %d: the Ascension portal only on 5" % f)
		assert_eq(layout.has_loop_device, f == 5, "floor %d: the Loop device only on 5" % f)
		assert_eq(layout.has_deep_portal, f < 5, "floor %d: the Deep gate before the last" % f)
		_beat_boss_and_take_portal(w)
		var reader := WorldReader.new(w)
		assert_eq(reader.outcome(), 3, "floor %d: the portal ends the floor" % f)
		if f == 5:
			assert_eq(reader.ascension_choice(), WorldReader.ASCEND_PORTAL)
		lab.next_floor(w)
	assert_true(lab.run.final_fight, "floor 5's portal leads to the final boss")
	assert_eq(lab.run.loop, 1)
	assert_eq(lab.run.floor_index, 5)
	assert_eq(lab.run.routes.size(), 5, "a route for each of the five floors")


## Seals the boss room, kills the boss, then walks into the (normal or Ascension) portal until the floor ends.
func _beat_boss_and_take_portal(w: World) -> void:
	var f := w.floor_layout
	w.actors.set_pos(0, f.boss_door_inside(1.5))
	CombatLab.idle(w, 4)
	assert_eq(w.boss_flow.state, BossFlow.State.FIGHT, "the boss room sealed")
	var bi := w.actors.index_of(w.boss_id)
	w.actors.invuln[bi] = 0
	Damage.hit(w, bi, 99999999, 0, 0, 1, 0, w.actors.pos(bi), w.actors.pos(bi))
	CombatLab.idle(w, 1)
	assert_eq(w.boss_flow.state, BossFlow.State.OPEN, "the portal opened")
	w.actors.set_pos(0, f.portal_front_point())
	CombatLab.until(
		w,
		func(x: World) -> bool:
			var frame := InputFrame.new()
			var d := (f.portal_pos - x.player_pos()).normalized()
			frame.move = Vector2i(roundi(d.x * SimTick.MOVE_MAX), roundi(d.y * SimTick.MOVE_MAX))
			x.step(frame)
			return x.boss_flow.state == BossFlow.State.ENTERING,
		240
	)
	CombatLab.idle(w, BossFlow.ENTER_TICKS + 2)


## v0.11.0 O13a (PLAN M3; owner Q23): the kinds floor f of `biome` can ever open: SpawnDirector.unlocked over the
## floor's curve (every phase and the overtime), on a world holding the biome's roster as FloorPlan gives it.
func _open_kinds(biome: BiomeDefinition, f: int, tables: Array[EnemyTable]) -> Dictionary:
	var w := World.new(1, PlayerTable.starting_values())
	w.set_enemy_tables(tables)
	w.floor_index = f
	w.spawner = ContentCompiler.compile_floor_spawning(_repo, f)
	w.roster_kinds = VariantCompiler.roster_kinds(_repo, biome)
	var out := {}
	for ticks in range(0, 60 * 600, 120):
		for k in SpawnDirector.unlocked(w, w.spawner, ticks):
			out[w.spawner.kinds[k]] = true
	return out


## Over 1,000 runs (the biome order shuffled per run): every floor spawns only its biome's roster (the shared core,
## its variant, the floor-unlocked kinds; its critter comes in the surges), no variant outside its biome, each variant
## on its own biome's floors once its base is open there, and the same seed gives the same rosters.
func test_every_floor_spawns_only_its_biomes_roster_over_a_thousand_seeds() -> void:
	var tables := ContentCompiler.compile_enemies(_repo)
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	var variant_of := {}  # biome id -> its variant's kind
	var variants := {}
	var roster := {}  # v0.11.0 O13b: biome id -> its own kinds (its variant and its built signatures)
	var signature_of := {}  # a signature's kind -> its biome id
	for id in run_def.biomes:
		var b: BiomeDefinition = _repo.get_def(&"biomes", id)
		var k := ContentCompiler.compile_enemy(_repo.get_def(&"enemies", b.variant_id)).kind
		variant_of[id] = k
		variants[k] = id
		roster[id] = VariantCompiler.roster_kinds(_repo, b)
		for kind: int in roster[id]:
			if kind != k:
				signature_of[kind] = id
	var shared := {}  # the kinds any biome may spawn: every mix row that is no biome's own
	var spawn := ContentCompiler.compile_floor_spawning(_repo, 1)
	for k in spawn.kinds.size():
		if spawn.biome_only[k] == 0:
			shared[spawn.kinds[k]] = true
	var open := {}  # "biome/floor" -> the kinds it can open (the same for every run)
	for id in run_def.biomes:
		for f in range(1, 6):
			open["%s/%d" % [id, f]] = _open_kinds(_repo.get_def(&"biomes", id), f, tables)
	var variant_floors := {}
	var signature_floors := {}
	for s in _seeds:
		var r := RunState.start(1000 + s * 7919, _table())
		var again := RunState.start(1000 + s * 7919, _table())
		assert_eq(r.biome_order, again.biome_order, "seed %d: the same order" % s)
		for f in range(1, 6):
			var id: StringName = run_def.biomes[r.biome_of(f)]
			var kinds: Dictionary = open["%s/%d" % [id, f]]
			for kind: int in kinds:
				var own: bool = (roster[id] as PackedInt32Array).has(kind)
				if not own and not shared.has(kind):
					fail_test(
						"seed %d floor %d (%s): kind %d is not its roster's" % [s, f, id, kind]
					)
					return
			for k: int in variants:
				if variants[k] != id and kinds.has(k):
					fail_test("seed %d floor %d (%s): %s's variant" % [s, f, id, variants[k]])
					return
			for k: int in signature_of:
				if signature_of[k] != id and kinds.has(k):
					fail_test("seed %d floor %d (%s): %s's signature" % [s, f, id, signature_of[k]])
					return
				if signature_of[k] == id and kinds.has(k):
					signature_floors[k] = int(signature_floors.get(k, 0)) + 1
			if kinds.has(variant_of[id]):
				variant_floors[id] = int(variant_floors.get(id, 0)) + 1
	for id in run_def.biomes:
		assert_gt(int(variant_floors.get(id, 0)), 0, "%s's variant spawns on its floors" % id)
	for k: int in signature_of:  # v0.11.0 O13b: every built signature appears on its own biome's floors
		assert_gt(int(signature_floors.get(k, 0)), 0, "signature kind %d spawns on its floors" % k)
	gut.p("variant floors over %d runs: %s" % [_seeds, variant_floors])
	gut.p("signature floors over %d runs: %s" % [_seeds, signature_floors])


## The roster reaches the real floor: FloorPlan gives each floor its biome's own kinds, and on a floor where a biome's
## variant is open, actually stepped spawns (packs every interval, each killed at once) are only its roster's.
func test_a_built_floor_spawns_its_biomes_roster() -> void:
	var run_def: RunDefinition = _repo.get_def(&"run", RunSaver.RUN_ID)
	for s in 5:
		var plan := FloorPlan.new_run(RunSaver.RUN_ID, 300 + s, &"blade", true)
		plan.repo = _repo
		plan.build()
		var b: BiomeDefinition = plan.biome
		assert_eq(
			plan.world.roster_kinds,
			VariantCompiler.roster_kinds(_repo, b),
			"seed %d: %s" % [s, b.id]
		)
	var tables := ContentCompiler.compile_enemies(_repo)
	for id in run_def.biomes:
		var b: BiomeDefinition = _repo.get_def(&"biomes", id)
		var w := World.new(77, PlayerTable.starting_values())
		w.set_enemy_tables(tables)
		w.floor_index = 4
		w.spawner = ContentCompiler.compile_floor_spawning(_repo, 4)
		w.spawner.intensity = null  # (packs every interval: the mix, not the rhythm, is under test)
		w.roster_kinds = VariantCompiler.roster_kinds(_repo, b)
		for r in [9.0, 12.0]:
			for k in 8:
				w.spawn_points.append(Kin.dir(k * 512) * r)
		w.actors.invuln[0] = LONG
		var allowed := _open_kinds(b, 4, tables)
		if allowed.has(ActorStore.Kind.SPLITTER):  # a Splitter splits into Splitlings (they come of it, not of the mix)
			allowed[ActorStore.Kind.SPLITLING] = true
		if allowed.has(ActorStore.Kind.WIRE_WEAVER):  # v0.11.0 O13b: a Weaver plants its posts
			allowed[ActorStore.Kind.WIRE_POST] = true
		var seen := {}
		for t in 60 * 240:
			w.step(InputFrame.new())
			for i in range(1, w.actors.size()):
				seen[w.actors.kinds[i]] = true
				w.actors.invuln[i] = 0
				Damage.hit(w, i, 99999, 1, 1, 1, 0, w.actors.pos(i), w.actors.pos(i))
		for kind: int in seen:
			assert_true(allowed.has(kind), "%s floor 4: kind %d is its roster's" % [id, kind])
		var v := ContentCompiler.compile_enemy(_repo.get_def(&"enemies", b.variant_id)).kind
		assert_true(seen.has(v), "%s floor 4: its variant spawns" % id)
		gut.p("%s floor 4: %d kinds spawned" % [id, seen.size()])
