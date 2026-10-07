extends GutTest
## PRESENTATION §4 / EI-07 for the boss challenge (v0.3.0 BX): the drawn area is the hit area. The pull's slam and
## the shockwave (rings read from WorldReader.telegraph) and the closing band (WorldReader.boss_arena_band) each hit
## a player standing just inside what is drawn (grown by the player's radius) and spare one just outside. The punish
## moves and the band's steps are marked for at least the telegraph minimum first.

const EPS := 0.04


func _pr() -> float:
	return PlayerTable.starting_values().radius_m


## Boss `id` at the origin performs `attack_id` on a player held at `stand`. Returns [hit, telegraph, windup ticks
## shown before the first damage].
func _ring(id: StringName, attack_id: StringName, stand: Vector2) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id)
	var aid := w.actors.ids[i]
	var reader := WorldReader.new(w)
	w.actors.hp[0] = 100000
	w.actors.set_pos(0, stand)
	BossLab.start(w, i, attack_id)
	var tg := reader.telegraph(i)
	var shown := 0
	for t in 400:
		var j := w.actors.index_of(aid)
		if w.actors.state[j] == EnemyAi.State.RECOVER:
			break
		if not reader.telegraph(j).is_empty() and CombatLab.player_damage(w).is_empty():
			shown += 1
		w.actors.set_pos(0, stand)
		w.step(InputFrame.new())
	return [CombatLab.player_damage(w).size() > 0, tg, shown]


func test_the_vortex_slam_hits_what_its_ring_shows() -> void:
	var pr := _pr()
	var first: Array = _ring(&"gatekeeper", &"vortex_slam", Vector2(3, 0))
	var tg: Dictionary = first[1]
	assert_eq(tg["shape"], &"ring")
	assert_eq(tg["move"], WorldReader.MOVE_PULL)
	assert_gt(tg["pull_m"], 10.0, "the vortex's reach is drawn too")
	assert_gte(first[2], SimTick.MIN_TELEGRAPH_TICKS, "marked long enough first")
	var outer: float = tg["outer"]
	for d in [0.5, outer + pr - EPS, outer + pr + EPS, outer + 3.0]:
		var got: Array = _ring(&"gatekeeper", &"vortex_slam", Vector2(0, d))
		assert_eq(got[0], d - pr <= outer, "distance %.2f: hit iff inside the drawn ring" % d)


func test_the_shockwave_hits_what_its_ring_shows_and_spares_the_inside() -> void:
	var pr := _pr()
	var first: Array = _ring(&"siege_engine", &"shockwave", Vector2(10, 0))
	var tg: Dictionary = first[1]
	assert_eq(tg["shape"], &"ring")
	assert_gte(first[2], SimTick.MIN_TELEGRAPH_TICKS)
	var inner: float = tg["inner"]
	var outer: float = tg["outer"]
	for d in [2.0, inner - pr - EPS, inner - pr + EPS, 20.0, outer + pr - EPS, outer + pr + EPS]:
		var got: Array = _ring(&"siege_engine", &"shockwave", Vector2(d, 0))
		var drawn: bool = d + pr >= inner and d - pr <= outer
		assert_eq(got[0], drawn, "distance %.2f: hit iff inside the drawn ring" % d)


func test_the_pounce_chain_lands_on_its_drawn_discs() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"brood_mother")
	var aid := w.actors.ids[i]
	var reader := WorldReader.new(w)
	w.actors.hp[0] = 100000
	w.actors.set_pos(0, Vector2(14, 0))
	BossLab.start(w, i, &"pounce_chain")
	var shown := 0
	var leaps := 0
	for t in 600:
		var j := w.actors.index_of(aid)
		if w.actors.state[j] == EnemyAi.State.RECOVER:
			break
		var tg := reader.telegraph(j)
		if w.actors.state[j] == EnemyAi.State.WINDUP:
			assert_eq(tg["shape"], &"disc")
			shown += 1
		if w.actors.state[j] == EnemyAi.State.ACTIVE and w.actors.state_t[j] == 0:
			leaps += 1
			assert_gte(shown, SimTick.MIN_TELEGRAPH_TICKS, "leap %d marked long enough" % leaps)
			shown = 0
		w.actors.set_pos(0, Vector2(14, 0))
		w.step(InputFrame.new())
	assert_eq(leaps, 3)


## A 30 m arena, the band `steps` deep, the boss held staggered; the player stands at `p` for 40 ticks.
func _band_hit(p: Vector2, steps: int) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var b := BossAi.entry_of(w, i)
	var t := BossAi.table_of(w, i)
	w.bosses.arena = Rect2(-15, -15, 30, 30)
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[b] = 99999
	w.bosses.close_t[b] = t.close_step_ticks * steps + 1
	var bd := WorldReader.new(w).boss_arena_band()
	for k in 40:
		w.actors.set_pos(0, p)
		w.step(InputFrame.new())
	return [CombatLab.player_damage(w).size() > 0, bd]


func test_the_closing_band_hurts_where_it_is_drawn() -> void:
	var pr := _pr()
	var bd: Dictionary = _band_hit(Vector2.ZERO, 2)[1]
	var arena: Rect2 = bd["arena"]
	var depth: Vector2 = bd["depth"]
	assert_eq(depth, Vector2(2, 2))
	var edge_x := arena.end.x - depth.x  # the band's inner face on +x
	var edge_y := arena.position.y + depth.y  # and on -y
	for spec in [
		[Vector2(edge_x - pr - EPS, 0), false],
		[Vector2(edge_x - pr + EPS, 0), true],
		[Vector2(0, edge_y + pr + EPS), false],
		[Vector2(0, edge_y + pr - EPS), true],
		[Vector2(14, 14), true],
		[Vector2(0, 0), false],
	]:
		var got: Array = _band_hit(spec[0], 2)
		var drawn := BossChallenge.touches_band(arena, depth, spec[0], pr)
		assert_eq(drawn, spec[1], "%s: the drawn band" % spec[0])
		assert_eq(got[0], drawn, "%s: hit iff touching the drawn band" % spec[0])


func test_each_step_is_marked_for_the_telegraph_minimum_before_it_hurts() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(0, 0))
	var b := BossAi.entry_of(w, i)
	w.bosses.arena = Rect2(-15, -15, 30, 30)
	w.actors.state[i] = BossAi.STAGGERED
	w.bosses.stagger_t[b] = 99999
	w.bosses.close_t[b] = 1
	var reader := WorldReader.new(w)
	var marked := 0
	var depth := Vector2.ZERO
	for k in 800:
		var bd := reader.boss_arena_band()
		if bd["depth"] != depth:
			assert_gte(marked, SimTick.MIN_TELEGRAPH_TICKS, "step to %s marked first" % bd["depth"])
			assert_eq(bd["depth"], depth + Vector2(1, 1), "the marked step is the one that comes")
			depth = bd["depth"]
			marked = 0
		elif int(bd["warn"]) >= 0:
			marked += 1
		w.actors.set_pos(0, Vector2.ZERO)
		w.step(InputFrame.new())
	assert_eq(depth, Vector2(2, 2), "two steps in 800 ticks (6 s each)")
