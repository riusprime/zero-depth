extends GutTest
## Items change the look (PLAN v0.2.0 L7): the blade, the bolts, burning enemies.
## v0.10.5 O1 retired the Rapid Coil, Ricochet Core and Ember Edge items, so their look tests went; the colours stay.
## The look tests below use live cards (Rapid Fire, Ricochet, Ember Core).

var _tables: Array[ItemTable] = []


func before_all() -> void:
	_tables = ContentCompiler.compile_items(AttackScenario.repo())


func _world_with(ids: Array) -> World:
	var w := CombatLab.world()
	w.set_item_tables(_tables)
	for id: StringName in ids:
		w.add_item(AttackScenario.item_index(_tables, id))
	return w


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


func test_bolts_change_with_wand_cards() -> void:
	var plain := ItemVisuals.bolt_look(WorldReader.new(_world_with([])))
	var fast := ItemVisuals.bolt_look(WorldReader.new(_world_with([&"gun_rapid_fire"])))
	assert_gt(fast["size"].x, plain["size"].x, "Rapid Fire: longer bolts")
	var rico := ItemVisuals.bolt_look(WorldReader.new(_world_with([&"gun_ricochet"])))
	assert_gt(rico["energy"], plain["energy"], "Ricochet: brighter bolts")


func test_an_element_tints_the_blade() -> void:
	var kit := KitView.new()
	add_child_autofree(kit)
	var actors := ActorViews.new()
	add_child_autofree(actors)
	var fx := ItemVisuals.new(kit, actors)
	add_child_autofree(fx)
	fx.sync(WorldReader.new(_world_with([&"ember_core"])))
	assert_eq(kit.color, ItemLooks.color(WorldReader.ITEM_EMBER_EDGE))
	assert_ne(kit.color, ThemePalette.color(&"player_core"), "differs from the plain blade")
