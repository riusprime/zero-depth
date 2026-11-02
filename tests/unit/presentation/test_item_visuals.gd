extends GutTest
## Items change the look (PLAN v0.2.0 L7): the blade, the bolts, burning enemies.
## v0.10.5 O1 retired the Rapid Coil, Ricochet Core and Ember Edge items, so their look tests went; the colours stay.


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
