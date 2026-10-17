extends GutTest
## The second boss of each pool reaches the real game (PLAN v0.4.0 BO). On a run each floor draws its boss from its
## pool of two (tests/unit/sim/test_bosses_2.gd); here the dev panel, opened with backtick and clicked with the
## mouse, picks each new boss by name (Next boss), summons it (Spawn boss), and the boss rises with its own model and
## its name on the HUD's boss bar, then telegraphs an attack that is drawn (on the ground, or the Gaze's aim line and
## beam) and lands on the player.
## God mode (also clicked) keeps the player standing; the hits still show as HIT events.


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _reach(id: StringName, kind: int, avatar_class: String) -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	assert_eq(e.world().boss_tables.size(), 6, "the run carries all six compiled bosses")
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, id)].name_key)
	for k in 8:
		if choice.text == name:
			break
		await _click(e, main, "NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name, "the panel names %s" % name)
	await _click(e, main, "SpawnBoss")
	await e.frames(3)
	assert_true(w.boss_alive(), "%s came" % id)
	var reader := main.driver.reader
	var i := reader.boss_index()
	assert_eq(reader.actor_kind(i), kind)
	var bid := reader.actor_id(i)
	var node := main.view.actors.actor_node(bid)
	assert_eq((node.get_meta(&"enemy_avatar") as Node).get_script().get_global_name(), avatar_class)
	var hud := main.ui.find_child("Hud", true, false) as Hud
	assert_true(hud.boss_bar.visible)
	assert_eq(hud.boss_bar.boss_name(), name, "the bar names it")
	# v0.7.5 BF1: the boss rises 6 m off with a pillar of the start hall between (its fireballs stop at walls); a few
	# steps to the side with the stick put the player in its sight.
	await e.tap(KEY_QUOTELEFT)  # the panel closes, the game takes the stick
	var to_boss := (reader.actor_pos(i) - reader.player_pos()).normalized()
	e.stick_toward(Vector2(-to_boss.y, to_boss.x))
	await e.frames(25)
	e.stick_toward(Vector2.ZERO)
	var drawn := false
	var hit := false
	var seq := w.last_event_seq()
	for k in 1200:
		await e.frames(1)
		var j := w.actors.index_of(bid)
		if j < 0:
			break
		# A ground telegraph is drawn by TelegraphViews; the Hive Lens's Gaze (v0.8.0 BS2: "ground": false, shape
		# &"signature") is drawn as its aim line and beam by BossSignatureViews instead. Which attack the boss picks
		# first follows the shared `ai` stream, which the floor's packs also draw from (2026-10-17: since N5 the packs
		# come sooner and the Lens picked Gaze, Petal Bloom, Gaze in these 1200 frames: no ground telegraph at all).
		var tg := reader.telegraph(j)
		if not tg.is_empty():
			if bool(tg.get("ground", true)) and main.view.telegraphs.count() > 0:
				drawn = true
			elif tg.get("shape") == &"signature" and main.view.signatures.gaze_drawn():
				drawn = true
		for ev in w.events_since(seq):
			seq = ev.seq
			if ev.kind == SimEvent.Kind.HIT and ev.target_id == w.actors.ids[0]:
				hit = hit or ev.owner_id == bid
		if drawn and hit:
			break
	assert_true(drawn, "%s: its telegraph is drawn" % id)
	assert_true(hit, "%s: its attack reached the player" % id)


func test_the_warlord_is_reached_through_the_dev_panel() -> void:
	await _reach(&"warlord", ActorStore.Kind.WARLORD, "WarlordAvatar")


func test_the_hive_lens_is_reached_through_the_dev_panel() -> void:
	await _reach(&"hive_lens", ActorStore.Kind.HIVE_LENS, "HiveLensAvatar")


func test_the_foundry_is_reached_through_the_dev_panel() -> void:
	await _reach(&"foundry", ActorStore.Kind.FOUNDRY, "FoundryAvatar")
