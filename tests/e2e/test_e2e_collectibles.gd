extends GutTest
## v0.9.0 CL (owner: "collectibles are fine", COLLECTIBLES.md as drafted) through main.tscn with real input only:
## 1. Run seed 5's floor-2 save (a Blood Shrine) is continued from the menu (Enter); God from the dev panel (clicked);
##    the stick walks up to the shrine, E pays its price, the Blood Coin shows beside it (drawn), the stick walks onto
##    it: the profile has it at once, a toast says "Added to the Rune Archive", the run's fragments rise by one. The
##    pause menu goes to the hub: its first floor rune is lit and the Blood Coin's niche on the Archive's shelf glows;
##    E at the Rune Archive opens the Codex on its Collectibles page, the Blood Coin found (name and lore when the
##    arrows reach it), the rest "?".
## 2. A profile with 12 found: Play; the hub's north gate is open and the Keystone waits on the alcove's pedestal; the
##    stick walks through the gate to it: taken (the profile, its fragment), its rune lit, the hub's line says so.

const BLOOD_SEED := 5
const FLOOR := 2


func after_each() -> void:
	E2e.center_sticks()
	TranslationServer.set_locale("en")


func _click(e: E2e, main: Main, button: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _front(w: World, at: Vector2) -> Vector2:
	var f := w.floor_layout
	return Gamble.front(at, f.door_approaches(f.room_of(at), 1.0)[0])


func test_a_find_in_a_run_is_kept_and_the_hub_shows_it() -> void:
	var run := SaveLab.run_state(BLOOD_SEED, FLOOR, &"blade")
	var saved := SaveLab.build_floor(run)
	var store := RunSaveStore.new("")
	assert_true(store.write(RunSaver.payload_of(saved, run, BLOOD_SEED, PackedByteArray())))
	var profile := ProfileStore.new("")
	var e := E2e.new(self)
	var main: Main = await e.boot(profile, store, BLOOD_SEED)
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	await main.loads.finished
	await e.landed()
	assert_eq(main.run.floor_index, FLOOR, "floor 2 continues")
	await e.tap(KEY_QUOTELEFT)
	await _click(e, main, "God")
	await e.tap(KEY_QUOTELEFT)
	var w := e.world()
	assert_true(w.shrine != null and w.shrine.kind == ShrineTable.Kind.BLOOD, "a Blood Shrine")
	assert_true(main.driver.reader.has_collectibles(), "the floor holds collectibles")
	if w.shrine == null or w.collect == null:
		return
	var k := w.collect.ids.find("blood_coin")
	assert_gte(k, 0, "the Blood Coin is armed")
	if k < 0:
		return
	assert_true(await e.walk_to(_front(w, w.shrine.pos), 0.5), "walked up to the Blood Shrine")
	E2e.center_sticks()
	await e.frames(3)
	await e.tap(KEY_E)
	await e.frames(3)
	assert_gt(w.shrine.paid, 0, "E took the deal")
	assert_gte(w.collect.shown_tick[k], 0, "the Blood Coin shows")
	var gem := (
		main.view.collectibles.gem_of(&"blood_coin") if main.view.collectibles != null else null
	)
	assert_not_null(gem, "drawn where it lies")
	if gem != null:
		assert_true(gem.position.distance_to(SimPlane.to_3d(w.collect.pos[k])) < 1.0, "at its spot")
	var fragments := main.run.fragments_done
	assert_true(await e.walk_to(w.collect.pos[k], 0.4), "walked onto it")
	await e.frames(3)
	assert_gte(w.collect.taken_tick[k], 0, "taken")
	assert_true(CollectibleBook.found(profile, &"blood_coin"), "in the profile at once")
	assert_eq(int(profile.section("collectibles")["blood_coin"]), main.run.run_seed, "with its run")
	assert_true(main.run.collected_run.has(&"blood_coin"), "the run knows it")
	assert_eq(
		main.run.fragments_done, fragments + main.run.fragment_table.collectible, "its fragment"
	)
	var toast := main.toast
	assert_true(
		toast.current_id() == &"blood_coin" or toast.queued_ids().has(&"blood_coin"),
		"a toast: added to the Rune Archive"
	)
	if toast.current_id() == &"blood_coin":
		assert_eq(toast.header.text, tr("COLLECTIBLE_TOAST"))
	var walk := HubWalk.new(e)
	assert_true(await walk.from_run(), "the pause menu goes to the hub")
	var hub := main.hub
	if hub == null:
		return
	assert_true(hub.view.rune_lit(0), "one floor rune lit")
	assert_false(hub.view.rune_lit(1), "one only")
	var slot := (
		hub
		. collectibles
		. map(func(d: CollectibleDefinition) -> StringName: return d.id)
		. find(&"blood_coin")
	)
	var slots: Array = hub.view.stations[&"archive"]["slots"]
	assert_true(bool((slots[slot] as Node).get_meta(&"lit", false)), "its niche glows")
	assert_false(bool((slots[0] as Node).get_meta(&"lit", false)), "the Cold Lantern's doesn't")
	await walk.use(&"archive")
	var codex := main.get_node_or_null("UI/CodexView") as CodexView
	assert_not_null(codex, "the Rune Archive opens the Codex")
	if codex == null:
		return
	assert_eq(codex.page, CodexView.COLLECTIBLES, "on its Collectibles")
	var page := codex.archive_page
	assert_true(page.visible, "the shelves show")
	assert_true(page.tile(&"blood_coin").found, "the Blood Coin found")
	assert_false(page.tile(&"cold_lantern").found, "the Cold Lantern not")
	assert_eq(page.name_label.text, "?", "the first niche: a ? only")
	assert_eq(page.shelf_label.text, tr("COLLECTIBLE_SHELF_STONE"), "and its shelf's name")
	assert_eq(page.lore_label.text, "", "no hint")
	await e.tap(KEY_DOWN)  # the Sealed shelf, its first
	for i in 4:
		await e.tap(KEY_RIGHT)
	await e.frames(2)
	assert_eq(page.shown().def.id, &"blood_coin", "the arrows reach it")
	assert_eq(page.name_label.text, tr("COLLECTIBLE_BLOOD_COIN"), "its name")
	assert_eq(page.lore_label.text, tr("COLLECTIBLE_BLOOD_COIN_LORE"), "its lore")
	assert_eq(codex.progress.text, tr("UI_CODEX_FOUND") % [1, 16], "1 of 16")
	gut.p("CL_E2E| blood coin seed=%d fragments_before=%d" % [BLOOD_SEED, fragments])
	assert_eq(get_errors().size(), 0, "no engine or script error")


func test_twelve_open_the_gate_and_the_keystone_waits() -> void:
	var repo := ContentRepository.load_all()
	var defs := CollectibleBook.defs(repo)
	var profile := ProfileStore.new("")
	for k in 12:
		CollectibleBook.record(profile, defs[k].id, 1)
	var before := MetaProgress.fragments(profile)
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var walk := HubWalk.new(e)
	assert_true(await walk.enter(), "Play: the hub")
	var hub := main.hub
	if hub == null:
		return
	assert_true(hub.layout.gate_open, "12 found: the gate's slab is gone")
	assert_true(hub.view.gate_open(), "the north gate is drawn open")
	assert_true(hub.view.rune_lit(11) and not hub.view.rune_lit(12), "12 runes lit")
	assert_true(hub.view.keystone_shown(), "the Keystone waits on the pedestal")
	var a := hub.hub.alcove_at
	var r := hub.hub.radius_m
	var path: Array[Vector2] = [
		Vector2(-6, -6), Vector2(-6, 6), Vector2(-1.2, r - 3.5), Vector2(0, r - 1.0), a
	]
	await walk.walk_through(path, 0.9)
	await e.frames(3)
	assert_true(CollectibleBook.found(profile, &"keystone"), "walking up to it takes it")
	assert_false(hub.view.keystone_shown(), "gone from the pedestal")
	assert_true(hub.view.rune_lit(12), "its rune lit: 13")
	var rules := MetaProgress.definition(repo)
	assert_eq(MetaProgress.fragments(profile), before + rules.collectible, "its fragment banked")
	assert_eq(hub.hud.station_name(), tr("COLLECTIBLE_KEYSTONE"), "the hub's line names it")
	assert_eq(hub.hud.prompt_text(), tr("COLLECTIBLE_TOAST"), "added to the Rune Archive")
	gut.p("CL_E2E| keystone fragments %d -> %d" % [before, MetaProgress.fragments(profile)])
	assert_eq(get_errors().size(), 0, "no engine or script error")
