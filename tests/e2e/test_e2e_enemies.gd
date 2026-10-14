extends GutTest
## Enemies reach you in the real game and their telegraphs show (PLAN v0.1.0 Step 4, v0.2.0 F): on the floor the
## spawner starts with Chargers and Needles (Wardens unlock at danger 2). v0.8.0 TG: their telegraphs are told by the
## body (a crouch, a glow and a flash), not drawn on the ground.


func test_the_first_enemies_arrive_and_telegraph() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	for k in 600:
		await e.frames(1)
		if e.world().actors.size() > 1:
			break
	assert_gt(e.world().actors.size(), 1, "an enemy spawned within 10 s")
	for i in range(1, e.world().actors.size()):
		assert_has(
			[ActorStore.Kind.CHARGER, ActorStore.Kind.NEEDLE],
			e.world().actors.kinds[i],
			"tier 0 mix"
		)
	# v0.8.0 TG (owner O4, Q3): a Charger's or Needle's windup draws nothing on the ground; its body tells it.
	var seen := false
	for k in 900:
		await e.frames(1)
		assert_eq(main.view.telegraphs.count(), 0, "no ground mark from a Charger or a Needle")
		var w := e.world()
		for i in range(1, w.actors.size()):
			if w.actors.state[i] != EnemyAi.State.WINDUP:
				continue
			var tg := main.driver.reader.telegraph(i)
			var node := main.view.actors.actor_node(w.actors.ids[i])
			if tg.is_empty() or tg.get("ground", true) or node == null:
				continue
			if float(node.get_meta(&"enemy_avatar").call(&"crouch_amount")) > 0.0:
				seen = true
		if seen:
			break
	assert_true(seen, "an enemy's body tells its windup within 15 s")
