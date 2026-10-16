extends GutTest
## v0.8.0 BS1 (owner O5; docs/roadmap/v0.8.0/BOSS_SIGNATURES.md S1-S3, approved 2026-10-14): each boss's signature
## mechanic. S1 the Gatekeeper's shock lanes leave stone pillars that are walls for a while (they block bodies and
## fireballs, the flow field goes round them, they sink on time, never rise on a body and never seal anyone in);
## S2 the Warlord's tower shield blocks hits from the front, and its Javelin Fan's javelins stick where they stop and
## all fly back along the same lines; S3 the Brood Mother's eggs sit as targets: broken they are gone, left alone they
## hatch, and in phase 3 they burst into the acid star. Determinism and the snapshot round trip with them standing.

const S := EnemyAi.State
const LONG := 1 << 20
## The free-space flood of the no-trap test: its cell and how far it reaches from the player (m).
const CELL := 0.12
const REACH := 13.0


## A boss at boss_at past its rise, the player at player_at; `untouchable`: no hit lands on the player (no hit-stop
## shifts the clock).
func _fight(
	id: StringName, player_at: Vector2, boss_at := Vector2.ZERO, untouchable := false
) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, boss_at)
	w.actors.set_pos(0, player_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	if untouchable:
		w.actors.invuln[0] = LONG
	return [w, w.actors.ids[i]]


## The tick boss `aid`'s attack turns active (stepping until then).
func _until_active(w: World, aid: int) -> int:
	CombatLab.until(
		w, func(x: World) -> bool: return x.actors.state[x.actors.index_of(aid)] == S.ACTIVE, 400
	)
	return w.tick - 1 - w.actors.state_t[w.actors.index_of(aid)]  # the tick it turned, as the sim counts it


func _atk(w: World, aid: int) -> BossAttackTable:
	return BossAi.attack_of(w, w.actors.index_of(aid))


## Steps until boss `aid`'s attack has struck its first marker (its windup over), at most `limit` ticks.
func _until_struck(w: World, aid: int, limit: int = 400) -> void:
	for k in limit:
		var i := w.actors.index_of(aid)
		if i < 0 or (w.actors.state[i] == S.ACTIVE and w.actors.state_t[i] >= 1):
			return
		w.step(InputFrame.new())


## A real floor (walls, the boss room behind its sealed door) whose boss is `id`, the fight begun and the boss past its
## rise. [world, boss actor id].
func _floor_fight(id: StringName, floor_index: int = 1) -> Array:
	for run_seed in range(1, 80):
		var w := SaveLab.floor_world(run_seed, floor_index)
		w.actors.hp[0] = LONG
		w.actors.max_hp[0] = LONG
		FightLab.enter_boss_room(w)
		CombatLab.idle(w, 3)
		if w.boss_id < 0:
			continue
		var i := w.actors.index_of(w.boss_id)
		if BossAi.table_of(w, i).id != id:
			continue
		w.actors.state[i] = S.MOVE
		w.actors.state_t[i] = 0
		w.actors.invuln[i] = 0
		return [w, w.boss_id]
	return []


# --- S1: the Gatekeeper's pillars --------------------------------------------------------------------------------


func test_the_shock_lanes_leave_pillars_along_your_row_and_column() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	var walls := w.walls.size()
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	var atk := _atk(w, aid)
	assert_eq(atk.pillar_ticks, 360, "6 s (a starting value)")
	_until_struck(w, aid)
	var c := BossDodge.mark_of(w, w.actors.index_of(aid), 0)
	var n := w.bosses.pillar_x.size()
	assert_gt(n, 4, "pillars stand along the lanes")
	assert_eq(w.walls.size(), walls + n, "each pillar is a wall")
	for k in n:
		var p := Vector2(w.bosses.pillar_x[k], w.bosses.pillar_y[k])
		var on_row := absf(p.y - c.y) < 0.001
		var on_col := absf(p.x - c.x) < 0.001
		assert_true(on_row or on_col, "pillar %s on the struck row or column through %s" % [p, c])
		assert_gt(Kin.length(p - c), 1.0, "the crossing stays open")


func test_pillars_never_rise_on_a_body() -> void:
	# The player stands right where the second pillar out along the row would rise.
	var s := _fight(&"gatekeeper", Vector2(4, 3))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks + 2)  # locked on (4, 3)
	var c := BossDodge.mark_of(w, w.actors.index_of(aid), 0)
	var spot := c + Vector2(atk.pillar_step_m * 2.0, 0)
	w.actors.set_pos(0, spot)
	_until_struck(w, aid)
	assert_gt(w.bosses.pillar_x.size(), 0)
	for k in w.bosses.pillar_x.size():
		var o := BossSignatures.pillar_obb(w.bosses, k)
		for j in w.actors.size():
			var touch := Collide.circle_vs_obb(w.actors.pos(j), w.actors.radius[j], o)
			assert_eq(touch, Vector2.ZERO, "pillar %d clear of body %d" % [k, j])


func test_pillars_block_bodies_and_fireballs_then_sink_on_time() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	var walls := w.walls.size()
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	var atk := _atk(w, aid)
	_until_struck(w, aid)
	var o := BossSignatures.pillar_obb(w.bosses, 0)
	assert_false(EnemyAi.clear_of_walls(w, o.center, 0.1), "a wall for bodies and sight")
	# A fireball flying at the pillar stops on it.
	var from := o.center + Vector2(-4.0, 0.0)
	if not EnemyAi.clear_of_walls(w, from, 0.3):
		from = o.center + Vector2(0.0, -4.0)
	var dir := (o.center - from) / Kin.length(o.center - from)
	w.queue_projectile(
		w.actors.ids[w.actors.index_of(aid)],
		ActorStore.TEAM_ENEMY,
		from,
		dir * 0.1,
		5,
		0.2,
		120,
		SimEvent.TAG_PROJECTILE
	)
	CombatLab.idle(w, 60)
	for k in w.projectiles.size():
		var p := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		assert_lt((p - from).dot(dir), Kin.length(o.center - from), "no shot passed the pillar")
	var risen: int = w.bosses.pillar_from[0]
	CombatLab.idle(w, risen + atk.pillar_ticks - w.tick + 1)
	assert_eq(w.bosses.pillar_x.size(), 0, "every pillar sank after pillar_ticks")
	assert_eq(w.walls.size(), walls, "and the walls are as before")
	assert_true(EnemyAi.clear_of_walls(w, o.center, 0.1))


func test_the_player_walks_into_a_pillar_and_stops() -> void:
	var s := _fight(&"gatekeeper", Vector2(5, 3))
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	_until_struck(w, aid)
	var o := BossSignatures.pillar_obb(w.bosses, 0)
	var start := o.center + Vector2(0.0, -2.0)
	w.actors.set_pos(0, start)
	w.vel = Vector2.ZERO
	for k in 90:
		w.step(InputFrame.make(Vector2i(0, 127), 1024, 300, 0, 0))
		if w.player_dead():
			break
	var p := w.player_pos()
	assert_eq(
		Collide.circle_vs_obb(p, w.player.radius_m - 0.01, o), Vector2.ZERO, "never inside it"
	)


func test_the_flow_field_goes_round_the_pillars() -> void:
	var f := _floor_fight(&"gatekeeper")
	if f.is_empty():
		fail_test("no run seed in 1..79 has the Gatekeeper on floor 1")
		return
	var w: World = f[0]
	var aid: int = f[1]
	BossLab.start(w, w.actors.index_of(aid), &"shock_lanes")
	_until_struck(w, aid)
	assert_gt(w.bosses.pillar_x.size(), 0)
	var o := BossSignatures.pillar_obb(w.bosses, 0)
	var c := w.nav.cell_of(o.center)
	assert_eq(w.nav.extra[c.y * w.nav.size.x + c.x], 1, "the pillar's cell is blocked")
	assert_eq(w.nav.dist[c.y * w.nav.size.x + c.x], NavField.UNREACHED, "no flow through it")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.pillar_ticks + 2)
	assert_true(w.nav.extra.is_empty(), "the field is open again once they sank")


## The fairness proof's invariant (BossSignatures.fits) on real floors: every pillar keeps the hero's width plus the
## slack from every other wall, so it is an island; and a flood of the hero's free space around the strike reaches
## every free spot it reached before the pillars rose.
func test_pillars_never_seal_the_player_in() -> void:
	var f := _floor_fight(&"gatekeeper")
	if f.is_empty():
		fail_test("no run seed in 1..79 has the Gatekeeper on floor 1")
		return
	var w: World = f[0]
	var aid: int = f[1]
	for attack_id: StringName in [&"shock_lanes_2", &"shock_lanes"]:
		var i := w.actors.index_of(aid)
		w.actors.state[i] = S.MOVE
		BossLab.start(w, i, attack_id)
		var atk := _atk(w, aid)
		CombatLab.idle(w, atk.windup_ticks - 1)
		var before := _free_reach(w)
		CombatLab.idle(w, atk.active_ticks + 2)
		assert_gt(w.bosses.pillar_x.size(), 0, attack_id)
		var gap := 2.0 * w.player.radius_m + BossSignatures.PASS_SLACK_M - 0.001
		for k in w.bosses.pillar_x.size():
			var o := BossSignatures.pillar_obb(w.bosses, k)
			for q: Vector2 in BossSignatures.corners(o):
				for j in w.walls.size():
					var x: Obb = w.walls[j]
					if x.center == o.center:
						continue
					assert_eq(
						Collide.circle_vs_obb(q, gap, x), Vector2.ZERO, "pillar %d keeps a way" % k
					)
		var after := _free_reach(w)
		var lost := 0
		for key: Vector2i in before:
			if not after.has(key) and _free(w, before[key]):
				lost += 1
		assert_eq(lost, 0, "%s: every free spot still reachable" % attack_id)


## The free spots (the hero's body, a little slimmer for the grid, clear of every wall) reachable from the player
## within REACH, as cell -> centre.
func _free_reach(w: World) -> Dictionary:
	var p := w.player_pos()
	var start := Vector2i(0, 0)
	var seen := {start: p}
	var queue: Array[Vector2i] = [start]
	var n := int(REACH / CELL)
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc := c + d
			if seen.has(nc) or absi(nc.x) > n or absi(nc.y) > n:
				continue
			var at := p + Vector2(nc) * CELL
			if not _free(w, at):
				continue
			seen[nc] = at
			queue.append(nc)
	return seen


func _free(w: World, at: Vector2) -> bool:
	return EnemyAi.clear_of_walls(w, at, w.player.radius_m - 0.04)


func test_pillars_are_deterministic_and_survive_a_save() -> void:
	var f1 := _floor_fight(&"gatekeeper")
	if f1.is_empty():
		fail_test("no run seed in 1..79 has the Gatekeeper on floor 1")
		return
	var f2 := _floor_fight(&"gatekeeper")
	var a: World = f1[0]
	var b: World = f2[0]
	for w: World in [a, b]:
		BossLab.start(w, w.actors.index_of(w.boss_id), &"shock_lanes_2")
	for k in 150:
		a.step(InputFrame.new())
		b.step(InputFrame.new())
	assert_gt(a.bosses.pillar_x.size(), 0, "pillars standing")
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree with pillars up")
	_round_trip(a, _floor_fight(&"gatekeeper")[0], "pillars")


## Snapshot `w` with its signature pieces standing, restore into `base` (built the same way), and step both.
func _round_trip(w: World, base: World, label: String) -> void:
	var snap := WorldSnapshot.take(w)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored, "%s: restores (%s)" % [label, WorldSnapshot.apply(base, snap)])
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "%s: same hash restored" % label)
	assert_eq(restored.nav.extra, w.nav.extra, "%s: the field goes round the same pillars" % label)
	for k in 420:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		w.step(f)
		restored.step(f)
	assert_eq(restored.state_hash(), w.state_hash(), "%s: same hash 420 ticks on" % label)
	assert_eq(
		w.bosses.pillar_x.size() + w.bosses.jav_x.size(),
		restored.bosses.pillar_x.size() + restored.bosses.jav_x.size()
	)


# --- S2: the Warlord's shield and javelins -----------------------------------------------------------------------


func test_the_warlords_shield_blocks_the_front_and_its_sides_and_back_take_hits() -> void:
	var s := _fight(&"warlord", Vector2(6, 0))
	var w: World = s[0]
	var aid: int = s[1]
	var i := w.actors.index_of(aid)
	w.actors.facing[i] = 0  # facing +x
	var cases := [
		[Vector2(3, 0), true, "front"],
		[Vector2(2.2, 1.5), true, "front, inside 60 degrees"],
		[Vector2(0, 3), false, "side"],
		[Vector2(-3, 0), false, "back"],
	]
	for cs: Array in cases:
		var hp := w.actors.hp[i]
		var got := Damage.hit(
			w, i, 30, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, cs[0], w.actors.pos(i)
		)
		var last: SimEvent = null
		for e in w.events_since(0):
			if e.kind == SimEvent.Kind.HIT and e.target_id == aid:
				last = e
		if cs[1]:
			assert_eq(got, 0, "%s: no damage" % cs[2])
			assert_eq(w.actors.hp[i], hp, cs[2])
			assert_true(last.tags & SimEvent.TAG_BLOCKED != 0, "%s: sparks (blocked)" % cs[2])
		else:
			assert_gt(got, 0, "%s: lands" % cs[2])


func test_javelins_stick_where_they_stop_then_fly_back_along_the_same_lines() -> void:
	var s := _fight(&"warlord", Vector2(20, 0), Vector2.ZERO, true)  # out of the fan's reach: every javelin sticks
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var atk := _atk(w, aid)
	var pat := atk.pattern
	assert_gt(atk.recall_ticks, 0)
	var boss_at := w.actors.pos(w.actors.index_of(aid))
	var start := _until_active(w, aid)
	CombatLab.idle(w, pat.duration_ticks() + pat.life_ticks + 2)
	var bs := w.bosses
	assert_eq(bs.jav_x.size(), pat.count * pat.waves, "every javelin stuck")
	var stuck := []
	for k in bs.jav_x.size():
		var at := Vector2(bs.jav_x[k], bs.jav_y[k])
		var d := Kin.dir(bs.jav_a[k])
		var off := (at - boss_at).cross(d)
		assert_almost_eq(off, 0.0, 0.05, "javelin %d on its line out from the Warlord" % k)
		assert_eq(bs.jav_back[k], start + atk.recall_at, "all come back on one tick")
		stuck.append([at, d])
	assert_eq(w.projectiles.size(), 0, "nothing flies while they stand")
	CombatLab.idle(w, start + atk.recall_at - w.tick + 2)
	assert_eq(bs.jav_x.size(), 0, "recalled")
	assert_eq(w.projectiles.size(), stuck.size(), "each flies back")
	for k in w.projectiles.size():
		var p := Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k])
		var v := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
		assert_eq(w.projectiles.cause_of(k), BossSignatures.LATE_CAUSE + w.bosses.attack[0])
		var on_a_line := false
		for j: Array in stuck:
			var d: Vector2 = j[1]
			if absf((p - boss_at).cross(d)) < 0.05 and v.dot(d) < 0.0:
				on_a_line = true
		assert_true(on_a_line, "javelin %d comes back along its own line, toward the Warlord" % k)
	CombatLab.idle(w, pat.life_ticks + 4)
	assert_eq(w.projectiles.size(), 0, "back at the Warlord")
	assert_eq(bs.jav_x.size(), 0, "and none sticks again")


func test_a_javelin_coming_back_names_its_death_line() -> void:
	var s := _fight(&"warlord", Vector2(20, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks + atk.pattern.duration_ticks() + atk.pattern.life_ticks + 2)
	# Stand on the middle javelin's line, halfway back, with a few HP.
	var bs := w.bosses
	var mid := bs.jav_x.size() / 2
	var at := Vector2(bs.jav_x[mid], bs.jav_y[mid])
	var boss_at := w.actors.pos(w.actors.index_of(aid))
	w.actors.set_pos(0, (at + boss_at) * 0.5)
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	w.actors.invuln[0] = 0
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 400)
	assert_true(w.player_dead(), "hit on the way back")
	assert_eq(BossAi.cause_key(w), &"CAUSE_WARLORD_RECALL")


func test_a_javelin_under_the_player_crumbles_instead_of_spawning_on_them() -> void:
	var s := _fight(&"warlord", Vector2(20, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	BossLab.start(w, w.actors.index_of(aid), &"javelin_fan")
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks + atk.pattern.duration_ticks() + atk.pattern.life_ticks + 2)
	var n := w.bosses.jav_x.size()
	var on := Vector2(w.bosses.jav_x[0], w.bosses.jav_y[0])
	w.actors.set_pos(0, on)
	var safe := atk.pattern.safe_radius_m + w.player.radius_m
	var under := 0
	for k in n:
		if Kin.length(Vector2(w.bosses.jav_x[k], w.bosses.jav_y[k]) - on) < safe:
			under += 1
	assert_gt(under, 0)
	CombatLab.until(w, func(x: World) -> bool: return x.bosses.jav_x.is_empty(), 300)
	assert_eq(w.projectiles.size(), n - under, "the ones under the player crumbled")


func test_the_warlords_javelins_are_deterministic_and_survive_a_save() -> void:
	var make := func() -> World:
		var s := _fight(&"warlord", Vector2(20, 0), Vector2.ZERO, true)
		var w: World = s[0]
		BossLab.start(w, w.actors.index_of(s[1]), &"javelin_fan_fast")
		CombatLab.idle(w, 150)  # v0.8.0 BP: they stick sooner and come back sooner (0.5 s; was 200 ticks)
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_gt(a.bosses.jav_x.size(), 0, "javelins stuck")
	assert_eq(a.state_hash(), b.state_hash())
	var base := BossLab.world()
	BossLab.ready_boss(base, &"warlord")
	_round_trip(a, base, "javelins")


# --- S3: the Brood Mother's eggs ---------------------------------------------------------------------------------


func _eggs(w: World) -> Array[int]:
	var out: Array[int] = []
	for i in w.actors.size():
		if BossSignatures.is_egg(w, i):
			out.append(i)
	return out


func _lay(w: World, aid: int, attack_id: StringName) -> BossAttackTable:
	BossLab.start(w, w.actors.index_of(aid), attack_id)
	var atk := _atk(w, aid)
	CombatLab.idle(w, atk.windup_ticks + atk.active_ticks + 2)
	return atk


func test_egg_storm_eggs_land_and_sit_as_targets() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	var atk := _lay(w, aid, &"egg_storm")
	assert_eq(atk.egg_ticks, 180, "3 s (a starting value)")
	var eggs := _eggs(w)
	assert_eq(eggs.size(), atk.count, "an egg on each circle")
	for i in eggs:
		assert_eq(w.actors.kinds[i], ActorStore.Kind.HATCHLING)
		assert_eq(w.actors.max_hp[i], atk.egg_hp, "little HP")
		assert_eq(w.actors.invuln[i], 0, "hittable at once")
		var at := w.actors.pos(i)
		CombatLab.idle(w, 1)
		assert_lt(Kin.length(w.actors.pos(i) - at), 0.05, "it sits still (bodies only nudge it)")


func test_an_egg_you_break_is_gone_and_counts_as_a_kill() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	_lay(w, aid, &"egg_storm")
	var eggs := _eggs(w)
	var egg_id := w.actors.ids[eggs[0]]
	var kills := w.kills
	var i := eggs[0]
	Damage.hit(
		w,
		i,
		8,
		w.actors.ids[0],
		w.actors.ids[0],
		w.take_root(),
		SimEvent.TAG_MELEE,
		w.player_pos(),
		w.actors.pos(i)
	)
	assert_lt(w.actors.hp[i], w.actors.max_hp[i], "it takes damage")
	assert_gt(w.actors.hp[i], 0, "a small hit leaves it standing")
	Damage.hit(
		w,
		i,
		99,
		w.actors.ids[0],
		w.actors.ids[0],
		w.take_root(),
		SimEvent.TAG_MELEE,
		w.player_pos(),
		w.actors.pos(i)
	)
	CombatLab.idle(w, 1)
	assert_eq(w.actors.index_of(egg_id), -1, "broken: gone")
	assert_eq(w.kills, kills + 1)
	assert_eq(_eggs(w).size(), eggs.size() - 1)


func test_an_egg_left_alone_hatches_on_time() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	var atk := _lay(w, aid, &"egg_storm")
	var eggs := _eggs(w)
	var ids: Array[int] = []
	for i in eggs:
		ids.append(w.actors.ids[i])
	var hatch_hp := w.enemy_table(ActorStore.Kind.HATCHLING).hp
	for id in ids:  # each in its turn, egg_ticks after it landed
		var i := w.actors.index_of(id)
		var left := atk.egg_ticks - w.actors.state_t[i]
		CombatLab.idle(w, left - 1)
		i = w.actors.index_of(id)
		assert_true(BossSignatures.is_egg(w, i), "still an egg a tick before")
		CombatLab.idle(w, 1)
		i = w.actors.index_of(id)
		assert_ne(i, -1, "hatched, not gone")
		assert_eq(w.actors.state[i], S.SPAWN, "a Hatchling rising")
		assert_eq(w.actors.max_hp[i], hatch_hp, "with its own HP")


func test_in_phase_three_eggs_burst_into_the_acid_star_instead() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	var b := BossAi.entry_of(w, w.actors.index_of(aid))
	w.bosses.phase[b] = 2
	var atk := _lay(w, aid, &"egg_storm_5")
	var eggs := _eggs(w)
	assert_eq(eggs.size(), atk.count)
	var kills := w.kills
	var last := eggs[eggs.size() - 1]
	var left := atk.egg_ticks - w.actors.state_t[last]
	w.actors.set_pos(0, Vector2(6, 9))
	var acid := 0
	var seq := w.last_event_seq()
	for t in left + 2:
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind != SimEvent.Kind.SPAWN:
				continue
			var k := w.projectiles.ids.find(e.source_id)
			if k >= 0 and w.projectiles.look_of(k) == "acid_glob":
				acid += 1
				var late := BossSignatures.LATE_CAUSE + _atk_index(w, aid, &"egg_storm_5")
				assert_eq(w.projectiles.cause_of(k), late, "the egg burst's own cause")
	assert_gt(acid, atk.count * 4, "each egg bursts into its star")
	# v0.8.0 BP: the boss starts nothing else meanwhile (its next pick, a brood's Hatchlings, is not an egg's).
	w.actors.cd[w.actors.index_of(aid)] = LONG
	CombatLab.idle(w, atk.pattern.duration_ticks())
	assert_eq(_eggs(w).size(), 0, "burst eggs are gone")
	assert_eq(w.kills, kills, "without a kill")
	for i in range(1, w.actors.size()):
		assert_ne(w.actors.kinds[i], ActorStore.Kind.HATCHLING, "nothing hatched")


func _atk_index(w: World, aid: int, attack_id: StringName) -> int:
	return BossAi.table_of(w, w.actors.index_of(aid)).attack_index(attack_id)


func test_an_egg_burst_names_its_death_line() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	w.bosses.phase[BossAi.entry_of(w, w.actors.index_of(aid))] = 2
	var atk := _lay(w, aid, &"egg_storm")
	assert_gt(_eggs(w).size(), 0)
	var bi := w.actors.index_of(aid)
	w.actors.state[bi] = BossAi.STAGGERED  # the Brood Mother holds still: only the eggs can kill
	w.bosses.stagger_t[BossAi.entry_of(w, bi)] = LONG
	var acid := func(x: World) -> bool:
		for k in x.projectiles.size():
			if x.projectiles.look_of(k) == "acid_glob":
				return true
		return false
	CombatLab.until(w, acid, atk.egg_ticks + 60)
	var k := 0
	while w.projectiles.look_of(k) != "acid_glob":
		k += 1
	var v := Vector2(w.projectiles.vel_x[k], w.projectiles.vel_y[k])
	w.actors.set_pos(0, Vector2(w.projectiles.pos_x[k], w.projectiles.pos_y[k]) + v.normalized())
	w.actors.hp[0] = 1
	w.actors.max_hp[0] = 100
	w.actors.invuln[0] = 0
	CombatLab.until(w, func(x: World) -> bool: return x.player_dead(), 60)
	assert_true(w.player_dead(), "a glob of the burst caught the player")
	assert_eq(BossAi.cause_key(w), &"CAUSE_BROOD_EGG_BURST")


func test_eggs_crumble_when_their_mother_dies() -> void:
	var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
	var w: World = s[0]
	var aid: int = s[1]
	_lay(w, aid, &"egg_storm")
	var n := _eggs(w).size()
	assert_gt(n, 0)
	var kills := w.kills
	var i := w.actors.index_of(aid)
	w.bosses.phase[BossAi.entry_of(w, i)] = 2  # past its gates
	w.actors.hp[i] = 1
	Damage.hit(
		w,
		i,
		999999,
		w.actors.ids[0],
		w.actors.ids[0],
		w.take_root(),
		0,
		w.actors.pos(i),
		w.actors.pos(i)
	)
	CombatLab.idle(w, 3)
	assert_eq(_eggs(w).size(), 0, "no egg outlives the Brood Mother")
	assert_eq(w.kills, kills + 1, "only the boss counted")


func test_the_eggs_are_deterministic_and_survive_a_save() -> void:
	var make := func() -> World:
		var s := _fight(&"brood_mother", Vector2(6, 0), Vector2.ZERO, true)
		var w: World = s[0]
		_lay(w, s[1], &"egg_storm_5")
		return w
	var a: World = make.call()
	var b: World = make.call()
	assert_gt(_eggs(a).size(), 0)
	assert_eq(a.state_hash(), b.state_hash())
	var base := BossLab.world()
	BossLab.ready_boss(base, &"brood_mother")
	_round_trip(a, base, "eggs")


# --- the fights' scripts after the trims -------------------------------------------------------------------------


func test_the_trimmed_moves_are_gone_from_the_fights() -> void:
	var gone := {
		&"gatekeeper": [&"cross_quake", &"cross_quake_fast"],
		&"warlord": [&"javelin_rain"],
		&"brood_mother": [&"web_spiral_fast"],
	}
	for t: BossTable in BossLab.tables():
		if not gone.has(t.id):
			continue
		for aid: StringName in gone[t.id]:
			assert_eq(t.attack_index(aid), -1, "%s: %s trimmed" % [t.id, aid])
		for k in t.phase_entry.size():
			assert_ne(
				t.phase_entry[k],
				-1 if k > 0 else -2,
				"%s phase %d opens with an attack" % [t.id, k]
			)
	var gk := (
		BossLab.tables().filter(func(x: BossTable) -> bool: return x.id == &"gatekeeper")[0]
		as BossTable
	)
	assert_eq(
		gk.attacks[gk.phase_entry[2]].id, &"shock_lanes_2", "phase 3 opens with two pillar crosses"
	)
	var bm := (
		BossLab.tables().filter(func(x: BossTable) -> bool: return x.id == &"brood_mother")[0]
		as BossTable
	)
	assert_eq(bm.attacks[bm.phase_entry[2]].id, &"egg_storm_5", "phase 3 opens with bursting eggs")
