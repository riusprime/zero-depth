extends GutTest
## v0.6.5 WN5b (docs/design/WAND.md "Old saves load: each held card maps to its new card, in pick order. A card
## without a match is refunded as shards") through main.tscn with real input only: a run save recorded with v0.6.1's
## code (tests/fixtures/saves/v061_blade_floor1.save: Long Edge, Orbit Blades level 2, Ember Core, Twin Cast, Drone
## Buddy, Echo Storm) is in the save store; the menu offers Continue, Enter resumes it, and the wand holds the new
## cards in pick order (Ember Core stays: WN5a kept it as S1 Fire) with the Drone refunded as shards.

const SAVE := "res://tests/fixtures/saves/v061_blade_floor1.save"


func after_each() -> void:
	Input.action_release(&"ui_accept")


func test_continue_a_v0_6_1_save_and_its_old_cards_are_wand_cards() -> void:
	var r := RunSaveStore.decode(FileAccess.get_file_as_bytes(SAVE))
	assert_eq(r[1], "", "the recorded save decodes")
	var payload: Dictionary = (r[0] as Dictionary)["payload"]
	assert_eq(int(payload["version"]), 3, "a v0.6.1 payload")
	var saved_shards := int(payload["world"]["world"]["shards"])
	var store := RunSaveStore.new("")
	assert_true(store.write(payload))
	var e := E2e.new(self)
	var main: Main = await e.boot(null, store)
	var menu := main.get_node_or_null("UI/MainMenu")
	assert_not_null(menu)
	var focus := main.get_viewport().gui_get_focus_owner()
	assert_eq(focus.name if focus != null else &"", &"Continue", "Continue, focused first")
	e.key(KEY_ENTER, true)
	e.key(KEY_ENTER, false)
	# v0.8.0 N12 (O70): the load runs over frames behind the cover (the World on a worker); CoverLoads.finished
	# comes in the frame the floor goes live, before its first tick.
	await main.loads.finished
	assert_true(main.is_playing(), "the old save is not set aside: it continues")
	var w := e.world()
	var ids := []
	var levels := []
	for c: Dictionary in main.driver.reader.wand()["cards"]:
		ids.append(c["id"])
		levels.append(int(c["level"]))
	assert_eq(
		ids,
		[&"wide_arc", &"blade_orbit", &"ember_core", &"double_slash", &"echo_slash"],
		"in pick order"
	)
	assert_eq(
		levels, [1, 2, 1, 1, 5], "Orbit Blades' level 2 carries; Echo Storm is Wave at level 5"
	)
	var refund := w.shop_table.ability_refund_per_level * 1  # the Drone (no row); Ember Core is S1
	assert_eq(w.shards, saved_shards + refund, "the Drone refunded at the salvage price")
	var t0 := w.tick
	await e.frames(10)
	assert_gt(w.tick, t0, "and the run goes on")
	assert_false(main.saves.store.read().is_empty(), "a save to continue from")
