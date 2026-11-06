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
	assert_eq(Stats.damage_permille(w), 1260, "v0.8.0 SG: one bucket, 1 + 0.08 + 0.18")
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
	# v0.10.5 O1: no auto ability ships any more; the stat's two readers are checked directly.
	var w := _world([Vector2(3, 0)])
	Stats.add_card(w, Stats.Stat.FAST_HANDS, Stats.Rarity.RARE)
	assert_eq(Stats.auto_cooldown(w, 150), 129, "150 ticks x 0.86")
	assert_eq(Stats.auto_period(w, 20), 17, "20 x 0.86")
	assert_eq(Stats.cooldown(w, 150), 150, "the cooldowns stat (blink, skill, dash) is untouched")
