extends GutTest
## The enemies are in the real game and their telegraphs show (PLAN v0.1.0 Steps 4–5): the first wave is a
## Charger and a Needle.


func test_the_first_wave_arrives_and_telegraphs() -> void:
	var e := E2e.new(self)
	var main: Main = await e.boot()
	await e.start_from_menu()
	for k in 120:
		await e.frames(1)
		if e.world().actors.size() > 1:
			break
	var kinds := []
	for i in range(1, e.world().actors.size()):
		kinds.append(e.world().actors.kinds[i])
	kinds.sort()
	assert_eq(kinds, [ActorStore.Kind.CHARGER, ActorStore.Kind.NEEDLE])
	var seen := false
	for k in 600:
		await e.frames(1)
		if main.view.telegraphs.count() > 0:
			seen = true
			break
	assert_true(seen, "a telegraph is drawn within 10 s")
