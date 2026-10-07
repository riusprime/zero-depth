extends GutTest
## Items change the look (PLAN v0.2.0 L7): the blade, the bolts, burning enemies.


func _world_with(kind: int) -> World:
	var w := CombatLab.world()
	var tables := ContentCompiler.compile_items(ContentRepository.load_all())
	w.set_item_tables(tables)
	for k in tables.size():
		if tables[k].kind == kind:
			w.add_item(k)
	return w


func test_bolts_change_with_items() -> void:
	var plain := ItemVisuals.bolt_look(WorldReader.new(CombatLab.world()))
	var coil := ItemVisuals.bolt_look(WorldReader.new(_world_with(WorldReader.ITEM_RAPID_COIL)))
	assert_gt(coil["size"].x, plain["size"].x, "Rapid Coil: longer bolts")
	var rico := ItemVisuals.bolt_look(WorldReader.new(_world_with(WorldReader.ITEM_RICOCHET_CORE)))
	assert_gt(rico["energy"], plain["energy"], "Ricochet Core: brighter bolts")


func test_ember_edge_turns_the_blade_orange() -> void:
	var w := _world_with(WorldReader.ITEM_EMBER_EDGE)
	var kit := KitView.new()
	add_child_autofree(kit)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := ItemVisuals.new(kit, actors)
	add_child_autofree(fx)
	fx.sync(WorldReader.new(w))
	assert_eq(kit.color, ItemLooks.color(WorldReader.ITEM_EMBER_EDGE))


func test_every_item_kind_has_a_colour() -> void:
	for k in [
		WorldReader.ITEM_LONG_EDGE,
		WorldReader.ITEM_TWIN_ARC,
		WorldReader.ITEM_EMBER_EDGE,
		WorldReader.ITEM_SPLINTER_SHOT,
		WorldReader.ITEM_RAPID_COIL,
		WorldReader.ITEM_RICOCHET_CORE,
		WorldReader.ITEM_KINETIC_DASH,
		WorldReader.ITEM_OVERCHARGE,
	]:
		assert_true(ItemLooks.COLORS.has(k), str(k))
