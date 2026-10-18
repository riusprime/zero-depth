extends GutTest
## v0.8.0 BD (owner O82, O83): each biome's boss room door is the owner's model for that biome (BossDoorModels),
## its jambs at the gap's sides and its slab exactly the gap's width; no model (an unknown biome, or the file missing)
## is the code-made door, as before. On a floor with the press the slab follows the sim's opening; on a floor saved
## before BD it opens by nearness, as before.

const BIOMES: Array[StringName] = [
	&"ruins", &"night_rocks", &"red_canyon", &"frozen_shore", &"starfall"
]
const WIDTH := 3.0


func after_each() -> void:
	BossDoorModels.dir = BossDoorModels.DIR
	BossDoorModels.clear_cache()


func _door(biome: StringName, width: float = WIDTH) -> BossDoorView:
	var d := BossDoorView.new()
	add_child_autofree(d)
	d.setup(Vector2.ZERO, 0, width, 0.4, Color(0.5, 0.5, 0.5), biome)
	return d


func test_each_biome_draws_its_own_door() -> void:
	var meshes := {}
	for b in BIOMES:
		var d := _door(b)
		assert_true(d.from_model, "%s: the owner's door" % b)
		assert_not_null(d.jamb_n, b)
		assert_not_null(d.lintel, b)
		assert_eq(d.jamb_n.position.z, -WIDTH * 0.5, "%s: a jamb at each side of the gap" % b)
		assert_eq(d.jamb_p.position.z, WIDTH * 0.5, b)
		assert_eq(d.jamb_n.scale, Vector3.ONE, "%s: the jambs unscaled" % b)
		var spec: Dictionary = BossDoorModels.SPECS[b]
		assert_almost_eq(
			d.slab.scale.z * float(spec["width"]), WIDTH, 0.001, "%s: the slab is the gap" % b
		)
		var box := d.slab.mesh.get_aabb()
		assert_almost_eq(box.size.y, 2.6, 0.05, "%s: an 18 %% bigger slab (2.6 m)" % b)
		assert_almost_eq(box.size.z * d.slab.scale.z, WIDTH, 0.06, "%s: its width" % b)
		meshes[d.slab.mesh] = true
	assert_eq(meshes.size(), BIOMES.size(), "five different doors")


func test_no_model_is_the_code_made_door() -> void:
	var d := _door(&"")
	assert_false(d.from_model, "no biome: the code-made door")
	assert_true(d.slab.mesh is BoxMesh)
	BossDoorModels.dir = "res://tests/fixtures/no_such_dir/"
	BossDoorModels.clear_cache()
	var e := _door(&"ruins")
	assert_false(e.from_model, "the file missing: the code-made door (L15)")
	assert_true(e.slab.mesh is BoxMesh)


## v0.8.0 BW (owner, 2026-10-18: "doors are too thin"): a thick wall gets a frame on each face, the slab in the
## middle and a lining along the passage's sides; a thin one keeps the one frame.
func test_a_thick_wall_is_a_tunnel_with_a_frame_on_each_face() -> void:
	const HALF := 2.5
	for b in BIOMES:
		var d := BossDoorView.new()
		add_child_autofree(d)
		d.setup(Vector2.ZERO, 0, WIDTH, HALF, Color(0.5, 0.5, 0.5), b)
		assert_eq(d.frames.size(), 2, "%s: a frame on each face" % b)
		var front := _x_span(d.frames[0])
		var back := _x_span(d.frames[1])
		var out := HALF + BossDoorView.FRAME_PROUD
		assert_almost_eq(front.x, -out, 0.01, "%s: the front frame proud of the front face" % b)
		assert_almost_eq(back.y, out, 0.01, "%s: the back frame proud of the back face" % b)
		assert_eq(d.slab.position.x, 0.0, "%s: the slab in the middle" % b)
		assert_eq(d.lining.size(), 2, "%s: a lining on each side" % b)
		for l in d.lining:
			var size: Vector3 = (l.mesh as BoxMesh).size
			assert_gt(l.position.x + size.x * 0.5, back.x, "%s: tucked under the back frame" % b)
			assert_lt(l.position.x - size.x * 0.5, front.y, "%s: tucked under the front frame" % b)
			var inner := absf(l.position.z) - size.z * 0.5
			assert_lt(inner, WIDTH * 0.5, "%s: over the wall's cut end" % b)
		assert_eq(_door(b).frames.size(), 1, "%s: a thin wall keeps the one frame" % b)
		assert_eq(_door(b).lining.size(), 0, b)


## The X span (min, max) of a frame's parts in the door's frame.
func _x_span(frame: Node3D) -> Vector2:
	var lo := INF
	var hi := -INF
	for c in frame.get_children():
		var m := c as MeshInstance3D
		var box := (frame.transform * m.transform) * m.mesh.get_aabb()
		lo = minf(lo, box.position.x)
		hi = maxf(hi, box.end.x)
	return Vector2(lo, hi)


func _world(rules: int) -> World:
	var lab := RunLab.new(ContentRepository.load_all(), 8311, &"blade")
	lab.run.floor_rules = rules
	return lab.floor_world()


func _press(w: World) -> void:
	w.step(InputFrame.new())
	w.actors.set_pos(0, w.floor_layout.boss_door_outside(0.8))
	w.vel = Vector2.ZERO
	var f := InputFrame.new()
	f.pressed = InputFrame.INTERACT
	w.step(f)


func test_the_slab_follows_the_sims_opening_and_lands() -> void:
	var w := _world(RunState.FLOOR_RULES)
	var r := WorldReader.new(w)
	var d := _door(&"ruins", r.boss_door_width())
	d.sync(r)
	d.settle()
	assert_eq(d.open_amount, 0.0, "shut while you stand by it")
	_press(w)
	for k in BossFlow.DOOR_OPEN_TICKS / 2:
		w.step(InputFrame.new())
	d.sync(r)
	assert_almost_eq(d.open_amount, 0.5, 0.02, "half way down with the sim")
	assert_almost_eq(d.slab.position.y, -0.5 * (2.6 + 0.05), 0.06, "the slab slid half its height")
	assert_true(d.slab.visible)
	var landed := false
	for k in BossFlow.DOOR_OPEN_TICKS / 2 + 2:
		w.step(InputFrame.new())
		d.sync(r)
		landed = landed or d.landed
	assert_true(landed, "it lands once (the shake)")
	assert_eq(d.open_amount, 1.0)
	assert_false(d.slab.visible, "down in the floor")


func test_the_seal_goes_dark_after_the_boss_as_before() -> void:
	var d := _door(&"starfall")
	assert_almost_eq(d.seal_material.emission_energy_multiplier, BossDoorView.SEAL_ENERGY, 0.001)
	var discs := d.slab.find_children("*", "MeshInstance3D", false, false)
	assert_eq(discs.size(), 10, "a disc and four studs on each face")
	var w := _world(RunState.FLOOR_RULES)
	var r := WorldReader.new(w)
	w.actors.invuln[0] = 1 << 24
	w.actors.set_pos(0, w.floor_layout.boss_door_inside(BossFlow.ENTRY_DEPTH_M + 1.2))
	for k in 4:
		w.step(InputFrame.new())
	d.sync(r)
	d.settle()
	assert_true(d.is_sealed(), "sealed behind you")
	assert_eq(d.open_amount, 0.0, "the slab up")
	for i in range(1, w.actors.size()):
		if w.actors.dead[i] == 0 and w.actors.teams[i] == ActorStore.TEAM_ENEMY:
			w.actors.invuln[i] = 0
			Damage.hit(w, i, 9999999, 0, 0, 1, 0, w.actors.pos(i), w.actors.pos(i))
	w.step(InputFrame.new())
	d.sync(r)
	assert_true(r.portal_active(), "the boss is dead")
	assert_almost_eq(
		d.seal_material.emission_energy_multiplier, BossDoorView.SEAL_ENERGY_SPENT, 0.001, "dark"
	)


func test_a_floor_before_bd_opens_by_nearness() -> void:
	var w := _world(RunState.FLOOR_RULES_V080_N19)
	var r := WorldReader.new(w)
	var d := _door(&"red_canyon", r.boss_door_width())
	w.actors.set_pos(0, w.floor_layout.boss_door_outside(1.0))
	w.step(InputFrame.new())
	d.sync(r)
	d.settle()
	assert_eq(d.open_amount, 1.0, "near: open, as before")
