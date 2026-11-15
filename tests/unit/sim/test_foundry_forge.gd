# gdlint: disable=max-public-methods
extends GutTest
## The Foundry's forge (BossForge, BossSlag), in ForgeLab's walled 24 m room: the Forged Plate's clock, its
## multipliers and its only way off (a drone's bomb landing by the Foundry); pools cooling into slabs, crumbling and
## shattered by the vent blast; Overpressure's clock, its cost off a slab, its wait for a safe slab and its marker; the
## scald gauge's arithmetic and burn; what ends with the fight; a seed loop for a safe slab at every Overpressure in
## the real fight; determinism and a save; the Overclock heat untouched.

const NEVER := 9
const PLATE := 1
const LAST := 2


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _fx(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return JudgeLab.effects(w, effect, seq)


func _state(w: World) -> Dictionary:
	return WorldReader.new(w).boss_forge()


## Steps `n` ticks, the hero idle and refilled each tick. Returns the HP it lost.
func _idle(w: World, n: int) -> int:
	var lost := 0
	for k in n:
		w.step(InputFrame.new())
		lost += ForgeLab.take_lost(w)
	return lost


## A hushed, still Foundry at the room's centre in phase index `phase`, with only the named parts of its forge on.
## The hero has 1000 HP, refilled by _idle.
func _only(hero_at: Vector2, phase: int, parts: Array, seed_value: int = 11) -> Array:
	var s := ForgeLab.fight(hero_at, Vector2.ZERO, seed_value)
	var w: World = s[0]
	ForgeLab.hush(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	if not parts.has("plate"):
		f.plate_phase = NEVER
	if not parts.has("slab"):
		f.slab_phase = NEVER
	if not parts.has("drop"):
		f.drop_ticks = 0
	if not parts.has("over"):
		f.over_phase = NEVER
	if not parts.has("scald"):
		f.scald_phase = NEVER
	ForgeLab.set_phase(w, s[1], phase)
	w.actors.max_hp[0] = 1000
	w.actors.hp[0] = 1000
	w.step(InputFrame.new())  # The forge takes its clocks (it forgets what it held before)
	w.actors.hp[0] = 1000
	return s


## A hit of `amount` from the hero on boss i, from 1 m off its edge: [the HIT's amount, the DAMAGE's amount, tags].
func _hero_hit(w: World, i: int, amount: int) -> Array:
	var seq := w.last_event_seq()
	var from := w.actors.pos(i) + Vector2(w.actors.radius[i] + 1.0, 0.0)
	var hero := w.actors.ids[0]
	Damage.hit(
		w, i, amount, hero, hero, w.take_root(), SimEvent.TAG_PROJECTILE, from, w.actors.pos(i)
	)
	var out := [0, 0, 0]
	for e in w.events_since(seq):
		if e.target_id != w.actors.ids[i]:
			continue
		if e.kind == SimEvent.Kind.HIT:
			out[0] = e.amount
		elif e.kind == SimEvent.Kind.DAMAGE:
			out[1] = e.amount
			out[2] = e.tags
	return out


# --- content --------------------------------------------------------------------------------------------------


func test_the_data_is_valid_and_compiles_to_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"foundry")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	var f := t.forge
	assert_not_null(f)
	assert_eq(
		[f.plate_phase, f.plate_first_ticks, f.plate_every_ticks, f.plate_cast_ticks],
		[1, 480, 1200, 90],
		"the plate's clock"
	)
	assert_eq([f.plate_taken, f.exposed_ticks, f.exposed_taken], [400, 300, 1250], "its shares")
	assert_eq(f.drone_kind, t.attacks[t.attack_index(&"bomb_launch")].enemy_kind, "its drones")
	assert_eq(
		[f.slab_phase, f.slab_cool_ticks, f.slab_ticks, f.drop_ticks],
		[2, 720, 480, 360],
		"the slag"
	)
	assert_eq(
		[f.over_phase, f.over_first_ticks, f.over_every_ticks, f.over_cast_ticks, f.over_ticks],
		[2, 600, 1320, 180, 240],
		"Overpressure"
	)
	assert_eq([f.over_step_ticks, f.over_hit], [30, 30], "6 % a second in 0.5 s steps")
	assert_eq(
		[f.scald_phase, f.scald_max, f.scald_hit, f.scald_lava, f.scald_open, f.scald_drain],
		[2, 1000, 200, 60, 40, 125],
		"the gauge"
	)
	assert_eq([f.scald_step_ticks, f.scald_burn], [30, 25], "5 % a second in 0.5 s steps")
	assert_eq(t.attacks[f.over_cause].cause_key, &"CAUSE_FOUNDRY_FIRESTORM", "the recap")
	assert_eq(t.attacks[f.scald_cause].cause_key, &"CAUSE_FOUNDRY_FLOOD")
	assert_null(ContentCompiler.compile_boss(repo.get_def(&"bosses", &"tidecaller"), repo).forge)


func test_the_rules_refuse_what_breaks_the_brief() -> void:
	var repo := ContentRepository.load_all()
	var base: BossDefinition = repo.get_def(&"bosses", &"foundry")
	var cases := [
		[{"nonsense": 1}, &"unknown_field"],
		[{"plate_taken_permille": 1200}, &"range"],
		[{"plate_cast_seconds": 0.2}, &"telegraph_short"],
		[{"overpressure_every_seconds": 6.0}, &"duration"],
		[{"slab_seconds": 6.0}, &"duration"],
		[{"overpressure_permille_per_second": 200, "overpressure_tick_seconds": 2.5}, &"range"],
		[{"scald_cause": "no_such_attack"}, &"attacks"],
	]
	for c: Array in cases:
		var def: BossDefinition = base.duplicate(true)
		var f: Dictionary = def.forge.duplicate()
		f.merge(c[0], true)
		def.forge = f
		var codes := def.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
		assert_true(codes.has(c[1]), "%s is refused (%s)" % [c[0], codes])


# --- the plate ----------------------------------------------------------------------------------------------------


func test_no_forge_before_its_phase() -> void:
	var s := _only(Vector2(-8, 0), 0, ["plate", "slab", "over", "scald"])
	var w: World = s[0]
	_idle(w, 900)
	assert_eq(w.bosses.fg_boss, -1, "nothing runs (and nothing is hashed) in the first phase")
	assert_eq(_state(w), {})


func test_the_plate_is_forged_on_its_clock() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["plate"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	var t0 := w.tick - 1  # The forge took its clocks on _only's step
	_idle(w, 600)
	var cast := _fx(w, BossForge.FORGE_CAST)
	var on := _fx(w, BossForge.PLATE_ON)
	assert_eq(cast.size(), 1)
	assert_eq(on.size(), 1)
	if cast.is_empty() or on.is_empty():
		return
	assert_eq(cast[0].tick - t0, f.plate_first_ticks, "the first forging 8 s into its phase")
	assert_eq(cast[0].amount, f.plate_cast_ticks)
	assert_eq(on[0].tick - cast[0].tick, f.plate_cast_ticks, "worn 1.5 s later")
	assert_true(_state(w)["plate"]["on"])
	assert_eq(_state(w)["plate"]["taken"], 400)


func test_the_plate_takes_sixty_percent_less_and_the_exposed_hull_more() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["plate"])
	var w: World = s[0]
	var i := _i(w, s[1])
	# The other shares on a hit (the far shot's, …) are the same each time: the plate's is measured against them
	var bare := _hero_hit(w, i, 1000)
	assert_gt(bare[1], 0)
	assert_eq(bare[2] & (SimEvent.TAG_ARMOURED | SimEvent.TAG_WEAK_SPOT), 0, "unplated: plain")
	var dot0 := _hero_dot(w, i, 1000)
	w.bosses.fg_plate = 1
	var plated := _hero_hit(w, i, 1000)
	assert_eq(plated[0], bare[0])
	assert_almost_eq(plated[1], bare[1] * 400 / 1000, 1, "plated: 40 %")
	assert_ne(plated[2] & SimEvent.TAG_ARMOURED, 0, "an armoured hit")
	assert_almost_eq(_hero_dot(w, i, 1000), dot0 * 400 / 1000, 1, "a damage tick too")
	w.bosses.fg_plate = 0
	w.bosses.fg_exposed_until = w.tick + 10
	var open := _hero_hit(w, i, 1000)
	assert_almost_eq(open[1], bare[1] * 1250 / 1000, 1, "exposed: 125 %")
	assert_ne(open[2] & SimEvent.TAG_WEAK_SPOT, 0)


## A damage tick of `amount` from the hero on boss i: the DAMAGE's amount.
func _hero_dot(w: World, i: int, amount: int) -> int:
	var seq := w.last_event_seq()
	w.actors.invuln[i] = 0
	Damage.tick_dot(w, i, amount, w.actors.ids[0], w.actors.ids[0], &"burn")
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[i]:
			return e.amount
	return 0


func test_a_drone_bomb_landing_by_the_foundry_blows_the_plate_off() -> void:
	var s := _only(Vector2(2.6, 0), PLATE, ["plate"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	w.bosses.fg_plate_due = w.tick  # forge at once
	_idle(w, f.plate_cast_ticks + 2)
	assert_eq(w.bosses.fg_plate, 1, "plated")
	var drones := _fx(w, BossForge.PLATE_DRONE)
	assert_eq(drones.size(), 1, "a drone is launched with the plate, none being alive")
	var on_tick := _fx(w, BossForge.PLATE_ON)[0].tick
	assert_eq(drones[0].tick, on_tick, "on the plate's own tick")
	var blown: SimEvent = null
	for k in 900:
		w.step(InputFrame.new())
		ForgeLab.take_lost(w)
		var got := _fx(w, BossForge.PLATE_BLOWN)
		if not got.is_empty():
			blown = got[0]
			break
	assert_not_null(blown, "the drone's bomb, thrown at the hero beside the Foundry, blew it off")
	if blown == null:
		return
	var di := w.actors.index_of(blown.target_id)
	assert_eq(w.actors.kinds[di], f.drone_kind, "a drone's")
	var bomb_hit := false
	for e in w.events_since(0):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.owner_id == blown.target_id
			and e.tick == blown.tick
		):
			bomb_hit = e.target_id == w.actors.ids[0]
	assert_true(bomb_hit, "on the tick its bomb landed (it hit the hero standing there too)")
	assert_eq(blown.amount, f.exposed_ticks)
	assert_eq(w.bosses.fg_plate, 0)
	assert_eq(_state(w)["plate"]["taken"], 1250, "exposed")
	assert_eq(w.bosses.fg_plate_due, blown.tick + f.plate_every_ticks, "the next forging in 20 s")
	_idle(w, f.exposed_ticks)
	assert_eq(_state(w)["plate"]["taken"], 1000, "5 s later the hull is plain again")
	var next := JudgeLab.until_effect(w, BossForge.FORGE_CAST, f.plate_every_ticks, blown.seq)
	assert_not_null(next)
	if next != null:
		assert_eq(next.tick - blown.tick, f.plate_every_ticks)


func test_nothing_else_takes_the_plate_off() -> void:
	var s := _only(Vector2(-10, 0), PLATE, ["plate"])
	var w: World = s[0]
	var i := _i(w, s[1])
	w.bosses.fg_plate = 1
	var landed := 0
	var blown := 0
	var kind := ForgeLab.forge(w, s[1]).drone_kind
	for k in 1200:
		var seq0 := w.last_event_seq()
		w.step(InputFrame.new())
		ForgeLab.take_lost(w)
		if k % 20 == 0:
			_hero_hit(w, i, 50)  # the hero's own hits
		for e in w.events_since(seq0):
			var di := w.actors.index_of(e.owner_id)
			if di > 0 and e.kind == SimEvent.Kind.DAMAGE and e.target_id == w.actors.ids[0]:
				landed += 1 if w.actors.kinds[di] == kind else 0
			if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossForge.PLATE_BLOWN:
				blown += 1
	assert_gt(landed, 0, "the drones' bombs landed on the hero, far from the Foundry")
	assert_eq(blown, 0, "and the plate stayed")
	assert_eq(w.bosses.fg_plate, 1)
	# A drone the hero kills beside the Foundry does not explode: still plated, and another is launched
	var f := ForgeLab.forge(w, s[1])
	var seq := w.last_event_seq()
	for j in range(1, w.actors.size()):
		if w.actors.kinds[j] == f.drone_kind and w.actors.dead[j] == 0:
			w.actors.set_pos(j, w.actors.pos(i) + Vector2(2.4, 0))
			var hero := w.actors.ids[0]
			Damage.hit(w, j, 1 << 20, hero, hero, w.take_root(), 0, w.player_pos(), w.actors.pos(j))
	_idle(w, f.drone_gap_ticks + 2)
	assert_eq(w.bosses.fg_plate, 1, "a killed drone blows nothing")
	assert_gt(_fx(w, BossForge.PLATE_DRONE, seq).size(), 0, "and another drone comes")
	assert_lte(BossAi.alive_of(w, f.drone_kind), 1, "one at a time")


# --- slabs --------------------------------------------------------------------------------------------------------


func test_a_pool_cools_into_a_slab_in_the_last_phase_and_crumbles() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["slab"])
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	var c := Vector2(6, 6)
	assert_true(BossHazard.place(w, i, c))
	var placed := w.bosses.hz_from[0]
	w.actors.set_pos(0, c)
	var lost := _idle(w, f.slab_cool_ticks + 2)
	assert_gt(lost, 0, "the pool burned while it was lava")
	var cool := _fx(w, BossSlag.SLAB_COOL)
	assert_eq(cool.size(), 1)
	if cool.is_empty():
		return
	assert_eq(cool[0].tick - placed, f.slab_cool_ticks, "12 s after it was placed")
	assert_eq(w.bosses.hz_x.size(), 0, "the pool is gone")
	assert_eq(BossSlag.slab_under(w, c), 0, "a slab lies there")
	assert_eq(_idle(w, f.slab_ticks - 10), 0, "a slab never burns")
	var crumble := JudgeLab.until_effect(w, BossSlag.SLAB_CRUMBLE, 20, cool[0].seq)
	assert_not_null(crumble)
	if crumble != null:
		assert_eq(crumble.tick - cool[0].tick, f.slab_ticks, "8 s later it crumbles")
	assert_eq(w.bosses.slab_id.size(), 0)


func test_with_no_slag_to_come_a_pool_drops_where_the_hero_stands() -> void:
	var s := _only(Vector2(-5, 3), LAST, ["slab", "drop"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	var drops := _fx(w, BossSlag.SLAG_DROP)
	assert_eq(drops.size(), 1, "nothing on the floor: one drops at once")
	if drops.is_empty():
		return
	assert_eq(drops[0].pos, Vector2(-5, 3), "where the hero stands")
	assert_eq(w.bosses.hz_x.size(), 1, "a pool of the boss's, warned as every pool")
	_idle(w, f.slab_cool_ticks - 10)
	assert_eq(_fx(w, BossSlag.SLAG_DROP).size(), 1, "while it cools, no other")
	_idle(w, 12)
	assert_eq(w.bosses.slab_id.size(), 1, "it cooled into a slab")
	var other := _only(Vector2(-5, 3), PLATE, ["plate", "slab", "drop"])
	assert_eq(_fx(other[0], BossSlag.SLAG_DROP).size(), 0, "never before the slag's phase")


func test_a_pool_does_not_cool_before_the_last_phase() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["plate", "slab"])
	var w: World = s[0]
	assert_true(BossHazard.place(w, _i(w, s[1]), Vector2(6, 6)))
	_idle(w, 900)
	assert_eq(_fx(w, BossSlag.SLAB_COOL).size(), 0)
	assert_eq(w.bosses.hz_x.size(), 1, "still lava")


func test_the_vent_blast_shatters_the_slab_you_stand_on_inside_its_ring() -> void:
	for case: Array in [[Vector2(3, 0), true, true], [Vector2(8, 0), true, false]]:
		for on: bool in [true, false]:
			var s := _only(Vector2(-8, 0), LAST, ["slab"])
			var w: World = s[0]
			var i := _i(w, s[1])
			var c: Vector2 = case[0]
			ForgeLab.slab(w, s[1], c)
			w.actors.set_pos(0, c if on else Vector2(-3, 0))
			BossLab.start(w, i, &"vent_blast")
			_idle(w, 90)
			var broke := _fx(w, BossSlag.SLAB_SHATTER).size() == 1
			var expect: bool = on and case[2]
			assert_eq(broke, expect, "slab at %s, hero on it %s" % [c, on])
			assert_eq(BossSlag.slab_under(w, c) < 0, expect, "no slab to stand on once broken")


# --- Overpressure -------------------------------------------------------------------------------------------------


func test_overpressure_on_its_clock_costs_six_percent_a_second_off_a_slab() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["over"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	var t0 := w.tick - 1  # The forge took its clocks on _only's step
	var seq := w.last_event_seq()
	_idle(w, f.over_first_ticks + f.over_cast_ticks + f.over_ticks + 2)
	var cast := _fx(w, BossSlag.OVER_CAST, seq)
	assert_eq(cast.size(), 1)
	if cast.is_empty():
		return
	assert_eq(cast[0].tick - t0, f.over_first_ticks, "10 s into the last phase")
	assert_eq(cast[0].pos, Vector2(6, 6), "it names the slab")
	var burn := _fx(w, BossSlag.OVER_BURN, seq)
	assert_eq(burn[0].tick - cast[0].tick, f.over_cast_ticks, "the floor burns 3 s later")
	var steps := ForgeLab.hurts(w, BossSlag.OVER_EFFECT, seq)
	assert_eq(steps.size(), f.over_ticks / f.over_step_ticks, "a step every 0.5 s for 4 s")
	for e in steps:
		assert_eq(e.amount_applied, 30, "3 % a step")
	assert_eq(_fx(w, BossSlag.OVER_END, seq).size(), 1)
	assert_eq(w.bosses.fg_over_due, cast[0].tick + f.over_every_ticks, "the next 22 s after")


func test_overpressure_is_paid_through_the_hurt_invulnerability_and_not_on_a_slab() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["over"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	w.bosses.fg_over_due = w.tick
	var seq := w.last_event_seq()
	for k in f.over_cast_ticks + f.over_ticks + 2:
		w.actors.invuln[0] = 999
		w.step(InputFrame.new())
		ForgeLab.take_lost(w)
	assert_eq(ForgeLab.hurts(w, BossSlag.OVER_EFFECT, seq).size(), 8, "no step is swallowed")
	w.bosses.fg_over_due = w.tick
	w.actors.set_pos(0, Vector2(6, 6))
	seq = w.last_event_seq()
	assert_eq(_idle(w, f.over_cast_ticks + f.over_ticks + 2), 0, "on the slab: nothing")
	assert_eq(_fx(w, BossSlag.OVER_CAST, seq).size(), 1, "it was cast")


func test_overpressure_waits_for_a_slab_that_is_safe_for_its_whole_length() -> void:
	var s := _only(Vector2(0, -6), LAST, ["over"])
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	BossLab.start(w, i, &"meltdown")  # the melt: the floor farther than 8 m from the centre burns
	_idle(w, 200)
	assert_eq(BossLava.melt_shapes(w).size(), 1, "the room melts")
	w.bosses.fg_over_due = w.tick
	ForgeLab.slab(w, s[1], Vector2(9.5, 0), 6000)  # on the melt
	ForgeLab.slab(w, s[1], Vector2(-3, 3), f.over_cast_ticks + f.over_ticks - 1)  # crumbles mid-burn
	var seq := w.last_event_seq()
	_idle(w, 120)
	assert_eq(_fx(w, BossSlag.OVER_CAST, seq).size(), 0, "no safe slab: it waits")
	assert_eq(_state(w)["overpressure"], {})
	ForgeLab.slab(w, s[1], Vector2(3, -3), 6000)
	_idle(w, 2)
	var cast := _fx(w, BossSlag.OVER_CAST, seq)
	assert_eq(cast.size(), 1, "a safe slab: it begins")
	if not cast.is_empty():
		assert_eq(cast[0].pos, Vector2(3, -3), "and names that slab")
	var safe := 0
	for r: Dictionary in _state(w)["slabs"]:
		safe += 1 if r["safe"] else 0
	assert_eq(safe, 1, "the view sees one safe slab")


func test_the_marker_points_at_the_nearest_safe_slab_through_overpressure() -> void:
	var s := _only(Vector2(-6, 0), LAST, ["over"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	ForgeLab.slab(w, s[1], Vector2(-6, 5), 6000)
	w.bosses.fg_over_due = w.tick
	_idle(w, 10)
	var marks: Array = WorldReader.new(w).objectives()
	assert_eq(marks.size(), 1)
	if marks.size() == 1:
		assert_eq(marks[0]["reason"], ObjectiveMarkers.FOUNDRY_SLAB)
		assert_eq(marks[0]["pos"], Vector2(-6, 5), "the nearer one")
	assert_true(_state(w)["overpressure"]["cast"] >= 0)
	_idle(w, f.over_cast_ticks + f.over_ticks)
	assert_false(w.objectives.has(ObjectiveMarkers.FOUNDRY_SLAB), "gone with it")


# --- the scald gauge ----------------------------------------------------------------------------------------------


func test_the_gauge_fills_from_lava_shots_and_open_floor_and_drains_only_on_a_slab() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["scald", "over"])
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	f.over_phase = NEVER
	var boss := w.actors.ids[i]
	_idle(w, 1)
	assert_eq(_state(w)["scald"]["gauge"], 0)
	_idle(w, 600)
	assert_eq(w.bosses.fg_scald, 0, "open floor outside Overpressure adds nothing")
	# A shot of the Foundry's: + 200; one the invulnerability takes: nothing
	var p := w.player_pos()
	Damage.hit(w, 0, 10, boss, boss, w.take_root(), SimEvent.TAG_PROJECTILE, p, p)
	assert_eq(w.bosses.fg_scald, f.scald_hit)
	Damage.hit(w, 0, 10, boss, boss, w.take_root(), SimEvent.TAG_PROJECTILE, p, p)
	assert_eq(w.bosses.fg_scald, f.scald_hit, "an absorbed hit fills nothing")
	w.actors.invuln[0] = 0
	Damage.hit(w, 0, 10, boss, boss, w.take_root(), SimEvent.TAG_AREA, p, p)
	assert_eq(w.bosses.fg_scald, f.scald_hit, "an area hit is not a shot")
	# In a pool: + 60 a step (no hurt freeze, so the window holds exactly four beats)
	w.player.hurt_freeze_ticks = 0
	w.actors.invuln[0] = 0
	assert_true(BossHazard.place(w, i, Vector2(6, 6)))
	w.actors.set_pos(0, Vector2(6, 6))
	_idle(w, 60)  # armed after its warning
	var g := w.bosses.fg_scald
	_idle(w, f.scald_step_ticks * 4)
	assert_eq(w.bosses.fg_scald - g, 4 * f.scald_lava, "four steps in lava")
	# Overpressure: + 40 a step off a slab
	f.over_phase = LAST
	ForgeLab.slab(w, s[1], Vector2(-6, -6), 6000)
	w.bosses.hz_x.clear()
	w.bosses.hz_y.clear()
	w.bosses.hz_r.clear()
	for fld: StringName in BossStore.HZ_INT_FIELDS:
		w.bosses.set(fld, PackedInt32Array())
	w.actors.set_pos(0, Vector2(0, -8))
	w.bosses.fg_over_due = w.tick
	g = w.bosses.fg_scald
	var seq := w.last_event_seq()
	_idle(w, f.over_cast_ticks + f.over_ticks + 2)
	var steps := ForgeLab.hurts(w, BossSlag.OVER_EFFECT, seq).size()
	assert_eq(w.bosses.fg_scald - g, steps * f.scald_open, "40 a step of Overpressure")
	# On a slab: - 125 a step, down to 0
	w.actors.set_pos(0, Vector2(-6, -6))
	g = w.bosses.fg_scald
	_idle(w, f.scald_step_ticks * 2)
	assert_eq(w.bosses.fg_scald, maxi(0, g - 2 * f.scald_drain), "two steps on a slab")
	assert_true(_state(w)["scald"]["draining"] or w.bosses.fg_scald == 0)


func test_a_full_gauge_burns_five_percent_a_second_until_a_slab_drains_it() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["scald"])
	var w: World = s[0]
	var i := _i(w, s[1])
	var f := ForgeLab.forge(w, s[1])
	_idle(w, 1)
	var boss := w.actors.ids[i]
	var seq := w.last_event_seq()
	for k in 5:
		w.actors.invuln[0] = 0
		var p := w.player_pos()
		Damage.hit(w, 0, 1, boss, boss, w.take_root(), SimEvent.TAG_PROJECTILE, p, p)
	assert_eq(w.bosses.fg_scald, 1000, "five shots fill it")
	assert_eq(_fx(w, BossForge.SCALD_BURN, seq).size(), 1, "the burn starts")
	assert_true(_state(w)["scald"]["burning"])
	ForgeLab.take_lost(w)
	seq = w.last_event_seq()
	for k in 300:
		w.actors.invuln[0] = 999
		w.step(InputFrame.new())
		ForgeLab.take_lost(w)
	var burns := ForgeLab.hurts(w, BossForge.SCALD_EFFECT, seq)
	assert_eq(burns.size(), 10, "every 0.5 s for 5 s, through the invulnerability")
	for e in burns:
		assert_eq(e.amount_applied, 25, "2.5 % a step")
	assert_eq(w.bosses.fg_scald, 1000, "it never falls by itself")
	ForgeLab.slab(w, s[1], Vector2(-8, 0), 6000)
	seq = w.last_event_seq()
	_idle(w, f.scald_step_ticks + 1)
	assert_eq(w.bosses.fg_scald, 1000 - f.scald_drain)
	assert_eq(_fx(w, BossForge.SCALD_BURN_END, seq).size(), 1, "below full: the burn stops")
	assert_false(_state(w)["scald"]["burning"])
	assert_eq(ForgeLab.hurts(w, BossForge.SCALD_EFFECT, seq).size(), 0)


func test_the_gauge_stays_empty_before_the_last_phase() -> void:
	var s := _only(Vector2(-8, 0), PLATE, ["plate", "scald"])
	var w: World = s[0]
	var boss := w.actors.ids[_i(w, s[1])]
	_idle(w, 2)
	var p := w.player_pos()
	Damage.hit(w, 0, 10, boss, boss, w.take_root(), SimEvent.TAG_PROJECTILE, p, p)
	assert_eq(w.bosses.fg_scald, 0)
	assert_eq(_state(w)["scald"], {})


# --- the end of a fight -------------------------------------------------------------------------------------------


func test_the_hero_dying_empties_the_gauge_and_ends_overpressure() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["over", "scald"])
	var w: World = s[0]
	var f := ForgeLab.forge(w, s[1])
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	w.bosses.fg_over_due = w.tick
	_idle(w, f.over_cast_ticks + 40)
	assert_gt(w.bosses.fg_scald, 0)
	assert_true(w.objectives.has(ObjectiveMarkers.FOUNDRY_SLAB))
	w.actors.hp[0] = 1
	w.actors.invuln[0] = 0
	w.step(InputFrame.new())
	for k in 40:
		w.step(InputFrame.new())
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_FOUNDRY_FIRESTORM", "the recap names it")
	assert_eq(w.bosses.fg_scald, 0, "the gauge empties")
	assert_eq(w.bosses.fg_over_from, -1, "Overpressure ends")
	assert_false(w.objectives.has(ObjectiveMarkers.FOUNDRY_SLAB))


func test_the_scald_names_the_molten_floor_in_the_recap() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["scald"])
	var w: World = s[0]
	_idle(w, 1)
	w.bosses.fg_scald = 1000
	w.bosses.fg_burning = 1
	w.actors.hp[0] = 1
	for k in 40:
		w.step(InputFrame.new())
	assert_true(w.player_dead())
	assert_eq(BossCauses.key(w), &"CAUSE_FOUNDRY_FLOOD")


func test_everything_goes_with_the_foundry() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["plate", "slab", "over", "scald"])
	var w: World = s[0]
	var i := _i(w, s[1])
	ForgeLab.slab(w, s[1], Vector2(6, 6), 6000)
	w.bosses.fg_plate = 1
	w.bosses.fg_over_due = w.tick
	_idle(w, 30)
	assert_ne(_state(w), {})
	w.actors.hp[i] = 0
	w.actors.dead[i] = 1
	_idle(w, 2)
	assert_eq(w.bosses.fg_boss, -1)
	assert_eq(w.bosses.slab_id.size(), 0, "its slabs go")
	assert_eq(w.bosses.fg_plate, 0)
	assert_false(w.objectives.has(ObjectiveMarkers.FOUNDRY_SLAB))
	assert_eq(_state(w), {})


# --- the real fight -----------------------------------------------------------------------------------------------


## The real Foundry (not hushed) at the room's centre, put in its last phase by its own gate (the meltdown is its
## entry), the hero circling it 6 m out and refilled. Steps `ticks` ticks; calls `check` after each step.
func _last_phase(seed_value: int, ticks: int, check: Callable = Callable()) -> World:
	var s := ForgeLab.fight(Vector2(-6, 0), Vector2.ZERO, seed_value)
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := ForgeLab.table(w, s[1])
	ForgeLab.set_phase(w, s[1], 1)
	w.actors.hp[i] = t.phase_threshold[2] * w.actors.max_hp[i] / 1000 + 1
	var hero := w.actors.ids[0]
	Damage.hit(w, i, 5, hero, hero, w.take_root(), 0, w.player_pos(), w.actors.pos(i))
	var turn := (seed_value * 97) % 4096
	for k in ticks:
		var c := w.actors.pos(i)
		var out := w.player_pos() - c
		var aim := Kin.angle_of(out) + 1024
		var mv := Kin.dir(aim) * 127.0
		if Kin.length(out) > 7.0:
			mv = -out / Kin.length(out) * 127.0
		elif Kin.length(out) < 5.0:
			mv = out / maxf(Kin.length(out), 0.01) * 127.0
		var f := InputFrame.make(Vector2i(roundi(mv.x), roundi(mv.y)), turn, 300, 0, 0)
		w.step(f)
		w.actors.hp[0] = ForgeLab.LONG
		w.actors.hp[i] = maxi(w.actors.hp[i], 10)
		if check.is_valid():
			check.call(w)
	return w


func test_a_safe_slab_lies_inside_the_melt_at_every_overpressure_over_seeds() -> void:
	var seeds := Seeds.count(60)
	var with_cast := 0
	var casts := 0
	var bad := []
	for sv in seeds:
		var seen := {"casts": 0, "seq": 0}
		var check := func(w: World) -> void:
			var from: int = seen["seq"]
			seen["seq"] = w.last_event_seq()
			for e in _fx(w, BossSlag.OVER_CAST, from):
				seen["casts"] += 1
				var f := BossAi.table_of(w, w.actors.index_of(w.bosses.fg_boss)).forge
				var ok := false
				for k in w.bosses.slab_id.size():
					var c := BossSlag.slab_centre(w.bosses, k)
					var lasts: bool = (
						w.bosses.slab_until[k] >= e.tick + f.over_cast_ticks + f.over_ticks
					)
					var cool := true
					for m: Array in BossLava.melt_shapes(w):
						var low := BossLava.melt_attack(w, 0).melt_min_m
						var end_r := maxf(low, float(m[BossLava.MELT_R]) - 2.0)  # one step in 7 s
						cool = cool and Kin.length(c - (m[BossLava.MELT_CENTRE] as Vector2)) < end_r
					if lasts and cool and w.bosses.slab_broke[k] == 0 and c == e.pos:
						ok = true
				if not ok:
					var why := []
					for k in w.bosses.slab_id.size():
						why.append(
							[
								BossSlag.slab_centre(w.bosses, k),
								w.bosses.slab_until[k] - e.tick,
								w.bosses.slab_broke[k]
							]
						)
					var melts := BossLava.melt_shapes(w).map(
						func(m: Array) -> Array: return [m[0], m[1]]
					)
					bad.append("seed %d tick %d at %s: %s %s" % [sv, e.tick, e.pos, why, melts])
		_last_phase(sv, 60 * 50, check)
		casts += int(seen["casts"])
		with_cast += 1 if int(seen["casts"]) > 0 else 0
	assert_eq(bad, [], "every Overpressure began with a safe slab, and named it")
	print("FORGE| seeds=%d with_overpressure=%d casts=%d" % [seeds, with_cast, casts])
	assert_gt(with_cast, seeds * 8 / 10, "pools keep coming: most last phases see an Overpressure")


func test_deterministic_hashed_and_a_save_mid_fight_restores() -> void:
	var a := _last_phase(7, 60 * 30)
	var b := _last_phase(7, 60 * 30)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	var before := a.state_hash()
	a.bosses.fg_scald += 1
	assert_ne(a.state_hash(), before, "the gauge is hashed")
	a.bosses.fg_scald -= 1
	if not a.bosses.slab_x.is_empty():
		a.bosses.slab_x[0] += 0.5
		assert_ne(a.state_hash(), before, "and the slabs")
		a.bosses.slab_x[0] -= 0.5
	var snap := WorldSnapshot.take(a)
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), JudgeLab.world(7))
	assert_not_null(restored, "restores")
	if restored == null:
		return
	assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
	assert_eq(WorldReader.new(restored).boss_forge(), WorldReader.new(a).boss_forge())
	for k in 600:
		var f := InputFrame.make(Vector2i(60, -40), 0, 300, InputFrame.SHOOT, 0)
		a.step(f)
		restored.step(f)
		a.actors.hp[0] = ForgeLab.LONG
		restored.actors.hp[0] = ForgeLab.LONG
	assert_eq(restored.state_hash(), a.state_hash(), "same hash 600 ticks on")


func test_a_world_without_a_forge_keeps_no_forge_state() -> void:
	var s := TideLab.fight(Vector2(-6, 0), Vector2(6, 0))
	var w: World = s[0]
	CombatLab.idle(w, 120)
	assert_eq(w.bosses.fg_boss, -1)
	assert_eq(WorldReader.new(w).boss_forge(), {})


func test_the_overclock_heat_is_untouched() -> void:
	var s := _only(Vector2(-8, 0), LAST, ["scald"])
	var w: World = s[0]
	var repo := SharedContent.repo()
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	var boss := w.actors.ids[_i(w, s[1])]
	_idle(w, 2)
	for k in 5:
		w.actors.invuln[0] = 0
		var p := w.player_pos()
		Damage.hit(w, 0, 1, boss, boss, w.take_root(), SimEvent.TAG_PROJECTILE, p, p)
	_idle(w, 120)
	assert_eq(w.bosses.fg_scald, 1000, "the scald is full")
	assert_eq(w.heat.milli, 0, "the Overclock heat is not")
	assert_eq(w.heat.tier, Heat.TIER_COOL, "and stays cool")
