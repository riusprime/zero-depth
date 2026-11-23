# gdlint: disable=max-public-methods
extends GutTest
## The Hive Lens's lattice (BossLens, BossGlass, BossLattice; SIM_CONTRACTS §10v): its drones feed it and its own
## Focus Beam cuts them, they are sent again, the burnt glass, the Lattice of light tick by tick, the rhythm with the
## Gaze over long fights, the end of a fight, determinism and a save mid-fight. The real compiled Hive Lens in
## JudgeLab's walled 24 m room (LensLab).

const P2 := 1
const P3 := 2
## Where _three puts its drones.
const PLACES := [Vector2(4, 0), Vector2(0, 8), Vector2(-7.07, -7.07)]


## The Hive Lens hushed (only its lattice runs) in phase `phase`, its clocks taken. Returns [world, its id].
func _ready_lens(phase: int, hero_at := Vector2(-10, 10), no_lattice := false) -> Array:
	var s := LensLab.fight(hero_at)
	var w: World = s[0]
	LensLab.hush(w, s[1])
	if no_lattice:
		LensLab.lens(w, s[1]).lat_phase = 9
	LensLab.set_phase(w, s[1], phase)
	w.step(InputFrame.new())
	return s


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The last event's seq (0 with none).
func _seq(w: World) -> int:
	var all := w.events_since(0)
	return 0 if all.is_empty() else all.back().seq


func _state(w: World) -> Dictionary:
	return WorldReader.new(w).boss_lens()


## Steps until `cond` holds (at most `limit` ticks). Returns true when it did.
func _until(w: World, cond: Callable, limit: int) -> bool:
	for k in limit:
		if cond.call():
			return true
		w.step(InputFrame.new())
	return cond.call()


## Three drones round the boss at distances 4, 8 and 10 m (angles 0, a quarter and five eighths of a turn).
func _three(w: World, aid: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for at: Vector2 in PLACES:
		out.append(LensLab.drone(w, aid, at))
	return out


## Steps until the web rises, holding the drones where they were placed. Returns the START event, or null.
func _until_web(w: World, ids: PackedInt32Array, at: Array, limit := 900) -> SimEvent:
	var seq := _seq(w)
	for k in limit:
		for n in ids.size():
			var j := w.actors.index_of(ids[n])
			if j >= 0 and w.actors.state[j] != BossLattice.ORBIT:
				w.actors.set_pos(j, at[n])
		w.step(InputFrame.new())
		var e := JudgeLab.effects(w, BossLattice.START, seq)
		if not e.is_empty():
			return e[0]
	return null


# --- the data -------------------------------------------------------------------------------------------------------


func test_the_data_is_valid_and_compiles_to_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"hive_lens")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var f := t.lens
	assert_not_null(f)
	assert_eq([f.feed_phase, f.feed_cut, f.feed_cap, f.resend_ticks], [1, 150, 450, 720], "feeding")
	assert_eq(f.split_attack, t.attack_index(&"split"))
	assert_eq(f.drone_kind, t.attacks[f.split_attack].enemy_kind, "its drones")
	assert_eq(
		Array(f.beams), [t.attack_index(&"focus_beam"), t.attack_index(&"focus_beam_3")], "beams"
	)
	assert_eq(
		[f.strip_phase, f.strip_len_m, f.strip_half_m, f.strip_ticks, f.strip_damage],
		[2, 8.0, 0.5, 360, 6],
		"the glass"
	)
	assert_eq([f.strip_step_ticks, f.strip_max], [30, 3])
	assert_eq(
		[
			f.lat_phase,
			f.lat_first_ticks,
			f.lat_every_ticks,
			f.lat_cast_ticks,
			f.lat_ticks,
			f.lat_min
		],
		[1, 600, 2700, 120, 600, 2],
		"the Lattice's clock"
	)
	assert_eq([f.strand_half_m, f.strand_hit, f.strand_lock_ticks], [0.3, 200, 30], "a strand")
	assert_eq([f.orbit_step, f.orbit_min_m, f.orbit_max_m, f.calm_ticks], [3793, 6.0, 12.0, 180])
	assert_eq(f.holds.size(), 7, "Gaze, Focus Beam, Dive and Prism Spiral (and their fast ones)")
	assert_eq(t.attacks[f.strand_cause].cause_key, &"CAUSE_HIVE_GLARE", "the recap")
	assert_eq(t.attacks[f.strip_cause].cause_key, &"CAUSE_HIVE_FOCUS")
	assert_null(ContentCompiler.compile_boss(repo.get_def(&"bosses", &"foundry"), repo).lens)


func test_the_rules_refuse_what_breaks_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"hive_lens")
	var cases := [
		[{"nonsense": 1}, &"unknown_field"],
		[{"feed_cut_permille": 600}, &"range"],
		[{"lattice_cast_seconds": 0.2}, &"telegraph_short"],
		[{"lattice_every_seconds": 12.0}, &"duration"],
		[{"orbit_min_m": 13.0}, &"range"],
		[{"strand_hit_permille": 500}, &"range"],
		[{"split_attack": "petal_bloom"}, &"attacks"],
		[{"strand_cause": "no_such_attack"}, &"attacks"],
		[{"lattice_holds": "gaze"}, &"type"],
		[{"beam_attacks": ["no_such_beam"]}, &"attacks"],
	]
	for c: Array in cases:
		var def: BossDefinition = base.duplicate(true)
		var f: Dictionary = def.lattice.duplicate()
		f.merge(c[0], true)
		def.lattice = f
		var codes := def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
		assert_true(codes.has(c[1]), "%s is refused (%s)" % [c[0], codes])


func test_no_lattice_state_in_the_first_phase() -> void:
	var s := _ready_lens(0)
	var w: World = s[0]
	LensLab.drone(w, s[1], Vector2(6, 0))
	LensLab.idle(w, 120)
	assert_eq(w.boss_fight.hl_boss, -1, "the first phase hashes as before")
	assert_eq(_state(w), {})
	assert_eq(BossLens.taken_permille(w, _i(w, s[1])), 1000, "no feeding in the first phase")


# --- feeding ------------------------------------------------------------------------------------------------------


func test_each_living_drone_cuts_fifteen_percent_up_to_forty_five() -> void:
	var s := _ready_lens(P2, Vector2(-10, 10), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	var hero := w.actors.ids[0]
	var hp := w.actors.hp[i]
	var base := Damage.tick_dot(w, i, 400, hero, hero, &"test_tick")
	assert_gt(base, 0)
	for n in range(1, 5):
		LensLab.drone(w, s[1], Vector2(8, -6 + n * 2))
		var want := 1000 - mini(450, 150 * n)
		assert_eq(BossLens.taken_permille(w, i), want, "%d drones" % n)
		assert_eq(int(_state(w)["cut"]), 1000 - want)
		assert_eq(_state(w)["drones"].size(), n, "the reader lists them")
		w.actors.hp[i] = hp
		var got := Damage.tick_dot(w, i, 400, hero, hero, &"test_tick")
		assert_eq(got, base * want / 1000, "%d drones: the tick is cut" % n)


# --- the cut ----------------------------------------------------------------------------------------------------------


func test_the_focus_beam_cuts_a_drone_on_its_line_and_not_one_beside() -> void:
	var s := _ready_lens(P2, Vector2(10, 0), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	var on_line := LensLab.drone(w, s[1], Vector2(5, 0))
	var beside := LensLab.drone(w, s[1], Vector2(5, 2.5))
	var seq := _seq(w)
	BossLab.start(w, i, &"focus_beam")
	var atk := BossAi.attack_of(w, i)
	var from := w.tick
	var cut_tick := -1
	for k in atk.windup_ticks + atk.active_ticks + 30:
		for pair: Array in [[on_line, Vector2(5, 0)], [beside, Vector2(5, 2.5)]]:
			var j := w.actors.index_of(int(pair[0]))
			if j >= 0:
				w.actors.set_pos(j, pair[1])
		w.step(InputFrame.new())
		if cut_tick < 0 and not JudgeLab.effects(w, BossLens.DRONE_CUT, seq).is_empty():
			cut_tick = w.tick - 1
	var cuts := JudgeLab.effects(w, BossLens.DRONE_CUT, seq)
	assert_eq(cuts.size(), 1, "one drone cut")
	if cuts.size() == 1:
		assert_eq(cuts[0].target_id, on_line, "the one on the beam's line")
	assert_lt(w.actors.index_of(on_line), 0, "it is gone")
	assert_gte(w.actors.index_of(beside), 0, "the one beside it lives")
	assert_eq(
		cut_tick, from + atk.windup_ticks - 1, "cut as the beam begins to burn, not in its windup"
	)
	assert_eq(w.boss_fight.hl_cuts, 1)
	assert_eq(int(_state(w)["cuts"]), 1)


func test_drones_are_sent_again_twelve_seconds_after_the_last_dies() -> void:
	var s := _ready_lens(P2, Vector2(-10, 10), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := LensLab.lens(w, s[1])
	var d := LensLab.drone(w, s[1], Vector2(8, 0))
	LensLab.idle(w, 900)
	assert_eq(w.boss_fight.hl_empty_at, -1, "with one alive, no clock")
	assert_ne(w.bosses.attack[BossAi.entry_of(w, i)], f.split_attack, "and no split")
	var j := w.actors.index_of(d)
	w.actors.hp[j] = 0
	w.actors.dead[j] = 1
	w.step(InputFrame.new())
	var empty := w.boss_fight.hl_empty_at
	assert_eq(empty, w.tick - 1, "the clock starts as the last one goes")
	assert_eq(int(_state(w)["resend_in"]), f.resend_ticks - 1)
	var split_at := -1
	for k in f.resend_ticks + 5:
		w.step(InputFrame.new())
		if w.bosses.attack[BossAi.entry_of(w, i)] == f.split_attack:
			split_at = w.tick - 1
			break
	assert_eq(split_at, empty + f.resend_ticks, "the split, 12 s after")
	var atk := BossAi.attack_of(w, i)
	LensLab.idle(w, atk.windup_ticks + 3)
	assert_eq(BossLens.drones(w, f).size(), 3, "three drones again")
	assert_eq(w.boss_fight.hl_empty_at, -1)


# --- the burnt glass ----------------------------------------------------------------------------------------------


func test_the_beam_leaves_burnt_glass_that_burns_in_steps_and_goes() -> void:
	var s := _ready_lens(P3, Vector2(6, 0), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := LensLab.lens(w, s[1])
	var seq := _seq(w)
	BossLab.start(w, i, &"focus_beam_3")
	var atk := BossAi.attack_of(w, i)
	var ends: Array[Vector2] = []
	var last := -1  # The last tick the beam burned (a hit's freeze holds the world, not this clock)
	for k in 600:
		w.step(InputFrame.new())
		if w.actors.state[i] == EnemyAi.State.ACTIVE:
			if last < 0 and w.actors.state_t[i] == atk.active_ticks - 1:
				last = w.tick - 1
			if ends.is_empty():
				for n in atk.count:
					var o := BossAi.lane_of(w, i, n)
					ends.append(o.center + o.axis_u * o.half.x)
		elif ends.size() > 0:
			break
	var laid := JudgeLab.effects(w, BossGlass.LAID, seq)
	assert_eq(laid.size(), 3, "a strip for each lane")
	if laid.size() != 3:
		return
	var lay_tick := last
	assert_eq(laid[0].tick, lay_tick, "laid on the last tick the beam burns")
	var rows: Array = _state(w)["glass"]
	assert_eq(rows.size(), 3)
	for n in rows.size():
		var r: Dictionary = rows[n]
		assert_almost_eq(
			(r["to"] as Vector2).distance_to(ends[n]), 0.0, 0.01, "it ends where the lane does"
		)
		assert_almost_eq((r["to"] as Vector2).distance_to(r["from"]), 8.0, 0.01, "its far 8 m")
		assert_eq(int(r["left"]), lay_tick + f.strip_ticks - w.tick, "6 s from when it was laid")
	# The hero on the middle strip pays a step every half second, through the hurt invulnerability
	var mid: Dictionary = rows[1]
	var on: Vector2 = ((mid["from"] as Vector2) + (mid["to"] as Vector2)) * 0.5
	var seq2 := _seq(w)
	var at: Array[int] = []
	for k in 120:
		w.actors.set_pos(0, on)
		if k == 40:
			w.actors.invuln[0] = 25
		w.step(InputFrame.new())
		for e in LensLab.hurts(w, BossGlass.EFFECT, seq2):
			if not at.has(e.tick):
				at.append(e.tick)
	assert_eq(at.size(), 4, "four steps in two seconds (%s)" % [at])
	for n in range(1, at.size()):
		assert_eq(at[n] - at[n - 1], f.strip_step_ticks, "on its beat")
	for e in LensLab.hurts(w, BossGlass.EFFECT, seq2):
		assert_eq(e.amount, BossAi.powered(w, i, f.strip_damage), "6 damage")
	LensLab.idle(w, lay_tick + f.strip_ticks - w.tick + 1)
	assert_eq(w.boss_fight.hl_s_x.size(), 0, "they go after 6 s")
	assert_eq(JudgeLab.effects(w, BossGlass.GONE, seq).size(), 3)


func test_at_most_three_strips_the_oldest_goes_first() -> void:
	var s := _ready_lens(P3, Vector2(6, 0), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"focus_beam_3")
	assert_true(_until(w, func() -> bool: return w.boss_fight.hl_s_x.size() == 3, 300))
	var first := w.boss_fight.hl_s_from.duplicate()
	assert_true(_until(w, func() -> bool: return w.actors.state[i] == EnemyAi.State.MOVE, 300))
	w.actors.set_pos(0, Vector2(0, 6))
	BossLab.start(w, i, &"focus_beam")
	var seq := _seq(w)
	assert_true(
		_until(
			w, func() -> bool: return not JudgeLab.effects(w, BossGlass.LAID, seq).is_empty(), 300
		)
	)
	var fs := w.boss_fight
	assert_eq(fs.hl_s_x.size(), 3, "still three")
	assert_eq(fs.hl_s_from[0], first[1], "the oldest went")
	assert_eq(fs.hl_s_from[2], w.tick - 1, "the newest is the single beam's")
	assert_eq(JudgeLab.effects(w, BossGlass.GONE, seq).size(), 1)


func test_no_glass_before_the_last_phase() -> void:
	var s := _ready_lens(P2, Vector2(6, 0), true)
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"focus_beam")
	LensLab.idle(w, 200)
	assert_eq(w.boss_fight.hl_s_x.size(), 0)


# --- the Lattice --------------------------------------------------------------------------------------------------


func test_the_lattice_is_cast_on_its_clock_and_its_web_turns() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := LensLab.lens(w, s[1])
	var due := w.boss_fight.hl_due
	assert_eq(due, w.tick - 1 + f.lat_first_ticks, "10 s into the phase")
	var ids := _three(w, s[1])
	var seq := _seq(w)
	var web := _until_web(w, ids, PLACES)
	assert_not_null(web, "the web rose")
	if web == null:
		return
	var casts := JudgeLab.effects(w, BossLattice.CAST, seq)
	assert_eq(casts.size(), 1)
	assert_eq(casts[0].tick, due, "cast when due")
	assert_eq(casts[0].amount, f.lat_cast_ticks)
	assert_eq(web.tick, due + f.lat_cast_ticks, "the web 2 s later")
	assert_eq(web.amount_applied, 3)
	var fs := w.boss_fight
	assert_eq(fs.hl_spin, casts[0].amount_applied)
	assert_eq(Array(fs.hl_d_id), Array(ids), "in the order of their angle")
	for id in ids:
		assert_eq(
			w.actors.state[w.actors.index_of(id)], BossLattice.ORBIT, "they stop their own ways"
		)
	var st: Dictionary = _state(w)["lattice"]
	assert_true(st["running"])
	var lines: Array = st["strands"]
	assert_eq(lines.size(), 4, "boss, three drones, boss")
	var boss: int = s[1]
	assert_eq(
		lines.map(func(l: Dictionary) -> Array: return [l["a"], l["b"]]),
		[[boss, ids[0]], [ids[0], ids[1]], [ids[1], ids[2]], [ids[2], boss]],
	)
	# The turn: 20 degrees a second, the distance eased to 6..12 m
	var a0 := Array(fs.hl_d_a)
	LensLab.idle(w, 60)
	var c := w.actors.pos(i)
	for k in 3:
		var want := posmod(int(a0[k]) + fs.hl_spin * 60 * f.orbit_step, BossLattice.TURN)
		assert_eq(fs.hl_d_a[k], want, "drone %d turned 60 steps" % k)
		var p := w.actors.pos(w.actors.index_of(ids[k]))
		assert_almost_eq(p.distance_to(c + Kin.dir(want / 1000) * Kin.length(p - c)), 0.0, 0.002)
	assert_almost_eq(absf(float(fs.hl_spin * 60 * f.orbit_step) / 1000.0), 227.6, 0.1, "20 degrees")
	var near := w.actors.pos(w.actors.index_of(ids[0]))
	assert_almost_eq(Kin.length(near - c), 6.0, 0.01, "the drone 4 m out eased to 6 m")
	var mid := w.actors.pos(w.actors.index_of(ids[1]))
	assert_almost_eq(Kin.length(mid - c), 8.0, 0.05, "8 m stays 8 m")
	var seq2 := _seq(w)
	assert_true(
		_until(
			w, func() -> bool: return not JudgeLab.effects(w, BossLattice.END, seq2).is_empty(), 700
		)
	)
	var end := JudgeLab.effects(w, BossLattice.END, seq2)[0]
	assert_eq(end.tick, web.tick + f.lat_ticks, "10 s of web")
	assert_eq(end.amount, 3)
	for id in ids:
		assert_eq(
			w.actors.state[w.actors.index_of(id)], EnemyAi.State.MOVE, "back to their own ways"
		)
	assert_eq(fs.hl_d_id.size(), 0)
	assert_eq(fs.hl_due, due + f.lat_every_ticks, "the next 45 s after this one's cast")


func test_a_strand_costs_twenty_percent_at_most_twice_a_second() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var ids := _three(w, s[1])
	assert_not_null(_until_web(w, ids, PLACES))
	var seq := _seq(w)
	for k in 120:
		var line: Dictionary = _state(w)["lattice"]["strands"][1]
		w.actors.set_pos(0, ((line["from"] as Vector2) + (line["to"] as Vector2)) * 0.5)
		w.step(InputFrame.new())
	var hits := JudgeLab.effects(w, BossLattice.STRAND_HIT, seq)
	assert_between(hits.size(), 3, 4, "at most twice a second")
	for n in range(1, hits.size()):
		assert_gte(hits[n].tick - hits[n - 1].tick, LensLab.lens(w, s[1]).strand_lock_ticks)
	var cost := SafeArea.cost(w, 200)
	for e in hits:
		assert_lte(e.amount, cost, "20 % of max HP")
		assert_gt(e.amount, cost * 9 / 10)


func test_killing_a_drone_removes_its_two_strands_and_the_gap_stays() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var ids := _three(w, s[1])
	assert_not_null(_until_web(w, ids, PLACES))
	var j := w.actors.index_of(ids[1])
	w.actors.hp[j] = 0
	w.actors.dead[j] = 1
	LensLab.idle(w, 2)
	var lines: Array = _state(w)["lattice"]["strands"]
	assert_eq(
		lines.map(func(l: Dictionary) -> Array: return [l["a"], l["b"]]),
		[[s[1], ids[0]], [ids[2], s[1]]],
		"the two strands at it are gone and no new one joins its neighbours"
	)
	# Where the strand between its neighbours would be, nothing hurts
	var seq := _seq(w)
	for k in 60:
		var a := w.actors.pos(w.actors.index_of(ids[0]))
		var b := w.actors.pos(w.actors.index_of(ids[2]))
		w.actors.set_pos(0, (a + b) * 0.5)
		w.step(InputFrame.new())
	assert_eq(JudgeLab.effects(w, BossLattice.STRAND_HIT, seq).size(), 0, "the gap is safe")


func test_the_lattice_holds_the_attacks_it_may_not_use() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := LensLab.table(w, s[1])
	var f := LensLab.lens(w, s[1])
	var ids := _three(w, s[1])
	assert_true(_until(w, func() -> bool: return BossLattice.busy(w), 900), "the cast begins")
	for stage in 2:
		for id: StringName in [&"gaze", &"focus_beam", &"focus_beam_3", &"dive", &"prism_spiral"]:
			assert_false(BossLens.may_use(w, i, t.attacks[t.attack_index(id)]), "%s held" % id)
		for id: StringName in [&"petal_bloom", &"lens_flare", &"split"]:
			assert_true(BossLens.may_use(w, i, t.attacks[t.attack_index(id)]), "%s allowed" % id)
		var b := BossAi.entry_of(w, i)
		assert_eq(BossLens.unless_held(w, b, t.attack_index(&"focus_beam")), -1, "no punish beam")
		assert_eq(BossLens.unless_held(w, b, t.attack_index(&"dive")), -1, "no dive")
		if stage == 0:
			assert_not_null(_until_web(w, ids, PLACES), "and through the web")
	assert_true(_until(w, func() -> bool: return not BossLattice.busy(w), 700))
	assert_true(BossLens.may_use(w, i, t.attacks[t.attack_index(&"focus_beam")]), "after it")
	assert_false(
		BossLens.may_use(w, i, t.attacks[t.attack_index(&"gaze")]), "the Gaze waits its calm"
	)
	LensLab.idle(w, f.calm_ticks)
	assert_true(BossLens.may_use(w, i, t.attacks[t.attack_index(&"gaze")]), "then it may")


func test_with_too_few_drones_the_split_comes_first() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := LensLab.lens(w, s[1])
	var split_at := -1
	var cast_at := -1
	for k in 1200:
		w.step(InputFrame.new())
		if split_at < 0 and w.bosses.attack[BossAi.entry_of(w, i)] == f.split_attack:
			split_at = w.tick - 1
		if w.boss_fight.hl_cast_from >= 0:
			cast_at = w.boss_fight.hl_cast_from
			break
	assert_gte(split_at, 0, "the split")
	assert_gt(cast_at, split_at, "then the cast")
	assert_gte(BossLens.drones(w, f).size(), f.lat_min)


func test_a_cast_left_with_too_few_drones_raises_no_web() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var ids := _three(w, s[1])
	assert_true(_until(w, func() -> bool: return w.boss_fight.hl_cast_from >= 0, 900))
	var seq := _seq(w)
	for n in 2:
		var j := w.actors.index_of(ids[n])
		w.actors.hp[j] = 0
		w.actors.dead[j] = 1
	LensLab.idle(w, LensLab.lens(w, s[1]).lat_cast_ticks + 2)
	assert_eq(JudgeLab.effects(w, BossLattice.START, seq).size(), 0, "no web")
	var ends := JudgeLab.effects(w, BossLattice.END, seq)
	assert_eq(ends.size(), 1)
	if ends.size() == 1:
		assert_eq(ends[0].amount, 0)
	assert_false(BossLattice.busy(w))


# --- the rhythm over long fights ----------------------------------------------------------------------------------


## The real fight (nothing hushed) in `phase` for `ticks`, the hero standing still and too tough to die, the boss kept
## in its phase. Returns its numbers: "lattice" and "gaze" (ticks each ran: the Lattice cast or web, the Gaze wound up
## or burning), "lattices", "gazes" (begun), "overlap" (ticks both ran), "short_calm" (a start less than the calm after
## the other ended), "hash".
func _rhythm(phase: int, ticks: int, seed_value: int) -> Dictionary:
	var s := LensLab.fight(Vector2(-8, 0), Vector2(4, 0), seed_value)
	var w: World = s[0]
	LensLab.set_phase(w, s[1], phase)
	var calm := LensLab.lens(w, s[1]).calm_ticks
	var out := {"lattice": 0, "gaze": 0, "lattices": 0, "gazes": 0, "overlap": 0, "short_calm": 0}
	var was_l := false
	var was_g := false
	var l_end := -100000
	var g_end := -100000
	var hp := -1
	for k in ticks:
		var i := _i(w, s[1])
		if hp < 0:
			hp = w.actors.hp[i]
		w.actors.hp[i] = hp
		w.actors.hp[0] = LensLab.LONG
		w.step(InputFrame.new())
		var l := BossLattice.busy(w)
		var g := BossLens.gazing(w, _i(w, s[1]))
		out["lattice"] += 1 if l else 0
		out["gaze"] += 1 if g else 0
		out["overlap"] += 1 if l and g else 0
		if l and not was_l:
			out["lattices"] += 1
			if w.tick - 1 - g_end < calm:
				out["short_calm"] += 1
		if g and not was_g:
			out["gazes"] += 1
			if w.tick - 1 - l_end < calm:
				out["short_calm"] += 1
		if was_l and not l:
			l_end = w.tick - 1
		if was_g and not g:
			g_end = w.tick - 1
		was_l = l
		was_g = g
	out["hash"] = w.state_hash()
	return out


func test_the_lattice_and_the_gaze_never_meet_over_long_fights() -> void:
	var minutes := 3
	for phase in [0, P2, P3]:
		var r := _rhythm(phase, 60 * 60 * minutes, 5)
		print(
			(
				"LENSRHYTHM| phase=%d minutes=%d lattice_s=%.1f gaze_s=%.1f big_s_per_min=%.1f lattices=%d gazes=%d"
				% [
					phase + 1,
					minutes,
					r["lattice"] / 60.0,
					r["gaze"] / 60.0,
					(r["lattice"] + r["gaze"]) / 60.0 / minutes,
					r["lattices"],
					r["gazes"],
				]
			)
		)
		assert_eq(r["overlap"], 0, "phase %d: never together" % (phase + 1))
		assert_eq(r["short_calm"], 0, "phase %d: 3 s of calm between them" % (phase + 1))
		if phase > 0:
			assert_gte(r["lattices"], 4, "phase %d: a Lattice every 45 s" % (phase + 1))


func test_a_fight_is_deterministic() -> void:
	var a := _rhythm(P2, 60 * 40, 7)
	var b := _rhythm(P2, 60 * 40, 7)
	assert_eq(a["hash"], b["hash"], "two runs agree")
	assert_eq(a["lattice"], b["lattice"])


# --- the end of a fight, saves ------------------------------------------------------------------------------------


func _glass(w: World, at: Vector2) -> void:
	var fs := w.boss_fight
	fs.hl_s_from.append(w.tick)
	fs.hl_s_until.append(w.tick + 6000)
	fs.hl_s_a.append(0)
	fs.hl_s_x.append(at.x - 4.0)
	fs.hl_s_y.append(at.y)
	fs.hl_s_len.append(8.0)


func test_the_heros_death_ends_the_lattice_and_takes_the_glass() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var ids := _three(w, s[1])
	assert_not_null(_until_web(w, ids, PLACES))
	_glass(w, Vector2(-9, -9))
	w.actors.hp[0] = 1
	w.actors.invuln[0] = 0
	for k in 30:
		if w.player_dead():
			break
		var line: Dictionary = _state(w)["lattice"]["strands"][1]
		w.actors.set_pos(0, ((line["from"] as Vector2) + (line["to"] as Vector2)) * 0.5)
		w.step(InputFrame.new())
	w.step(InputFrame.new())
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_HIVE_GLARE", "the recap names the Lens's light")
	assert_false(BossLattice.busy(w), "the Lattice ends")
	assert_eq(w.boss_fight.hl_s_x.size(), 0, "the glass goes")
	for id in ids:
		var j := w.actors.index_of(id)
		if j >= 0:
			assert_eq(w.actors.state[j], EnemyAi.State.MOVE)


func test_the_glass_names_the_focus_beam_in_the_recap() -> void:
	var s := _ready_lens(P3, Vector2(-9, -9), true)
	var w: World = s[0]
	_glass(w, Vector2(-9, -9))
	w.actors.hp[0] = 1
	LensLab.idle(w, 40)
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_HIVE_FOCUS")


func test_everything_goes_with_the_lens() -> void:
	var s := _ready_lens(P2)
	var w: World = s[0]
	var ids := _three(w, s[1])
	assert_not_null(_until_web(w, ids, PLACES))
	_glass(w, Vector2(-9, -9))
	var i := _i(w, s[1])
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	LensLab.idle(w, 2)
	assert_eq(w.boss_fight.hl_boss, -1)
	assert_eq(w.boss_fight.hl_s_x.size(), 0)
	assert_eq(w.boss_fight.hl_d_id.size(), 0)
	assert_eq(_state(w), {})


func test_a_save_mid_lattice_restores() -> void:
	# The real fight (a save keeps the content, so nothing is hushed), in the last phase, saved while a web stands
	var s := LensLab.fight(Vector2(-8, 0), Vector2(4, 0), 7)
	var w: World = s[0]
	LensLab.set_phase(w, s[1], P3)
	var hp := w.actors.hp[_i(w, s[1])]
	for k in 2400:
		w.actors.hp[_i(w, s[1])] = hp
		w.step(InputFrame.new())
		w.actors.hp[0] = LensLab.LONG
		if BossLattice.running(w) and w.tick - w.boss_fight.hl_run_from > 30:
			break
	assert_true(BossLattice.running(w), "a web stands")
	if not BossLattice.running(w):
		return
	_glass(w, Vector2(-9, -9))
	var before := w.state_hash()
	w.boss_fight.hl_d_a[0] += 1
	assert_ne(w.state_hash(), before, "the web is hashed")
	w.boss_fight.hl_d_a[0] -= 1
	w.boss_fight.hl_s_x[0] += 0.5
	assert_ne(w.state_hash(), before, "and the glass")
	w.boss_fight.hl_s_x[0] -= 0.5
	var snap := WorldSnapshot.take(w)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(11))
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), w.state_hash(), "same hash restored")
	assert_eq(WorldReader.new(restored).boss_lens(), WorldReader.new(w).boss_lens())
	for k in 600:
		var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
		w.step(f)
		restored.step(f)
		w.actors.hp[0] = LensLab.LONG
		restored.actors.hp[0] = LensLab.LONG
	assert_eq(restored.state_hash(), w.state_hash(), "same hash 600 ticks on")
