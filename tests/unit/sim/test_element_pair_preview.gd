extends GutTest
## v0.9.5 EP4: ElementPairs.preview, the pairs taking an item would turn on or raise (the offer card's line).

const W := preload("res://tests/support/mx4_world.gd")
const CARDS := ElementPairs.CARDS


func _world(held: Array, lv: int = 1) -> World:
	var ids: Array = []
	for e: int in held:
		ids.append(CARDS[e])
	var w := W.world(&"gun", ids, [])
	w.pair_table = WandCompiler.pairs(W.repo())
	for id: StringName in ids:
		CardLevels.set_level(w, W.item(w, id), lv)
	ElementPairs.refresh(w)
	return w


func test_a_second_element_turns_a_pair_on() -> void:
	var w := _world([ElementPairs.FIRE])
	var pv := ElementPairs.preview(w, W.item(w, &"frost_core"))
	assert_eq(pv, PackedInt32Array([ElementPairs.X1, 1]))


func test_a_card_that_raises_the_lower_element_raises_the_pair() -> void:
	var w := _world([ElementPairs.FIRE, ElementPairs.FROST])
	var pv := ElementPairs.preview(w, W.item(w, &"frost_core"))
	assert_eq(pv.size(), 0, "Frost 2 with Fire 1: the pair stays Lv 1")
	CardLevels.set_level(w, W.item(w, &"ember_core"), 2)
	ElementPairs.refresh(w)
	pv = ElementPairs.preview(w, W.item(w, &"frost_core"))
	assert_eq(pv, PackedInt32Array([ElementPairs.X1, 2]), "Fire 2 and Frost 1 -> 2: Lv 2")


func test_nothing_to_pair_is_empty() -> void:
	var w := _world([])
	assert_eq(ElementPairs.preview(w, W.item(w, &"frost_core")).size(), 0)


func test_a_non_element_card_is_empty() -> void:
	var w := _world([ElementPairs.FIRE, ElementPairs.FROST])
	var other := -1
	for k in w.item_tables.size():
		if not CARDS.has(w.item_tables[k].id):
			other = k
			break
	assert_ne(other, -1)
	assert_eq(ElementPairs.preview(w, other).size(), 0)


func test_a_maxed_pair_is_empty() -> void:
	var w := _world([ElementPairs.FIRE, ElementPairs.FROST], 3)
	assert_eq(ElementPairs.preview(w, W.item(w, &"ember_core")).size(), 0)
