extends GutTest
## v0.8.0 GF3 (owner O22: "the exact same exercise to the blade, animations, hit enemy, flinch, hit animation, what we
## did to the gun but applied to the blade, also for the blade and flinch we add a 2 frame or so freeze"): every combo
## step accents the hero (a wind-up up to the hit, the swing, a follow-through; the finisher's bigger; reduced motion:
## no overshoot) timed to the sim's swing ticks; a bright slash edge rides the trail and a pooled spark rides the
## blade's tip, flaring on the cut; every slash hit throws its own impact (a cut along the slash, sparks along the
## swing's tangent, at least a bolt's size, in the pools and budget); the struck enemy flinches harder than from a bolt
## and is knocked away from the swing (the pose only); and the view's hit-stop holds the hero's swing and the struck
## enemy about 2 frames (shared by one swing's hits, rate-limited, a tiny camera kick; Options "Hit-stop" and reduced
## motion turn it off) while the sim ticks on untouched.

const DT := 1.0 / 60.0
const K := ActorStore.Kind


func after_each() -> void:
	ViewPrefs.reduced_motion = false
	ViewPrefs.hit_stop = true
	ViewPrefs.effects_density = "high"


func _press(w: World, aim: int = 0) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, aim, 100, InputFrame.PRIMARY, InputFrame.PRIMARY))


func _idle(w: World, aim: int = 0) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, aim, 100, 0, 0))


## [world, reader, actors, feel, kit, enemy index, enemy id]: a Blade world with one held enemy of `kind` at `at`,
## turned away (its back to the blade), the views a game view builds for the hit feel, none processing on their own.
func _setup(kind: int = K.CHARGER, at: Vector2 = Vector2(1.3, 0)) -> Array:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	var id := w.add_enemy(kind, at)
	var i := w.actors.index_of(id)
	w.actors.invuln[i] = 0
	w.actors.hp[i] = 1 << 20
	w.actors.max_hp[i] = 1 << 20
	w.actors.facing[i] = 0
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.set_process(false)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	rig.set_process(false)
	var kit := KitView.new()
	add_child_autofree(kit)
	kit.set_process(false)
	var feel := HitFeel.new(actors, rig)
	feel.hit_stop.kit = kit
	add_child_autofree(feel)
	feel.set_process(false)
	_sync(reader, actors, kit, feel)
	return [w, reader, actors, feel, kit, i, id]


func _sync(r: WorldReader, actors: ActorViews, kit: KitView, feel: HitFeel) -> void:
	actors.sync(r)
	kit.sync(r)
	feel.sync(r)


func _enemy_avatar(actors: ActorViews, id: int) -> Node:
	var av: Node = actors.actor_node(id).get_meta(&"enemy_avatar")
	av.set_process(false)
	return av


func _hero_avatar(actors: ActorViews, r: WorldReader) -> PlayerAvatar:
	var av := actors.actor_node(r.actor_id(0)).get_meta(&"avatar") as PlayerAvatar
	av.set_process(false)
	return av


# --- The swing ----------------------------------------------------------------------------------------------------
func test_each_combo_step_winds_up_swings_and_follows_through() -> void:
	var t := PlayerTable.starting_values()
	assert_eq(t.combo.size(), 4)
	for k in t.combo.size():
		var st := t.step(k)
		var before := PlayerAvatar.swing_accent(
			float(st.active_tick) - 0.6, st.active_tick, st.sweep_ticks, st.ticks, false
		)
		assert_gt(before.x, 0.5, "step %d winds up before its hit" % k)
		var hit := PlayerAvatar.swing_accent(
			float(st.active_tick) + 0.8, st.active_tick, st.sweep_ticks, st.ticks, false
		)
		assert_gt(hit.y, 0.8, "step %d swings through on its hit tick" % k)
		assert_lt(hit.x, 0.5, "the wind-up lets go as it strikes")
		var after := PlayerAvatar.swing_accent(
			float(st.sweep_ticks + 3), st.active_tick, st.sweep_ticks, st.ticks, false
		)
		assert_gt(after.z, 0.5, "step %d follows through past the arc's end" % k)
		assert_eq(
			(
				PlayerAvatar
				. swing_accent(
					float(st.ticks) + 1.0, st.active_tick, st.sweep_ticks, st.ticks, false
				)
				. z
			),
			0.0,
			"settled by the swing's end"
		)
		assert_eq(
			PlayerAvatar.swing_accent(0.0, st.active_tick, st.sweep_ticks, st.ticks, false),
			Vector3.ZERO
		)
		var calm := PlayerAvatar.swing_accent(
			float(st.sweep_ticks + 3), st.active_tick, st.sweep_ticks, st.ticks, true
		)
		assert_eq(calm.z, 0.0, "reduced motion: no overshoot (step %d)" % k)


## A real combo read by the hero model each tick (the sim's swing ticks): every step shows all three parts, the
## finisher bigger, and none of it is left after the swing.
func test_the_hero_model_accents_a_real_combo_and_the_finisher_most() -> void:
	var s := _setup(K.CHARGER, Vector2(30, 30))  # far off: nothing is hit, no hit-stop
	var w: World = s[0]
	var r: WorldReader = s[1]
	var actors: ActorViews = s[2]
	var hero := _hero_avatar(actors, r)
	var peaks := {}
	var scales := {}
	for k in 160:
		if r.swing_tick() == 0 or w.combo_window > 0:
			_press(w)
		else:
			_idle(w)
		actors.sync(r)
		hero._process(DT)
		var step := r.combo_step()
		var a := hero.swing_accent_now()
		var p: Vector3 = peaks.get(step, Vector3.ZERO)
		peaks[step] = Vector3(maxf(p.x, a.x), maxf(p.y, a.y), maxf(p.z, a.z))
		scales[step] = hero.accent_scale()
	assert_eq(peaks.size(), 4, "every step was swung")
	for step: int in peaks:
		var p: Vector3 = peaks[step]
		assert_gt(p.x, 0.4, "step %d: a wind-up" % step)
		assert_gt(p.y, 0.8, "step %d: the swing" % step)
		assert_gt(p.z, 0.4, "step %d: a follow-through" % step)
	assert_eq(scales[3], PlayerAvatar.ACCENT_FINISHER, "the finisher's accent is the bigger one")
	assert_eq(scales[0], 1.0)
	for k in 60:
		_idle(w)
		actors.sync(r)
		hero._process(DT)
	assert_eq(hero.swing_accent_now(), Vector3.ZERO, "gone after the swing")


func test_reduced_motion_keeps_the_wind_up_and_swing_without_overshoot() -> void:
	ViewPrefs.reduced_motion = true
	var s := _setup(K.CHARGER, Vector2(30, 30))
	var w: World = s[0]
	var r: WorldReader = s[1]
	var hero := _hero_avatar(s[2], r)
	var most := Vector3.ZERO
	_press(w)
	for k in 20:
		(s[2] as ActorViews).sync(r)
		hero._process(DT)
		var a := hero.swing_accent_now()
		most = Vector3(maxf(most.x, a.x), maxf(most.y, a.y), maxf(most.z, a.z))
		_idle(w)
	assert_gt(most.y, 0.8, "the swing")
	assert_eq(most.z, 0.0, "no follow-through overshoot")


func test_the_slash_edge_rides_the_trail_in_the_hero_s_colours() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	var children := kit.get_child_count()
	_press(w)
	kit.sync(r)
	var drew := 0
	for k in 6:
		_idle(w)
		kit.sync(r)
		drew = maxi(drew, kit.edge_segments())
	assert_gt(drew, 0, "the bright edge is drawn over the trail")
	assert_eq(kit.edge_color(), ImpactFx.HERO, "the hero's blue-white with no element")
	kit.set_heat_tier(HeatLooks.TIER_HOT)
	assert_ne(kit.edge_color(), ImpactFx.HERO, "the heat tier tints it from Hot up")
	kit.set_heat_tier(HeatLooks.TIER_COOL)
	kit._edge_element = AttackFormLooks.element_color(&"fire")
	assert_eq(
		kit.edge_color(),
		AttackFormLooks.element_color(&"fire").lerp(Color.WHITE, 0.3),
		"an element tints it"
	)
	while r.swing_tick() > 0:
		_idle(w)
	kit.sync(r)
	assert_eq(kit.edge_segments(), 0, "gone with the blade")
	assert_eq(kit.get_child_count(), children, "one layer, built once")


func test_the_edge_spark_is_pooled_and_flares_on_the_cut() -> void:
	var w := CombatLab.world()
	var r := WorldReader.new(w)
	var kit: KitView = add_child_autofree(KitView.new())
	var fx := BladeSwingFx.new(kit)
	add_child_autofree(fx)
	fx.set_process(false)
	kit.sync(r)
	fx.sync(r)
	var children := fx.get_child_count()
	assert_eq(fx.pool_size(), BladeSwingFx.POOL)
	var swings := 0
	var flare := 0.0
	for k in 240:
		if r.swing_tick() == 0:
			_press(w)
			swings += 1
		else:
			_idle(w)
		kit.sync(r)
		fx.sync(r)
		fx._process(DT)
		flare = maxf(flare, fx.spark_size())
	assert_gt(swings, 4)
	assert_eq(fx.started, swings, "one spark a swing")
	assert_eq(fx.cuts, swings, "each flares on its hit tick")
	assert_gt(flare, BladeSwingFx.RIDE_SIZE * 1.5, "the cut flares it")
	assert_eq(fx.get_child_count(), children, "nothing built per swing")
	assert_lte(fx.live_count(), BladeSwingFx.POOL)


# --- The impact ---------------------------------------------------------------------------------------------------
func test_a_real_slash_hit_throws_a_cut_along_the_swing() -> void:
	var s := _setup()
	var w: World = s[0]
	var r: WorldReader = s[1]
	var feel: HitFeel = s[3]
	_press(w)
	for k in 4:
		_sync(r, s[2], s[4], feel)
		if feel.impacts.added > 0:
			break
		_idle(w)
	assert_eq(feel.impacts.added, 1, "one impact for the slash hit")
	var imp: Array = feel.impacts._live[0]
	assert_eq(int(imp[6]), ImpactFx.SLASH)
	assert_gte(float(imp[5]), ImpactFx.STRENGTH[ImpactFx.BOLT], "at least a bolt's")
	# The first step slashes right to left: across a body dead ahead (+x) the blade moves toward +y on the sim
	# plane, -z in 3D: the tangent, not the hit's way in.
	var tan: Vector3 = imp[1]
	assert_lt(tan.z, -0.95, "the cut lies along the swing's tangent")
	for j in ImpactFx.SLASH_SPARKS:
		var d := ImpactFx.slash_spark_at(imp, j, 0.6) - (imp[0] as Vector3)
		assert_gt(d.dot(tan), 0.3, "spark %d flies on along the blade's way" % j)
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(float(w.tick) + 3.0)
	feel.impacts.draw(layer)
	assert_gt(feel.impacts.last_pieces, 10)
	for id: StringName in [&"spark", &"debris", &"smoke"]:
		assert_lte(layer.used(id), int(layer.pools[id]["cap"]), "within the pool")
	layer.begin(float(w.tick) + ImpactFx.LIFE_TICKS + 1.0)
	feel.impacts.draw(layer)
	assert_eq(feel.impacts.live(), 0, "and it goes")


func test_the_tangent_follows_each_motion() -> void:
	var r := Vector2.RIGHT
	assert_eq(ImpactFx.slash_tangent(WorldReader.MOTION_SLASH_RIGHT_TO_LEFT, r), Vector2(0, 1))
	assert_eq(ImpactFx.slash_tangent(WorldReader.MOTION_SLASH_LEFT_TO_RIGHT, r), Vector2(0, -1))
	assert_eq(ImpactFx.slash_tangent(WorldReader.MOTION_THRUST, r), r, "a thrust's along its aim")
	assert_eq(
		ImpactFx.slash_tangent(WorldReader.MOTION_SPIN, r), Vector2(0, 1), "the spin turns up"
	)


func test_a_slash_impact_is_at_least_as_punchy_as_a_bolt_s_and_the_finisher_s_bigger() -> void:
	var pieces := {}
	for kind: int in [ImpactFx.BOLT, ImpactFx.SLASH]:
		var fx := ImpactFx.new()
		fx.add(
			Vector3.ZERO,
			Vector3.RIGHT,
			Vector3(0.4, 0, 0),
			ImpactFx.HERO,
			0,
			ImpactFx.STRENGTH[kind],
			kind
		)
		var layer := VfxLayer.new()
		add_child_autofree(layer)
		layer.begin(3.0)
		fx.draw(layer)
		pieces[kind] = fx.last_pieces
	assert_gte(pieces[ImpactFx.SLASH], pieces[ImpactFx.BOLT], "as many pieces as a bolt's")
	assert_gt(ImpactFx.STRENGTH[ImpactFx.SLASH], 0.6, "past GF2's 0.6 share")
	assert_gte(ImpactFx.STRENGTH[ImpactFx.SLASH], ImpactFx.STRENGTH[ImpactFx.BOLT])
	assert_gt(ImpactFx.FINISHER_MULT, 1.0)


func test_slash_impacts_merge_and_stay_within_the_budget() -> void:
	var fx := ImpactFx.new()
	for k in 60:
		fx.add(
			Vector3(0, 0.6, 0),
			Vector3.FORWARD,
			Vector3(0.4, 0.6, 0),
			ImpactFx.HERO,
			5,
			1.1,
			ImpactFx.SLASH
		)
	assert_eq(fx.live(), 1, "a burst of slashes on one spot draws once")
	var many := ImpactFx.new()
	for k in 80:
		many.add(
			Vector3(k, 0.6, 0),
			Vector3.FORWARD,
			Vector3(k + 0.4, 0.6, 0),
			ImpactFx.HERO,
			5,
			1.4,
			ImpactFx.SLASH
		)
	assert_eq(many.live(), ImpactFx.MAX_LIVE)
	var layer := VfxLayer.new()
	add_child_autofree(layer)
	layer.begin(7.0)
	many.draw(layer)
	for id: StringName in [&"spark", &"debris", &"smoke"]:
		assert_lte(layer.used(id), int(layer.pools[id]["cap"]), "within the pool")


# --- The flinch ---------------------------------------------------------------------------------------------------
## The peak lean and knock of a hit with `tags` on a fresh Charger (the melee's or a bolt's), and whether the sim
## body, the node and the pose all come back.
func _flinch_of(tags: int) -> Array:
	var s := _setup()
	var w: World = s[0]
	var actors: ActorViews = s[2]
	var feel: HitFeel = s[3]
	var i: int = s[5]
	var av := _enemy_avatar(actors, s[6]) as AvatarBase
	var rest := av.transform
	var sim_before := w.actors.pos(i)
	var node_before := actors.actor_node(s[6]).position
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i) - Vector2(w.actors.radius[i], 0)
	Damage.hit(w, i, 5, pid, pid, w.take_root(), tags, at - Vector2(0.3, 0), at)
	feel.sync(s[1])
	var lean := av.flinch_amount()
	var knock := av.knock_amount()
	for f in 30:
		av.advance_flinch(DT)
		lean = maxf(lean, av.flinch_amount())
		knock = maxf(knock, av.knock_amount())
	var back := (
		av.transform == rest
		and w.actors.pos(i) == sim_before
		and actors.actor_node(s[6]).position == node_before
	)
	return [lean, knock, back]


func test_a_slash_flinches_harder_than_a_bolt_and_knocks_the_pose_away() -> void:
	var bolt := _flinch_of(SimEvent.TAG_PROJECTILE)
	var slash := _flinch_of(SimEvent.TAG_MELEE)
	assert_gt(slash[0], bolt[0] * 1.2, "a stronger flinch than a bolt's")
	assert_gt(slash[1], 0.04, "and a knock of the pose away from the swing")
	assert_eq(bolt[1], 0.0, "a bolt doesn't knock")
	assert_true(slash[2], "the pose, the node and the sim body all back where they were")
	assert_true(bolt[2])
	ViewPrefs.reduced_motion = true
	var calm := _flinch_of(SimEvent.TAG_MELEE)
	assert_lt(calm[0], slash[0], "reduced motion: smaller")
	assert_lt(calm[1], slash[1])


func test_a_boss_flinches_through_its_clip_rate_limited() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2(2.6, 0))
	var reader := WorldReader.new(w)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	actors.set_process(false)
	var rig := IsoRig.new()
	add_child_autofree(rig)
	var feel := HitFeel.new(actors, rig)
	add_child_autofree(feel)
	feel.set_process(false)
	actors.sync(reader)
	feel.sync(reader)
	var boss := _enemy_avatar(actors, w.actors.ids[i]) as BossAvatar
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i) - Vector2(w.actors.radius[i], 0)
	Damage.hit(w, i, 5, pid, pid, w.take_root(), SimEvent.TAG_MELEE, at - Vector2(0.3, 0), at)
	feel.sync(reader)
	assert_eq(feel.flinches, 1, "the clip plays on a Blade hit")
	assert_eq(boss.flinch_amount(), 1.0)
	assert_eq(feel.hit_stop.freezes, 1, "and the boss is held by the hit-stop")
	assert_gt(boss._hold, 0.0)
	Damage.hit(w, i, 5, pid, pid, w.take_root(), SimEvent.TAG_MELEE, at - Vector2(0.3, 0), at)
	feel.sync(reader)
	assert_eq(feel.flinches, 1, "a fresh one isn't restarted")


# --- The hit-stop -------------------------------------------------------------------------------------------------
## Swings at the enemy until the slash lands; returns the hit's tick (or -1).
func _swing_until_hit(s: Array) -> int:
	var w: World = s[0]
	var feel: HitFeel = s[3]
	_press(w)
	for k in 6:
		_sync(s[1], s[2], s[4], feel)
		if feel.impacts.added > 0:
			return w.tick
		_idle(w)
	return -1


func test_a_blade_hit_holds_the_hero_s_swing_and_the_struck_enemy_for_2_frames() -> void:
	var s := _setup()
	var actors: ActorViews = s[2]
	var feel: HitFeel = s[3]
	var kit: KitView = s[4]
	var id: int = s[6]
	var enemy := _enemy_avatar(actors, id) as AvatarBase
	var hero := _hero_avatar(actors, s[1])
	assert_gt(_swing_until_hit(s), 0, "the slash lands")
	assert_eq(feel.hit_stop.freezes, 1, "one freeze")
	assert_true(feel.hit_stop.holds(id))
	assert_true(enemy.holding(), "the struck enemy's pose is held")
	assert_true(hero.holding(), "the hero's swing pose is held")
	assert_true(kit.holding(), "and the blade with its trail")
	assert_true(actors.flash_held(id), "the white flash is held lit")
	assert_gt(enemy.flinch_amount(), 0.9, "held at the flinch's peak: the impact pose")
	var pose := enemy.transform
	var hero_pose := hero._pelvis.transform
	var hero_yaw := hero.body_yaw()
	for f in 2:
		enemy._process(DT)
		hero._process(DT)
		kit._process(DT)
		actors._process(DT)
		feel.hit_stop.advance(DT)
		assert_true(enemy.transform.is_equal_approx(pose), "frame %d: the enemy holds" % f)
		assert_true(
			hero._pelvis.transform.is_equal_approx(hero_pose), "frame %d: the hero holds" % f
		)
		assert_almost_eq(hero.body_yaw(), hero_yaw, 1e-5, "frame %d: its head and swing too" % f)
		assert_true(actors.is_flashing(id), "frame %d: still flashing" % f)
	assert_false(feel.hit_stop.holding(), "2 frames, then it lets go")
	assert_false(enemy.holding())
	assert_false(hero.holding())
	assert_false(kit.holding())
	# It runs on from where it stopped: the flinch carries on down from its peak, no jump back.
	enemy._process(DT)
	assert_false(enemy.transform.is_equal_approx(pose), "the enemy moves again")
	assert_gt(enemy.flinch_amount(), 0.6, "on from the peak, not reset")
	# The flash runs its own frames after the hold.
	for f in actors.flash_frames:
		actors._process(DT)
	assert_false(actors.is_flashing(id), "then the flash ends as before")


func test_the_hit_stop_never_touches_the_sim() -> void:
	var hashes := []
	for on: bool in [true, false]:
		ViewPrefs.hit_stop = on
		var s := _setup()
		var w: World = s[0]
		var feel: HitFeel = s[3]
		var actors: ActorViews = s[2]
		var enemy := _enemy_avatar(actors, s[6])
		for k in 240:
			if w.swing_t == 0 or w.combo_window > 0:
				_press(w)
			else:
				_idle(w)
			_sync(s[1], actors, s[4], feel)
			for node: Node in [enemy, actors, s[4], feel]:
				node.call(&"_process", DT)
		hashes.append([w.tick, w.state_hash(), feel.hit_stop.freezes, feel.impacts.added])
	assert_gt(hashes[0][2], 0, "on: it froze the views")
	assert_eq(hashes[1][2], 0, "off: never")
	assert_gt(hashes[1][3], 0, "the slashes landed both times")
	assert_eq(hashes[0][0], hashes[1][0], "the same ticks")
	assert_eq(hashes[0][1], hashes[1][1], "the same sim state, hash for hash")


func test_nothing_in_the_sim_or_the_input_reads_the_hit_stop() -> void:
	var dirs := ["res://src/sim", "res://src/presentation/input", "res://src/application"]
	var found := []
	for d: String in dirs:
		for path in _gd_files(d):
			var text := FileAccess.get_file_as_string(path)
			if (
				text.contains("HitStop")
				or text.contains("hit_stop_on")
				or text.contains("ViewPrefs.hit_stop")
			):
				found.append(path)
	assert_eq(found, [], "only the view knows the hit-stop")
	var driver := FileAccess.get_file_as_string("res://src/app/sim_driver.gd")
	assert_false(
		driver.contains("HitStop") or driver.contains("hit_stop"), "the driver never waits for it"
	)


func _gd_files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var da := DirAccess.open(dir)
	if da == null:
		return out
	for f in da.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in da.get_directories():
		out.append_array(_gd_files(dir + "/" + sub))
	return out


func test_one_swing_shares_one_freeze_and_fast_swings_are_rate_limited() -> void:
	var hs := HitStop.new()
	assert_true(hs.on_blade_hit(5, 100, 1, Vector3.RIGHT, false, 0), "a freeze")
	assert_true(
		hs.on_blade_hit(6, 100, 1, Vector3.RIGHT, false, 0),
		"a second enemy in the same swing joins it"
	)
	assert_eq([hs.freezes, hs.joined], [1, 1])
	assert_almost_eq(hs.left(), HitStop.HOLD_SECONDS, 1e-6, "not lengthened")
	hs.advance(DT * 3)
	assert_false(hs.holding())
	assert_false(
		hs.on_blade_hit(7, 103, 1, Vector3.RIGHT, false, 0),
		"the same swing's later hit: no second freeze"
	)
	assert_false(
		hs.on_blade_hit(5, 104, 2, Vector3.RIGHT, false, 0), "a new swing too soon: limited"
	)
	assert_eq(hs.limited, 1)
	assert_true(
		hs.on_blade_hit(5, 100 + HitStop.MIN_GAP_TICKS, 3, Vector3.RIGHT, false, 0),
		"after the gap: again"
	)
	assert_eq(hs.freezes, 2)


func test_two_enemies_struck_by_one_slash_share_the_freeze() -> void:
	var s := _setup(K.CHARGER, Vector2(1.3, 0.45))
	var w: World = s[0]
	var id2 := w.add_enemy(K.CHARGER, Vector2(1.3, -0.45))
	var i2 := w.actors.index_of(id2)
	w.actors.invuln[i2] = 0
	w.actors.hp[i2] = 1 << 20
	w.actors.max_hp[i2] = 1 << 20
	(s[2] as ActorViews).sync(s[1])
	assert_gt(_swing_until_hit(s), 0)
	var feel: HitFeel = s[3]
	assert_eq(feel.hit_stop.freezes, 1, "one freeze")
	assert_eq(feel.hit_stop.joined, 1, "the second hit joined it")
	assert_true(feel.hit_stop.holds(s[6]) and feel.hit_stop.holds(id2), "both struck enemies held")


func test_the_option_and_reduced_motion_turn_it_off() -> void:
	var profile := ProfileStore.new("")
	assert_eq(GameSettings.get_value(profile, "hit_stop"), "on", "on by default")
	profile.section("settings")["hit_stop"] = "off"
	ViewPrefs.apply_settings(profile)
	assert_false(ViewPrefs.hit_stop, "Options off reaches the view")
	assert_false(HitStop.new().on_blade_hit(5, 100, 1, Vector3.RIGHT, false, 0))
	profile.section("settings")["hit_stop"] = "on"
	profile.section("settings")["reduced_motion"] = "on"
	ViewPrefs.apply_settings(profile)
	assert_true(ViewPrefs.hit_stop)
	assert_false(ViewPrefs.hit_stop_on(), "reduced motion turns it off")
	assert_false(HitStop.new().on_blade_hit(5, 100, 1, Vector3.RIGHT, false, 0))
	profile.section("settings")["reduced_motion"] = "off"
	ViewPrefs.apply_settings(profile)
	assert_true(ViewPrefs.hit_stop_on())


func test_options_accessibility_has_the_hit_stop_row() -> void:
	var menu := OptionsMenu.new(ProfileStore.new(""))
	add_child_autofree(menu)
	menu._open(&"accessibility")
	var c := menu.find_child("hit_stop", true, false) as OptionCycler
	assert_not_null(c, "a Hit-stop row under Accessibility")
	var row := c.get_parent()
	var label := row.get_child(0) as Label
	assert_eq(label.text, "UI_HIT_STOP", "its label is the translated key")
	assert_ne(tr("UI_HIT_STOP"), "UI_HIT_STOP", "with an English string")


func test_the_camera_kick_is_tiny_brief_and_follows_the_shake_option() -> void:
	var rig := IsoRig.new()
	add_child_autofree(rig)
	rig.set_process(false)
	rig.kick(Vector3.RIGHT, HitStop.KICK_M)
	assert_gt(rig.kick_offset().length(), 0.0, "a kick along the swing")
	assert_lte(rig.kick_offset().length(), HitStop.KICK_M + 1e-6, "tiny")
	rig._process(IsoRig.KICK_SECONDS + 0.01)
	assert_eq(rig.kick_offset(), Vector2.ZERO, "and brief")
	rig.shake_enabled = false
	rig.kick(Vector3.RIGHT, HitStop.KICK_M)
	assert_eq(rig.kick_offset(), Vector2.ZERO, "shake off: no kick")
	rig.shake_enabled = true
	ViewPrefs.reduced_motion = true
	rig.kick(Vector3.RIGHT, HitStop.KICK_M)
	assert_eq(rig.kick_offset(), Vector2.ZERO, "reduced motion: no kick")
