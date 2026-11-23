extends GutTest


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
	await e.click_dev("God")
	assert_true(main.driver.debug.god, "God mode")
	var choice := main.get_node("UI/DevPanel").find_child("EnemyChoice", true, false) as Label
	for spec in [
		[ActorStore.Kind.ARC_CASTER, "ENEMY_ARC_CASTER", [&"cast", &"disc"]],
		[ActorStore.Kind.BOMB_DRONE, "ENEMY_BOMB_DRONE", [&"cast", &"lob"]],
	]:
		for k in 8:
			if choice.text == tr(spec[1]):
				break
			await e.click_dev("NextEnemy")
			await e.frames(1)
		assert_eq(choice.text, tr(spec[1]), "the panel names the %s" % spec[1])
		await e.click_dev("SpawnEnemy")
		await e.frames(3)
		var w := e.world()
		var id := _spawned_kind(w, spec[0])
		assert_gt(id, 0, "%s came" % spec[1])
		var node := main.view.actors.actor_node(id)
		assert_not_null(node, "its model is drawn")
		var avatar: Node = node.get_meta(&"enemy_avatar", null)
		var caster: bool = spec[0] == ActorStore.Kind.ARC_CASTER
		if caster:
			assert_true(avatar is ArcCasterAvatar, "the Arc Caster on the owner's model")
		else:
			assert_true(avatar is BombDroneAvatar, "the Bomb Drone on the owner's model")
		var gathered := false
		var styled := false
		var hit := false
		var lobbed := false
		var seq := w.last_event_seq()
		for k in 900:
			await e.frames(1)
			var i := w.actors.index_of(id)
			if i < 0:
				break
			var tg := main.driver.reader.telegraph(i)
			if caster and avatar is ArcCasterAvatar:
				gathered = gathered or (avatar as ArcCasterAvatar).gather_pose() > 0.2
			if avatar is BombDroneAvatar:
				lobbed = lobbed or not (avatar as BombDroneAvatar).bomb_armed()
			if (spec[2] as Array).has(tg.get("shape", &"")):
				var ground: bool = tg.get("ground", true)
				styled = styled or not ground or main.view.telegraphs.count() > 0
			for ev in w.events_since(seq):
				seq = ev.seq
				if ev.kind == SimEvent.Kind.HIT and ev.target_id == w.actors.ids[0]:
					hit = hit or ev.owner_id == id
			if styled and hit and (gathered if caster else lobbed):
				break
		assert_true(styled, "%s: its spell's telegraph is drawn" % spec[1])
		assert_true(hit, "%s: its spell reached the player" % spec[1])
		if caster:
			assert_true(gathered, "the Arc Caster's body gathers its spell through the windup")
		else:
			assert_true(lobbed, "the Bomb Drone lets its bomb go as it lobs")
