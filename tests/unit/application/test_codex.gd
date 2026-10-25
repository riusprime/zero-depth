extends GutTest
## v0.7.5 CX (owner N6): the Codex's counters in the profile (CodexStore), its persistence and old profiles, the
## catalog read from the content (CodexCatalog), and the recorder that turns a world's ticks into unlocks and counts
## (CodexRecorder).

const PATH := "user://test_codex_profile.json"


func after_each() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _catalog() -> CodexCatalog:
	return CodexCatalog.build(ContentRepository.load_all())


# --- The store ---------------------------------------------------------------------------------------------------


func test_a_fresh_profile_has_an_empty_codex_with_its_version() -> void:
	var store := CodexStore.new(ProfileStore.new(""))
	assert_eq(store.version(), CodexStore.VERSION)
	for page in CodexStore.PAGES:
		assert_eq(store.unlocked_count(page), 0, "%s starts empty" % page)
	assert_false(store.is_unlocked(&"enemies", &"charger"))
	assert_eq(store.count(&"enemies", &"charger", &"kills"), 0)


func test_counters_unlock_add_and_keep_the_highest_level() -> void:
	var store := CodexStore.new(ProfileStore.new(""))
	var unlocked: Array = []
	var changes: Array = []
	store.unlocked.connect(func(p: StringName, id: StringName) -> void: unlocked.append([p, id]))
	store.changed.connect(
		func(p: StringName, id: StringName, c: StringName, v: int) -> void:
			changes.append([p, id, c, v])
	)
	assert_true(store.unlock(&"enemies", &"charger"), "a first meeting unlocks")
	assert_false(store.unlock(&"enemies", &"charger"), "only once")
	assert_eq(store.add(&"enemies", &"charger", &"kills"), 1)
	assert_eq(store.add(&"enemies", &"charger", &"kills", 2), 3)
	assert_eq(store.add(&"enemies", &"needle", &"kills"), 1, "a count unlocks too")
	assert_true(store.is_unlocked(&"enemies", &"needle"))
	assert_eq(store.raise_to(&"cards", &"gun_twin", &"level", 3), 3)
	assert_eq(store.raise_to(&"cards", &"gun_twin", &"level", 2), 3, "the highest level stays")
	assert_eq(store.count(&"cards", &"gun_twin", &"level"), 3)
	assert_eq(store.total(&"enemies", &"kills"), 4, "a page's total")
	assert_eq(store.unlocked_ids(&"enemies"), [&"charger", &"needle"] as Array[StringName])
	assert_eq(
		unlocked,
		[[&"enemies", &"charger"], [&"enemies", &"needle"], [&"cards", &"gun_twin"]],
		"one unlocked signal per first meeting"
	)
	assert_eq(changes.size(), 4, "a changed signal per counter write that changed it")
	assert_true(store.dirty)


func test_the_codex_persists_in_the_profile_file() -> void:
	var p := ProfileStore.new(PATH)
	var store := CodexStore.new(p)
	store.add(&"bosses", &"warlord", &"kills")
	store.add(&"biomes", &"ruins", &"visits", 2)
	store.raise_to(&"cards", &"heavy", &"level", 4)
	assert_true(p.save_file())
	var again := CodexStore.new(ProfileStore.open(PATH))
	assert_eq(again.version(), CodexStore.VERSION, "saved with its version")
	assert_eq(again.count(&"bosses", &"warlord", &"kills"), 1)
	assert_eq(again.count(&"biomes", &"ruins", &"visits"), 2)
	assert_eq(again.count(&"cards", &"heavy", &"level"), 4)
	assert_true(again.is_unlocked(&"bosses", &"warlord"))


func test_an_old_profile_without_the_section_loads_an_empty_codex() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"profile_version": 1, "settings": {"shake": "off"}}))
	f.close()
	var p := ProfileStore.open(PATH)
	assert_eq(p.section("settings").get("shake"), "off", "the old settings load")
	var store := CodexStore.new(p)
	assert_eq(store.version(), CodexStore.VERSION)
	for page in CodexStore.PAGES:
		assert_eq(store.unlocked_count(page), 0, "%s is empty" % page)
	store.add(&"enemies", &"charger", &"kills")
	assert_eq(store.count(&"enemies", &"charger", &"kills"), 1, "and it records from there")


func test_a_broken_codex_section_is_repaired_not_fatal() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"codex": {"version": 1, "cards": 5, "enemies": {"charger": 3}}}))
	f.close()
	var store := CodexStore.new(ProfileStore.open(PATH))
	assert_false(store.is_unlocked(&"cards", &"heavy"))
	assert_eq(store.count(&"enemies", &"charger", &"kills"), 0, "a bad entry reads as zero")
	assert_eq(store.add(&"cards", &"heavy", &"taken"), 1)
	assert_eq(store.add(&"enemies", &"charger", &"kills"), 1)


# --- The catalog -------------------------------------------------------------------------------------------------


func test_the_catalog_lists_the_content_by_pool_without_retired_cards() -> void:
	var repo := ContentRepository.load_all()
	var c := CodexCatalog.build(repo)
	var retired := CodexCatalog.retired_ids(repo)
	assert_gt(retired.size(), 0, "the migration table retires v0.6 cards")
	for e: Dictionary in c.entries(&"cards"):
		assert_false(retired.has(e["id"]), "%s is retired and not listed" % e["id"])
	var want := {
		&"gun_twin": &"gun",
		&"halo_shot": &"gun",
		&"heavy": &"blade",
		&"wide_arc": &"blade",
		&"ember_core": &"shared",
		&"shared_bleed": &"shared",
		&"trigger_on_hit": &"triggers",
		&"trigger_on_finisher": &"triggers",
		&"trigger_on_hit_twice": &"legendary",
		&"damage": &"stats",
		&"glass_cannon": &"stats",
		&"blink": &"utilities",
		&"aegis": &"utilities",
		&"momentum": &"passives",
	}
	for id: StringName in want:
		assert_true(c.has(&"cards", id), "%s listed" % id)
		assert_eq(c.entry(&"cards", id)["section"], want[id], "%s in %s" % [id, want[id]])
	for id: StringName in [
		&"pulse_gun", &"combo_sword", &"long_edge", &"bomb_lobber", &"twin_cast"
	]:
		assert_false(c.has(&"cards", id), "%s is not a Codex card" % id)
	assert_eq(c.entry(&"cards", &"trigger_on_finisher")["alt_name_key"], &"ITEM_TRIGGER_ON_CRIT")
	assert_true(c.entry(&"cards", &"gun_twin")["leveled"], "a wand card levels")
	assert_false(c.entry(&"cards", &"damage")["leveled"], "a stat card doesn't")
	assert_eq(
		c.sections(&"cards"),
		(
			[
				&"gun",
				&"blade",
				&"shared",
				&"triggers",
				&"legendary",
				&"stats",
				&"utilities",
				&"passives"
			]
			as Array[StringName]
		),
		"the pools in order (no other abilities today)"
	)


func test_enemies_bosses_and_biomes_come_from_the_data() -> void:
	var repo := ContentRepository.load_all()
	var c := CodexCatalog.build(repo)
	assert_eq(c.size(&"enemies"), repo.count(&"enemies"))
	assert_eq(
		c.size(&"bosses"),
		repo.count(&"bosses") + repo.count(&"final_bosses"),
		"v0.8.0 FB1: the floors' bosses and the final boss's bodies"
	)
	assert_eq(
		c.size(&"biomes"), repo.count(&"biomes"), "every biome of the data, new ones included"
	)
	assert_eq(c.enemy_of_kind(ActorStore.Kind.CHARGER), &"charger")
	assert_eq(c.enemy_of_kind(ActorStore.Kind.LENS_DRONE), &"lens_drone")
	assert_eq(c.boss_of_kind(ActorStore.Kind.WARLORD), &"warlord")
	assert_eq(c.enemy_of_kind(ActorStore.Kind.WARLORD), &"", "a boss is not an enemy entry")
	for e: Dictionary in c.entries(&"biomes"):
		assert_eq((e["palette"] as Array).size(), BiomeDefinition.PALETTE_KEYS.size())


# --- The recorder ------------------------------------------------------------------------------------------------


func _rec(w: World) -> Array:
	var store := CodexStore.new(ProfileStore.new(""))
	var rec := CodexRecorder.new(store, _catalog())
	var r := WorldReader.new(w)
	rec.attach(r)
	return [store, rec, r]


func _idle(w: World, rec: CodexRecorder, r: WorldReader, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())
		rec.observe(r)


func test_an_enemy_unlocks_when_met_and_counts_its_kill() -> void:
	var w := CombatLab.world()
	var parts := _rec(w)
	var store: CodexStore = parts[0]
	var rec: CodexRecorder = parts[1]
	var r: WorldReader = parts[2]
	var far := w.add_enemy(ActorStore.Kind.NEEDLE, Vector2(CodexRecorder.SEEN_M + 6.0, 0))
	var near := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(6, 0))
	_idle(w, rec, r, SimTick.SPAWN_IN_TICKS + 2)
	assert_true(store.is_unlocked(&"enemies", &"charger"), "met: it stood near")
	assert_false(store.is_unlocked(&"enemies", &"needle"), "too far to count as met")
	var i := w.actors.index_of(near)
	Damage.hit(w, i, 100000, w.actors.ids[0], w.actors.ids[0], 0, 0, Vector2.ZERO, w.actors.pos(i))
	_idle(w, rec, r, 2)
	assert_eq(store.count(&"enemies", &"charger", &"kills"), 1, "its KILL counted")
	assert_eq(store.count(&"enemies", &"needle", &"kills"), 0)
	assert_ne(far, near)


func test_dying_to_an_enemy_counts_against_it() -> void:
	var w := CombatLab.world()
	var parts := _rec(w)
	var store: CodexStore = parts[0]
	var rec: CodexRecorder = parts[1]
	var r: WorldReader = parts[2]
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 0))
	w.actors.hp[0] = 1
	for k in 900:
		w.step(InputFrame.new())
		rec.observe(r)
		if w.player_dead():
			break
	_idle(w, rec, r, 2)
	assert_true(w.player_dead(), "the Charger killed the idle player")
	assert_eq(
		store.count(&"enemies", &"charger", &"deaths"), 1, "once, however long the dead world ticks"
	)


func test_a_taken_card_counts_and_keeps_its_level() -> void:
	var lab := RunLab.new(ContentRepository.load_all(), 7, &"gun")
	var w := lab.floor_world()
	var parts := _rec(w)
	var store: CodexStore = parts[0]
	var rec: CodexRecorder = parts[1]
	var r: WorldReader = parts[2]
	var idx := -1
	for k in w.item_tables.size():
		if w.item_tables[k].id == &"gun_twin":
			idx = k
	assert_gt(idx, -1)
	for n in 2:  # a pick's PICKUP, then the card goes in (as Rewards.choose does)
		var e := w.emit_event(
			SimEvent.Kind.PICKUP, 0, w.actors.ids[0], w.actors.ids[0], Vector2.ZERO
		)
		e.amount = idx
		Offers.apply(w, idx)
		rec.observe(r)
	assert_eq(store.count(&"cards", &"gun_twin", &"taken"), 2)
	assert_eq(store.count(&"cards", &"gun_twin", &"level"), 2, "taken twice: level 2 in the wand")
	assert_false(
		store.is_unlocked(&"cards", &"pulse_gun"), "the starting weapon is not a Codex card"
	)


func test_biome_visits_and_a_tweaked_run_records_nothing() -> void:
	var w := CombatLab.world()
	var parts := _rec(w)
	var store: CodexStore = parts[0]
	var rec: CodexRecorder = parts[1]
	var r: WorldReader = parts[2]
	rec.enter_biome(&"ruins")
	rec.enter_biome(&"no_such_biome")
	assert_eq(store.count(&"biomes", &"ruins", &"visits"), 1)
	assert_false(store.is_unlocked(&"biomes", &"no_such_biome"))
	rec.enabled = false
	rec.enter_biome(&"ruins")
	w.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 0))
	_idle(w, rec, r, SimTick.SPAWN_IN_TICKS + 2)
	assert_eq(store.count(&"biomes", &"ruins", &"visits"), 1, "a tweaked run's floor doesn't count")
	assert_false(store.is_unlocked(&"enemies", &"charger"), "nor its enemies")


func test_a_reader_from_another_floor_is_ignored() -> void:
	var w := CombatLab.world()
	var parts := _rec(w)
	var store: CodexStore = parts[0]
	var rec: CodexRecorder = parts[1]
	var other := CombatLab.world()
	other.add_enemy(ActorStore.Kind.CHARGER, Vector2(5, 0))
	var r2 := WorldReader.new(other)
	for k in SimTick.SPAWN_IN_TICKS + 2:
		other.step(InputFrame.new())
		rec.observe(r2)
	assert_false(store.is_unlocked(&"enemies", &"charger"))
