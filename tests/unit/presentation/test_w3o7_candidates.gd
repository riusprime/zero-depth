extends GutTest
## v0.10.5 W3-O7 (owner F6, F16; docs/roadmap/v0.10.5/W3_O7_VFX_G2.md): the G2 candidate looks for the purple enemy
## bolt (the Twin Wardens' violet ember) and the Lance's ball. Today's looks stay the default until the owner picks;
## each candidate is a row of the pack table (so the session warm-up compiles it before a fight), and the recoloured
## fireball takes each shot's own colours.

const VIOLET := &"warden_violet_ember"


func after_each() -> void:
	CandidateLooks.bolt = CandidateLooks.BOLT
	CandidateLooks.lance = CandidateLooks.LANCE


func _colors(a: Color, b: Color, c: Color) -> Dictionary:
	return {&"primary": a, &"secondary": b, &"tertiary": c}


func test_todays_looks_stay_the_default() -> void:
	assert_eq(CandidateLooks.BOLT, &"", "the purple bolt: today's look until the owner picks")
	assert_eq(CandidateLooks.LANCE, &"", "the Lance: today's look until the owner picks")
	assert_eq(CandidateLooks.bolt_id(VIOLET), &"shot_warden_violet_ember")
	var pk := CandidateLooks.lance_pack(
		&"", PackLooks.colors(PackedStringArray()), HeroPulseViews.BIG_PER_RADIUS
	)
	assert_eq(pk[0], &"vx2_big_storm", "the plain Lance's big orb")
	assert_eq(float(pk[2]), HeroPulseViews.BIG_PER_RADIUS)
	assert_eq(
		CandidateLooks.lance_pack(&"ember", {}, HeroPulseViews.BIG_PER_RADIUS)[0], &"vx2_big_ember"
	)


func test_every_candidate_is_a_table_row_in_its_family_and_warmed() -> void:
	var def := PackFx.shared_def()
	var fx := PackFx.new(def)
	var warm := fx.warm_ids()
	fx.free()
	for c: StringName in CandidateLooks.BOLTS:
		var id: StringName = CandidateLooks.BOLTS[c][0]
		var k := def.row(id)
		assert_gte(k, 0, "bolt %s: %s is in the table" % [c, id])
		if k >= 0:
			assert_eq(def.families[k], FireballViews.PACK_FAMILY, "bolt %s: a hostile shot" % c)
		assert_has(warm, id, "bolt %s: warmed with the session" % c)
	for c: StringName in CandidateLooks.LANCES:
		CandidateLooks.lance = c
		for e: StringName in [&"", &"ember", &"frost", &"venom", &"storm", &"bleed", &"void"]:
			var id: StringName = CandidateLooks.lance_pack(e, {}, HeroPulseViews.BIG_PER_RADIUS)[0]
			var k := def.row(id)
			assert_gte(k, 0, "lance %s, %s: %s is in the table" % [c, e, id])
			if k >= 0:
				assert_eq(def.families[k], &"projectile", "lance %s: a hero projectile" % c)
			assert_has(warm, id, "lance %s: warmed with the session" % c)


func test_a_picked_bolt_candidate_draws_only_the_violet_ember() -> void:
	CandidateLooks.bolt = &"c"
	assert_eq(CandidateLooks.bolt_id(VIOLET), &"w3o7_bolt_c")
	assert_eq(
		CandidateLooks.bolt_hide(VIOLET, []), ["Flare"], "the flare orb's star burst is left out"
	)
	assert_eq(
		CandidateLooks.bolt_id(&"warden_amber_ember"),
		&"shot_warden_amber_ember",
		"the amber twin keeps its own"
	)
	assert_eq(
		CandidateLooks.bolt_hide(&"prism_orb", ["Flare"]),
		["Flare"],
		"PACK_HIDE still applies elsewhere"
	)
	assert_has(
		FireballPack.ids(), &"w3o7_bolt_c", "the floor's prefill fills the picked look's pool"
	)
	assert_does_not_have(FireballPack.ids(), &"shot_warden_violet_ember")


func test_the_violet_ember_spawns_the_picked_candidate() -> void:
	for c: StringName in CandidateLooks.BOLTS:
		CandidateLooks.bolt = c
		var w := CombatLab.world()
		var fb := FireballViews.new()
		add_child_autofree(fb)
		var pack := PackFx.new()
		add_child_autofree(pack)
		fb.pack_fx = pack
		w.projectiles.add(801, -1, 1, Vector2(3, 1), Vector2(3, 0), 0.2, 600)
		w.projectiles.set_look(0, VIOLET)
		fb.sync(WorldReader.new(w))
		var id: StringName = CandidateLooks.BOLTS[c][0]
		assert_eq(pack.pooled(id), 1, "%s: the violet ember is drawn by %s" % [c, id])
		assert_eq(fb.edge_count(VIOLET), 1, "%s: its dark edge (hostile) is still drawn" % c)


func test_the_lance_candidate_a_takes_the_fireball_colours() -> void:
	CandidateLooks.lance = &"a"
	var cols := PackLooks.colors(PackedStringArray(["frost"]))
	var pk := CandidateLooks.lance_pack(&"frost", cols, HeroPulseViews.BIG_PER_RADIUS)
	assert_eq(pk[0], &"w3o7_lance_a")
	var c: Dictionary = pk[1]
	assert_eq(
		c[&"primary"], cols[&"secondary"], "its hot puffs and light: the element's hot centre"
	)
	assert_eq(c[&"secondary"], cols[&"tertiary"], "its flame and rim: the element's deep tone")
	CandidateLooks.lance = &"b"
	var jav := CandidateLooks.lance_pack(&"frost", cols, HeroPulseViews.BIG_PER_RADIUS)
	assert_eq(jav[0], &"vx2_jav_frost", "the element's javelin")
	assert_eq(jav[1], cols, "in the element's own colours")


func test_the_recoloured_fireball_takes_each_shots_own_colours() -> void:
	var pack := PackFx.new()
	add_child_autofree(pack)
	var violet := _colors(Color("#BB99CC"), Color("#7A3ADB"), Color("#3A1A6A"))
	var blue := _colors(Color("#F4FCFF"), Color("#2050C8"), Color("#2050C8"))
	var a := pack.spawn(&"w3o7_bolt_a", Vector3.ZERO, 1.0, violet, 0.0)
	var b := pack.spawn(&"w3o7_lance_a", Vector3.ONE, 1.0, blue, 0.0)
	assert_not_null(a)
	assert_not_null(b)
	var parts := 0
	for name: String in ["Flame", "Ball", "sparks"]:
		var ma := (a.get_node(name) as GeometryInstance3D).material_override as ShaderMaterial
		var mb := (b.get_node(name) as GeometryInstance3D).material_override as ShaderMaterial
		assert_ne(ma, mb, "%s: each instance its own material" % name)
		assert_eq(
			ma.get_shader_parameter(&"primary_color"), violet[&"primary"], "%s: the bolt's" % name
		)
		assert_eq(
			mb.get_shader_parameter(&"primary_color"), blue[&"primary"], "%s: the Lance's" % name
		)
		parts += 1
	assert_eq(parts, 3)
	var flame := (a.get_node("Flame") as GeometryInstance3D).material_override as ShaderMaterial
	assert_eq(
		flame.get_shader_parameter(&"secondary_color"),
		violet[&"secondary"],
		"the flame is the bolt's violet"
	)
