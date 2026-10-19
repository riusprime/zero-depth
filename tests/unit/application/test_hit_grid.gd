extends GutTest
## v0.8.0 HS (owner O89: "lag mostly comes from shooting hordes with multiple modifiers"): inside _projectile_hits the
## area attacks (Explosive's blast, Static Chain's first jump, Wildfire, Blood Harvest, the shock jumps, Resonance)
## read a grid's candidates instead of every actor (World.aoe_candidates). The perf probe's horde build must give
## the same world, tick by tick, as the full scan, and the grid must never leave out a body in reach.

const CARDS: Array[StringName] = [
	&"gun_twin",
	&"split_shot",
	&"shared_explosive",
	&"cinder_shot",
	&"static_chain",
	&"ember_core",
	&"wildfire",
]
const HORDE := 110
const TICKS := 360


func _horde_world(full: bool) -> World:
	var repo := AttackScenario.repo()
	var w := PlaygroundScenario.build(repo, &"gun", repo.get_def(&"biomes", &"ruins"))
	var api := PlaygroundApi.new(w)
	api.god = true
	for id in CARDS:
		var code := -1
		for k in w.item_tables.size():
			if w.item_tables[k].id == id:
				code = k
		assert_true(api.grant_now(code, 5), "granted %s" % id)
	w.debug_aoe_full = full
	w.debug_aoe_misses = 0
	w.set_meta(&"api", api)
	return w


## Tops the horde up round the hero at fixed spots (the perf probe's pattern, without trigonometry).
func _refill(w: World, placed: Array) -> void:
	var api: PlaygroundApi = w.get_meta(&"api")
	var hero := w.player_pos()
	var alive := 0
	for i in range(1, w.actors.size()):
		if EnemyAi.is_enemy_kind(w.actors.kinds[i]) and w.actors.dead[i] == 0:
			alive += 1
	var want := mini(HORDE - alive, 8)
	var tries := 0
	while want > 0 and tries < 32:
		tries += 1
		placed[0] += 1
		var n: int = placed[0]
		var at := hero + Kin.dir((n * 1567) & 4095) * (3.0 + float(n % 7))
		if api.place_enemy_now(ActorStore.Kind.CHARGER, at):
			want -= 1


func _run(full: bool) -> Array:
	var w := _horde_world(full)
	var placed := [0]
	var hashes: PackedStringArray = []
	_refill(w, placed)
	for t in TICKS:
		w.step(InputFrame.make(Vector2i.ZERO, (t * 16) & 4095, 600, InputFrame.SHOOT, 0))
		_refill(w, placed)
		if t % 30 == 29:
			hashes.append(w.state_hash())
	return [w, hashes]


func test_the_grid_gives_the_full_scans_world_tick_by_tick() -> void:
	var grid: Array = _run(false)
	var full: Array = _run(true)
	var wg: World = grid[0]
	assert_gt(wg.kills, 0, "the horde build killed (the area attacks ran)")
	assert_gt(wg._hit_grid.count(), 0, "the grid was built inside _projectile_hits")
	assert_eq(grid[1], full[1], "the same hash every 30 ticks")
	assert_eq(wg.debug_aoe_misses, 0, "no body in reach was left out of the candidates")
	assert_eq((full[0] as World).debug_aoe_misses, 0)


func test_outside_projectile_hits_the_candidates_are_every_actor() -> void:
	var w := _horde_world(false)
	_refill(w, [0])
	var got := w.aoe_candidates(w.player_pos(), 0.1)
	assert_eq(got.size(), w.actors.size() - 1)
	assert_eq(got[0], 1)
	assert_eq(got[got.size() - 1], w.actors.size() - 1)
