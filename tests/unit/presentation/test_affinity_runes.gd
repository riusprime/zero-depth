extends GutTest
## v0.9.0 RB (owner, PLAN "Owner decisions" RB): the robe recolours the hero's cloak and hood (the blue core stays);
## the affinity's rune shows under the feet and on the robe's back in its colour, none for None; layered (a glow, the
## circle, a light and motes; VX), Low density keeping the shapes; Guardian's spent ward dims the circle and its break
## flashes; the hub's hero and stand-in robe follow the Wardrobe; the Wardrobe panel's cyclers and its locked robes;
## Astral's pulses near secrets and its minimap mark.

var _repo: ContentRepository
var _density := "high"


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	_density = ViewPrefs.effects_density


func after_each() -> void:
	ViewPrefs.effects_density = _density


func _avatar(look: Dictionary) -> PlayerAvatar:
	var a := PlayerAvatar.new()
	a.setup(Color("#1A1A22"))
	add_child_autofree(a)
	a.set_look(look)
	return a


func _look(robe: StringName, aff: StringName) -> Dictionary:
	return Wardrobe.look(_repo, _repo.get_def(&"robe", robe), aff)


## Whether the cloak mesh holds vertex colour `c` (the mesh stores colours packed: within a step of 8 bits).
func _has_colour(a: PlayerAvatar, c: Color) -> bool:
	for v: Color in (a.cloak.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR]:
		if absf(v.r - c.r) < 0.006 and absf(v.g - c.g) < 0.006 and absf(v.b - c.b) < 0.006:
			return true
	return false


func test_a_robe_recolours_the_cloak_and_hood_not_the_core() -> void:
	var cream := _avatar({})
	var night := _avatar(_look(&"night", &"none"))
	var ncol: Color = (_repo.get_def(&"robe", &"night") as RobeDefinition).cloak
	var nunder: Color = (_repo.get_def(&"robe", &"night") as RobeDefinition).underside
	assert_true(_has_colour(cream, PlayerAvatar.CLOAK_COLOR), "Cream by default")
	assert_true(_has_colour(night, ncol), "the cloak takes the robe's colour")
	assert_true(_has_colour(night, nunder), "and its underside")
	assert_false(_has_colour(night, PlayerAvatar.CLOAK_COLOR), "no cream left")
	assert_eq(night.cloak_color, ncol)
	assert_eq(night.visor_color(), cream.visor_color(), "the blue core is the same on every robe")


func test_none_draws_no_rune() -> void:
	var a := _avatar(_look(&"cream", &"none"))
	assert_eq(a.runes.glyph, 0)
	assert_false(a.runes.visible, "no circle")
	assert_false(a.runes.back.visible, "no rune on the back")


func test_each_affinity_draws_its_rune_in_its_colour() -> void:
	for id: StringName in [&"ember", &"storm", &"venom", &"astral", &"guardian"]:
		var def: AffinityDefinition = _repo.get_def(&"affinity", id)
		var a := _avatar(_look(&"cream", id))
		assert_true(
			a.runes.visible and a.runes.circle.visible, "%s: the circle under the feet" % id
		)
		assert_true(a.runes.back.visible, "%s: the rune on the robe's back" % id)
		assert_eq(a.runes.glyph, def.glyph)
		for q: MeshInstance3D in [a.runes.circle, a.runes.halo, a.runes.back]:
			var m := q.material_override as ShaderMaterial
			assert_eq(
				m.get_shader_parameter(&"tint"), def.color, "%s %s in its colour" % [id, q.name]
			)
		assert_not_null(a.runes.light, "%s: a light (High)" % id)
		assert_not_null(a.runes.motes, "%s: motes (High)" % id)
		assert_eq(a.runes.motes.amount, AffinityRunes.MOTES_HIGH)


func test_the_back_rune_sits_on_the_cloaks_back() -> void:
	var a := _avatar(_look(&"cream", &"ember"))
	a.advance(0.016)
	var at := a.runes.back.position
	assert_lt(at.x, -0.15, "behind the hero (the cloak frame's back)")
	assert_between(at.y, 0.45, 0.8, "between the neck and the hem")
	var n := a.runes.back.transform.basis.z
	assert_lt(n.x, -0.7, "facing out of the back")


func test_low_density_keeps_the_shapes() -> void:
	ViewPrefs.effects_density = "low"
	var a := _avatar(_look(&"cream", &"storm"))
	assert_true(
		a.runes.circle.visible and a.runes.halo.visible and a.runes.back.visible, "shapes kept"
	)
	assert_null(a.runes.light, "no light at Low")
	assert_null(a.runes.motes, "no motes at Low")
	ViewPrefs.effects_density = "medium"
	var m := _avatar(_look(&"cream", &"storm"))
	assert_eq(m.runes.motes.amount, AffinityRunes.MOTES_HIGH / 2, "Medium: half the motes")


func test_guardian_spent_ward_dims_and_its_break_flashes() -> void:
	var a := _avatar(_look(&"cream", &"guardian"))
	a.runes.set_ward(true, 1, -1)
	assert_eq(a.runes.strength(), 1.0, "the ward up: full")
	a.runes.set_ward(true, 0, 120)
	assert_eq(a.runes.strength(), AffinityRunes.WARD_SPENT, "spent: dimmed")
	a.runes.advance(0.05)
	assert_true(a.runes.flash_ring.visible, "the break flashes a ring")
	a.runes.advance(AffinityRunes.FLASH_SECONDS)
	assert_false(a.runes.flash_ring.visible, "then it's gone")
	var resumed := _avatar(_look(&"cream", &"guardian"))
	resumed.runes.set_ward(true, 0, 50)
	resumed.runes.advance(0.05)
	assert_false(resumed.runes.flash_ring.visible, "a floor resumed after the break doesn't flash")


func _hub_view() -> HubView:
	var hub: HubDefinition = _repo.get_def(&"hub", &"rune_ring")
	var l := HubLayout.new(hub, false)
	var w := HubScenario.build(_repo, l, &"blade")
	var biome: BiomeDefinition = _repo.get_def(&"biomes", &"ruins")
	var v := HubView.new()
	add_child_autofree(v)
	v.setup(WorldReader.new(w), l, {}, [false], biome.mood, biome.palette, "low")
	return v


func test_the_hub_hero_wears_the_wardrobe_choice() -> void:
	var v := _hub_view()
	v.set_look(_look(&"ash", &"venom"))
	assert_eq(v.avatar.cloak_color, (_repo.get_def(&"robe", &"ash") as RobeDefinition).cloak)
	assert_eq(
		v.avatar.runes.glyph, (_repo.get_def(&"affinity", &"venom") as AffinityDefinition).glyph
	)
	var robe := v.stations[&"wardrobe"]["robe"] as MeshInstance3D
	if robe != null:  # the stand-in's robe (the owner's wardrobe draws its robe fused: art list hub_wardrobe_robe)
		assert_eq((robe.material_override as StandardMaterial3D).albedo_color, v.avatar.cloak_color)


func _panel(unlocked: Array[bool]) -> WardrobePanel:
	var p := WardrobePanel.new(
		Wardrobe.robes(_repo), unlocked, &"cream", Wardrobe.affinities(_repo), &"none"
	)
	add_child_autofree(p)
	return p


func test_the_wardrobe_panel_picks_a_robe_and_an_affinity() -> void:
	var p := _panel([true, true, false, false, false, false])
	var got := []
	p.picked.connect(func(r: StringName, a: StringName) -> void: got.append([r, a]))
	p.robe_cycler.step(1)
	assert_eq(got.back(), [&"ash", &"none"], "Ash is worn")
	p.robe_cycler.step(1)
	assert_eq(got.size(), 1, "Night is locked: nothing worn")
	assert_true(p.lock_note.visible, "and the panel says so")
	assert_true(p.robe_cycler.text.contains(tr("WARDROBE_LOCKED")))
	p.affinity_cycler.step(1)
	assert_eq(got.back(), [&"ash", &"ember"], "the worn robe stays Ash; Ember picked")
	assert_true(p.desc.text.contains(tr("AFFINITY_EMBER_DESC")), "its gain")
	assert_true(p.desc.text.contains(tr("AFFINITY_EMBER_COST")), "and its trade-off")


func test_the_wardrobe_panel_reads_in_spanish() -> void:
	TranslationServer.set_locale("es")
	var p := _panel([true, true, false, false, false, false])
	p.affinity_cycler.step(5)
	assert_true(p.affinity_cycler.text.contains("Guardián"), "the affinity's name in Spanish")
	assert_true(p.desc.text.contains("Una guarda bloquea"), "its line in Spanish")
	TranslationServer.set_locale("en")


## A floor of `aff` that holds a secret (the first run seed from 1 that has one on floor 1), or null.
func _secret_floor(aff: StringName) -> World:
	for s in range(1, 40):
		var plan := FloorPlan.new_run(RunSaver.RUN_ID, s, &"gun", true, aff)
		plan.repo = _repo
		plan.build()
		if not WorldReader.new(plan.world).secret_spots().is_empty():
			return plan.world
	return null


func test_astral_secrets_pulse_near_the_hero_and_the_map_marks_them() -> void:
	var w := _secret_floor(&"astral")
	assert_not_null(w, "a seed with a secret on floor 1")
	if w == null:
		return
	var r := WorldReader.new(w)
	var spot: Dictionary = r.secret_spots()[0]
	var v := AstralSenseView.new()
	add_child_autofree(v)
	v.setup(r, PackedVector2Array())
	assert_eq(v.pulses.size(), r.secret_spots().size(), "a pulse per secret")
	w.actors.set_pos(0, Vector2(spot["pos"]) + Vector2(30, 30))  # test-side placement, far away
	v.sync(r)
	assert_eq(v.shown[0], 0.0, "dark beyond 8 m")
	w.actors.set_pos(0, Vector2(spot["pos"]) + Vector2(2, 0))
	v.sync(r)
	assert_almost_eq(
		v.shown[0], AstralSenseView.PEAK, 0.001, "full (and faint) within half the reach"
	)
	w.actors.set_pos(0, Vector2(spot["pos"]) + Vector2(6, 0))
	v.sync(r)
	assert_between(v.shown[0], 0.01, AstralSenseView.PEAK - 0.01, "fading toward the edge")
	var mm := Minimap.new()
	add_child_autofree(mm)
	mm.sync(r)
	mm.state.discovered[int(spot["room"])] = 1
	mm.full_map.visible = true
	mm.full_map.queue_redraw()
	await get_tree().process_frame
	assert_true(r.affinity_maps_secrets(), "the minimap draws the secret's room mark")
	var plain := _secret_floor(&"none")
	assert_eq(WorldReader.new(plain).affinity_sense_m(), 0.0, "no sense without Astral")
