extends GutTest


## Reaches boss `id` through the dev panel (God on) and sees its telegraph and its attack. Returns [main, its id,
## the E2e].
func _reach(id: StringName, kind: int, avatar_class: String) -> Array:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	var n := ContentRepository.load_all().count(&"bosses")
	assert_eq(
		e.world().boss_tables.size(),
		n,
		"the run carries every compiled boss (v0.9.0 NB: the six and the new ones)"
	)
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await e.click_dev("God")
	var choice := main.get_node("UI/DevPanel").find_child("BossChoice", true, false) as Label
	var w := e.world()
	var name := tr(w.boss_tables[BossLab.table_index(w, id)].name_key)
	for k in 8:
		if choice.text == name:
			break
		await e.click_dev("NextBoss")
		await e.frames(1)
	assert_eq(choice.text, name, "the panel names %s" % name)
	await e.click_dev("SpawnBoss")
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
	return [main, bid, e]


## Waits up to `limit` frames for `done`.
func _wait(e: E2e, done: Callable, limit: int) -> bool:
	for k in limit:
		if done.call():
			return true
		await e.frames(1)
	return done.call()


func test_the_warlord_is_reached_through_the_dev_panel_and_shows_its_banner_and_its_cage() -> void:
	var got: Array = await _reach(&"warlord", ActorStore.Kind.WARLORD, "WarlordAvatar")
	var main: Main = got[0]
	var bid: int = got[1]
	var e: E2e = got[2]
	var w := e.world()
	var reader := main.driver.reader
	var i := w.actors.index_of(bid)
	if i < 0:
		return
	# Its War Banner (phase 2). TEST HELPER: its HP is set just under the phase's threshold (a real fight to it is
	# minutes long); everything after is the game: the phase gate, the 8 s to the banner, its cast, real frames.
	w.actors.hp[i] = w.actors.max_hp[i] * 640 / 1000
	var banner: WarBannerViews = main.view.war_banner
	var planted := func() -> bool:
		return (
			int(reader.boss_warlord().get("banner", {}).get("cast", 0)) < 0
			and banner.banner_shown()
		)
	assert_true(await _wait(e, planted, 60 * 14), "the War Banner is planted and drawn")
	if not planted.call():
		return
	var b: Dictionary = reader.boss_warlord()["banner"]
	assert_almost_eq(
		banner.pole(), b["centre"], Vector2(0.01, 0.01), "its pole where the sim planted it"
	)
	assert_almost_eq(
		float(banner.ring_circle()[1]), float(b["radius"]), 0.001, "its ring of its radius"
	)
	# Its Duel (phase 3). TEST HELPER: its HP set just under the last phase's threshold; then the game again.
	i = w.actors.index_of(bid)
	if i < 0:
		return
	w.actors.hp[i] = w.actors.max_hp[i] * 300 / 1000
	var cage: DuelCageViews = main.view.duel_cage
	var closed := func() -> bool:
		return (
			int(reader.boss_warlord().get("duel", {}).get("stage", 0)) == 2
			and cage.shafts_shown() > 0
		)
	assert_true(await _wait(e, closed, 60 * 14), "the javelin cage closes and is drawn")
	if not closed.call():
		return
	assert_false(banner.banner_shown(), "the banner fell with its phase")
	var d: Dictionary = reader.boss_warlord()["duel"]
	assert_eq(cage.shafts_shown(), DuelCageViews.SHAFTS, "every javelin of the fence")
	assert_almost_eq(
		cage.shaft_head(0).distance_to(d["centre"]),
		float(d["radius"]),
		0.05,
		"on the fence's circle"
	)


func test_the_hive_lens_is_reached_through_the_dev_panel() -> void:
	await _reach(&"hive_lens", ActorStore.Kind.HIVE_LENS, "HiveLensAvatar")


func test_the_foundry_is_reached_through_the_dev_panel() -> void:
	var got: Array = await _reach(&"foundry", ActorStore.Kind.FOUNDRY, "FoundryAvatar")
	var main: Main = got[0]
	# Lit from the camera's side so it never reads as a black silhouette, and its slabs are stood on
	var lights := main.view.get_children().filter(func(n: Node) -> bool: return n is BossKeyLight)
	assert_eq(lights.size(), 1, "the game view carries the bosses' key light")
	var avatar := main.view.actors.actor_node(got[1]).get_meta(&"enemy_avatar") as BossAvatar
	assert_true(
		avatar.imported.layers & BossKeyLight.LAYER != 0, "the Foundry's body is in its light"
	)
	assert_true(main.view.actors.grounds.has(main.view.forge_slag), "a slab's top is stood on")
