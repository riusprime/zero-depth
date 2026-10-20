extends GutTest
## v0.8.0 RM (owner O91: "Make Fire+Frost's Thermal Break a natural elemental reaction"): an enemy both burning and
## chilled or frozen breaks (Engines.thermal_break), whichever came second: its burn and frost are consumed (a freeze
## ends) into one damage-over-time hit of 6 + 4 per burn stack (× the damage stat, never a crit, proc 0), after a
## STATUS_APPLY the view shows as a shatter. Fire and Frost from any source react. Mechanics only (owner P1).

const W := preload("res://tests/support/mx4_world.gd")


func _world() -> World:
	return W.world(&"blade", [&"ember_core", &"frost_core"], [[Vector2(3.0, 0.0), 100000]])


func _breaks(w: World) -> Array[SimEvent]:
	return W.damage(w, Engines.EFFECT_THERMAL_BREAK)


func test_burning_then_chilled_breaks() -> void:
	var w := _world()
	var root := w.take_root()
	Engines.add_burn(w, 1, 3, root, &"test")
	assert_eq(_breaks(w).size(), 0, "burning alone: nothing")
	Engines.add_frost(w, 1, 1, root, &"test")
	var hits := _breaks(w)
	assert_eq(hits.size(), 1, "the frost that arrived second breaks it")
	assert_eq(hits[0].amount, Stats.dot(w, 6 + 4 * 3), "6 + 4 per burn stack, × the damage stat")
	assert_ne(hits[0].tags & SimEvent.TAG_DOT, 0, "a damage-over-time hit")
	assert_eq(hits[0].proc_pct, 0, "it sets nothing off")
	var a := w.actors
	assert_eq([a.burn_stacks[1], a.frost_stacks[1], a.frozen_t[1]], [0, 0, 0], "both consumed")
	var shatter := W.events(w, SimEvent.Kind.STATUS_APPLY, Engines.EFFECT_THERMAL_BREAK)
	assert_eq(shatter.size(), 1, "the shatter the view shows")
	assert_eq(shatter[0].amount, 3)


func test_chilled_then_burning_breaks() -> void:
	var w := _world()
	var root := w.take_root()
	Engines.add_frost(w, 1, 1, root, &"test")
	assert_eq(_breaks(w).size(), 0, "chilled alone: nothing")
	Engines.add_burn(w, 1, 2, root, &"test")
	assert_eq(_breaks(w).size(), 1, "the fire that arrived second breaks it")
	assert_eq(_breaks(w)[0].amount, Stats.dot(w, 6 + 4 * 2))


func test_a_frozen_enemy_set_alight_breaks_out_of_the_freeze() -> void:
	var w := _world()
	w.actors.frozen_t[1] = 40
	Engines.add_burn(w, 1, 1, w.take_root(), &"test")
	assert_eq(_breaks(w).size(), 1)
	assert_eq(w.actors.frozen_t[1], 0, "the freeze is consumed")


func test_it_never_chains_itself() -> void:
	var w := _world()
	var root := w.take_root()
	Engines.add_burn(w, 1, 5, root, &"test")
	Engines.add_frost(w, 1, 1, root, &"test")
	W.run(w, 60)
	assert_eq(_breaks(w).size(), 1, "one break: the reaction feeds neither status again")
