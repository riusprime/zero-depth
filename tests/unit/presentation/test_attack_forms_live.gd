extends GutTest
## v0.6.0 MX3 on MX2's runners: the forms the sim now emits are drawn from their own specs at the sim's numbers (a
## ring at its radius now, a patch at its radius, a bomb over its blast circle, each projectile in its own spec's
## look), and the older views leave those to AttackFormView when it is there (forms_drawn), keeping what has no spec.

const P := InputFrame.PRIMARY
const MX4 := preload("res://tests/support/mx4_world.gd")

var _repo: ContentRepository
var _view: AttackFormView


func before_all() -> void:
	_repo = ContentRepository.load_all()


func before_each() -> void:
	ViewPrefs.effects_density = "high"
	_view = add_child_autofree(AttackFormView.new())


## MX2's test world (test_modifier_abilities.gd): the runner with `build`, crit off, the abilities granted.
func _world(build: StringName, abilities: Array, items: Array = [], enemies: Array = []) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", build))
	t.crit_chance_permille = 0
	var w := World.new(9, t)
	w.dummy_speed = 0.0
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.set_combo_tables(ContentCompiler.compile_combos(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	Abilities.grant_start(w)
	for id: StringName in items:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	for id: StringName in abilities:
		for k in w.ability_tables.size():
			if w.ability_tables[k].id == id:
				Abilities.grant(w, k)
	Abilities.start_floor(w)
	for e: Array in enemies:
		w.add_dummy(e[0], 0.35, e[1])
	return w


func _f(pressed: int = 0, held: int = 0) -> InputFrame:
	return InputFrame.make(Vector2i.ZERO, 0, 300, held, pressed)


func _swing(w: World, r: WorldReader) -> void:
	w.step(_f(P))
	_view.sync(r)
	for k in 30:
		w.step(_f())
		_view.sync(r)


func _sx(id: StringName, i: int = 0) -> float:
	return _view.pool(id).instance_transform(i).basis.x.length()


## v0.9.0 XP (owner Q11, "Burning ground on kill"): Fire's burning patch is a low flat zone in the ember look, at the
## sim's radius (no blast).
func test_fires_burning_patch_is_an_ember_zone() -> void:
	var w := _world(&"gun", [], [&"ember_core"], [[Vector2(2.5, 0), 4]])
	var r := WorldReader.new(w)
	for k in 90:
		w.step(_f(0, InputFrame.SHOOT if w.actors.dead[1] == 0 else 0))
		_view.sync(r)
		if not w.ab.fire_pos.is_empty():
			break
	assert_eq(w.ab.fire_pos.size(), 1, "the kill left one patch")
	assert_ne(r.fire_spec_keys()[0], "", "the patch names its spec")
	_view.draw_at(float(r.tick()))
	assert_eq(_view.pool(&"zone_fill").used, 1)
	assert_almost_eq(_sx(&"zone_fill"), w.ab.fire_r[0], 0.0001, "drawn at the sim's radius")
	var c := _view.pool(&"zone_rim").instance_color(0)
	assert_gt(c.r, c.b, "in the ember look (warm)")
	assert_false(AttackFormLooks.is_hostile_hue(c), "never a telegraph hue")


func test_the_reader_reads_keys_as_plain_data() -> void:
	var w := _world(&"gun", [])
	var r := WorldReader.new(w)
	assert_eq(r.attack_spec_at(""), {})
	assert_eq(r.attack_spec_at("nope"), {})
	assert_eq(r.attack_spec_at("gun_bolt")["form"], WorldReader.FORM_BOLT)
	assert_eq(r.bomb_spec_keys().size(), w.ab.bomb_pos.size())
	assert_eq(r.fire_spec_keys().size(), w.ab.fire_pos.size())
	assert_true(r.rings_live().is_empty())


## Audit P-19a: the bomb-look cache drops its oldest entries past 64, never wholesale, so a bomb in flight when the
## cache fills still lands in its own look (not the plain one).
func test_a_full_bomb_look_cache_keeps_the_newest_bomb() -> void:
	var view: AttackFormView = add_child_autofree(AttackFormView.new())
	for k in 64:
		view._bomb_looks[AttackFormView._pos_key(Vector2(k, 50))] = {"old": k}
	var mine := {"form": "mine", "colour": Color.RED}
	view._bomb_looks[AttackFormView._pos_key(Vector2(3, 4))] = mine
	var none := {
		"blast_tick": PackedInt32Array(),
		"blast_pos": PackedVector2Array(),
		"blast_r": PackedFloat32Array()
	}
	view._sync_blasts(none)  # the sync it was cached on: the cache is past 64
	assert_eq(view._bomb_looks.size(), 64, "trimmed to 64")
	assert_false(view._bomb_looks.has(AttackFormView._pos_key(Vector2(0, 50))), "the oldest went")
	var landed := {
		"blast_tick": PackedInt32Array([10]),
		"blast_pos": PackedVector2Array([Vector2(3, 4)]),
		"blast_r": PackedFloat32Array([1.5])
	}
	view._sync_blasts(landed)
	assert_eq(view._effects[-1]["look"], mine, "it lands in its own look")


## v0.8.0 (owner bug, 2026-10-17: "picking ring I had twin and echo … Invalid access to property or key 'length'"):
## shots already flying when Ring is picked keep being drawn as bolts, though the wand's look is now a ring.
func test_shots_in_flight_when_ring_is_picked_are_still_drawn() -> void:
	var w := MX4.world(&"gun", [&"gun_twin", &"gun_echo"], [[Vector2(9.0, 0), 50000]])
	var r := WorldReader.new(w)
	MX4.run(w, 1, MX4.S, MX4.S)
	for k in 6:
		MX4.run(w, 1, 0, MX4.S)
		_view.sync(r)
		_view.draw_at(float(r.tick()))
	assert_gt(r.projectile_count(), 0, "bolts are flying")
	w.add_item(MX4.item(w, &"gun_ring"))
	for k in 30:
		MX4.run(w, 1, 0, 0)
		_view.sync(r)
		_view.draw_at(float(r.tick()))
	assert_eq(r.projectile_count(), 0, "the old bolts flew out")
