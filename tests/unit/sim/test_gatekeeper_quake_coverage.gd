extends GutTest
## v0.11.0 F5 (owner: the pillars must be a real threat): with the 7 m rings, three pillars still place in the
## Gatekeeper's real boss room (a floor built as Main builds it) and at least 20 % of the walkable arena floor stays
## outside every ring, over several floor seeds.

const MIN_OUTSIDE := 0.20
const STEP_M := 0.5
const WANT_ROOMS := 4


## The pillars' centres of a Gatekeeper fight on floor (run_seed, floor_index), or [] when that floor's boss isn't it.
## [centres, ring_m, walkable-and-outside fraction]
func _measure(run_seed: int, floor_index: int) -> Array:
	var w := FightLab.floor_world(run_seed, floor_index)
	FightLab.enter_boss_room(w)
	for t in 30:
		w.step(InputFrame.new())
	if w.boss_id < 0:
		return []
	var i := w.actors.index_of(w.boss_id)
	if BossAi.table_of(w, i).id != &"gatekeeper":
		return []
	var aid := w.boss_id
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	w.actors.invuln[0] = 1 << 20
	var t := BossAi.table_of(w, i)
	w.actors.hp[i] = w.actors.max_hp[i] * (t.phase_threshold[1] - 10) / 1000
	for k in 4:
		w.step(InputFrame.new())
	var pillars := BossQuake.pillars_of(w, aid)
	var centres: Array[Vector2] = []
	for k in pillars:
		centres.append(BossQuake.center(w.bosses, k))
	var ring := t.quake.ring_m
	var room := w.bosses.arena
	var walk := 0
	var outside := 0
	var y := room.position.y + STEP_M * 0.5
	while y < room.end.y:
		var x := room.position.x + STEP_M * 0.5
		while x < room.end.x:
			var p := Vector2(x, y)
			if EnemyAi.clear_of_walls(w, p, w.player.radius_m):
				walk += 1
				var inside := false
				for c in centres:
					if Kin.length(c - p) <= ring:
						inside = true
				if not inside:
					outside += 1
			x += STEP_M
		y += STEP_M
	return [centres, ring, float(outside) / float(maxi(walk, 1))]


func test_three_pillars_place_and_at_least_a_fifth_of_the_floor_is_outside_the_rings() -> void:
	var rooms := 0
	var lowest := 1.0
	var report := []
	for run_seed in range(1, 41):
		for floor_index in [1]:
			var m := _measure(run_seed, floor_index)
			if m.is_empty():
				continue
			rooms += 1
			var centres: Array = m[0]
			var frac: float = m[2]
			lowest = minf(lowest, frac)
			report.append(
				(
					"%d/%d: %d pillars, %.1f %% outside"
					% [run_seed, floor_index, centres.size(), frac * 100.0]
				)
			)
			assert_eq(
				centres.size(),
				3,
				"three pillars placed (seed %d floor %d)" % [run_seed, floor_index]
			)
			assert_gte(
				frac,
				MIN_OUTSIDE,
				"20 %% of the floor outside the rings (seed %d floor %d)" % [run_seed, floor_index]
			)
			if rooms >= WANT_ROOMS * 2:
				break
		if rooms >= WANT_ROOMS * 2:
			break
	gut.p(
		(
			"Gatekeeper rooms measured: %d, lowest outside-rings fraction: %.1f %%"
			% [rooms, lowest * 100.0]
		)
	)
	for r in report:
		gut.p(r)
	assert_gte(rooms, WANT_ROOMS, "enough Gatekeeper rooms found")
