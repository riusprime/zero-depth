extends GutTest
## v0.6.0 MX2 (owner B7): the six old abilities as weapon modifiers. Each launches its compiled spec (Modifiers: the
## ability's v0.5 numbers at its level, carrying the weapon's statuses, elements and hooks) through Attacks:
## Bomb Lobber lobs on every 4th weapon attack (form LOB), the drone fires a copy of the weapon's attack, the orbit
## blades are orbiters, Arc Field leaves a shock field where an attack ends (ZONE), Frost Nova gives the weapon frost
## and rings on a kill streak (RING), Flame Trail's dash and projectiles leave fire (ZONE). Crit off, exact numbers.

const P := InputFrame.PRIMARY

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


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
		Abilities.grant(w, _idx(w, id))
	Abilities.start_floor(w)
	for e: Array in enemies:
		w.add_dummy(e[0], 0.35, e[1])
	return w


func _idx(w: World, id: StringName) -> int:
	for k in w.ability_tables.size():
		if w.ability_tables[k].id == id:
			return k
	return -1


func _t(w: World, id: StringName) -> AbilityTable:
	return w.ability_tables[_idx(w, id)]


func _f(pressed: int = 0, held: int = 0, aim: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _damage(w: World, effect: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == effect:
			out.append(e)
	return out


## Swings once (a press, then the swing's ticks).
func _swing(w: World) -> void:
	w.step(_f(P))
	for k in 30:
		w.step(_f())


func test_the_specs_keep_the_v0_5_numbers_at_every_level() -> void:
	var ids: Array = [
		&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
	]
	var w := _world(&"blade", ids)
	for lvl in range(1, 6):
		for k in w.ability_owned.size():
			if w.ability_tables[w.ability_owned[k]].is_modifier():
				w.ability_levels[k] = lvl
		w.refresh_build(false)
		var bomb := _t(w, &"bomb_lobber")
		var b := Modifiers.ability(w, bomb)
		assert_eq(b.form, AttackSpec.Form.LOB)
		assert_eq(b.damage, Abilities.damage_at(bomb, lvl), "bomb damage L%d" % lvl)
		assert_almost_eq(b.radius_m, bomb.radius_m * bomb.radius_permille(lvl) / 1000.0, 0.0001)
		assert_eq(b.count, bomb.count(lvl), "bombs per throw L%d" % lvl)
		assert_eq(b.life_ticks, bomb.duration_ticks)
		var drone := _t(w, &"drone_buddy")
		var d := Modifiers.ability(w, drone)
		assert_eq([d.form, d.damage], [AttackSpec.Form.BOLT, Abilities.damage_at(drone, lvl)])
		assert_eq(d.life_ticks, int(ceil(drone.range_m / drone.speed)) + 2)
		var orbit := _t(w, &"orbit_blades")
		var o := Modifiers.ability(w, orbit)
		assert_eq([o.form, o.count, o.damage], [AttackSpec.Form.ORBITER, orbit.count(lvl), 8])
		var arc := _t(w, &"arc_field")
		var a := Modifiers.ability(w, arc)
		assert_eq([a.form, a.damage], [AttackSpec.Form.ZONE, 12])
		assert_eq(a.stacks_of(&"shock"), arc.extra(lvl))
		var nova := _t(w, &"frost_nova")
		var n := Modifiers.ability(w, nova)
		assert_eq([n.form, n.damage], [AttackSpec.Form.RING, 10])
		assert_eq(n.stacks_of(&"frost"), nova.extra(lvl))
		assert_almost_eq(n.radius_m, nova.radius_m * nova.radius_permille(lvl) / 1000.0, 0.0001)
		var fire := _t(w, &"flame_trail")
		var f := Modifiers.ability(w, fire)
		assert_eq(f.form, AttackSpec.Form.ZONE)
		assert_eq(f.damage, Abilities.damage_at(fire, lvl))
		assert_eq(f.life_ticks, maxi(1, fire.duration_ticks * fire.rate_permille(lvl) / 1000))
		assert_eq(f.stacks_of(&"burn"), fire.extra(lvl))


func test_bomb_lobber_lobs_on_the_fourth_attack_for_its_v0_5_damage() -> void:
	var w := _world(&"blade", [&"bomb_lobber"], [], [[Vector2(5, 0), 5000]])
	for n in 3:
		_swing(w)
	assert_eq(w.ab.bomb_pos.size() + w.ab.blast_tick.size(), 0, "three attacks: no bomb yet")
	_swing(w)
	assert_eq(w.ab.blast_tick.size() + w.ab.bomb_pos.size(), 1, "the fourth lobs one")
	for k in 60:
		w.step(_f())
	var hits := _damage(w, Abilities.EFFECT_BOMB)
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 22, "v0.5's 22")


func test_a_bomb_carries_the_blades_burn() -> void:
	var w := _world(&"blade", [&"bomb_lobber"], [&"ember_edge"], [[Vector2(5, 0), 5000]])
	assert_true(Modifiers.ability(w, _t(w, &"bomb_lobber")).has_status(&"burn"))
	for n in 4:
		_swing(w)
	for k in 60:
		w.step(_f())
	assert_gt(w.actors.burn_stacks[1], 0, "the bomb's blast burns (the sword it carries burns)")


func test_the_drone_fires_a_copy_of_the_guns_shot() -> void:
	var w := _world(&"gun", [&"drone_buddy"], [&"ricochet_core"], [[Vector2(4, 0), 5000]])
	var d := Modifiers.ability(w, _t(w, &"drone_buddy"))
	assert_eq(d.bounces, Modifiers.bolt(w).bounces, "the gun's ricochet")
	var keyed := false
	for k in 60:
		w.step(_f())
		for pk in w.projectiles.spec_key:
			keyed = keyed or pk == d.key
	assert_true(keyed, "its bolts run the drone's spec")
	assert_gt(_damage(w, Abilities.EFFECT_DRONE).size(), 0)


func test_orbit_blades_hit_as_orbiters_and_razor_orbit_bleeds() -> void:
	var w := _world(&"blade", [&"orbit_blades"], [], [[Vector2(1.6, 0), 5000]])
	w.add_item(AttackScenario.item_index(w.item_tables, &"razor_orbit"))
	assert_true(Modifiers.ability(w, _t(w, &"orbit_blades")).has_status(&"bleed"))
	for k in 120:
		w.step(_f())
	var hits := _damage(w, Abilities.EFFECT_ORBIT)
	assert_gt(hits.size(), 0)
	assert_eq(hits[0].amount, 8, "v0.5's 8")
	assert_gt(w.actors.bleed_stacks[1], 0, "Razor Orbit's bleed, from its modifier")


func test_arc_field_leaves_a_shock_field_where_the_swing_ends() -> void:
	var w := _world(&"blade", [&"arc_field"], [], [[Vector2(1.8, 0), 5000]])
	_swing(w)
	assert_true(w.ab.fire_kind.has(ElementAbilities.FIRE_FIELD), "a field")
	for k in 40:
		w.step(_f())
	var hits := _damage(w, ElementAbilities.EFFECT_ARC)
	assert_gt(hits.size(), 0, "the field hits what stands in it")
	assert_eq(hits[0].amount, 12, "v0.5's 12")


func test_frost_nova_gives_the_weapon_frost_and_rings_on_a_kill_streak() -> void:
	var enemies := []
	for k in 4:
		enemies.append([Vector2(1.2, -0.6 + 0.4 * k), 1])
	enemies.append([Vector2(-2.5, 0), 5000])
	var w := _world(&"blade", [&"frost_nova"], [], enemies)
	assert_true(Modifiers.step(w, 0).elements.has("frost"), "the frost element on the weapon")
	assert_true(Modifiers.step(w, 0).has_status(&"frost"))
	_swing(w)
	assert_ne(w.ab.nova_tick, -1, "four kills in a row: the ring")
	for k in 30:
		w.step(_f())
	var hits := _damage(w, ElementAbilities.EFFECT_NOVA)
	assert_gt(hits.size(), 0, "the ring reaches the enemy behind")
	assert_eq(hits[0].amount, 10, "v0.5's 10")


func test_flame_trail_fire_from_the_dash_and_from_a_projectile() -> void:
	var w := _world(&"blade", [&"flame_trail"])
	w.step(_f(InputFrame.DASH, 0, 0, Vector2i(127, 0)))
	for k in 20:
		w.step(_f(0, 0, 0, Vector2i(127, 0)))
	assert_gt(w.ab.fire_pos.size(), 0, "the dash leaves fire")
	var g := _world(&"gun", [&"flame_trail"])
	for k in 80:
		g.step(_f(0, InputFrame.SHOOT))
	assert_gt(g.ab.fire_pos.size(), 0, "a bolt that ends leaves fire")
	for k in g.ab.fire_kind.size():
		assert_eq(g.ab.fire_kind[k], ElementAbilities.FIRE_TRAIL)


func test_the_same_seed_replays_the_six_together() -> void:
	var ids: Array = [
		&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
	]
	var hashes := []
	for n in 2:
		var w := _world(
			&"blade", ids, [&"ember_edge"], [[Vector2(2, 1), 400], [Vector2(-2, 2), 400]]
		)
		for k in 400:
			w.step(_f(P if k % 12 == 0 else 0, 0, (k * 31) & 4095))
		hashes.append(w.state_hash())
	assert_eq(hashes[0], hashes[1])
