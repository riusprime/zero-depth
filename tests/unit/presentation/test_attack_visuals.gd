extends GutTest
## v0.8.0 AV (owner O7, O8): the hostile fireballs are lit 3D bodies (every source's look defined, each with its own
## shape, three pooled MultiMeshes a look, Low density thins the trails, reduced motion stills them, the big ones ask
## for light within VfxCore's budget), and the Gatekeeper's shock lanes crack the ground while they track and lock,
## then strike as stone spikes along the lanes they hit, which sink and return to the pool (bounded), with debris,
## dust, a flash and crack marks in the effects layer.

const PATTERNS := "res://data/bullet_patterns/"


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false


func after_each() -> void:
	ViewPrefs.effects_density = "high"
	ViewPrefs.reduced_motion = false
	StoneSpikeViews.model_path = StoneSpikeViews.MODEL_PATH
	StoneSpikeViews.clear_cache()


func _firing(id: StringName, attack_id: StringName, ticks: int = 70) -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, id, Vector2.ZERO)
	w.actors.set_pos(0, Vector2(9, 0))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	BossLab.start(w, i, attack_id)
	CombatLab.idle(w, ticks)
	return [w, i]


## Every look key the content's bullet patterns name (bosses and enemies alike).
func _content_looks() -> Array[StringName]:
	var out: Array[StringName] = []
	for f in DirAccess.get_files_at(PATTERNS):
		if not f.ends_with(".tres"):
			continue
		var res: Resource = load(PATTERNS + f)
		var key := StringName(res.get("look"))
		if key != &"" and not out.has(key):
			out.append(key)
	return out


# --- Fireballs ---------------------------------------------------------------------------------------------------
func test_every_fireball_source_has_its_own_3d_look() -> void:
	var looks := _content_looks()
	assert_gt(looks.size(), 8, "the patterns name their looks")
	for key in looks:
		assert_true(FireballViews.LOOKS.has(key), "%s has a look of its own" % key)
		var look := FireballViews.look_of(key)
		assert_not_null(ProjectileMeshes.get_mesh(look["mesh"]), "%s: a 3D body" % key)
		var m := FireballViews.core_material(look)
		assert_true(m.shader == FireballShaders.core(float(look.get("opacity", 1.0)) < 1.0))
		assert_gt(float(m.get_shader_parameter("energy")), 1.0, "%s: it glows" % key)
		assert_true(FireballViews.trail_material(look).shader != null, "%s: a trail" % key)


func test_each_look_keeps_its_identity() -> void:
	var expect := {
		&"ember_stone": [&"rock", &"glow"],
		&"spear_ember": [&"spear", &"glow"],
		&"prism_orb": [&"gem", &"glow"],
		&"acid_glob": [&"glob", &"drips"],
		&"molten_drop": [&"drop", &"drips"],
		&"cannon_ember": [&"rock", &"smoke"],
		&"arc_plasma": [&"orb", &"glow"],
		&"lens_orb": [&"orb", &"glow"],
		&"bomb_cinder": [&"orb", &"glow"],
	}
	for key: StringName in expect:
		var look := FireballViews.look_of(key)
		assert_eq(look["mesh"], expect[key][0], "%s's shape" % key)
		assert_eq(look["trail_style"], expect[key][1], "%s's trail" % key)
	assert_lt(float(FireballViews.look_of(&"acid_glob")["opacity"]), 1.0, "the acid is see-through")
	assert_gt(float(FireballViews.look_of(&"acid_glob")["wobble"]), 0.0, "and wobbles")
	assert_gt(float(FireballViews.look_of(&"prism_orb")["facets"]), 0.0, "the prism glints")
	assert_gt(
		float(FireballViews.look_of(&"ember_stone")["crack"]), 0.5, "the stone glows in veins"
	)
	assert_gt(
		float(FireballViews.look_of(&"spear_ember")["tip"]), 1.5, "the spear ember is elongated"
	)
	assert_true(FireballViews.trail_material(FireballViews.look_of(&"arc_plasma")).shader != null)
	assert_true(
		(
			FireballViews.trail_material(FireballViews.look_of(&"cannon_ember")).shader
			== FireballShaders.trail(false)
		),
		"smoke is mixed, not added light"
	)


func test_each_look_is_three_pooled_multimeshes() -> void:
	var s := _firing(&"gatekeeper", &"rock_rings", 110)
	var reader := WorldReader.new(s[0])
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	var n := reader.projectile_count()
	assert_gt(n, 0)
	var parts := fb.get_children()
	assert_eq(parts.size(), 3, "one look: core, edge and trail, one draw each")
	for mi: MultiMeshInstance3D in parts:
		assert_gte(mi.multimesh.instance_count, mi.multimesh.visible_instance_count)
		assert_true(mi.material_override is ShaderMaterial, "%s is shaded" % mi.name)
	var core: MultiMeshInstance3D = fb.get_node("ember_stone_core")
	assert_eq(core.multimesh.visible_instance_count, n, "every stone drawn")
	CombatLab.idle(s[0], 30)
	fb.sync(reader)
	assert_eq(fb.get_child_count(), 3, "the pool is reused, not grown per shot")


func test_density_low_thins_and_narrows_the_trails_and_keeps_the_balls() -> void:
	var s := _firing(&"gatekeeper", &"rock_rings", 110)
	var reader := WorldReader.new(s[0])
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	var wide := fb.trail_width()
	var balls := fb.ball_count(&"ember_stone")
	var trails := fb.trail_count(&"ember_stone")
	ViewPrefs.effects_density = "low"
	fb.sync(reader)
	assert_eq(fb.ball_count(&"ember_stone"), balls, "the balls stay")
	assert_lt(fb.trail_count(&"ember_stone"), trails, "fewer trails")
	assert_lt(fb.trail_width(), wide, "thinner")


func test_reduced_motion_stills_the_swirl_and_the_turning() -> void:
	var s := _firing(&"gatekeeper", &"rock_rings", 110)
	var reader := WorldReader.new(s[0])
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	var core: MultiMeshInstance3D = fb.get_node("ember_stone_core")
	var mat := core.material_override as ShaderMaterial
	assert_eq(float(mat.get_shader_parameter("motion")), 1.0)
	ViewPrefs.reduced_motion = true
	fb.sync(reader)
	for part in ["core", "edge", "trail"]:
		var m := (fb.get_node("ember_stone_" + part) as MultiMeshInstance3D).material_override
		assert_eq(float((m as ShaderMaterial).get_shader_parameter("motion")), 0.0, part)


func test_the_big_ones_ask_for_light_within_the_budget() -> void:
	var w := CombatLab.world()
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	w.add_enemy(ActorStore.Kind.BOMB_DRONE, Vector2(7, 0))
	var reader := WorldReader.new(w)
	var fb := FireballViews.new()
	add_child_autofree(fb)
	var layer: VfxLayer = add_child_autofree(VfxLayer.new())
	layer.drawers.append(fb.draw_lights)
	var lit := false
	for k in 600:
		w.step(InputFrame.new())
		w.actors.hp[0] = w.actors.max_hp[0]
		fb.sync(reader)
		assert_eq(fb.light_requests() > 0, fb.lob_count() > 0, "a light while the fireball flies")
		if fb.lob_count() > 0:
			layer.begin(float(k))
			layer.finish()
			assert_gt(layer.lights_on(), 0)
			assert_lte(layer.lights_on(), VfxCore.LIGHTS, "within the budget")
			lit = true
	assert_true(lit, "the lob flew")


func test_a_bosss_signature_shots_ask_for_a_few_lights_only() -> void:
	var s := _firing(&"gatekeeper", &"rock_rings", 110)
	var reader := WorldReader.new(s[0])
	assert_true(reader.boss_shielded(s[1]), "the signature pattern runs")
	var fb := FireballViews.new()
	add_child_autofree(fb)
	fb.sync(reader)
	assert_gt(fb.light_requests(), 0)
	assert_lte(fb.light_requests(), FireballViews.SIGNATURE_LIGHTS)
	var plain := _firing(&"warlord", &"javelin_fan", 90)
	var fb2 := FireballViews.new()
	add_child_autofree(fb2)
	fb2.sync(WorldReader.new(plain[0]))
	assert_gt(fb2.count(), 0)
	assert_eq(fb2.light_requests(), 0, "ordinary shots light nothing")


# --- Stone spikes ------------------------------------------------------------------------------------------------
func _lanes_fight(attack_id: StringName = &"shock_lanes") -> Array:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	var aid := w.actors.ids[i]
	w.actors.set_pos(0, Vector2(6, 3))
	w.actors.hp[0] = 1 << 20
	w.actors.max_hp[0] = 1 << 20
	BossLab.start(w, i, attack_id)
	return [w, aid]


func test_the_shock_lanes_strike_as_spikes_that_sink_back_into_the_pool() -> void:
	var s := _lanes_fight()
	var w: World = s[0]
	var aid: int = s[1]
	var reader := WorldReader.new(w)
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	var atk := BossAi.attack_of(w, w.actors.index_of(aid))
	var lanes: Array = []
	for t in atk.windup_ticks - 1:
		w.step(InputFrame.new())
		spikes.sync(reader)
		assert_eq(spikes.strike_count(), 0, "nothing rises before the strike")
		var tg := reader.telegraph(w.actors.index_of(aid))
		if not tg.is_empty():
			lanes = tg["items"][0]["obbs"]
	w.step(InputFrame.new())  # the strike tick
	spikes.sync(reader)
	assert_eq(spikes.strike_count(), 1, "the strike raises its spikes")
	assert_gt(spikes.pooled(), 20, "a row down each lane")
	assert_lte(spikes.pooled(), StoneSpikeViews.MAX_SPIKES)
	for k in 6:
		w.step(InputFrame.new())
		spikes.sync(reader)
	assert_gt(spikes.spike_count(), 20, "standing")
	var mm: MultiMesh = (spikes.get_node("Spikes") as MultiMeshInstance3D).multimesh
	assert_eq(mm.visible_instance_count, spikes.spike_count(), "one instance a spike")
	var bases := spikes.spike_positions()
	assert_eq(bases.size(), spikes.spike_count())
	for k in bases.size():
		var p := SimPlane.to_sim(bases[k])
		var inside := false
		for lane: Obb in lanes:
			inside = inside or Collide.circle_vs_obb(p, 0.05, lane) != Vector2.ZERO
		assert_true(inside, "spike %d stands in a lane it hit" % k)
	for k in int(StoneSpikeViews.LIFE_TICKS + StoneSpikeViews.SPREAD_TICKS) + 2:
		w.step(InputFrame.new())
		spikes.sync(reader)
	assert_eq(spikes.strike_count(), 0, "the strike ends")
	assert_eq(spikes.pooled(), 0, "back in the pool")
	# v0.8.0 BS1 (owner O5, S1): the pillars stay standing (the sim's walls), then sink when they go.
	assert_eq(spikes.pillar_count(), w.bosses.pillar_x.size(), "one cluster a pillar")
	assert_gt(spikes.pillar_count(), 0, "the spikes that stay")
	assert_eq(
		spikes.spike_count(),
		spikes.pillar_count() * (StoneSpikeViews.PILLAR_SATELLITES + 1),
		"only the pillars stand"
	)
	CombatLab.idle(w, atk.pillar_ticks)
	spikes.sync(reader)
	assert_eq(w.bosses.pillar_x.size(), 0)
	assert_eq(spikes.spike_count(), 0, "sunk")
	assert_eq(mm.visible_instance_count, 0)


func test_only_the_shock_lanes_raise_spikes() -> void:
	for attack_id: StringName in [&"fist_slam", &"rock_rings", &"sweep"]:
		var w := BossLab.world()
		var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
		w.actors.set_pos(0, Vector2(6, 3))
		w.actors.hp[0] = 1 << 20
		w.actors.max_hp[0] = 1 << 20
		BossLab.start(w, i, attack_id)
		var reader := WorldReader.new(w)
		var spikes := StoneSpikeViews.new()
		add_child_autofree(spikes)
		for t in 200:
			w.step(InputFrame.new())
			spikes.sync(reader)
			assert_eq(spikes.strike_count(), 0, "%s raises no spikes" % attack_id)


func test_the_spike_pool_is_bounded() -> void:
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	for k in 30:
		var a := AttackShapes.lane(Vector2(-12, k * 0.3), 0, 24.0, 0.6)
		var b := AttackShapes.lane(Vector2(k * 0.3, -12), 1024, 24.0, 0.6)
		spikes._spawn([a, b], 100)
	assert_lte(spikes.pooled(), StoneSpikeViews.MAX_SPIKES)
	assert_lte(spikes.strike_count(), StoneSpikeViews.MAX_STRIKES)
	spikes._draw(103.0)
	assert_lte(spikes.spike_count(), StoneSpikeViews.MAX_SPIKES)


func test_the_thrust_overshoots_unless_reduced_motion_and_ends_sunk() -> void:
	var top := 0.0
	var top_still := 0.0
	for k in 60:
		var a := k * 0.1
		top = maxf(top, StoneSpikeViews.extent(a, false))
		top_still = maxf(top_still, StoneSpikeViews.extent(a, true))
	assert_gt(top, 1.0, "a quick thrust past its height")
	assert_almost_eq(top_still, 1.0, 0.001, "reduced motion: no overshoot")
	assert_eq(StoneSpikeViews.extent(0.0, false), 0.0)
	assert_eq(StoneSpikeViews.extent(StoneSpikeViews.LIFE_TICKS, false), 0.0, "sunk at the end")


func test_the_strike_throws_debris_and_dust_flashes_and_cracks_the_floor() -> void:
	var s := _lanes_fight()
	var w: World = s[0]
	var reader := WorldReader.new(w)
	var spikes := StoneSpikeViews.new()
	add_child_autofree(spikes)
	var layer: VfxLayer = add_child_autofree(VfxLayer.new())
	spikes.vfx = layer
	layer.drawers.append(spikes.draw_fx)
	var atk := BossAi.attack_of(w, w.actors.index_of(s[1]))
	for t in atk.windup_ticks + 4:
		w.step(InputFrame.new())
		spikes.sync(reader)
	assert_eq(spikes.strike_count(), 1)
	layer.begin(float(reader.tick()))
	layer.finish()
	assert_gt(layer.used(&"debris"), 0, "rock debris")
	assert_gt(layer.used(&"smoke"), 0, "dust")
	assert_gt(layer.lights_on(), 0, "a hot flash")
	assert_gt(layer.marks_of(BossStrikeFx.crack_mark()), 0, "cracks left on the floor")
	ViewPrefs.effects_density = "low"
	var high := layer.used(&"debris")
	layer.density = 0.3
	layer.begin(float(reader.tick()))
	layer.finish()
	assert_lt(layer.used(&"debris"), high, "thinned with the density")


func test_the_spike_is_code_made_until_the_owners_model_is_listed() -> void:
	StoneSpikeViews.model_path = "res://assets/models/fx/no_such_spike.glb"
	StoneSpikeViews.clear_cache()
	assert_false(StoneSpikeViews.from_model(), "no model: the code spike")
	var m := StoneSpikeViews.spike_mesh()
	assert_not_null(m)
	var box := m.get_aabb()
	assert_almost_eq(box.end.y, 1.0, 0.01, "one unit tall")
	assert_lt(box.position.y, 0.0, "planted a little below the floor")


# --- The cracked-ground marker -----------------------------------------------------------------------------------
func _fill_materials(tv: TelegraphViews) -> Array:
	var out := []
	for mi: MeshInstance3D in tv.find_children("Fill", "MeshInstance3D", true, false):
		var im := mi.mesh as ImmediateMesh
		for k in im.get_surface_count():
			out.append(im.surface_get_material(k))
	return out


func test_the_shock_lanes_crack_the_ground_while_tracking_and_locked() -> void:
	var s := _lanes_fight()
	var w: World = s[0]
	var reader := WorldReader.new(w)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	var i := w.actors.index_of(s[1])
	CombatLab.idle(w, 10)
	tv.sync(reader)
	assert_true(TelegraphViews.is_cracked(reader.telegraph(i)))
	var mats := _fill_materials(tv)
	assert_eq(mats.size(), 1, "tracking: faint cracks along the lanes")
	assert_true(mats[0] is ShaderMaterial, "cracked ground, not a flat red fill")
	var dim := float((mats[0] as ShaderMaterial).get_shader_parameter("heat"))
	var atk := BossAi.attack_of(w, i)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks - 10 + 2)
	tv.sync(reader)
	tv._process(0.0)
	assert_true(reader.telegraph(i)["locked"])
	mats = _fill_materials(tv)
	assert_eq(mats.size(), 1)
	var hot := float((mats[0] as ShaderMaterial).get_shader_parameter("heat"))
	assert_gt(hot, dim, "locked: the cracks glow hot")
	ViewPrefs.reduced_motion = true
	tv._process(0.05)
	assert_eq(
		float((mats[0] as ShaderMaterial).get_shader_parameter("heat")),
		TelegraphViews.CRACK_LOCK_HEAT.y,
		"steady with reduced motion"
	)


## v0.8.0 AV part 2: the fist slams' locked circles flash in the stone look (BossStrikeLooks), not the shock lanes'
## cracked ground and not flat red.
func test_the_fist_slams_flash_in_their_own_look() -> void:
	var w := BossLab.world()
	var i := BossLab.ready_boss(w, &"gatekeeper", Vector2.ZERO)
	w.actors.set_pos(0, Vector2(6, 0))
	w.actors.hp[0] = 1 << 20
	BossLab.start(w, i, &"fist_slam")
	var atk := BossAi.attack_of(w, i)
	CombatLab.idle(w, atk.windup_ticks - atk.lock_ticks + 2)
	var tv := TelegraphViews.new()
	add_child_autofree(tv)
	tv.sync(WorldReader.new(w))
	assert_false(TelegraphViews.is_cracked(WorldReader.new(w).telegraph(i)))
	var mats := _fill_materials(tv)
	assert_gt(mats.size(), 0)
	for m in mats:
		assert_true(m is ShaderMaterial, "the circles flash styled")
		assert_eq(
			(m as ShaderMaterial).shader, BossStrikeLooks.mark_shader(), "not the cracked lanes"
		)
