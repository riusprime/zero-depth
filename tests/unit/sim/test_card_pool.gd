extends GutTest
## The v0.5.0 CP cards with the shipped data, one deterministic test per effect: the five rule stat cards (Glass
## Cannon, Onrush, Overkill, Hoarder, Fast Hands) and the four ability mods (Cluster Payload, Overclocked Drone,
## Razor Orbit, Afterimage), and the mods' ability gate. Crit is off (crit_chance_permille = 0) so numbers are exact.

const U := InputFrame.UTILITY

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(enemies: Array = [], hp: int = 5000) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	t.crit_chance_permille = 0
	var w := World.new(31, t)
	w.dummy_speed = 0.0
	w.dummy_fire_period = 100000
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	for at: Vector2 in enemies:
		w.add_dummy(at, 0.35, hp)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


func _grant(w: World, kind: int) -> int:
	var idx := Abilities.index_of_kind(w, kind)
	Abilities.grant(w, idx)
	return idx


func _item(w: World, id: StringName) -> int:
	for k in w.item_tables.size():
		if w.item_tables[k].id == id:
			return k
	return -1


func _f(pressed: int = 0, move := Vector2i.ZERO) -> InputFrame:
	return InputFrame.make(move, 0, 300, 0, pressed)


func _run(w: World, n: int) -> void:
	for i in n:
		w.step(_f())


func _damage(w: World, effect: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.DAMAGE and e.effect_id == effect:
			out.append(e)
	return out


# --- Data ---------------------------------------------------------------------------------------------------
func test_the_rule_cards_compile_with_their_side_numbers_and_limits() -> void:
	var t := ContentCompiler.compile_stat_cards(_repo)
	var glass := t[Stats.Stat.GLASS_CANNON]
	assert_eq(
		[glass.amounts, glass.side],
		[PackedInt32Array([150, 250, 400, 640]), PackedInt32Array([80, 100, 120, 192])]  # v0.5.5 AR: + legendary
	)
	assert_eq(
		[glass.cap, glass.limit_permille], [3000, 400], "damage at most x3, max HP at least x0.4"
	)
	assert_eq(
		[t[Stats.Stat.ONRUSH].amounts, t[Stats.Stat.ONRUSH].cap],
		[PackedInt32Array([100, 180, 300, 480]), 900]
	)
	var ok := t[Stats.Stat.OVERKILL]
	assert_eq(
		[ok.amounts[0], ok.cap, ok.limit_permille], [400, 1500, 3000], "40 %, at most 150 %, 3 m"
	)
	var hoard := t[Stats.Stat.HOARDER]
	assert_eq(
		[hoard.amounts[0], hoard.side[0], hoard.cap, hoard.limit_permille], [40, 100, 200, 1000000]
	)
	assert_eq([t[Stats.Stat.FAST_HANDS].amounts[1], t[Stats.Stat.FAST_HANDS].cap], [140, 400])


func test_bad_rule_cards_are_rejected() -> void:
	var g := (load("res://data/stat_cards/glass_cannon.tres") as StatCardDefinition).duplicate(true)
	assert_eq(g.validate(), [])
	g.limit = 1.0
	assert_eq(g.validate().size(), 1, "Glass Cannon's floor is below x1")
	g.limit = 0.4
	g.side = PackedFloat32Array([8, 0, 12])
	assert_eq(g.validate().size(), 1, "side numbers are positive")
	var d := (load("res://data/stat_cards/damage.tres") as StatCardDefinition).duplicate(true)
	d.side = PackedFloat32Array([1, 2, 3])
	d.limit = 2.0
	assert_eq(d.validate().size(), 2, "a plain stat has no side and no limit")


func test_bad_ability_mods_are_rejected() -> void:
	var c := (load("res://data/items/cluster_payload.tres") as ItemDefinition).duplicate(true)
	assert_eq(c.validate(), [])
	c.requires_ability = &"no_such_ability"
	assert_eq(c.validate().size(), 1, "an unknown ability")
	c.requires_ability = &""
	assert_eq(c.validate().size(), 1, "an ability mod names its ability")
	c.requires_ability = &"bomb_lobber"
	c.modifiers.clear()  # v0.6.0 MX4: the bomblets are its modifier's ops now
	assert_eq(c.validate().size(), 1, "it names its modifier")
	assert_eq(ItemDefinition.ability_kind(&"orbit_blades"), AbilityDefinition.Kind.ORBIT_BLADES)


# --- Rule stat cards ----------------------------------------------------------------------------------------
func test_glass_cannon_trades_max_hp_for_damage_down_to_its_floor() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.COMMON)
	assert_eq(Stats.damage_permille(w), 1150, "+15 % damage")
	assert_eq([w.actors.max_hp[0], w.actors.hp[0]], [92, 92], "-8 % max HP, HP held to it")
	assert_eq(Stats.outgoing(w, 100, 0)[0], 115)
	for k in 30:
		Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.EPIC)
	assert_eq(Stats.value(w, Stats.Stat.MAX_HP), 400, "never under x0.4")
	assert_eq(w.actors.max_hp[0], 40)
	assert_eq(Stats.value(w, Stats.Stat.GLASS_CANNON), 3000, "damage at most x3")
	assert_true(Stats.at_cap(w, Stats.Stat.GLASS_CANNON), "offers stop")


func test_onrush_adds_damage_only_while_moving() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.ONRUSH, Stats.Rarity.RARE)
	assert_eq(Stats.damage_permille(w), 1000, "standing still: nothing")
	w.step(_f(0, Vector2i(SimTick.MOVE_MAX, 0)))
	assert_eq(Stats.damage_permille(w), 1180, "moving: +18 %")
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	assert_eq(Stats.damage_permille(w), 1274, "x1.08 then +18 %: 1080 x 1.18")
	w.step(_f())
	assert_eq(Stats.damage_permille(w), 1080, "stopped again")


func test_overkill_splashes_a_kills_excess_once_onto_the_nearest_enemy() -> void:
	var w := _world()
	var a := w.add_dummy(Vector2(2, 0), 0.35, 10)
	var b := w.add_dummy(Vector2(3, 0), 0.35, 5)
	var far := w.add_dummy(Vector2(9, 0), 0.35, 1000)
	var pid := w.actors.ids[0]
	var ia := w.actors.index_of(a)
	Damage.hit(w, ia, 60, pid, pid, w.take_root(), SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(2, 0))
	assert_eq(_damage(w, Stats.EFFECT_OVERKILL).size(), 0, "no card: no splash")
	Stats.add_card(w, Stats.Stat.OVERKILL, Stats.Rarity.COMMON)
	var c := w.add_dummy(Vector2(2, 1), 0.35, 10)
	var ic := w.actors.index_of(c)
	Damage.hit(w, ic, 60, pid, pid, w.take_root(), SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(2, 1))
	var splash := _damage(w, Stats.EFFECT_OVERKILL)
	assert_eq(splash.size(), 1, "one splash, and its own kill never splashes again")
	assert_eq(splash[0].target_id, b, "onto the nearest live enemy (A is already dead)")
	assert_eq(splash[0].amount, 20, "40 % of the 50 left over")
	assert_eq(w.actors.hp[w.actors.index_of(far)], 1000, "the far one is out of the 3 m reach")


func test_hoarder_counts_whole_hundreds_of_shards_up_to_its_limit() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.HOARDER, Stats.Rarity.COMMON)
	assert_eq(Stats.shards(w, 100), 110, "+10 % shard gain")
	w.shards = 99
	assert_eq(Stats.damage_permille(w), 1000, "under 100 shards: nothing")
	w.shards = 250
	assert_eq(Stats.damage_permille(w), 1080, "two hundreds: +8 %")
	w.shards = 5000
	assert_eq(Stats.damage_permille(w), 1400, "at most 1000 shards count: +40 %")


func test_fast_hands_cuts_auto_ability_cooldowns_only() -> void:
	var w := _world([Vector2(3, 0)])
	var s := w.ability_owned.size()
	_grant(w, AbilityTable.Kind.BOMB_LOBBER)
	var drone := _grant(w, AbilityTable.Kind.DRONE_BUDDY)
	Stats.add_card(w, Stats.Stat.FAST_HANDS, Stats.Rarity.RARE)
	w.step(_f())
	for k in 4:  # v0.6.0 MX2: Bomb Lobber lobs on the fourth weapon attack
		ModifierAbilities.on_attack(w, w.player_pos())
	assert_eq(w.ab.cd[s], 129, "Bomb Lobber: 150 ticks x 0.86")
	assert_eq(Abilities.drone_period(w, w.ability_tables[drone]), 17, "drone: 20 x 0.86")
	assert_eq(Stats.cooldown(w, 150), 150, "the cooldowns stat (blink, skill, dash) is untouched")


# --- Ability mods -------------------------------------------------------------------------------------------
func test_ability_mods_are_offered_only_with_their_ability() -> void:
	var w := _world()
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	var pairs := {
		&"cluster_payload": AbilityTable.Kind.BOMB_LOBBER,
		&"overclocked_drone": AbilityTable.Kind.DRONE_BUDDY,
		&"razor_orbit": AbilityTable.Kind.ORBIT_BLADES,
		&"afterimage": AbilityTable.Kind.BLINK,
	}
	for id: StringName in pairs:
		assert_false(ItemPool.available(w).has(_item(w, id)), "%s: not before its ability" % id)
	for id: StringName in pairs:
		var v := _world()  # a fresh run each: four slots can't hold them all
		Heat.enable(v, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
		_grant(v, pairs[id])
		assert_true(ItemPool.available(v).has(_item(v, id)), "%s: once owned" % id)


func test_cluster_payload_splits_each_bomb_into_bomblets_that_never_split() -> void:
	var w := _world([Vector2(-6, 0), Vector2(-6.6, 0.5), Vector2(-6.4, -0.6)])
	_grant(w, AbilityTable.Kind.BOMB_LOBBER)
	w.add_item(_item(w, &"cluster_payload"))
	w.step(_f())
	for k in 4:  # v0.6.0 MX2: Bomb Lobber lobs on the fourth weapon attack
		ModifierAbilities.on_attack(w, w.player_pos())
	_run(w, 37)
	assert_eq(_damage(w, Abilities.EFFECT_BOMB).size(), 3, "the bomb lands on the three")
	assert_eq(w.ab.bomb_pos.size(), 3, "three bomblets in the air")
	assert_eq(w.ab.bomb_split, PackedInt32Array([0, 0, 0]), "bomblets never split")
	assert_almost_eq(w.ab.bomb_r[0], 1.0, 1e-5, "half the radius")
	assert_eq(w.ab.bomb_dmg[0], 8, "40 % of 22 (v0.6.0 MX4: a hook's share rounds down)")
	_run(w, 15)
	var bits := _damage(w, AbilityMods.EFFECT_CLUSTER)
	assert_gt(bits.size(), 0, "the bomblets landed on the cluster")
	for e in bits:
		assert_eq(e.amount, 8)
	assert_eq(w.ab.bomb_pos.size(), 0, "and nothing more")


func test_overclocked_drone_fires_faster_with_heat() -> void:
	var w := _world()
	Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	var d := _grant(w, AbilityTable.Kind.DRONE_BUDDY)
	var t := w.ability_tables[d]
	w.heat.milli = 50 * HeatTable.MILLI
	assert_eq(Abilities.drone_period(w, t), 20, "no mod: heat changes nothing")
	w.add_item(_item(w, &"overclocked_drone"))
	assert_eq(Abilities.drone_period(w, t), 14, "50 heat x 0.8 %: +40 % fire rate")
	w.heat.milli = 0
	assert_eq(Abilities.drone_period(w, t), 20, "cold: the base period")


func test_razor_orbit_makes_blade_touches_bleed() -> void:
	var plain := _world([Vector2(1.6, 0)])
	_grant(plain, AbilityTable.Kind.ORBIT_BLADES)
	_run(plain, 60)
	assert_eq(plain.actors.bleed_stacks[1], 0, "plain blades don't bleed")
	var w := _world([Vector2(1.6, 0)])
	_grant(w, AbilityTable.Kind.ORBIT_BLADES)
	w.add_item(_item(w, &"razor_orbit"))
	_run(w, 60)
	assert_eq(
		_damage(w, Abilities.EFFECT_ORBIT).size(), _damage(plain, Abilities.EFFECT_ORBIT).size()
	)
	assert_gt(w.actors.bleed_stacks[1], 0, "a bleed stack per touch")


func test_afterimage_bursts_where_the_blink_started() -> void:
	var w := _world([Vector2(0, 1.0)])
	_grant(w, AbilityTable.Kind.BLINK)
	w.add_item(_item(w, &"afterimage"))
	var start := w.player_pos()
	w.step(_f(U, Vector2i(SimTick.MOVE_MAX, 0)))
	assert_gt(w.player_pos().x, 3.0, "blinked away")
	assert_eq(w.ab.echo_pos, start, "the echo waits at the start")
	_run(w, 22)
	assert_eq(_damage(w, AbilityMods.EFFECT_AFTERIMAGE).size(), 0, "not yet (0.4 s)")
	_run(w, 2)
	var burst := _damage(w, AbilityMods.EFFECT_AFTERIMAGE)
	assert_eq(burst.size(), 1, "it burst on the dummy by the start")
	assert_eq(burst[0].amount, 18)
	assert_eq(w.ab.echo_at, -1, "and is spent")
	assert_eq(Abilities.fx(w)["echo_tick"], w.ab.echo_tick, "the view sees the burst")


func test_new_state_is_hashed_and_deterministic() -> void:
	var a := _world([Vector2(-5, 0)])
	var b := _world([Vector2(-5, 0)])
	for w in [a, b]:
		_grant(w, AbilityTable.Kind.BOMB_LOBBER)
		_grant(w, AbilityTable.Kind.BLINK)
		w.add_item(_item(w, &"cluster_payload"))
		w.add_item(_item(w, &"afterimage"))
		for k in Stats.COUNT:
			Stats.add_card(w, k, Stats.Rarity.RARE)
	for k in 120:
		var f := _f(U if k == 5 else 0, Vector2i(0, SimTick.MOVE_MAX) if k < 10 else Vector2i.ZERO)
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash())
	var before := a.state_hash()
	a.ab.echo_tick += 1
	assert_ne(a.state_hash(), before, "Afterimage's state is in the hash")
