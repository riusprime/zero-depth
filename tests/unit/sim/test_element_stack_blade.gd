extends GutTest
## v0.10.5 W3-P1b (owner, 2026-11-04: "Merge, fix Blade next"; docs/roadmap/v0.10.5/W3_O4_PROGRESSION_G1.md P1): the
## Blade's element stacks fall off like the Gun's. Lightning leaves no status, so a hero Lightning hit charges its enemy
## for storm_mark_seconds (element_pairs.tres) and the charge counts as carrying Lightning in the others' falloff
## (saved; hashed only while an enemy is charged; an older save loads uncharged). Thermal Break's hit is Fire's: it
## falls off by what the enemy carried before the break consumed its burn and frost, and takes Fire's level share.

const W := preload("res://tests/support/mx4_world.gd")
const BIG := 9000000

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


## A Gun world holding the element cards `ids` at `lv`, a standing dummy at 4 m, the pairs' table loaded.
func _world(ids: Array, lv: int = 1) -> World:
	var w := W.world(&"gun", ids, [[Vector2(4, 0), BIG]])
	w.pair_table = WandCompiler.pairs(W.repo())
	for id: StringName in ids:
		CardLevels.set_level(w, W.item(w, id), lv)
	ElementPairs.refresh(w)
	W.run(w, 1)
	return w


func _tick(w: World, i: int, amount: int, element: StringName) -> int:
	var a := w.actors
	var before := a.hp[i]
	Damage.tick_dot(w, i, amount, a.ids[0], a.ids[0], &"test", element)
	return before - a.hp[i]


func _venom(w: World, i: int) -> void:
	w.actors.poison_stacks[i] = 1
	w.actors.poison_t[i] = 600


func _lightning_hit(w: World, i: int) -> void:
	var a := w.actors
	Damage.hit(w, i, 10, a.ids[0], a.ids[0], w.take_root(), 0, a.pos(0), a.pos(i), &"storm_core")


func test_the_charge_is_data() -> void:
	var def := _repo.get_def(&"element_pairs", &"element_pairs") as ElementPairsDefinition
	assert_eq(def.storm_mark_seconds, 1.0, "the shipped charge")
	assert_eq(WandCompiler.pairs(W.repo()).storm_mark_ticks, 60, "in ticks")
	var bad := def.duplicate() as ElementPairsDefinition
	var base := bad.validate().size()
	for s in [-1.0, 6.0]:
		bad.storm_mark_seconds = s
		assert_gt(bad.validate().size(), base, "%s s refused" % s)


func test_a_lightning_hit_charges_its_enemy_and_the_charge_counts_against_the_others() -> void:
	var w := _world([])
	var a := w.actors
	assert_eq(_tick(w, 1, 100, &"ember"), 100, "nothing on it")
	_lightning_hit(w, 1)
	assert_eq(a.charged_t[1], w.pair_table.storm_mark_ticks, "charged")
	assert_true(ElementStack.carries(w, 1, ElementStack.STORM), "it carries Lightning")
	assert_eq(_tick(w, 1, 100, &"ember"), 70, "a burn tick on a charged enemy: one other element")
	assert_eq(
		ElementStack.others(w, 1, ElementStack.STORM), 0, "the charge never counts against itself"
	)
	Damage.hit(w, 1, 10, a.ids[0], a.ids[0], w.take_root(), 0, a.pos(0), a.pos(1), &"")
	assert_eq(
		a.charged_t[1], w.pair_table.storm_mark_ticks, "a plain hit does not charge or clear it"
	)


func test_the_charge_runs_down_with_the_sim_clock() -> void:
	var w := _world([])
	var a := w.actors
	_lightning_hit(w, 1)
	var ticks := w.pair_table.storm_mark_ticks
	W.run(w, ticks - 1)
	assert_eq(a.charged_t[1], 1, "one tick left")
	assert_true(ElementStack.carries(w, 1, ElementStack.STORM))
	W.run(w, 1)
	assert_eq(a.charged_t[1], 0, "spent")
	assert_false(ElementStack.carries(w, 1, ElementStack.STORM))
	assert_eq(_tick(w, 1, 100, &"ember"), 100, "and Fire counts in full again")


func test_no_charge_without_the_pairs_table_or_from_an_enemy() -> void:
	var w := _world([])
	w.pair_table = null
	_lightning_hit(w, 1)
	assert_eq(w.actors.charged_t[1], 0, "no table: as before")
	var e := _world([])
	var a := e.actors
	Damage.hit(e, 1, 10, a.ids[1], a.ids[1], e.take_root(), 0, a.pos(1), a.pos(1), &"storm_core")
	assert_eq(a.charged_t[1], 0, "only the hero's Lightning charges")


func _break(w: World) -> Array[SimEvent]:
	Engines.add_burn(w, 1, 3, w.take_root(), &"test")
	Engines.add_frost(w, 1, 1, w.take_root(), &"test")
	return W.damage(w, Engines.EFFECT_THERMAL_BREAK)


func test_thermal_break_falls_off_as_fire_by_what_the_enemy_carried_before_it_broke() -> void:
	var w := _world([&"ember_core", &"frost_core"], 1)  # Fire Lv 1: 750 per mille; Frost has no row
	var a := w.actors
	_venom(w, 1)
	var hits := _break(w)
	assert_eq(hits.size(), 1, "it broke")
	var want := Stats.dot(w, ElementStack.scale(6 + 4 * 3, 500 * 750 / 1000))
	assert_eq(hits[0].amount, want, "Venom and Frost were on it (k = 2: 50 %) x Fire Lv 1 (75 %)")
	assert_eq([a.burn_stacks[1], a.frost_stacks[1]], [0, 0], "both still consumed")
	var lone := _world([&"ember_core", &"frost_core"], 1)
	want = Stats.dot(lone, ElementStack.scale(6 + 4 * 3, 700 * 750 / 1000))
	assert_eq(_break(lone)[0].amount, want, "only the frost that broke it: 70 % x 75 %")


func test_the_charge_is_hashed_only_while_an_enemy_is_charged_and_saved() -> void:
	var w := _world([])
	var h0 := w.state_hash()
	_lightning_hit(w, 1)
	assert_ne(w.state_hash(), h0, "a charge is hashed")
	var snap: Dictionary = bytes_to_var(var_to_bytes(w.to_snapshot()))
	var r := World.from_snapshot(snap, _world([]))
	assert_not_null(r, "the save restores")
	if r == null:
		return
	assert_eq(r.actors.charged_t, w.actors.charged_t, "the charge round-trips")
	assert_eq(r.state_hash(), w.state_hash(), "with the same hash")
	for x: World in [w, r]:
		W.run(x, 90)
	assert_eq(r.state_hash(), w.state_hash(), "and they go on the same")
	var clean := _world([])
	var hc := clean.state_hash()
	clean.actors.charged_t[1] = 0
	assert_eq(clean.state_hash(), hc, "an uncharged world hashes as before")


func test_an_old_save_without_the_charge_loads_uncharged() -> void:
	var w := _world([])
	var snap: Dictionary = bytes_to_var(var_to_bytes(w.to_snapshot()))
	var actors: Dictionary = snap["world"]["actors"]
	actors.erase(&"charged_t")
	actors.erase("charged_t")
	assert_false(actors.has(&"charged_t") or actors.has("charged_t"), "gone, as in an older save")
	var r := World.from_snapshot(snap, _world([]))
	assert_not_null(r, "an older save restores (%s)" % WorldSnapshot.apply(_world([]), snap))
	if r == null:
		return
	assert_eq(r.actors.charged_t.size(), r.actors.ids.size(), "padded")
	assert_eq(r.actors.charged_t[1], 0, "not charged")
	assert_eq(r.state_hash(), w.state_hash(), "it hashes as before")
