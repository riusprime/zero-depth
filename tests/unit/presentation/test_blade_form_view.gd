extends GutTest
## v0.6.5 WN4 (docs/design/WAND.md, the Blade pool's "You see" column): each Blade card visibly changes the slash. The
## scripted Blade fight (AttackScenario) runs with a card held while BladeFormView, KitView and the hero's avatar read
## the world each tick; the test checks what they drew: crescents (Wave, Split Wave, Counter), ghost slashes
## (Afterimage, Double Slash's mirrored echo), the fissure's crack and eruption, Parry Edge's sparks, the orbiting
## blades, the spin's and the stab's motion, Heavy's thicker blade and the hero's lean. Presentation only (EI-07).

const TICKS := 420


## The most each kind was drawn at once over the fight, by BladeFormView.drawn's kinds.
func _drawn(ids: Array, ticks: int = TICKS) -> Dictionary:
	var w := WandLab.fight(&"blade", ids)
	var r := WorldReader.new(w)
	var view: BladeFormView = add_child_autofree(BladeFormView.new())
	var most := {}
	for t in ticks:
		w.step(AttackScenario.frame(t))
		view.sync(r)
		for k: StringName in view.drawn:
			most[k] = maxi(int(most.get(k, 0)), int(view.drawn[k]))
	return most


func test_a_plain_blade_draws_nothing_extra() -> void:
	assert_eq(_drawn([]), {}, "no card: the laser blade alone")


func test_wave_and_split_wave_draw_crescents() -> void:
	assert_gt(int(_drawn([&"echo_slash"]).get(&"crescent", 0)), 0, "a flying crescent")
	var split := _drawn([&"echo_slash", &"split_wave"])
	assert_gt(int(split.get(&"crescent", 0)), 1, "crescents fanning out")


func test_whirl_wave_draws_a_ring_of_crescents() -> void:
	assert_gte(int(_drawn([&"whirl", &"echo_slash"]).get(&"crescent", 0)), BladeForms.CRESCENT_RING)


func test_double_slash_draws_ghost_slashes() -> void:
	# v0.8.0 RM: Afterimage is Dodge Imprint (no ghost copy; RemnantViews marks its point)
	assert_gt(int(_drawn([&"double_slash"]).get(&"ghost", 0)), 0, "the mirrored echo")


func test_fissure_draws_its_crack_then_the_eruption() -> void:
	var d := _drawn([&"fissure"])
	assert_gt(int(d.get(&"crack", 0)), 0, "a crack line")
	assert_gt(int(d.get(&"line", 0)), 0, "then an eruption")


func test_parry_edge_draws_sparks() -> void:
	assert_gt(int(_drawn([&"parry_edge"], 900).get(&"spark", 0)), 0, "sparks off the cut shots")


func test_orbit_blades_and_counter_and_finisher() -> void:
	assert_gt(int(_drawn([&"blade_orbit"]).get(&"blade", 0)), 1, "blades orbiting you")
	assert_gt(int(_drawn([&"counter"]).get(&"ring", 0)), 0, "the counter's flash")
	assert_gt(int(_drawn([&"counter"]).get(&"crescent", 0)), 0, "the dash-slash wave")
	# v0.8.0 RM: Finisher+ is Fracture Bank (its extraction flashes in RemnantViews)


func test_the_swing_itself_changes_on_the_blade_and_the_hero() -> void:
	for case: Array in [
		[&"whirl", WorldReader.MOTION_SPIN], [&"thrust", WorldReader.MOTION_THRUST]
	]:
		var w := WandLab.fight(&"blade", [case[0]])
		var r := WorldReader.new(w)
		var kit: KitView = add_child_autofree(KitView.new())
		var seen := false
		for t in 60:
			w.step(AttackScenario.frame(t))
			kit.sync(r)
			seen = seen or (kit.blade_visible() and kit.motion() == case[1])
		assert_true(seen, "%s: the blade moves its way" % case[0])
	var heavy := WandLab.fight(&"blade", [&"heavy"])
	var hr := WorldReader.new(heavy)
	var hk: KitView = add_child_autofree(KitView.new())
	for t in 3:
		heavy.step(AttackScenario.frame(t))
	hk.sync(hr)
	assert_gt(hk.form_weight(), 1.5, "Heavy's blade is thicker")
	assert_gt(float(hr.blade_swing()["weight"]), 1.6)
	assert_true(WorldReader.new(WandLab.fight(&"blade", [&"lunge_step"])).blade_swing()["lunge"])


func test_the_hero_leans_into_a_lunge_step() -> void:
	var w := WandLab.fight(&"blade", [&"lunge_step"])
	var r := WorldReader.new(w)
	var hero := PlayerAvatar.new()
	hero.setup(Color("#1A1A22"))
	add_child_autofree(hero)
	var most := 0.0
	for t in 12:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY if t == 0 else 0))
		hero.sync(r)
		hero.advance(1.0 / 60.0)
		most = maxf(most, hero.lunge_amount())
	assert_gt(most, 0.2, "the hero drives forward with the step")


func test_looks_carry_the_blade_cues() -> void:
	var w := WandLab.fight(&"blade", [&"whirl", &"echo_slash", &"parry_edge"])
	var r := WorldReader.new(w)
	var step := r.attack_spec(Modifiers.step_id(0))
	var cues := AttackFormLooks.cues_of(step)
	assert_has(cues, &"spin")
	assert_has(cues, &"cut")
	var crescent: Dictionary = AttackFormView.hook_child(
		step, AttackSpec.Trigger.ON_LAUNCH, WorldReader.FORM_BOLT
	)
	assert_has(AttackFormLooks.cues_of(crescent), &"crescent")
	assert_has(AttackFormLooks.cues_of(r.attack_spec(Modifiers.step_id(0))), &"spin")
	var t := WorldReader.new(WandLab.fight(&"blade", [&"thrust"]))
	assert_has(AttackFormLooks.cues_of(t.attack_spec(Modifiers.step_id(0))), &"stab")


## v0.8.0 PF2 (owner O9): the crescents and the ghost slashes are instances of baked shapes (BakedMeshPools), each the
## band the ImmediateMesh drew (14 segments, 84 vertices), so a crowd of them costs a transform each.
func test_crescents_and_ghosts_are_baked_instances() -> void:
	var w := WandLab.fight(&"blade", [&"double_slash", &"echo_slash"])
	var r := WorldReader.new(w)
	var view: BladeFormView = add_child_autofree(BladeFormView.new())
	var most := 0
	var counted := 0
	for t in TICKS:
		w.step(AttackScenario.frame(t))
		view.sync(r)
		most = maxi(most, view.baked_drawn())
		counted = maxi(
			counted, int(view.drawn.get(&"crescent", 0)) + int(view.drawn.get(&"ghost", 0))
		)
	assert_gt(most, 1, "crescents and ghosts laid out as instances")
	assert_eq(most, counted, "each one counted is an instance")
	var mesh: ArrayMesh = view._bake(Vector4(BladeFormView.SHAPE_CRESCENT, 0.6, 0.8, 0.0))
	var arrays := mesh.surface_get_arrays(0)
	assert_eq(
		(arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 84, "the band's 14 segments"
	)
	assert_eq((arrays[Mesh.ARRAY_COLOR] as PackedColorArray).size(), 84, "its colours baked in")
