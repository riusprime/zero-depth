extends GutTest
## The Arc Caster and the Bomb Drone reach the real game (v0.3.5 AI; owner lines F5, F6). On a run they join the
## spawner's mix at danger tiers 1 and 2 (30 s and 60 s in; tests/unit/sim/test_spawn_director.gd); here the dev
## panel, opened with backtick and clicked with the mouse, brings each one in at once: its model appears, it winds
## up a spell with its telegraph on the ground (the drone's bomb circle filling), and the spell lands on the player.
## God mode (also clicked) keeps the player standing; the hits still show as DAMAGE events (0 applied is fine: the
## point is that the attack reached the player through the real loop).


func _click(e: E2e, main: Main, button_name: String) -> void:
	var b := main.get_node("UI/DevPanel").find_child(button_name, true, false) as Button
	await e.click_at(b.get_global_rect().get_center())


func _spawned_kind(w: World, kind: int) -> int:
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == kind and w.actors.dead[i] == 0:
			return w.actors.ids[i]
	return -1


func test_the_dev_panel_brings_in_both_new_enemies_and_they_attack() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	await e.tap(KEY_QUOTELEFT)
	assert_true(main.is_dev_panel_open())
	await _click(e, main, "God")
	assert_true(main.driver.debug.god, "God mode")
	var choice := main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for spec in [
		[ActorStore.Kind.ARC_CASTER, "ENEMY_ARC_CASTER", [&"bolt", &"rune"]],
		[ActorStore.Kind.BOMB_DRONE, "ENEMY_BOMB_DRONE", [&"bomb"]],
	]:
		for k in 8:
			if choice.text == tr(spec[1]):
				break
			await _click(e, main, "NextEnemy")
			await e.frames(1)
		assert_eq(choice.text, tr(spec[1]), "the panel names the %s" % spec[1])
		await _click(e, main, "SpawnEnemy")
		await e.frames(3)
		var w := e.world()
		var id := _spawned_kind(w, spec[0])
		assert_gt(id, 0, "%s came" % spec[1])
		var node := main.view.actors.actor_node(id)
		assert_not_null(node, "its model is drawn")
		var styled := false
		var hit := false
		var seq := w.last_event_seq()
		for k in 900:
			await e.frames(1)
			var i := w.actors.index_of(id)
			if i < 0:
				break
			var tg := main.driver.reader.telegraph(i)
			if (spec[2] as Array).has(tg.get("style", &"")) and main.view.telegraphs.count() > 0:
				styled = true
			for ev in w.events_since(seq):
				seq = ev.seq
				if ev.kind == SimEvent.Kind.HIT and ev.target_id == w.actors.ids[0]:
					hit = hit or ev.owner_id == id
			if styled and hit:
				break
		assert_true(styled, "%s: its spell's telegraph is drawn" % spec[1])
		assert_true(hit, "%s: its spell reached the player" % spec[1])
