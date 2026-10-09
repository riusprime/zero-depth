extends GutTest
## v0.6.0 MX3 on MX2's runners: the forms the sim now emits are drawn from their own specs at the sim's numbers (a
## ring at its radius now, a patch at its radius, a bomb over its blast circle, each projectile in its own spec's
## look), and the older views leave those to AttackFormView when it is there (forms_drawn), keeping what has no spec.

const P := InputFrame.PRIMARY

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


func test_a_shock_field_is_a_zone_in_its_specs_look() -> void:
	var w := _world(&"blade", [&"arc_field"], [], [[Vector2(1.8, 0), 5000]])
	var r := WorldReader.new(w)
	w.step(_f(P))
	_view.sync(r)
	for k in 30:
		if w.ab.fire_kind.has(ElementAbilities.FIRE_FIELD):
			break
		w.step(_f())
		_view.sync(r)
	var k := Array(w.ab.fire_kind).find(ElementAbilities.FIRE_FIELD)
	assert_gte(k, 0, "the swing left a field")
	assert_ne(r.fire_spec_keys()[k], "", "the field names its spec")
	_view.draw_at(float(r.tick()))
	assert_eq(_view.pool(&"zone_fill").used, w.ab.fire_pos.size())
	assert_almost_eq(_sx(&"zone_fill"), w.ab.fire_r[k], 0.0001, "drawn at the sim's radius")
	var c := _view.pool(&"zone_rim").instance_color(0)
	assert_false(AttackFormLooks.is_hostile_hue(c), "never a telegraph hue")
	var el := ElementVisuals.new()
	el.forms_drawn = true
	add_child_autofree(el)
	el.sync(r)
	assert_eq(el.fire_count(), 0, "ElementVisuals leaves the spec patch to the forms")
	var old := ElementVisuals.new()
	add_child_autofree(old)
	old.sync(r)
	assert_eq(old.fire_count(), 1, "alone, it still draws it")


func test_a_frost_ring_is_drawn_at_the_sims_radius_now() -> void:
	var enemies := []
	for k in 4:
		enemies.append([Vector2(1.2, -0.6 + 0.4 * k), 1])
	enemies.append([Vector2(-2.5, 0), 5000])
	var w := _world(&"blade", [&"frost_nova"], [], enemies)
	var r := WorldReader.new(w)
	w.step(_f(P))
	_view.sync(r)
	for k in 30:
		if not r.rings_live().is_empty():
			break
		w.step(_f())
		_view.sync(r)
	assert_false(r.rings_live().is_empty(), "a ring")
	w.step(_f())
	_view.sync(r)
	var ring: Dictionary = r.rings_live()[0]
	_view.draw_at(float(r.tick()))
	var want := ModifierAbilities.ring_radius(w, 0, r.tick())
	assert_almost_eq(_sx(&"ring_fill"), want, 0.0001, "the drawn front is the hit front")
	var look := AttackFormLooks.compose(r.attack_spec_at(ring["key"]), HeatLooks.TIER_COOL)
	assert_eq(look["core"], AttackFormLooks.ELEMENT_CORE[&"frost"], "frost's core")


func test_bombs_arc_over_their_blast_circle_and_land_in_their_look() -> void:
	var w := _world(&"blade", [&"bomb_lobber"], [&"ember_edge"], [[Vector2(5, 0), 5000]])
	var r := WorldReader.new(w)
	for n in 4:
		_swing(w, r)
	var guard := 0
	while w.ab.bomb_pos.is_empty() and w.ab.blast_tick.is_empty() and guard < 60:
		w.step(_f())
		_view.sync(r)
		guard += 1
	assert_false(w.ab.bomb_pos.is_empty(), "a bomb in flight")
	if not w.ab.bomb_pos.is_empty():
		_view.draw_at(float(r.tick()))
		assert_eq(_view.pool(&"lob_body").used, w.ab.bomb_pos.size(), "one shell per bomb")
		assert_almost_eq(_sx(&"lob_ground"), w.ab.bomb_r[0], 0.0001, "its blast circle")
		var ab := AbilityVisuals.new()
		ab.forms_drawn = true
		add_child_autofree(ab)
		ab.sync(r)
		assert_eq(ab.bomb_count(), 0, "AbilityVisuals leaves the spec bomb to the forms")
	while w.ab.blast_tick.is_empty() and guard < 120:
		w.step(_f())
		_view.sync(r)
		guard += 1
	assert_false(w.ab.blast_tick.is_empty(), "it landed")
	_view.draw_at(float(w.ab.blast_tick[0]) + 2.0)
	assert_gt(_view.pool(&"burst_fill").used, 0, "the landing flash")
	var landing: Dictionary = {}
	for e in _view._effects:
		if e["kind"] == &"landing":
			landing = e
	assert_eq(
		landing["look"]["core"], AttackFormLooks.ELEMENT_CORE[&"ember"], "the bomb burns: ember"
	)


func test_each_projectile_is_drawn_in_its_own_spec() -> void:
	var w := _world(&"gun", [&"drone_buddy"], [&"ricochet_core"], [[Vector2(4, 0), 5000]])
	var r := WorldReader.new(w)
	var drone_key := ""
	for k in 60:
		w.step(_f())
		_view.sync(r)
		for i in r.projectile_count():
			if r.projectile_team(i) == 0 and r.projectile_spec_key(i) != "":
				drone_key = r.projectile_spec_key(i)
		if drone_key != "" and _view.live_count() > 0:
			break
	assert_ne(drone_key, "", "the drone's bolts name their spec")
	assert_gt(_view.live_count(), 0, "a bouncing bolt draws its cue layer")
	var want := AttackFormLooks.compose(r.attack_spec_at(drone_key), r.heat_state().get("tier", 0))
	var found := false
	for b in _view._live:
		found = found or b["look"]["cues"] == want["cues"]
	assert_true(found, "the live look is its spec's")
	assert_true(
		(want["cues"] as Array).has(&"bounce_flash"), "the gun's ricochet rides the drone's copy"
	)


func test_the_reader_reads_keys_as_plain_data() -> void:
	var w := _world(&"gun", [])
	var r := WorldReader.new(w)
	assert_eq(r.attack_spec_at(""), {})
	assert_eq(r.attack_spec_at("nope"), {})
	assert_eq(r.attack_spec_at("gun_bolt")["form"], WorldReader.FORM_BOLT)
	assert_eq(r.bomb_spec_keys().size(), w.ab.bomb_pos.size())
	assert_eq(r.fire_spec_keys().size(), w.ab.fire_pos.size())
	assert_true(r.rings_live().is_empty())
