extends GutTest
## v0.5.5 LK (owner A1: "The ability for gun and blade should match the animation"): the skills' hero poses and
## drawn shapes, timed from the sim's ticks. The Lunge Cleave: a lunge pose wound back, whipping through the arc as
## the cleave sweep crosses the real hit fan (half_arc, the hero's edge out to edge + reach) and lands on the hit
## tick. The Scatter Blast: a braced stance and a recoil kick on the blast's tick, easing out over the recoil step,
## with the cone flash the real cone. Read from a real world through WorldReader.

const DT := 1.0 / 60.0

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(build: StringName, enemies: Array = []) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, 5000)
	return w


func _f(pressed: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, 0, pressed)


func _avatar(actors: ActorViews, w: World) -> PlayerAvatar:
	return actors.actor_node(w.actors.ids[0]).get_meta(&"avatar") as PlayerAvatar


## One tick: the sim steps, the views sync, the avatar animates a frame.
func _tick(
	w: World, r: WorldReader, actors: ActorViews, fx: SkillVisuals, pressed: int = 0
) -> void:
	w.step(_f(pressed))
	actors.sync(r)
	fx.sync(r)
	_avatar(actors, w).advance(DT)


func test_the_cleave_sweep_lands_on_the_hit_tick_across_the_real_fan() -> void:
	assert_eq(SkillVisuals.cleave_progress(0, 12, -1), Vector2.ZERO, "no skill: nothing")
	assert_eq(SkillVisuals.cleave_progress(3, 12, -1).x, 0.0, "early in the lunge: wound back")
	var late := SkillVisuals.cleave_progress(12, 12, -1).x
	assert_gt(late, 0.5, "the lunge's last tick: most of the way across")
	assert_lt(late, 1.0, "but not there yet")
	assert_eq(SkillVisuals.cleave_progress(0, 12, 0), Vector2(1, 1), "the hit tick: across, full")
	var held := SkillVisuals.cleave_progress(0, 12, SkillVisuals.CLEAVE_HOLD_TICKS)
	assert_eq(held, Vector2(1, 1), "held through the hit-stop")
	var gone := SkillVisuals.CLEAVE_HOLD_TICKS + SkillVisuals.CLEAVE_FADE_TICKS
	assert_eq(SkillVisuals.cleave_progress(0, 12, gone).y, 0.0, "then faded out")


func test_the_lunge_cleave_pose_and_sweep_follow_the_skill_ticks() -> void:
	var w := _world(&"blade", [Vector2(5.5, 0)])
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := SkillVisuals.new()
	add_child_autofree(fx)
	actors.sync(r)
	fx.sync(r)
	var av := _avatar(actors, w)
	av.set_process(false)
	for k in 5:
		av.advance(DT)
	assert_almost_eq(av.lunge_amount(), 0.0, 0.01, "standing: no lunge")
	_tick(w, r, actors, fx, InputFrame.SKILL)
	var t := w.player.skill
	var twists: Array[float] = []
	var hit_tick := -1
	for k in 30:
		_tick(w, r, actors, fx)
		twists.append(av.twist_amount())
		var s := r.skill_state()
		if (
			int(s["running"]) > 0
			and int(s["running"]) == t.lunge_ticks - SkillVisuals.CLEAVE_SWEEP_TICKS
		):
			assert_gt(av.lunge_amount(), 0.7, "mid-lunge: deep in the lunge pose")
			assert_lt(av.twist_amount(), -0.6, "wound back to the arc's starting side")
			assert_eq(fx.cleave_sweep()[0], 0.0, "the sweep hasn't started")
		if int(s["hit_tick"]) >= 0 and hit_tick < 0:
			hit_tick = int(s["hit_tick"])
			assert_eq(hit_tick, w.tick - 1, "the cleave hit on the tick just stepped")
			var sweep := fx.cleave_sweep()
			assert_eq(sweep[0], 1.0, "the sweep reaches the arc's far edge on the hit tick")
			assert_eq(sweep[1], 1.0, "drawn full")
			assert_eq(sweep[2], t.half_arc, "across the hit's own half arc (180 degrees in all)")
			assert_almost_eq(
				sweep[3],
				r.player_radius() + t.reach_m,
				1e-5,
				"out to the hit's reach from the edge"
			)
			assert_true(fx.cleave_edge_visible(), "led by the blade edge")
			assert_gt(av.twist_amount(), 0.4, "the body has whipped through the arc")
	assert_gt(hit_tick, -1, "the cleave went off")
	assert_lt(twists.min(), -0.6, "the twist wound back")
	assert_gt(twists.max(), 0.6, "and swung through")
	assert_lt(fx.cleave_sweep()[1], 0.01, "the sweep has faded")
	for k in 30:
		av.advance(DT)
	assert_almost_eq(av.lunge_amount(), 0.0, 0.02, "recovered: the lunge pose let go")


func test_the_scatter_blast_braces_and_recoils_on_its_tick() -> void:
	var w := _world(&"gun", [Vector2(2, 0)])
	var r := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := SkillVisuals.new()
	add_child_autofree(fx)
	actors.sync(r)
	fx.sync(r)
	var av := _avatar(actors, w)
	av.set_process(false)
	var from := r.player_pos()
	_tick(w, r, actors, fx, InputFrame.SKILL)
	var s := r.skill_state()
	assert_eq(int(s["hit_tick"]), w.tick - 1, "the blast fired on the tick just stepped")
	assert_eq(fx.fx_count_of(&"cone"), 1, "the cone flash")
	assert_eq(fx.fx_count_of(&"muzzle"), 1, "and a muzzle flash")
	var t := w.player.skill
	assert_eq(int(s["half_cone"]), t.half_cone, "the real cone: 60 degrees in all")
	assert_eq(t.half_cone, 341)
	_tick(w, r, actors, fx)
	assert_gt(av.recoil_amount(), 0.4, "kicked back by the recoil")
	assert_gt(av.brace_amount(), 0.3, "braced")
	for k in t.recoil_ticks:
		_tick(w, r, actors, fx)
	assert_lt(r.player_pos().x, from.x, "the sim stepped the hero back")
	assert_lt(av.recoil_amount(), 0.3, "the recoil eased out over the step back")
	for k in SkillVisuals.TRACER_TICKS:
		_tick(w, r, actors, fx)
	assert_eq(fx.fx_count_of(&"cone"), 0, "the cone flash is gone in its ticks")
	for k in 40:
		_tick(w, r, actors, fx)
	assert_almost_eq(av.brace_amount(), 0.0, 0.02, "the brace let go")
