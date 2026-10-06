extends GutTest


func test_ids_are_monotonic_and_never_reused() -> void:
	var w := KernelScenario.build(3, 4, 10, 5, 0)
	var seen := {}
	var last := 0
	for t in 200:
		w.step(InputFrame.new())
		for id in w.projectiles.ids:
			if not seen.has(id):
				assert_gt(id, last, "a new id is larger than every earlier one")
				last = id
				seen[id] = true
	assert_gt(seen.size(), 10, "projectiles were spawned and expired")
	for i in range(1, w.projectiles.size()):
		assert_gt(w.projectiles.ids[i], w.projectiles.ids[i - 1], "arrays stay in id order")


func test_spawns_apply_at_end_of_tick() -> void:
	var w := KernelScenario.build(3, 1, 1, 50, 0)
	var before := w.projectiles.size()
	w.step(InputFrame.new())
	var spawns := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.SPAWN
	)
	assert_gt(spawns.size(), 0)
	assert_eq(w.projectiles.size(), before + 1, "the shot exists after the tick, not during it")
