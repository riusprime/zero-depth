extends GutTest
## v0.10.5 W3-P10a (owner W7, G1 A2): a double crit's damage number is the crit number, 25 % bigger, in ice-white
## #CFE4FF with a thin ink #0E131C edge; a plain crit keeps its look. Read from the DAMAGE event's TAG_DOUBLE_CRIT.

const W := preload("res://tests/support/mx4_world.gd")


func _numbers() -> DamageNumbers:
	var n := DamageNumbers.new()
	add_child_autofree(n)
	n.set_process(false)
	return n


func _damage(w: World, target: int, amount: int, tags: int) -> void:
	var e := w.emit_event(
		SimEvent.Kind.DAMAGE, w.actors.ids[0], w.actors.ids[0], target, Vector2(1, 0)
	)
	e.amount = amount
	e.tags = tags


func test_a_double_crit_number_is_bigger_ice_white_with_a_thin_ink_edge() -> void:
	assert_eq(DamageNumbers.DOUBLE_CRIT_SIZE, roundi(DamageNumbers.CRIT_SIZE * 1.25))
	var w := W.world(&"gun", [], [[Vector2(1, 0), 500]])
	var target := w.actors.ids[1]
	_damage(w, target, 40, SimEvent.TAG_CRIT)
	_damage(w, target, 100, SimEvent.TAG_CRIT | SimEvent.TAG_DOUBLE_CRIT)
	var n := _numbers()
	n.sync(WorldReader.new(w))
	var shown := n.shown()
	assert_eq(shown.size(), 2)
	assert_eq(shown[0], ["40", true, DamageNumbers.CRIT_SIZE], "a crit keeps its look")
	assert_eq(shown[1], ["100", true, DamageNumbers.DOUBLE_CRIT_SIZE])
	var crit: Label3D = n.label_at(0)[0]
	var double: Label3D = n.label_at(1)[0]
	assert_eq(crit.modulate, DamageNumbers.CRIT_COLOR)
	assert_eq(crit.outline_size, DamageNumbers.EDGE_SIZE)
	assert_eq(double.modulate, Color("#CFE4FF"))
	assert_eq(double.outline_modulate, Color("#0E131C"))
	assert_lt(double.outline_size, crit.outline_size, "a thin edge")
