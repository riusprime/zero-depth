extends GutTest
## Starting builds, the damage rebalance, melee along the facing and out-of-combat regen (v0.3.0 PLAN L15, L16,
## L25, L29; workstream P).

const P := InputFrame.PRIMARY
const S := InputFrame.SHOOT


func _build(id: StringName) -> BuildDefinition:
	return ContentRepository.load_all().get_def(&"build", id)


func _table(build: StringName) -> PlayerTable:
	var t := PlayerTable.starting_values()
	return ContentCompiler.apply_build(t, _build(build)) if build != &"" else t


func _world(build: StringName, enemy_at: Vector2 = Vector2(1.2, 0), hp: int = 900) -> World:
	var w := World.new(3, _table(build))
	if enemy_at != Vector2.INF:
		w.add_dummy(enemy_at, 0.35, hp)
		w.dummy_speed = 0.0
	return w


func _f(
	held: int = 0, pressed: int = 0, move: Vector2i = Vector2i.ZERO, aim: int = 0
) -> InputFrame:
	return InputFrame.make(move, aim, 300, held, pressed)


func _idle(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _hits(w: World, tag: int) -> Array:
	var out := []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and e.tags & tag and e.target_id != w.actors.ids[0]:
			out.append(e.amount)
	return out


func _player_bolts(w: World) -> int:
	var n := 0
	for i in w.projectiles.size():
		if w.projectiles.team[i] == ActorStore.TEAM_PLAYER:
			n += 1
	return n


# --- Data ----------------------------------------------------------------------------------------------------
func test_the_two_builds_in_data() -> void:
	var repo := ContentRepository.load_all()
	assert_eq(repo.count(&"build"), 2, "Blade and Gun")
	var blade := _build(&"blade")
	var gun := _build(&"gun")
	assert_eq(blade.weapon, BuildDefinition.Weapon.BLADE)
	assert_eq(gun.weapon, BuildDefinition.Weapon.GUN)
	assert_eq(blade.damage_permille, 1150, "L16: Blade +15 % (starting value)")
	assert_eq(gun.damage_permille, 1000, "owner 2026-10-08: no Gun -15 % (supersedes L16's)")
	for d: BuildDefinition in [blade, gun]:
		assert_eq(d.validate().size(), 0, "%s validates" % d.id)


func test_a_bad_build_fails_validation() -> void:
	var d := BuildDefinition.new()
	d.id = &"lance"
	d.weapon = 7 as BuildDefinition.Weapon
	d.damage_permille = 20
	var codes := []
	for i in d.validate():
		codes.append(String(i.code))
	codes.sort()
	assert_eq(
		codes, ["missing", "missing", "range", "range"], "keys, skill (v0.3.5 K), weapon and damage"
	)


func test_apply_build_enables_one_weapon_and_its_factor() -> void:
	var b := _table(&"blade")
	assert_eq(b.weapons, PlayerTable.WEAPON_BLADE)
	assert_eq([b.melee_damage_permille, b.bolt_damage_permille], [1150, 1000])
	var g := _table(&"gun")
	assert_eq(g.weapons, PlayerTable.WEAPON_GUN)
	assert_eq([g.melee_damage_permille, g.bolt_damage_permille], [1000, 1000])
	assert_eq(_table(&"").weapons, PlayerTable.WEAPONS_ALL, "no build keeps both (kernel, labs)")


# --- Inputs gated by the build ---------------------------------------------------------------------------------
func test_blade_swings_and_never_shoots() -> void:
	var w := _world(&"blade")
	for i in 30:
		w.step(_f(S, S if i == 0 else 0))
		assert_eq(_player_bolts(w), 0, "holding shoot fires nothing")
	assert_eq(_hits(w, SimEvent.TAG_PROJECTILE), [])
	w.step(_f(0, P))
	_idle(w, 20)
	assert_eq(_hits(w, SimEvent.TAG_MELEE).size(), 1, "the blade swings")


func test_gun_shoots_and_melee_does_nothing() -> void:
	var w := _world(&"gun")
	w.step(_f(0, P))
	_idle(w, 30)
	assert_eq(w.swing_t, 0, "no swing")
	assert_eq(_hits(w, SimEvent.TAG_MELEE), [], "the melee press does nothing")
	assert_eq(w.buffered(InputFrame.PRIMARY), 0, "and isn't kept for later")
	for i in 30:
		w.step(_f(S))
	assert_gt(_hits(w, SimEvent.TAG_PROJECTILE).size(), 0, "the gun shoots")


# --- Damage factors ------------------------------------------------------------------------------------------
func test_blade_damage_is_up_15_percent_exactly_on_average() -> void:
	var w := _world(&"blade")
	var t := w.player
	for k in 2:
		for i in t.combo.size():
			w.step(_f(0, P))
			_idle(w, t.step(w.combo_step).ticks + t.step(w.combo_step).hitstop_ticks + 1)
	var got := _hits(w, SimEvent.TAG_MELEE)
	# 10, 10, 12, 24 at 1150 per mille, remainders carried: 11 12 13 28, then 11 12 14 27.
	assert_eq(got, [11, 12, 13, 28, 11, 12, 14, 27])
	var total := 0
	for v in got:
		total += v
	assert_eq(total, (10 + 10 + 12 + 24) * 2 * 1150 / 1000, "the sum is exact: 112 + 15 %")


func test_gun_damage_is_the_bolts_own() -> void:  # owner 2026-10-08: the Gun's -15 % is gone
	var w := _world(&"gun", Vector2(2.0, 0), 5000)
	for i in 7 * 10:
		w.step(_f(S))
	_idle(w, 20)
	var got := _hits(w, SimEvent.TAG_PROJECTILE)
	assert_eq(got.size(), 10, "ten bolts landed")
	var total := 0
	for v in got:
		total += v
	assert_eq(total, 40, "4 x 1.00 x 10 = 40")
	for v in got:
		assert_eq(v, 4)


func test_full_damage_without_a_build() -> void:
	var w := _world(&"")
	w.step(_f(0, P))
	_idle(w, 20)
	assert_eq(_hits(w, SimEvent.TAG_MELEE), [10])


# --- Melee goes along the facing, shots along the aim (L29) --------------------------------------------------
func test_melee_follows_the_move_direction_not_the_aim() -> void:
	# Enemy to the left (-x); aim right (0); move left (-x): the swing hits the left one.
	var w := _world(&"blade", Vector2(-1.3, 0))
	var left := Vector2i(-127, 0)
	w.step(_f(0, P, left, 0))
	assert_eq(w.swing_angle, 2048, "the swing locks the move direction")
	for i in 20:
		w.step(_f(0, 0, Vector2i.ZERO, 0))
	assert_eq(_hits(w, SimEvent.TAG_MELEE).size(), 1, "the enemy on the left is hit")


func test_standing_still_keeps_the_last_facing() -> void:
	var w := _world(&"blade", Vector2(0, 2.5))
	for i in 3:
		w.step(_f(0, 0, Vector2i(0, 127), 0))  # walk +y (toward the enemy) a little
	_idle(w, 30)
	assert_eq(w.build_state.facing_angle, 1024)
	w.step(_f(0, P, Vector2i.ZERO, 0))  # aim +x, standing still
	assert_eq(w.swing_angle, 1024, "the swing keeps the last facing")


func test_before_any_move_melee_uses_the_aim() -> void:
	var w := _world(&"blade")
	w.step(_f(0, P, Vector2i.ZERO, 300))
	assert_eq(w.swing_angle, 300)


func test_shots_go_along_the_aim_while_moving_elsewhere() -> void:
	var w := _world(&"gun", Vector2.INF)
	w.step(_f(S, 0, Vector2i(-127, 0), 0))
	w.step(_f(S, 0, Vector2i(-127, 0), 0))
	assert_eq(_player_bolts(w), 1)
	assert_gt(w.projectiles.vel_x[0], 0.0, "the bolt goes right (the aim) while moving left")


# --- Offers filtered by weapon -------------------------------------------------------------------------------
func _offer_world(build: StringName) -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.apply_build(PlayerTable.starting_values(), _build(build))
	t.utility = PlayerTable.Utility.GUARD
	var w := World.new(5, t)
	var items: Array[ItemTable] = []
	for def: ItemDefinition in repo.all_of(&"items"):
		items.append(ContentCompiler.compile_item(def))
	w.set_item_tables(items)
	return w


func test_items_are_tagged_by_weapon_honestly() -> void:
	var blade := []
	var gun := []
	for def: ItemDefinition in ContentRepository.load_all().all_of(&"items"):
		if def.requires_weapon == &"blade":
			blade.append(String(def.id))
		elif def.requires_weapon == &"gun":
			gun.append(String(def.id))
	blade.sort()
	gun.sort()
	assert_eq(
		blade,
		[
			"bulwark",
			"conductor",
			"ember_edge",
			"glacial_edge",
			"long_edge",
			"momentum",
			"overcharge",
			"serrated_edge",
			"twin_arc"
		]
	)
	assert_eq(
		gun,
		[
			"barbed_bolts",
			"cinder_shot",
			"frost_core",
			"rapid_coil",
			"ricochet_core",
			"splinter_shot",
			"static_chain"
		]
	)


func test_a_build_is_never_offered_the_other_weapons_items() -> void:
	for build: StringName in [&"blade", &"gun"]:
		var w := _offer_world(build)
		var other := PlayerTable.WEAPON_GUN if build == &"blade" else PlayerTable.WEAPON_BLADE
		var avail := ItemPool.available(w)
		assert_gt(avail.size(), 10, "%s still has a pool" % build)
		for idx in avail:
			assert_ne(
				w.item_tables[idx].requires_weapon, other, "%s: %s" % [build, w.item_tables[idx].id]
			)
		for s in 40:
			w.rng_loot = RngStream.derive(s, "loot")
			for idx in ItemPool.draw_weighted(w, 3, 3):
				assert_ne(w.item_tables[idx].requires_weapon, other)


func test_every_combo_is_reachable_in_some_build() -> void:
	# Both items of every combo can be offered in one run of at least one build and utility (heat on, as in the
	# game). Plasma Arc was Ember Edge (blade) + Static Chain (gun); it now pairs Ember Edge with Conductor.
	var repo := ContentRepository.load_all()
	var heat := ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock"))
	var reach := {}
	for build: StringName in [&"blade", &"gun"]:
		for util in [PlayerTable.Utility.GUARD, PlayerTable.Utility.BLINK]:
			var w := _offer_world(build)
			w.player.utility = util
			Heat.enable(w, heat)
			var ids := []
			for idx in ItemPool.available(w):
				ids.append(w.item_tables[idx].id)
			for c: ComboDefinition in repo.all_of(&"combos"):
				if c.item_a in ids and c.item_b in ids:
					reach[c.id] = reach.get(c.id, []) + ["%s/%d" % [build, util]]
	for c: ComboDefinition in repo.all_of(&"combos"):
		if not c.is_ability_combo():  # v0.4.0 AB: ability pairs are test_abilities_ab's
			assert_true(reach.has(c.id), "%s is reachable in some build" % c.id)
	var plasma: ComboDefinition = repo.get_def(&"combos", &"plasma_arc")
	assert_eq([plasma.item_a, plasma.item_b], [&"ember_edge", &"conductor"])
	gut.p("combo reach: %s" % reach)


# --- Run carry and hash of the build -------------------------------------------------------------------------
func test_the_build_is_the_runs_and_hashed() -> void:
	var r := RunState.start(7, RunTable.new(), &"gun")
	assert_eq(r.build_id, &"gun")
	r.finish_floor(World.new(1, PlayerTable.starting_values()))
	assert_eq(r.build_id, &"gun", "the build holds on the next floor")
	var a := World.new(3, _table(&"blade"))
	var b := World.new(3, _table(&"gun"))
	assert_ne(a.state_hash(), b.state_hash(), "the build is in the hash")


func test_the_kernel_hash_ignores_untouched_build_state() -> void:
	var a := World.new(3, PlayerTable.starting_values())
	assert_false(PlayerBuild.touched(a), "kernel worlds keep their golden hash")
