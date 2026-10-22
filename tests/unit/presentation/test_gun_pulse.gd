extends GutTest
## v0.8.0 GF1 (owner O19): the Gun's shot is a lit blue pulse (HeroPulseViews: a pale core falling off to the hero's
## cyan, a soft swelling glow, a short trail), batched (three MultiMeshes per look however many shots fly), drawn at the
## shot's own hit radius, in the hero's colours only (off every hostile look), with the cards' tints and the element
## layers on top; every shot casts a light flourish at the muzzle (HeroCastFx: a spark and a swirl, pooled, merged when
## the shots come fast) and a quick accent on the hero's body (PlayerAvatar); reduced motion keeps only the spark.

var _repo: ContentRepository
var _tables: Array[ItemTable] = []


func before_all() -> void:
	_repo = ContentRepository.load_all()
	_tables = ContentCompiler.compile_items(AttackScenario.repo())


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.effects_density = "high"


func _world(items: Array = []) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	t.crit_chance_permille = 0
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"gun"))
	var w := World.new(5, t)
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	for id: StringName in items:
		w.add_item(AttackScenario.item_index(_tables, id))
	return w


func _views(_r: WorldReader) -> Array:
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.set_process(false)
	var pulses := HeroPulseViews.new()
	pulses.actors = actors
	add_child_autofree(pulses)
	var items := ItemVisuals.new(KitView.new(), actors)
	autofree(items.kit)
	add_child_autofree(items)
	return [actors, pulses, items]


func _sync(r: WorldReader, v: Array) -> void:
	(v[0] as ActorViews).sync(r)
	(v[2] as ItemVisuals).sync(r)
	(v[1] as HeroPulseViews).sync(r)


func _shoot(w: World, r: WorldReader, v: Array, ticks: int) -> void:
	for k in ticks:
		w.step(
			InputFrame.make(
				Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0
			)
		)
		_sync(r, v)


func _player_shots(r: WorldReader) -> Array[int]:
	var out: Array[int] = []
	for i in r.projectile_count():
		if r.projectile_team(i) == 0:
			out.append(i)
	return out


func test_the_guns_shots_are_pulses_not_darts() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	_shoot(w, r, v, 30)
	var pulses: HeroPulseViews = v[1]
	var shots := _player_shots(r)
	assert_gt(shots.size(), 1, "shots in flight")
	assert_eq(pulses.count(), shots.size(), "each one a pulse")
	for i in shots:
		assert_null((v[0] as ActorViews).projectile_node(r.projectile_id(i)), "no dart node")
		assert_ne(pulses.key_of(r.projectile_id(i)), "")
	assert_eq(pulses.looks().size(), 1, "one look: the plain shot")
	var key: String = pulses.looks()[0]
	assert_eq(pulses.ball_count(key), shots.size())
	assert_eq(pulses.trail_count(key), shots.size(), "each with its trail")
	for p: StringName in [&"core", &"glow", &"trail"]:
		var mi := pulses.part(key, p)
		assert_not_null(mi, "a %s MultiMesh" % p)
		assert_eq(mi.multimesh.visible_instance_count, shots.size(), "%s: one instance a shot" % p)


func test_hundreds_of_shots_stay_three_draws_a_look() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	_shoot(w, r, v, 2)
	var pulses: HeroPulseViews = v[1]
	var children := pulses.get_child_count()
	for k in 300:
		var dir := Kin.dir(k * 4096 / 300)
		w.queue_projectile(0, ActorStore.TEAM_PLAYER, dir * 1.0, dir * 0.05, 0, 0.2, 30, 0)
	w.step(InputFrame.new())
	_sync(r, v)
	assert_gt(pulses.count(), 290, "hundreds drawn")
	assert_eq(pulses.get_child_count(), children, "no node per shot: the same MultiMeshes")
	assert_eq(pulses.get_child_count(), 3 * pulses.looks().size())


func test_what_you_see_is_what_hits() -> void:
	assert_between(HeroPulseViews.CORE_SCALE, 0.8, 1.0, "the core is the hit radius")
	var drawn := []
	for items: Array in [[], [&"gun_big_shot"]]:
		var w := _world(items)
		var r := WorldReader.new(w)
		var v := _views(r)
		_shoot(w, r, v, 2)
		var i: int = _player_shots(r)[0]
		var radius := r.projectile_radius(i)
		var got := (v[1] as HeroPulseViews).drawn_radius(r.projectile_id(i))
		assert_almost_eq(got, radius * HeroPulseViews.CORE_SCALE, 1e-6, "drawn at its hit radius")
		drawn.append(got)
	assert_almost_eq(
		drawn[0], 0.2 * HeroPulseViews.CORE_SCALE, 1e-6, "the plain bolt's 0.2 m (O18)"
	)
	assert_almost_eq(
		drawn[1], drawn[0] * 2.0, 1e-5, "Big Shot doubles the pulse with its hit radius"
	)


func test_the_pulse_is_the_heros_colours_and_off_every_hostile_look() -> void:
	var hero := ThemePalette.color(&"player_core")
	var cols := HeroPulseViews.colors(hero)
	assert_gt(cols[0].get_luminance(), 0.75, "a bright pale core")
	assert_gt(cols[0].b, cols[0].r, "pale cyan, not white-hot")
	assert_lt(_dist(cols[1], hero), 0.3, "the body is the hero's cyan leaned to blue")
	assert_gt(cols[1].h * 360.0, hero.h * 360.0, "bluer than the cyan")
	assert_lt(cols[1].h * 360.0, 225.0, "but not the Arc Caster's periwinkle")
	for c: Color in cols:
		assert_gt(c.get_luminance(), 0.3, "no dark edge: that is the hostile shots' mark")
	for key: StringName in FireballViews.LOOKS:
		var look := FireballViews.look_of(key)
		for c: Color in [cols[1], cols[2], cols[3]]:
			assert_gt(_dist(look["core"], c), 0.2, "%s's core is off the pulse" % key)
			assert_gt(_dist(look["trail"], c), 0.2, "%s's trail is off the pulse" % key)
		assert_false(AttackFormLooks.is_hostile_hue(cols[1]))


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func test_cards_and_elements_recolour_and_reshape_on_top() -> void:
	var plain := _world()
	var rp := WorldReader.new(plain)
	var vp := _views(rp)
	_shoot(plain, rp, vp, 3)
	var plain_look: Array = (vp[1] as HeroPulseViews).look((vp[1] as HeroPulseViews).looks()[0])
	for card: StringName in [&"cinder_shot", &"barbed_bolts", &"gun_rapid_fire"]:
		var w := _world([card])
		var r := WorldReader.new(w)
		var v := _views(r)
		_shoot(w, r, v, 3)
		var pulses: HeroPulseViews = v[1]
		assert_eq(pulses.count(), _player_shots(r).size(), "%s: still pulses" % card)
		var look: Array = pulses.look(pulses.looks()[0])
		assert_ne(look, plain_look, "%s changes the pulse (its tint or its stretch)" % card)
	var rapid := _world([&"gun_rapid_fire"])
	var rr := WorldReader.new(rapid)
	var vr := _views(rr)
	_shoot(rapid, rr, vr, 3)
	var rk: String = (vr[1] as HeroPulseViews).looks()[0]
	assert_gt((vr[1] as HeroPulseViews).look(rk)[2], 1.0, "Rapid Fire draws it drawn out")
	# The element layers (AttackFormView) still draw over the pulse: an ember shot adds its layer.
	var ember := _world([&"cinder_shot"])
	var re := WorldReader.new(ember)
	var forms := AttackFormView.new()
	add_child_autofree(forms)
	for k in 3:
		ember.step(InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT))
		forms.sync(re)
	assert_gt(forms.live_count(), 0, "the ember layer flies with the pulse")


func test_a_shot_keeps_the_colour_it_was_fired_with() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	_shoot(w, r, v, 2)
	var pulses: HeroPulseViews = v[1]
	var id := r.projectile_id(_player_shots(r)[0])
	var key := pulses.key_of(id)
	(v[0] as ActorViews).bolt_look = {"color": Color("#FFAA33"), "energy": 2.5}
	for k in 3:
		w.step(InputFrame.new())
		pulses.sync(r)
	assert_eq(pulses.key_of(id), key, "in flight it keeps its look")


func test_effects_density_low_thins_the_trails_and_keeps_the_shots() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	_shoot(w, r, v, 30)
	var pulses: HeroPulseViews = v[1]
	var key: String = pulses.looks()[0]
	var shots := pulses.ball_count(key)
	ViewPrefs.effects_density = "low"
	pulses.sync(r)
	assert_eq(pulses.ball_count(key), shots, "every shot stays")
	assert_lt(pulses.trail_count(key), shots, "every other trail")
	assert_lt(pulses.trail_width(), 1.0, "and thinner")


func test_reduced_motion_stills_the_pulse() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	ViewPrefs.reduced_motion = true
	_shoot(w, r, v, 3)
	var pulses: HeroPulseViews = v[1]
	var key: String = pulses.looks()[0]
	for p: StringName in [&"core", &"glow", &"trail"]:
		var m := pulses.part(key, p).material_override as ShaderMaterial
		assert_eq(m.get_shader_parameter("motion"), 0.0, "%s holds still" % p)


# --- The cast ---------------------------------------------------------------------------------------------------
func test_shot_fired_is_true_on_the_ticks_a_shot_leaves() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var fired := 0
	var launched := 0
	for k in 60:
		var before := w.player_projectiles()
		w.step(
			InputFrame.make(
				Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0
			)
		)
		var shot := r.shot_fired()
		fired += 1 if shot else 0
		if w.player_projectiles() > before:
			launched += 1
			assert_true(shot, "tick %d: a shot left, the reader says so" % k)
	assert_eq(fired, launched, "and only then")
	assert_eq(fired, 7, "60 ticks at 9 a shot: 7 shots (the first at once)")


func test_every_shot_casts_a_pooled_flourish() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var fx := HeroCastFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	fx.sync(r)
	var children := fx.get_child_count()
	assert_eq(fx.pool_size(), HeroCastFx.POOL)
	for k in 90:
		w.step(
			InputFrame.make(
				Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0
			)
		)
		fx.sync(r)
		fx._process(1.0 / 60.0)
	assert_eq(fx.started, 10, "90 ticks at 9 a shot: one flourish a shot")
	assert_eq(fx.merged, 0, "shots 9 ticks apart don't merge")
	assert_eq(fx.get_child_count(), children, "nothing built per shot")
	assert_lte(fx.live_count(), 2, "each fades before long")


func test_rapid_shots_merge_into_one_flourish() -> void:
	var w := _world([&"gun_rapid_fire", &"rapid_coil"])
	# v0.8.0 SG: the attack-speed curve now holds these two cards at 6 ticks (MERGE_TICKS); with the knee lifted for
	# this world only, they fire fast enough to merge, which is what this test is about.
	w.tuning.attack_speed_knee_permille = 5000
	w.tuning.attack_speed_knee2_permille = 5000
	var r := WorldReader.new(w)
	assert_lt(r.shot_period_ticks(), HeroCastFx.MERGE_TICKS, "fast enough to merge")
	var fx := HeroCastFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	var shots := 0
	for k in 60:
		w.step(
			InputFrame.make(
				Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT if k == 0 else 0
			)
		)
		shots += 1 if r.shot_fired() else 0
		fx.sync(r)
		fx._process(1.0 / 60.0)
	assert_gt(fx.merged, 0, "rapid shots merge")
	assert_eq(fx.started + fx.merged, shots, "every shot is shown")
	assert_lt(fx.started, shots, "fewer flourishes than shots")
	assert_lte(fx.live_count(), HeroCastFx.POOL)


func test_reduced_motion_keeps_only_the_spark() -> void:
	ViewPrefs.reduced_motion = true
	var w := _world()
	var r := WorldReader.new(w)
	var fx := HeroCastFx.new()
	add_child_autofree(fx)
	fx.set_process(false)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, InputFrame.SHOOT))
	fx.sync(r)
	assert_eq(fx.started, 1)
	assert_true(fx.spark_visible(0), "the spark")
	assert_false(fx.swirl_visible(0), "no swirl")
	ViewPrefs.reduced_motion = false
	w.step(InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, 0))
	for k in 20:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 400, InputFrame.SHOOT, 0))
		fx.sync(r)
		fx._process(1.0 / 60.0)
		if fx.started == 2:
			break
	assert_eq(fx.started, 2)
	assert_true(fx.swirl_visible(1), "with motion: the swirl")


func _avatar(shot: bool) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color.BLACK)
	add_child_autofree(a)
	a.set_process(false)
	(
		a
		. apply_state(
			{
				"tick": 10,
				"pos": Vector2.ZERO,
				"aim": 0,
				"dashing": false,
				"swing_t": 0,
				"swing_ticks": 1,
				"swing_angle": 0,
				"combo": 0,
				"guarding": false,
				"dead": false,
				"gun": true,
				"shooting": true,
				"shot": shot,
			}
		)
	)
	return a


func test_the_hero_accents_each_shot_and_reduced_motion_drops_it() -> void:
	var cast := _avatar(true)
	var still := _avatar(false)
	assert_eq(cast.cast_amount(), 1.0, "a shot kicks the accent")
	assert_eq(still.cast_amount(), 0.0)
	cast.advance(1.0 / 60.0)
	still.advance(1.0 / 60.0)
	assert_gt(cast.cast_amount(), 0.0)
	assert_gt(cast.hood.rotation.z, still.hood.rotation.z, "the hood flicks back")
	assert_ne(cast.body_yaw(), still.body_yaw(), "the head turns a touch")
	for k in 20:
		cast.advance(1.0 / 60.0)
	assert_eq(cast.cast_amount(), 0.0, "gone in a moment")
	ViewPrefs.reduced_motion = true
	assert_eq(_avatar(true).cast_amount(), 0.0, "reduced motion: no accent")


func test_the_game_view_draws_once_a_frame_and_clears_the_last_shots() -> void:
	var w := _world()
	var r := WorldReader.new(w)
	var v := _views(r)
	var pulses: HeroPulseViews = v[1]
	pulses.draw_on_sync = false
	pulses.set_process(false)
	_shoot(w, r, v, 3)
	var key: String = pulses.looks()[0]
	assert_eq(pulses.ball_count(key), 0, "the sync alone draws nothing (the frame does)")
	pulses._process(1.0 / 60.0)
	assert_eq(pulses.ball_count(key), pulses.count(), "the frame draws them")
	for k in 80:
		w.step(InputFrame.new())
		pulses.sync(r)
	assert_eq(pulses.count(), 0, "every shot is gone")
	pulses._process(1.0 / 60.0)
	assert_eq(
		pulses.part(key, &"core").multimesh.visible_instance_count, 0, "and so are their pulses"
	)
