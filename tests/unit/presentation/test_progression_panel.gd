extends GutTest
## v0.9.0 MP: the Progression Station's panel: the balance, one row per robe (its price, or "owned" once bought), the
## Void's unlock line, the status line, in English and Spanish; a press asks to buy; the run summary's fragment line.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func after_each() -> void:
	TranslationServer.set_locale("en")


func _panel(owned: Array[bool], fragments: int, void_open: bool) -> ProgressionPanel:
	var p := ProgressionPanel.new(MetaProgress.wares(_repo), owned, fragments, void_open)
	add_child_autofree(p)
	return p


func test_rows_prices_and_owned() -> void:
	var p := _panel([false, true, false, false] as Array[bool], 40, false)
	var night: RobeDefinition = _repo.get_def(&"robe", &"night")
	assert_eq(p.rows.size(), 4, "the four robes")
	assert_eq(p.balance.text, tr("PROGRESSION_BALANCE") % 40)
	assert_eq(
		p.rows[0].text, "%s  ·  %s" % [tr("ROBE_NIGHT"), tr("PROGRESSION_PRICE") % night.price]
	)
	assert_true(p.rows[1].text.ends_with(tr("PROGRESSION_OWNED")), "Canyon owned")
	assert_eq(p.void_line.text, tr("PROGRESSION_VOID_LOCKED"))
	assert_false(p.status.visible, "no status yet")
	watch_signals(p)
	p.rows[2].pressed.emit()
	assert_signal_emitted_with_parameters(p, "buy_requested", [&"frost"])
	p.show_state([true, true, false, false] as Array[bool], 15, true)
	p.show_status(&"PROGRESSION_BOUGHT", "ROBE_NIGHT")
	assert_true(p.rows[0].text.ends_with(tr("PROGRESSION_OWNED")), "bought")
	assert_eq(p.void_line.text, tr("PROGRESSION_VOID_OPEN"))
	assert_eq(p.status.text, tr("PROGRESSION_BOUGHT") % tr("ROBE_NIGHT"))


func test_spanish() -> void:
	TranslationServer.set_locale("es")
	var p := _panel([false, false, false, false] as Array[bool], 3, false)
	assert_eq(p.balance.text, "Fragmentos de Runa: 3")
	assert_true(p.rows[0].text.begins_with("Noche"), p.rows[0].text)
	p.show_status(&"PROGRESSION_SHORT", "ROBE_NIGHT")
	assert_eq(p.status.text, "No tienes Fragmentos de Runa suficientes para la túnica Noche.")


func test_the_run_summary_shows_the_fragments() -> void:
	var recap := {"floor": 2, "floors": 5, "fragments": 7, "fragments_total": 31}
	var e := EndPanel.new(false, 0, &"", recap)
	add_child_autofree(e)
	assert_eq(e.recap_line("Fragments"), tr("UI_RECAP_FRAGMENTS") % [7, 31])
	TranslationServer.set_locale("es")
	var es := EndPanel.new(false, 0, &"", recap)
	add_child_autofree(es)
	assert_eq(es.recap_line("Fragments"), "Fragmentos de Runa: +7 (ahora 31)")
