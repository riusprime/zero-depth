extends GutTest
## Enemies reach you in the real game and their telegraphs show (PLAN v0.1.0 Step 4, v0.2.0 F): on the floor the
## spawner starts with Chargers and Needles (Wardens unlock at danger 2).


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
	var seen := false
	for k in 900:
		await e.frames(1)
		if main.view.telegraphs.count() > 0:
			seen = true
			break
	assert_true(seen, "a telegraph is drawn within 15 s")
