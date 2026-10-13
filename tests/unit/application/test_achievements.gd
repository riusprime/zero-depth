extends GutTest
## v0.7.5 AC (owner N7): the local achievements. The profile's section (AchievementStore: unlocks, their order, the
## run counters; persistence, an old profile, a broken section), the book read from the content (AchievementBook:
## the per-boss and per-biome ones from the data, every condition kind), and the tracker that records the run
## counters from a world's ticks and unlocks what the profile meets (AchievementTracker), off in a tweaked run.

const PATH := "user://test_achievements_profile.json"


## A reader whose run state the test sets (the tracker reads only these calls); the events come from a real world.
class FakeReader:
	extends WorldReader
	var out := 0
	var floor_i := 1
	var arena := {"active": true, "sealed": -1, "cleared": PackedInt32Array()}
	var over := {"cleared": false}
	var steal := -1
	var cards := 0
	var weapon := &"gun"
	var curse_codes := PackedInt32Array()

	func outcome() -> int:
		return out

	func floor_index() -> int:
		return floor_i

	func arenas() -> Dictionary:
		return arena

	func overrun() -> Dictionary:
		return over

	func steal_tick() -> int:
		return steal

	func wand() -> Dictionary:
		var list := []
		for k in cards:
			list.append({"id": &"x"})
		return {"weapon": weapon, "cards": list}

	func card_info(code: int) -> Dictionary:
		if curse_codes.has(code):
			return {"type": WorldReader.CARD_CURSE, "id": &"curse"}
		return {"type": WorldReader.CARD_MOD, "id": &""}


func after_each() -> void:
	for p in [PATH, PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _parts() -> Dictionary:
	var profile := ProfileStore.new("")
	var codex := CodexStore.new(profile)
	var store := AchievementStore.new(profile)
	var repo := ContentRepository.load_all()
	var catalog := CodexCatalog.build(repo)
	var book := AchievementBook.build(repo, store, codex, catalog)
	var tracker := AchievementTracker.new(book)
	var got: Array[StringName] = []
	tracker.achieved.connect(func(a: Dictionary) -> void: got.append(a["id"]))
	return {
		"profile": profile,
		"codex": codex,
		"store": store,
		"book": book,
		"tracker": tracker,
		"repo": repo,
		"catalog": catalog,
		"got": got
	}


func _attached(p: Dictionary) -> Array:
	var w := CombatLab.world()
	var r := FakeReader.new(w)
	(p["tracker"] as AchievementTracker).attach(r)
	return [w, r]


func _tick(p: Dictionary, w: World, r: WorldReader) -> void:
	(p["tracker"] as AchievementTracker).observe(r)
	assert_not_null(w)


# --- The store ---------------------------------------------------------------------------------------------------


func test_the_store_unlocks_once_in_order_and_keeps_run_counters() -> void:
	var store := AchievementStore.new(ProfileStore.new(""))
	var seen: Array = []
	store.unlocked.connect(func(id: StringName) -> void: seen.append(id))
	assert_eq(store.version(), AchievementStore.VERSION)
	assert_eq(store.unlocked_count(), 0, "a fresh profile has none")
	assert_true(store.unlock(&"kills_1"))
	assert_false(store.unlock(&"kills_1"), "only once")
	assert_true(store.unlock(&"biome_ruins"))
	assert_eq(store.unlock_order(&"kills_1"), 1)
	assert_eq(store.unlock_order(&"biome_ruins"), 2, "the order they came")
	assert_eq(store.unlock_order(&"win_run"), 0)
	assert_eq(seen, [&"kills_1", &"biome_ruins"])
	assert_eq(store.add_stat(&"shards:spent", 30), 30)
	assert_eq(store.add_stat(&"shards:spent", 55), 85)
	assert_eq(store.raise_stat(&"wand:cards_max", 6), 6)
	assert_eq(store.raise_stat(&"wand:cards_max", 4), 6, "the most stays")
	assert_true(store.dirty)


func test_achievements_persist_in_the_profile_file() -> void:
	var p := ProfileStore.new(PATH)
	var store := AchievementStore.new(p)
	store.unlock(&"win_run")
	store.add_stat(&"runs:won", 2)
	assert_true(p.save_file())
	var again := AchievementStore.new(ProfileStore.open(PATH))
	assert_eq(again.version(), AchievementStore.VERSION, "saved with its version")
	assert_true(again.is_unlocked(&"win_run"))
	assert_eq(again.stat(&"runs:won"), 2)
	assert_eq(again.unlocked_ids(), [&"win_run"] as Array[StringName])


func test_an_old_profile_without_the_section_loads_empty() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(
		JSON.stringify(
			{
				"profile_version": 1,
				"settings": {"shake": "off"},
				"codex": {"version": 1, "enemies": {"charger": {"kills": 4}}}
			}
		)
	)
	f.close()
	var p := ProfileStore.open(PATH)
	var store := AchievementStore.new(p)
	assert_eq(store.version(), AchievementStore.VERSION)
	assert_eq(store.unlocked_count(), 0, "nothing unlocked")
	assert_eq(store.stat(&"runs:won"), 0)
	assert_eq(CodexStore.new(p).count(&"enemies", &"charger", &"kills"), 4, "the Codex loads")
	assert_true(store.unlock(&"kills_1"), "and it unlocks from there")


func test_a_broken_section_is_repaired_not_fatal() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"achievements": {"version": 1, "unlocked": 7, "stats": "x"}}))
	f.close()
	var store := AchievementStore.new(ProfileStore.open(PATH))
	assert_false(store.is_unlocked(&"kills_1"))
	assert_eq(store.stat(&"runs:won"), 0)
	assert_true(store.unlock(&"kills_1"))
	assert_eq(store.add_stat(&"runs:won"), 1)


# --- The book ------------------------------------------------------------------------------------------------------


func test_the_book_expands_one_per_boss_and_biome_from_the_data() -> void:
	var p := _parts()
	var book: AchievementBook = p["book"]
	var repo: ContentRepository = p["repo"]
	var bosses := 0
	var biomes := 0
	var ids := {}
	for a in book.all():
		assert_false(ids.has(a["id"]), "%s is unique" % a["id"])
		ids[a["id"]] = true
		if a["def_id"] == &"boss":
			bosses += 1
			assert_eq(
				a["arg_key"], (repo.get_def(&"bosses", a["entry_id"]) as BossDefinition).name_key
			)
		elif a["def_id"] == &"biome":
			biomes += 1
	assert_eq(bosses, repo.count(&"bosses"), "one per boss in the data")
	assert_eq(biomes, repo.count(&"biomes"), "one per biome, Frozen Shore included")
	assert_true(book.has(&"biome_frozen_shore"))
	assert_true(book.has(&"boss_warlord"))
	assert_eq(book.size(), repo.count(&"achievements") - 2 + bosses + biomes)
	assert_between(book.size(), 30, 45, "a starting set of about 30")
	assert_eq(book.groups()[0], &"run", "the page's groups in order")
	assert_eq(book.groups()[book.groups().size() - 1], &"ascension")


func test_each_condition_kind_reads_its_counters() -> void:
	var p := _parts()
	var book: AchievementBook = p["book"]
	var codex: CodexStore = p["codex"]
	var store: AchievementStore = p["store"]
	var catalog: CodexCatalog = p["catalog"]
	# STAT
	var won := book.get_entry(&"win_5")
	store.add_stat(&"runs:won", 4)
	assert_false(book.met(won))
	assert_eq(book.progress(won), 4)
	store.add_stat(&"runs:won")
	assert_true(book.met(won), "5 wins")
	# CODEX_TOTAL
	var k100 := book.get_entry(&"kills_100")
	codex.add(&"enemies", &"charger", &"kills", 60)
	codex.add(&"enemies", &"needle", &"kills", 39)
	assert_eq(book.progress(k100), 99, "kills summed over the enemies")
	codex.add(&"enemies", &"needle", &"kills")
	assert_true(book.met(k100))
	# CODEX_MAX
	var lv5 := book.get_entry(&"card_level_5")
	codex.raise_to(&"cards", &"gun_spread", &"level", 4)
	codex.raise_to(&"cards", &"heavy", &"level", 3)
	assert_eq(book.progress(lv5), 4, "the highest level of any card")
	codex.raise_to(&"cards", &"heavy", &"level", 5)
	assert_true(book.met(lv5))
	# CODEX_EACH
	var warlord := book.get_entry(&"boss_warlord")
	assert_false(book.met(warlord))
	codex.add(&"bosses", &"warlord", &"fights")
	assert_false(book.met(warlord), "fought is not beaten")
	codex.add(&"bosses", &"warlord", &"kills")
	assert_true(book.met(warlord))
	assert_false(book.met(book.get_entry(&"boss_foundry")))
	# CODEX_EVERY (a counter, and met-only over a section)
	var all_biomes := book.get_entry(&"biomes_all")
	assert_eq(book.goal(all_biomes), catalog.size(&"biomes"), "every biome of the data")
	for e: Dictionary in catalog.entries(&"biomes"):
		assert_false(book.met(all_biomes))
		codex.add(&"biomes", e["id"], &"visits")
	assert_true(book.met(all_biomes))
	var gun := book.get_entry(&"codex_gun")
	var pool := catalog.section_entries(&"cards", &"gun")
	assert_eq(book.goal(gun), pool.size(), "the Gun pool's cards")
	assert_eq(book.progress(gun), 1, "gun_spread was seen (its level above)")
	for e: Dictionary in pool:
		assert_false(book.met(gun))
		codex.unlock(&"cards", e["id"])
	assert_true(book.met(gun), "every Gun card seen")


# --- The tracker ---------------------------------------------------------------------------------------------------


func test_a_floor_cleared_and_a_won_run_unlock_with_the_weapon() -> void:
	var p := _parts()
	var wr := _attached(p)
	var r: FakeReader = wr[1]
	_tick(p, wr[0], r)
	assert_eq((p["got"] as Array).size(), 0, "nothing on a plain tick")
	r.out = 3
	_tick(p, wr[0], r)
	_tick(p, wr[0], r)
	assert_eq((p["store"] as AchievementStore).stat(&"floors:cleared_1"), 1, "once per floor")
	assert_true((p["got"] as Array).has(&"clear_floor_1"))
	var wr2 := _attached(p)
	var r2: FakeReader = wr2[1]
	r2.floor_i = 3
	r2.weapon = &"blade"
	r2.out = 1
	_tick(p, wr2[0], r2)
	var got: Array = p["got"]
	assert_true(got.has(&"win_run"), "the run won")
	assert_true(got.has(&"win_blade"), "with the Blade")
	assert_false(got.has(&"win_gun"))
	assert_false(got.has(&"clear_floor_2"), "floor 2 wasn't cleared in this test")


func test_a_child_spells_kill_counts_and_a_plain_kill_does_not() -> void:
	var p := _parts()
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var tracker: AchievementTracker = p["tracker"]
	tracker.attach(r)
	var a := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(6, 0))
	var b := w.add_enemy(ActorStore.Kind.CHARGER, Vector2(-6, 0))
	CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 2)
	tracker.observe(r)
	var me := w.actors.ids[0]
	var i := w.actors.index_of(a)
	Damage.hit(w, i, 100000, me, me, 0, 0, Vector2.ZERO, w.actors.pos(i))
	tracker.observe(r)
	var store: AchievementStore = p["store"]
	assert_eq(store.stat(&"kills:child_spell"), 0, "a root attack's kill is not a child spell's")
	var j := w.actors.index_of(b)
	Damage.hit(w, j, 100000, me, me, 0, 0, Vector2.ZERO, w.actors.pos(j), &"", 50)
	tracker.observe(r)
	assert_eq(store.stat(&"kills:child_spell"), 1, "a hook's hit (proc 50) killed it")
	assert_true((p["got"] as Array).has(&"trigger_kill"))


func test_a_sealed_room_cleared_without_a_hit_counts_clean() -> void:
	var p := _parts()
	var wr := _attached(p)
	var w: World = wr[0]
	var r: FakeReader = wr[1]
	var store: AchievementStore = p["store"]
	r.arena["sealed"] = 4
	_tick(p, w, r)
	r.arena["sealed"] = -1
	r.arena["cleared"] = PackedInt32Array([4])
	_tick(p, w, r)
	assert_eq(store.stat(&"rooms:sealed_cleared"), 1)
	assert_eq(store.stat(&"rooms:no_hit"), 1, "no HP lost in it")
	assert_true((p["got"] as Array).has(&"no_hit_room"))
	# The next sealed room: a hit that costs HP spoils it.
	r.arena["sealed"] = 7
	_tick(p, w, r)
	var e := w.emit_event(SimEvent.Kind.DAMAGE, 99, 99, w.actors.ids[0], Vector2.ZERO)
	e.amount_applied = 3
	_tick(p, w, r)
	r.arena["sealed"] = -1
	r.arena["cleared"] = PackedInt32Array([4, 7])
	_tick(p, w, r)
	assert_eq(store.stat(&"rooms:sealed_cleared"), 2)
	assert_eq(store.stat(&"rooms:no_hit"), 1, "the hurt room is not clean")


func test_overrun_core_curse_shards_and_a_full_wand() -> void:
	var p := _parts()
	var wr := _attached(p)
	var w: World = wr[0]
	var r: FakeReader = wr[1]
	var store: AchievementStore = p["store"]
	var me := w.actors.ids[0]
	r.over["cleared"] = true
	r.steal = 120
	r.curse_codes = PackedInt32Array([4321])
	var pick := w.emit_event(SimEvent.Kind.PICKUP, 1, me, me, Vector2.ZERO)
	pick.amount = 4321
	for price in [300, 250]:
		var buy := w.emit_event(SimEvent.Kind.SHOP_BUY, 2, me, me, Vector2.ZERO)
		buy.amount = price
	r.cards = 8
	_tick(p, w, r)
	_tick(p, w, r)
	assert_eq(store.stat(&"overruns:cleared"), 1, "the Overrun once")
	assert_eq(store.stat(&"cores:stolen"), 1, "a steal")
	assert_eq(store.stat(&"curses:chest_card"), 1, "a cursed card taken")
	assert_eq(store.stat(&"shards:spent"), 550)
	assert_eq(store.stat(&"wand:cards_max"), 8)
	var got: Array = p["got"]
	for id in [&"overrun_cleared", &"core_stolen", &"cursed_card", &"shards_500", &"wand_full"]:
		assert_true(got.has(id), "%s unlocked" % id)


func test_codex_counts_unlock_as_they_are_written_and_the_toast_signal_carries_it() -> void:
	var p := _parts()
	_attached(p)
	var codex: CodexStore = p["codex"]
	codex.add(&"biomes", &"frozen_shore", &"visits")
	codex.add(&"enemies", &"charger", &"kills")
	var got: Array = p["got"]
	assert_true(got.has(&"biome_frozen_shore"), "a biome's own, from its visit")
	assert_true(got.has(&"kills_1"), "First Blood from the Codex's kill")
	assert_false(got.has(&"biomes_all"))
	assert_eq(got.count(&"kills_1"), 1)
	codex.add(&"enemies", &"charger", &"kills")
	assert_eq(got.count(&"kills_1"), 1, "unlocks once")


func test_what_the_profile_already_meets_unlocks_when_a_floor_starts() -> void:
	var p := _parts()
	var codex: CodexStore = p["codex"]
	(p["tracker"] as AchievementTracker).enabled = false
	codex.add(&"enemies", &"charger", &"kills", 120)  # a Codex from before AC
	assert_eq((p["got"] as Array).size(), 0, "off: nothing")
	(p["tracker"] as AchievementTracker).enabled = true
	_attached(p)
	var got: Array = p["got"]
	assert_true(got.has(&"kills_1") and got.has(&"kills_100"), "unlocked at the floor's start")


func test_a_tweaked_run_unlocks_nothing_and_ascension_reports_through_the_hook() -> void:
	var p := _parts()
	var wr := _attached(p)
	var r: FakeReader = wr[1]
	var tracker: AchievementTracker = p["tracker"]
	var store: AchievementStore = p["store"]
	tracker.enabled = false
	r.out = 3
	r.steal = 50
	tracker.observe(r)
	tracker.report(&"runs:ascended")
	(p["codex"] as CodexStore).add(&"enemies", &"charger", &"kills")
	assert_eq(store.stat(&"floors:cleared_1"), 0, "a tweaked run records nothing")
	assert_eq(store.stat(&"runs:ascended"), 0)
	assert_eq(store.unlocked_count(), 0, "and unlocks nothing")
	tracker.enabled = true
	tracker.report(&"runs:ascended")
	assert_true(store.is_unlocked(&"ascend_1"), "the Ascension hook (AP reports runs:ascended)")
	assert_false(store.is_unlocked(&"ascend_5"))
	for k in 4:
		tracker.report(&"runs:ascended")
	assert_true(store.is_unlocked(&"ascend_5"))


func test_a_reader_from_another_floor_is_ignored() -> void:
	var p := _parts()
	_attached(p)
	var other := FakeReader.new(CombatLab.world())
	other.out = 3
	(p["tracker"] as AchievementTracker).observe(other)
	assert_eq((p["store"] as AchievementStore).stat(&"floors:cleared_1"), 0)
