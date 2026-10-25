extends GutTest
## The run recap and the run's HUD pieces (v0.3.0 B): the end panel reads a recap (victory or death, floor reached,
## time, kills, shards only when present, items), the pause menu offers Resume, Restart run and Main menu, and the
## HUD's floor-title card shows, then fades.


func test_victory_recap_lists_the_run() -> void:
	var p := (
		EndPanel
		. new(
			true,
			-1,
			&"",
			{
				"floor": 3,
				"floors": 3,
				"seconds": 754.0,
				"kills": 212,
				"shards": 340,
				"items": ["ITEM_LONG_EDGE", "ITEM_FROST_CORE"],
			}
		)
	)
	assert_eq((p.find_child("Title", true, false) as Label).text, "UI_RUN_COMPLETE")
	assert_null(p.find_child("Cause", true, false), "no cause on a win")
	assert_eq(p.recap_line("Floor"), tr("UI_RECAP_FLOOR") % [3, 3])
	assert_eq(p.recap_line("Time"), tr("UI_RECAP_TIME") % [12, 34])
	assert_eq(p.recap_line("Kills"), tr("UI_RECAP_KILLS") % 212)
	assert_eq(p.recap_line("Shards"), tr("UI_RECAP_SHARDS") % 340)
	assert_eq(
		p.recap_line("Items"),
		tr("UI_RECAP_ITEMS") % ("%s, %s" % [tr("ITEM_LONG_EDGE"), tr("ITEM_FROST_CORE")])
	)
	p.free()


func test_death_recap_has_the_cause_and_omits_missing_shards() -> void:
	var p := EndPanel.new(
		false,
		WorldReader.KIND_WARDEN,
		&"",
		{"floor": 2, "floors": 3, "seconds": 61.0, "kills": 9, "items": []}
	)
	assert_eq((p.find_child("Title", true, false) as Label).text, "UI_YOU_DIED")
	assert_eq((p.find_child("Cause", true, false) as Label).text, "CAUSE_WARDEN")
	assert_eq(p.recap_line("Shards"), "", "no shards line without shards")
	assert_eq(p.recap_line("Items"), tr("UI_RECAP_NO_ITEMS"))
	assert_eq(p.recap_line("Floor"), tr("UI_RECAP_FLOOR") % [2, 3])
	p.free()


func test_pause_menu_offers_restart_run() -> void:
	var m := PauseMenu.new()
	var names := []
	for c in m.box.get_children():
		if c is Button:
			names.append(String(c.name))
	# Options: v0.3.0 O; Build: v0.6.5 WN2; Codex: v0.7.5 CX
	# v0.9.0 HB (owner 2026-10-23): the last row leaves to the hub, in the end panel's words
	assert_eq(names, ["Resume", "Build", "Restart", "Options", "Codex", "Hub"])
	assert_eq((m.box.get_node("Hub") as Button).text, "UI_TO_HUB")
	m.free()
	var dev := PauseMenu.new(false)  # the dev Playground keeps Main menu
	assert_not_null(dev.box.get_node_or_null("MainMenu"))
	assert_null(dev.box.get_node_or_null("Hub"))
	dev.free()


func test_hud_floor_card_shows_then_fades() -> void:
	var h := Hud.new()
	add_child_autofree(h)
	h.show_floor(2, "BIOME_NIGHT_ROCKS")
	assert_true(h.floor_card_showing())
	assert_eq(h.floor_card_text(), "%s %s" % [tr("HUD_FLOOR_CARD") % 2, tr("BIOME_NIGHT_ROCKS")])
	await wait_seconds(Hud.FLOOR_CARD_SECONDS + 0.3)
	assert_false(h.floor_card_showing(), "the card fades away")
