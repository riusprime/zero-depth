extends GutTest
## v0.6.0 MX3 (MODIFIER_ENGINE §4): element mixing (the first element's core, the second's rim), the heat edge over
## the rim (HeatLooks.attack_color), ground marks that never take the telegraphs' hostile hue, the motion cues, crit
## and weight; the live wiring draws the arc and the bolt only when their spec adds something over the v0.5 looks.

const AT := Vector2(2, 3)

var _view: AttackFormView


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())


func _spec(form: int, extra: Dictionary = {}) -> Dictionary:
	var s := {"form": form, "elements": PackedStringArray(["ember"])}
	s.merge(extra, true)
	return s


func _used(id: StringName) -> int:
	return _view.pool(id).used


## Where instance i of pool `id` sits on the sim plane.
func _origin(id: StringName, i: int) -> Vector2:
	return SimPlane.to_sim(_view.pool(id).instance_transform(i).origin)


func test_two_elements_core_of_one_rim_of_the_other() -> void:
	var look := AttackFormLooks.compose(
		{"form": 1, "elements": PackedStringArray(["storm", "ember"])}
	)
	assert_eq(look["core"], AttackFormLooks.ELEMENT_CORE[&"storm"])
	assert_eq(look["rim"], AttackFormLooks.ELEMENT_CORE[&"ember"])
	var kinds := []
	for p: Array in look["particles"]:
		kinds.append([p[0], p[2]])
	assert_eq(kinds, [[&"crackle", 0.5], [&"sparks", 0.5]], "half of each element's particles")
	var one := AttackFormLooks.compose({"form": 1, "elements": PackedStringArray(["frost"])})
	assert_eq(one["rim"], AttackFormLooks.ELEMENT_CORE[&"frost"].lerp(Color.WHITE, 0.35))
	var plain := AttackFormLooks.compose({"form": 1})
	assert_eq(plain["core"], ThemePalette.color(&"player_core"), "no element: the plain cyan")
	assert_true((plain["particles"] as Array).is_empty())
	var bleed := AttackFormLooks.compose({"form": 0, "elements": PackedStringArray(["bleed"])})
	assert_eq(
		bleed["core"],
		ThemePalette.color(&"player_core").lerp(
			ItemLooks.color(WorldReader.ITEM_SERRATED_EDGE), 0.7
		),
		"bleed keeps MX1's tint"
	)


func test_every_element_has_its_own_core_and_particles() -> void:
	var want := {
		&"storm": &"crackle",
		&"ember": &"sparks",
		&"frost": &"shards",
		&"venom": &"drip",
		&"void": &"smear"
	}
	var cores := []
	for el: StringName in want:
		var look := AttackFormLooks.compose({"form": 1, "elements": PackedStringArray([el])})
		assert_eq((look["particles"] as Array)[0][0], want[el], String(el))
		for c: Color in cores:
			var d := Vector3(c.r, c.g, c.b).distance_to(
				Vector3(look["core"].r, look["core"].g, look["core"].b)
			)
			assert_gt(d, 0.15, "%s reads apart from the other cores" % el)
		cores.append(look["core"])
	for el: StringName in ModifierOpDefinition.ELEMENTS:
		assert_true(
			AttackFormLooks.ELEMENT_PARTICLE.has(el), "every content element draws: %s" % el
		)


func test_the_drawn_core_is_the_element_colour() -> void:
	var e := _view.spawn(
		{"form": 1, "elements": PackedStringArray(["venom"])}, AT, 0.0, {"start": 0}
	)
	_view.draw_at(2.0)
	var c := _view.pool(&"bolt_core").instance_color(0)
	var want: Color = AttackFormLooks.ELEMENT_CORE[&"venom"] * float(e["look"]["energy"])
	assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * 0.001)
	assert_gt(_view.particle_pool(&"drip").used, 0, "venom drips")


func test_heat_sets_the_edge_over_the_rim() -> void:
	var spec := {"form": 0, "elements": PackedStringArray(["storm", "frost"])}
	for tier in [
		HeatLooks.TIER_COOL, HeatLooks.TIER_HOT, HeatLooks.TIER_OVERCLOCK, HeatLooks.TIER_OVERHEAT
	]:
		var look := AttackFormLooks.compose(spec, tier)
		assert_eq(look["edge"], HeatLooks.attack_color(look["rim"], tier), "tier %d" % tier)
		assert_eq(
			look["core"], AttackFormLooks.ELEMENT_CORE[&"storm"], "the core stays the element's"
		)
	var e := _view.spawn(spec, AT, 0.0, {"start": 0, "tier": HeatLooks.TIER_HOT})
	_view.draw_at(5.0)
	var c := _view.pool(&"arc_edge").instance_color(0)
	var energy: float = e["look"]["energy"]
	assert_almost_eq(
		c.r, HeatLooks.HOT.r * energy, 0.001, "the drawn edge is the meter's Hot orange"
	)
	assert_almost_eq(c.g, HeatLooks.HOT.g * energy, 0.001)


func test_ground_marks_never_take_the_telegraph_hue() -> void:
	assert_true(AttackFormLooks.is_hostile_hue(ThemePalette.color(&"telegraph_hostile")))
	assert_true(AttackFormLooks.is_hostile_hue(Color("#FF8A2E")), "the molten telegraph core")
	var els: Array = Array(ModifierOpDefinition.ELEMENTS)
	for a: StringName in els:
		for b: StringName in [&""] + els:
			var pair := PackedStringArray([a]) if b == &"" else PackedStringArray([a, b])
			for tier in [HeatLooks.TIER_COOL, HeatLooks.TIER_OVERCLOCK]:
				var look := AttackFormLooks.compose({"form": 4, "elements": pair}, tier)
				assert_false(AttackFormLooks.is_hostile_hue(look["ground"]), "%s ground" % pair)
				assert_false(AttackFormLooks.is_hostile_hue(look["ground_edge"]), "%s rim" % pair)
	var e := _view.spawn(
		{"form": 4, "elements": PackedStringArray(["bleed"])}, AT, 0.0, {"start": 0}
	)
	_view.draw_at(10.0)
	assert_false(
		AttackFormLooks.is_hostile_hue(_view.pool(&"zone_fill").instance_color(0)), "drawn"
	)
	assert_true(
		AttackFormLooks.is_hostile_hue(e["look"]["core"]),
		"bleed's core itself is red: only the floor mark leans"
	)


func test_behaviour_cues() -> void:
	assert_eq(
		AttackFormLooks.cues_of({"pierce": 2, "bounces": 1, "home": true, "return": true}),
		[&"streak", &"bounce_flash", &"curve", &"tether"] as Array[StringName]
	)
	_view.spawn(_spec(1, {"speed": 0.3}), AT, 0.0, {"start": 0})
	_view.draw_at(20.0)
	var plain_tail := _used(&"bolt_edge")
	_view.clear()
	_view.spawn(_spec(1, {"speed": 0.3, "pierce": 1}), AT, 0.0, {"start": 0})
	_view.draw_at(20.0)
	assert_gt(_used(&"bolt_edge"), plain_tail, "pierce: a longer streak")
	_view.clear()
	_view.spawn(_spec(1, {"speed": 0.3, "home": true}), AT, 0.0, {"start": 0})
	_view.draw_at(20.0)
	assert_gt(absf(_origin(&"bolt_core", 0).y - AT.y), 0.2, "home: the path curves off the aim")
	_view.clear()
	_view.spawn(_spec(1, {"speed": 0.3, "return": true}), AT, 0.0, {"start": 0})
	_view.draw_at(10.0)
	assert_eq(_used(&"cue"), 1, "return: a tether to the thrower")


func test_crit_flashes_white_hot_and_weight_thickens() -> void:
	_view.spawn(_spec(7), AT, 0.0, {"start": 0, "crit": true})
	_view.draw_at(1.0)
	assert_eq(_used(&"flash"), 1)
	var c := _view.pool(&"flash").instance_color(0)
	assert_almost_eq(c.b / c.r, HeatLooks.WHITE_HOT.b / HeatLooks.WHITE_HOT.r, 0.001, "white-hot")
	var light := AttackFormLooks.compose(_spec(1))
	var heavy := AttackFormLooks.compose(_spec(1, {"damage_mul_permille": 2000}))
	assert_gt(heavy["thick"], light["thick"], "thicker")
	assert_gt(heavy["energy"], light["energy"], "brighter")
	assert_eq(
		AttackFormLooks.compose(_spec(1), 0, {"weight": 9.0})["width"], AttackFormLooks.WEIGHT_MAX
	)


# --- Live wiring ----------------------------------------------------------------------------------------------
## A lab world (no dummies in the way) holding `items`.
func _lab(items: Array) -> World:
	var w := CombatLab.world()
	var tables := ContentCompiler.compile_items(AttackScenario.repo())
	w.set_item_tables(tables)
	for id: StringName in items:
		w.add_item(AttackScenario.item_index(tables, id))
	return w


func _shoot(w: World, reader: WorldReader, ticks: int) -> void:
	for k in ticks:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, InputFrame.SHOOT, 0))
		_view.sync(reader)


func _press(w: World, buttons: int) -> void:
	w.step(InputFrame.make(Vector2i.ZERO, 0, 100, buttons, buttons))


func test_the_plain_weapons_draw_nothing_extra() -> void:
	var w := AttackScenario.world(&"blade", [], false, [])
	var reader := WorldReader.new(w)
	_press(w, InputFrame.PRIMARY)
	_view.sync(reader)
	assert_gt(reader.swing_tick(), 0)
	assert_eq(_view.effect_count(), 0, "the v0.5 blade is the arc")
	w = _lab([])
	reader = WorldReader.new(w)
	_shoot(w, reader, 30)
	assert_gt(reader.projectile_count(), 0)
	assert_eq(_view.live_count(), 0, "the v0.5 dart is the bolt")


func test_an_element_on_the_blade_draws_its_arc_layer() -> void:
	var w := AttackScenario.world(&"blade", [&"ember_edge"], false, [])
	var reader := WorldReader.new(w)
	_press(w, InputFrame.PRIMARY)
	_view.sync(reader)
	assert_eq(_view.effect_count(), 1, "the swing spawns its arc")
	var look: Dictionary = _view._effects[0]["look"]
	assert_eq(look["form"], AttackFormLooks.ARC)
	assert_eq(look["core"], AttackFormLooks.ELEMENT_CORE[&"ember"])
	assert_almost_eq(
		float(look["reach"]), float(reader.swing_shape()[1]), 0.0001, "the hit's reach"
	)
	w.step(InputFrame.new())
	_view.sync(reader)
	assert_eq(_view.effect_count(), 1, "one arc per swing")
	_view.draw_at(float(reader.tick()))
	assert_gt(_used(&"arc_core"), 0)


func test_an_element_on_the_bolt_rides_each_live_shot() -> void:
	var w := _lab([&"cinder_shot"])
	var reader := WorldReader.new(w)
	_shoot(w, reader, 30)
	var player_shots := 0
	for i in reader.projectile_count():
		if reader.projectile_team(i) == 0 and not reader.projectile_is_shard(i):
			player_shots += 1
	assert_gt(player_shots, 0)
	assert_eq(_view.live_count(), player_shots, "every live player bolt carries the layer")
	_view.draw_at(float(reader.tick()))
	assert_gt(_used(&"bolt_core"), 0, "the ember rim")
	assert_gt(_view.particle_pool(&"sparks").used, 0, "ember sparks")
