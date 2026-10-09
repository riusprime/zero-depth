extends GutTest
## v0.6.0 MX1 (MODIFIER_ENGINE §4): the weapon attacks are drawn from their final specs (AttackView), and the looks
## are the v0.5 looks: each attack item's blade or bolt look, now read from the spec, equals what v0.5 drew for the
## item. The edge takes the heat tier's colour (Step LK) over the core.

var _tables: Array[ItemTable] = []


func before_all() -> void:
	_tables = ContentCompiler.compile_items(AttackScenario.repo())


func _reader(ids: Array) -> WorldReader:
	var w := CombatLab.world()
	w.set_item_tables(_tables)
	for id: StringName in ids:
		w.add_item(AttackScenario.item_index(_tables, id))
	return WorldReader.new(w)


func test_the_plain_attacks_look_as_before() -> void:
	var r := _reader([])
	var blade := AttackView.blade_look_of(r)
	assert_eq(blade, {"color": ThemePalette.color(&"player_core"), "width": 1.0, "trail": 6})
	var bolt := AttackView.bolt_look_of(r)
	assert_eq(bolt["size"], Vector3(0.38, 0.07, 0.07))
	assert_eq(bolt["energy"], 2.5)
	assert_eq(AttackView.drawer(r.attack_spec(r.step_attack_id(0))), &"blade")
	assert_eq(AttackView.drawer(r.attack_spec(WorldReader.ATTACK_BOLT)), &"bolt")


## v0.5's ItemVisuals rules, written out: what each item drew.
func test_each_blade_item_looks_as_it_did() -> void:
	var core := ThemePalette.color(&"player_core")
	var cases := [
		[&"conductor", core.lerp(ItemLooks.color(WorldReader.ITEM_CONDUCTOR), 0.7), 1.0, 6],
		[&"serrated_edge", core.lerp(ItemLooks.color(WorldReader.ITEM_SERRATED_EDGE), 0.7), 1.0, 6],
		[&"glacial_edge", core.lerp(ItemLooks.color(WorldReader.ITEM_GLACIAL_EDGE), 0.7), 1.0, 6],
		[&"ember_edge", ItemLooks.color(WorldReader.ITEM_EMBER_EDGE), 1.0, 6],
		[&"twin_arc", core, 1.0, 11],
		[&"overcharge", core, 1.15, 6],
		[&"long_edge", core, 1.0, 6],
	]
	for c: Array in cases:
		var look := AttackView.blade_look_of(_reader([c[0]]))
		assert_eq([look["color"], look["width"], look["trail"]], [c[1], c[2], c[3]], String(c[0]))
	var both := core.lerp(ItemLooks.color(WorldReader.ITEM_CONDUCTOR), 0.7)
	both = both.lerp(ItemLooks.color(WorldReader.ITEM_GLACIAL_EDGE), 0.7)
	var look := AttackView.blade_look_of(_reader([&"glacial_edge", &"conductor"]))
	assert_eq(look["color"], both, "the fixed tint order, whatever the pick order")


func test_the_charged_swing_flares() -> void:
	var spec := _reader([&"overcharge"]).attack_spec(&"blade_step_3")
	var look := AttackView.blade_look(spec, true)
	assert_eq(look["width"], 1.7)
	var want := ThemePalette.color(&"player_core").lerp(
		ItemLooks.color(WorldReader.ITEM_OVERCHARGE), 0.6
	)
	assert_eq(look["color"], want)


func test_each_bolt_item_looks_as_it_did() -> void:
	var core := ThemePalette.color(&"player_core")
	var coil := AttackView.bolt_look_of(_reader([&"rapid_coil"]))
	assert_eq(coil["size"], Vector3(0.62, 0.06, 0.06))
	var split := AttackView.bolt_look_of(_reader([&"splinter_shot"]))
	assert_eq(split["size"], Vector3(0.38, 0.07, 0.07) * Vector3(0.75, 1, 1))
	assert_eq(split["color"], core.lerp(ItemLooks.color(WorldReader.ITEM_SPLINTER_SHOT), 0.5))
	var rico := AttackView.bolt_look_of(_reader([&"ricochet_core"]))
	assert_eq([rico["color"], rico["energy"]], [core.lerp(Color.WHITE, 0.6), 4.5])
	var cinder := AttackView.bolt_look_of(_reader([&"cinder_shot"]))
	assert_eq(cinder["color"], core.lerp(ItemLooks.color(WorldReader.ITEM_CINDER_SHOT), 0.55))
	var barbed := AttackView.bolt_look_of(_reader([&"barbed_bolts"]))
	assert_eq(barbed["color"], core.lerp(ItemLooks.color(WorldReader.ITEM_BARBED_BOLTS), 0.55))
	for id: StringName in [&"static_chain", &"frost_core"]:
		var plain := AttackView.bolt_look_of(_reader([id]))
		assert_eq(plain["color"], core, "%s: no bolt tint before the element art (MX stage 3)" % id)


func test_the_edge_takes_the_heat_tier() -> void:
	var c := Color.CYAN
	assert_eq(AttackView.edge_color(c, HeatLooks.TIER_COOL), c)
	assert_eq(AttackView.edge_color(c, HeatLooks.TIER_HOT), HeatLooks.HOT)
	assert_eq(AttackView.edge_color(c, HeatLooks.TIER_OVERCLOCK), HeatLooks.OVERCLOCK)


func test_the_reader_gives_plain_data() -> void:
	var r := _reader([&"static_chain", &"long_edge"])
	assert_eq(
		r.attack_ids(),
		PackedStringArray(
			[
				"blade_step_0",
				"blade_step_1",
				"blade_step_2",
				"blade_step_3",
				"gun_bolt",
				"dash",  # v0.6.0 MX4: the moments' specs
				"move",
				"blink",
				"body",
			]
		)
	)
	var bolt := r.attack_spec(WorldReader.ATTACK_BOLT)
	assert_eq(bolt["form"], WorldReader.FORM_BOLT)
	assert_eq(bolt["elements"], PackedStringArray(["storm"]))
	assert_eq(bolt["hooks"][0]["child"]["form"], WorldReader.FORM_BEAM)
	assert_eq(r.attack_spec(&"nope"), {})
	assert_eq(r.swing_shape(0)[1], r.swing_reach_m(0), "the drawn blade is the spec's reach")
