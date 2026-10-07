extends GutTest
## The Skill button (v0.3.5 K, owner F18) with the shipped data: the Blade's Lunge Cleave and the Gun's Scatter
## Blast (damage, shape, cooldown, the lunge against walls, knockback, the step back, heat, commitment), the
## forecast agreeing with the hit (EI-07), and the slower dash (F12). Aim angle 0 = +x.

const Q := InputFrame.SKILL
const P := InputFrame.PRIMARY
const D := InputFrame.DASH
const M := HeatTable.MILLI

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## The runner with build `build`, still dummies (radius 0.35, lots of HP) at `enemies`, optional walls.
func _world(build: StringName, enemies: Array = [], walls: Array[Obb] = []) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0  # exact numbers here; crit has its own tests (v0.4.0 BS)
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	if not walls.is_empty():
		w.set_walls(walls)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _f(pressed: int = 0, aim: int = 0, move := Vector2i.ZERO, held: int = 0) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _events(w: World, kind: SimEvent.Kind, after: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(after):
		if e.kind == kind:
			out.append(e)
	return out


func _damage_to(w: World, id: int) -> int:
	var n := 0
	for e in _events(w, SimEvent.Kind.DAMAGE):
		if e.target_id == id:
			n += e.amount
	return n


# --- Data ---------------------------------------------------------------------------------------------------
func test_the_builds_compile_to_their_skills() -> void:
	var b := _world(&"blade").player.skill
	assert_eq(b.kind, SkillTable.Kind.LUNGE_CLEAVE)
	assert_eq(
		[b.cooldown_ticks, b.damage, b.heat_gain, b.lunge_ticks, b.half_arc, b.hitstop_ticks],
		[240, 28, 5000, 12, 1024, 7],
		"4 s, 28, 5 heat, a 0.2 s lunge, 180 degrees, the finisher's 7-tick hit-stop"
	)
	assert_almost_eq(b.lunge_m, 3.5, 1e-6)
	assert_almost_eq(b.reach_m, 2.2, 1e-6)
	var g := _world(&"gun").player.skill
	assert_eq(g.kind, SkillTable.Kind.SCATTER_BLAST)
	assert_eq(
		[g.cooldown_ticks, g.damage, g.heat_gain, g.pellets, g.half_cone, g.knockback_ticks],
		[210, 6, 2500, 7, 341, 8],
		"3.5 s, 6 a pellet, 7 pellets over 60 degrees"
	)
	assert_eq(g.recoil_ticks, 6)
	assert_almost_eq(g.range_m, 4.0, 1e-6)
	assert_almost_eq(g.knockback_m, 1.5, 1e-6)
	assert_almost_eq(g.recoil_m, 0.8, 1e-6)
	var none := World.new(5, PlayerTable.starting_values())
	assert_null(none.player.skill, "no build, no skill (kernel and labs)")


func test_a_bad_skill_is_refused() -> void:
	var d := BuildDefinition.new()
	d.id = &"blade_x"
	d.name_key = &"BUILD_BLADE"
	d.desc_key = &"BUILD_BLADE_DESC"
	d.weapon = BuildDefinition.Weapon.BLADE
	d.skill = SkillDefinition.new()
	d.skill.kind = SkillDefinition.Kind.SCATTER_BLAST
	d.skill.damage = 0
	d.skill.cone_degrees = 0.0
	var codes := []
	for i in d.validate():
		codes.append(String(i.code))
	codes.sort()
	assert_eq(
		codes, ["mismatch", "missing", "range", "range"], "gun skill on a blade, keys, damage, cone"
	)
	var ok: BuildDefinition = _repo.get_def(&"build", &"gun")
	assert_eq(ok.validate().size(), 0, "the shipped gun build validates")


# --- Lunge Cleave -------------------------------------------------------------------------------------------
func test_lunge_cleave_lunges_then_cleaves_the_half_in_front() -> void:
	# In front within reach after the lunge (3.5 m + 0.35 + 2.2), beside it, and behind the start.
	var w := _world(&"blade", [Vector2(5.5, 0), Vector2(4.0, 1.8), Vector2(-1.5, 0)])
	var seq := w.last_event_seq()
	w.step(_f(Q))
	var used := _events(w, SimEvent.Kind.SKILL_USED, seq)
	assert_eq(used.size(), 1, "SKILL_USED")
	assert_eq(used[0].amount, SkillTable.Kind.LUNGE_CLEAVE)
	assert_eq(w.kit.skill_cd, 240, "the cooldown starts at the press")
	_idle(w, 11)
	assert_almost_eq(w.player_pos().x, 3.5, 1e-4, "3.5 m along the facing in 12 ticks")
	assert_eq(_events(w, SimEvent.Kind.DAMAGE, seq).size(), 0, "no hit during the lunge")
	w.step(_f())
	var hits := _events(w, SimEvent.Kind.DAMAGE, seq)
	assert_eq(hits.size(), 2, "the one ahead and the one beside; not the one behind")
	for e in hits:
		assert_eq(e.amount, 32, "28 x the Blade's 1.15")
		assert_ne(e.tags & SimEvent.TAG_SKILL, 0, "tagged skill")
		assert_ne(e.tags & SimEvent.TAG_MELEE, 0, "and melee")
		assert_eq(e.root_id, used[0].root_id, "one root")
	assert_eq(w.freeze_ticks, 7, "the finisher's hit-stop")
	assert_eq(_damage_to(w, w.actors.ids[3]), 0)
	assert_false(PlayerSkill.busy(w), "done")


func test_the_lunge_stops_at_a_wall_like_a_dash() -> void:
	var wall: Array[Obb] = [Obb.make(Vector2(2.0, 0), Vector2(0.25, 3.0), 0)]
	var w := _world(&"blade", [], wall)
	w.step(_f(Q))
	_idle(w, 14)
	assert_almost_eq(
		w.player_pos().x, 2.0 - 0.25 - w.player.radius_m, 0.02, "flush against the wall"
	)
	assert_almost_eq(w.player_pos().y, 0.0, 1e-4)


func test_the_skill_commits_and_waits_out_its_cooldown() -> void:
	var w := _world(&"blade")
	w.step(_f(Q))
	w.step(_f(P | D))
	assert_eq(w.swing_t, 0, "no swing during the lunge")
	assert_false(w.is_dashing(), "nor a dash")
	_idle(w, 20)
	var used := func() -> int: return _events(w, SimEvent.Kind.SKILL_USED).size()
	assert_eq(used.call(), 1)
	w.step(_f(Q))
	_idle(w, 20)
	assert_eq(used.call(), 1, "pressed again inside 4 s: nothing")
	while w.kit.skill_cd > 0:
		w.step(_f())
	w.step(_f(Q))
	assert_eq(used.call(), 2, "ready again after 240 ticks")


func test_a_skill_pressed_mid_swing_waits_only_as_long_as_a_press_buffers() -> void:
	var w := _world(&"blade")
	w.step(_f(P))
	w.step(_f(Q))
	assert_eq(_events(w, SimEvent.Kind.SKILL_USED).size(), 0, "the swing runs first")
	_idle(w, 14)
	assert_eq(_events(w, SimEvent.Kind.SKILL_USED).size(), 0, "the buffered press expired")


func test_a_landed_skill_adds_its_heat_once() -> void:
	var w := _world(&"blade", [Vector2(5.0, 0.4), Vector2(5.0, -0.4)])
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	w.step(_f(Q))
	_idle(w, 12)
	assert_eq(_events(w, SimEvent.Kind.DAMAGE).size(), 2)
	assert_eq(w.heat.milli, 5 * M, "5 heat for the use, not per enemy")


# --- Scatter Blast ------------------------------------------------------------------------------------------
func test_scatter_blast_hits_the_cone_knocks_back_and_steps_back() -> void:
	# Close in the cone (several pellets), at the cone's edge, outside the cone, and out of range.
	var w := _world(&"gun", [Vector2(1.5, 0), Vector2(2.5, 1.3), Vector2(0, 2.0), Vector2(5.5, 0)])
	var ids := w.actors.ids.duplicate()
	var near0 := w.actors.pos(1)
	w.step(_f(Q))
	var used := _events(w, SimEvent.Kind.SKILL_USED)
	assert_eq(used.size(), 1)
	assert_eq(used[0].amount, SkillTable.Kind.SCATTER_BLAST)
	assert_eq(w.kit.pellet_ends.size(), 7, "7 pellets")
	var near := _damage_to(w, ids[1])
	assert_gte(near, 15, "the close one takes three pellets or more")
	assert_gt(_damage_to(w, ids[2]), 0, "the one at the cone's edge is hit")
	assert_eq(_damage_to(w, ids[3]), 0, "outside the cone")
	assert_eq(_damage_to(w, ids[4]), 0, "past 4 m")
	for e in _events(w, SimEvent.Kind.DAMAGE):
		assert_ne(e.tags & SimEvent.TAG_SKILL, 0)
		assert_ne(e.tags & SimEvent.TAG_PROJECTILE, 0)
	_idle(w, 10)
	var i := w.actors.index_of(ids[1])
	assert_almost_eq(w.actors.pos(i).distance_to(near0), 1.5, 0.02, "knocked 1.5 m away")
	assert_almost_eq(w.player_pos().x, -0.8, 0.02, "the user stepped back 0.8 m")
	assert_eq(w.kit.skill_cd, 200, "3.5 s (210 ticks) cooldown, counting down")


func test_pellets_stop_at_walls_and_at_the_first_enemy() -> void:
	var wall: Array[Obb] = [Obb.make(Vector2(1.5, 0), Vector2(0.2, 3.0), 0)]
	var w := _world(&"gun", [Vector2(2.8, 0)], wall)
	w.step(_f(Q))
	assert_eq(_events(w, SimEvent.Kind.DAMAGE).size(), 0, "behind the wall")
	for p in w.kit.pellet_ends:
		assert_lt(p.x, 1.31, "every pellet ends at the wall")
	var lined := _world(&"gun", [Vector2(1.2, 0), Vector2(2.4, 0)])
	lined.step(_f(Q, 0))
	var front := _damage_to(lined, lined.actors.ids[1])
	assert_gt(front, 0)
	assert_lt(
		_damage_to(lined, lined.actors.ids[2]), front, "the front body shields the one behind"
	)


func test_the_pellet_damage_takes_the_guns_factor() -> void:
	var w := _world(&"gun", [Vector2(0.8, 0)])
	w.step(_f(Q))
	var amounts := _events(w, SimEvent.Kind.DAMAGE).map(func(e: SimEvent) -> int: return e.amount)
	assert_eq(amounts.size(), 7, "point blank: all 7 pellets")
	var total := 0
	for a: int in amounts:
		total += a
		assert_true(a == 5 or a == 6, "6 x 0.85 = 5.1, the remainder carried")
	assert_eq(total, 35, "42 x 0.85 = 35.7, floored with the carry")


# --- Forecast (EI-07) ---------------------------------------------------------------------------------------
func test_the_forecast_calls_the_same_shape_as_the_hit() -> void:
	var seen := {true: 0, false: 0}
	for build: StringName in [&"blade", &"gun"]:
		for x in range(-3, 9):
			for y in range(-4, 5):
				var at := Vector2(x * 0.75, y * 0.75)
				if at.length() < 0.8:
					continue
				var w := _world(build, [at])
				var r := WorldReader.new(w)
				var predicted := r.skill_hits(1, r.player_pos(), 0)
				w.step(_f(Q))
				if build == &"blade":
					# The cleave goes off where the lunge ends (a body in the way can stop it short).
					_idle(w, 11)
					predicted = r.skill_hits(1, r.player_pos(), 0)
					w.step(_f())
				var got := _damage_to(w, w.actors.ids[1]) > 0
				assert_eq(got, predicted, "%s at %s" % [build, at])
				seen[got] += 1
	assert_gt(seen[true], 20, "spots in reach")
	assert_gt(seen[false], 20, "and out of it")


# --- Hash -----------------------------------------------------------------------------------------------------
func test_worlds_that_never_use_the_kit_hash_as_before_and_use_is_deterministic() -> void:
	var a := World.new(5, PlayerTable.starting_values())
	var b := World.new(5, PlayerTable.starting_values())
	a.step(_f())
	b.step(_f(Q))
	assert_eq(a.state_hash(), b.state_hash(), "no skill: a Skill press leaves nothing behind")
	var x := _world(&"gun", [Vector2(2, 0)])
	var y := _world(&"gun", [Vector2(2, 0)])
	for w: World in [x, y]:
		w.step(_f(Q, 300))
		_idle(w, 20)
	assert_eq(x.state_hash(), y.state_hash(), "the same presses, the same state")
	var z := _world(&"gun", [Vector2(2, 0)])
	z.step(_f(0, 300))
	_idle(z, 20)
	assert_ne(z.state_hash(), x.state_hash(), "a blast changes the hash")


# --- Dash (F12) ---------------------------------------------------------------------------------------------
func test_the_dash_waits_1_4_seconds() -> void:
	var w := _world(&"blade")
	w.step(_f(D))
	assert_eq(w.dash_cooldown_left, 84, "1.4 s")
	for k in 82:
		w.step(_f())
	w.step(_f(D))
	assert_false(w.is_dashing(), "not ready a tick early")
	w.step(_f())
	assert_true(w.is_dashing(), "the buffered press dashes 84 ticks after the last dash")
