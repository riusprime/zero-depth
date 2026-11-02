extends GutTest
## v0.10.5 O9 (theory audit P2; docs/roadmap/v0.10.5/O9_RULE_CARDS.md): the seven rule stat cards that replace the
## flat stats, one test each of the trigger, the condition, the payoff and its cap or window, with the shipped data.
## Crit is off (crit_chance_permille = 0) so numbers are exact. Also: the flat cards they replace are retired (weight 0,
## never offered) but still apply when a save holds them.

const KIND := ActorStore.Kind
const RETIRED: Array[StringName] = [
	&"crit_damage",
	&"area",
	&"cooldowns",
	&"move_speed",
	&"regen",
	&"armour",
	&"pickup_range",
	&"shard_gain",
]
const RULES: Array[StringName] = [
	&"vent_mend",
	&"heat_shield",
	&"adrenaline",
	&"close_quarters",
	&"third_strike",
	&"reflex",
	&"scavenger",
]

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(heat := false) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	t.crit_chance_permille = 0
	var w := World.new(31, t)
	w.dummy_speed = 0.0
	w.dummy_fire_period = 100000
	w.set_item_tables(ContentCompiler.compile_items(_repo))
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	if heat:
		Heat.enable(w, ContentCompiler.compile_heat(_repo.get_def(&"heat", &"overclock")))
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	return w


## The player's melee hit of `amount` on dummy `id` in root `root`; returns the HP it removed.
func _hit(w: World, id: int, amount: int, root: int, tags := SimEvent.TAG_MELEE) -> int:
	var pid := w.actors.ids[0]
	var i := w.actors.index_of(id)
	return Damage.hit(w, i, amount, pid, pid, root, tags, Vector2.ZERO, w.actors.pos(i))


## An enemy's hit of `amount` on the player; returns the HP it removed (the hurt iframes cleared first).
func _hurt(w: World, from_id: int, amount: int) -> int:
	w.actors.invuln[0] = 0
	return Damage.hit(
		w, 0, amount, from_id, from_id, w.take_root(), 0, Vector2(1, 0), w.player_pos()
	)


func _set_heat(w: World, points: int) -> void:
	w.heat.milli = points * HeatTable.MILLI


func test_the_flat_cards_are_retired_and_the_rule_cards_offered() -> void:
	var w := _world(true)
	for id in RETIRED:
		var s := StatCardDefinition.STATS.find(id)
		assert_eq(w.stat_tables[s].weight, 0, "%s: retired (weight 0)" % id)
	for id in RULES:
		var s := StatCardDefinition.STATS.find(id)
		assert_gt(w.stat_tables[s].weight, 0, "%s: offered" % id)
		assert_false(Stats.at_cap(w, s), "%s: offerable with heat" % id)
	var leg: LegendaryDefinition = _repo.get_def(&"legendary", &"boss")
	for id in RETIRED:
		assert_false(leg.stat_cards.has(id), "%s: not the boss tier's either" % id)
	var cool := _world(false)
	assert_true(Stats.at_cap(cool, Stats.Stat.VENT_MEND), "no heat: no Vent to mend on")
	assert_true(Stats.at_cap(cool, Stats.Stat.HEAT_SHIELD), "no heat: never Hot")


func test_a_retired_card_a_save_holds_still_applies() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.ARMOUR, Stats.Rarity.COMMON)
	assert_eq(Stats.armour_permille(w), 960, "-4 % damage taken, as before O9")
	Stats.add_card(w, Stats.Stat.AREA, Stats.Rarity.COMMON)
	assert_almost_eq(Stats.area(w, 1.0), 1.08, 0.0001)


func test_a_world_without_an_o9_card_keeps_its_value_array() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	assert_eq(w.stat_values.size(), Stats.LEGACY_COUNT, "the pre-O9 size, so its hash is as before")
	Stats.add_card(w, Stats.Stat.SCAVENGER, Stats.Rarity.COMMON)
	assert_eq(w.stat_values.size(), Stats.COUNT)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1080, "the old values carried over")


func test_close_quarters_adds_damage_within_two_metres_only() -> void:
	var w := _world()
	var near := w.add_dummy(Vector2(2.2, 0), 0.35, 100000)  # edge at 1.85 m
	var far := w.add_dummy(Vector2(5, 0), 0.35, 100000)
	assert_eq(_hit(w, near, 100, w.take_root()), 100, "no card: nothing")
	Stats.add_card(w, Stats.Stat.CLOSE_QUARTERS, Stats.Rarity.COMMON)
	assert_eq(_hit(w, near, 100, w.take_root()), 115, "within 2 m: +15 %")
	assert_eq(_hit(w, far, 100, w.take_root()), 100, "5 m away: nothing")
	for k in 10:
		Stats.add_card(w, Stats.Stat.CLOSE_QUARTERS, Stats.Rarity.EPIC)
	assert_eq(_hit(w, near, 100, w.take_root()), 180, "capped at +80 %")
	assert_true(Stats.at_cap(w, Stats.Stat.CLOSE_QUARTERS), "offers stop")
	var i := w.actors.index_of(near)
	var before := w.actors.hp[i]
	Damage.tick_dot(w, i, 10, w.actors.ids[0], w.actors.ids[0], &"bleed")
	assert_eq(before - w.actors.hp[i], 10, "a DoT tick never gets it")


func test_third_strike_hits_harder_on_the_third_attack_in_a_row() -> void:
	var w := _world()
	var d := w.add_dummy(Vector2(2.5, 0), 0.35, 100000)
	Stats.add_card(w, Stats.Stat.THIRD_STRIKE, Stats.Rarity.COMMON)
	assert_eq(_hit(w, d, 100, w.take_root()), 100, "first")
	var r2 := w.take_root()
	assert_eq(_hit(w, d, 100, r2), 100, "second")
	assert_eq(_hit(w, d, 100, r2), 100, "the same attack's second hit counts once")
	var r3 := w.take_root()
	assert_eq(_hit(w, d, 100, r3), 130, "third in a row: +30 %")
	assert_eq(_hit(w, d, 100, r3), 130, "every hit of that attack")
	assert_eq(_hit(w, d, 100, w.take_root()), 100, "the row starts over")
	var chain := SimEvent.TAG_MELEE | SimEvent.TAG_CHAIN
	assert_eq(_hit(w, d, 100, w.take_root(), chain), 100, "a chain jump isn't an attack")
	assert_eq(_hit(w, d, 100, w.take_root()), 100, "second (the chain didn't count)")
	for k in RuleCards.STRIKE_WINDOW_TICKS + 1:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	assert_eq(_hit(w, d, 100, w.take_root()), 100, "after a pause past 1 s: first again")
	assert_eq(_hit(w, d, 100, w.take_root()), 100)
	assert_eq(_hit(w, d, 100, w.take_root()), 130)
	for k in 10:
		Stats.add_card(w, Stats.Stat.THIRD_STRIKE, Stats.Rarity.EPIC)
	_hit(w, d, 100, w.take_root())
	_hit(w, d, 100, w.take_root())
	assert_eq(_hit(w, d, 100, w.take_root()), 250, "capped at +150 %")


func test_reflex_cuts_the_dash_cooldown_once_per_attack_on_a_kill() -> void:
	var w := _world()
	var full := ItemProcs.dash_cooldown_ticks(w)
	var a := w.add_dummy(Vector2(2, 0), 0.35, 10)
	var b := w.add_dummy(Vector2(2, 1), 0.35, 10)
	var c := w.add_dummy(Vector2(2, -1), 0.35, 10)
	Stats.add_card(w, Stats.Stat.REFLEX, Stats.Rarity.COMMON)
	w.dash_cooldown_left = full
	var root := w.take_root()
	_hit(w, a, 50, root)
	var cut := (full * 100 + 500) / 1000
	assert_eq(
		w.dash_cooldown_left, full - cut, "a kill while recharging: -10 % of the full cooldown"
	)
	_hit(w, b, 50, root)
	assert_eq(w.dash_cooldown_left, full - cut, "the same attack's second kill: nothing more")
	_hit(w, c, 50, w.take_root())
	assert_eq(w.dash_cooldown_left, full - 2 * cut, "a new attack's kill cuts again")
	w.dash_cooldown_left = 0
	var e := w.add_dummy(Vector2(3, 0), 0.35, 10)
	_hit(w, e, 50, w.take_root())
	assert_eq(w.dash_cooldown_left, 0, "dash ready: nothing to cut")


func test_adrenaline_gives_a_short_burst_after_a_close_kill() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.ADRENALINE, Stats.Rarity.COMMON)
	var far := w.add_dummy(Vector2(6, 0), 0.35, 10)
	_hit(w, far, 50, w.take_root())
	assert_eq(Stats.move_permille(w), 1000, "a kill 6 m away: nothing")
	var near := w.add_dummy(Vector2(2, 0), 0.35, 10)
	_hit(w, near, 50, w.take_root())
	assert_eq(Stats.move_permille(w), 1150, "a kill within 3 m: +15 %")
	var again := w.add_dummy(Vector2(2, 1), 0.35, 10)
	_hit(w, again, 50, w.take_root())
	assert_eq(Stats.move_permille(w), 1150, "a second kill refreshes, never stacks")
	for k in RuleCards.RUSH_TICKS:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	assert_eq(Stats.move_permille(w), 1000, "1.5 s later: over")


func test_vent_mend_heals_once_a_vent_that_hits_an_enemy() -> void:
	var w := _world(true)
	Stats.add_card(w, Stats.Stat.VENT_MEND, Stats.Rarity.COMMON)
	var a := w.actors
	a.hp[0] = 50
	_set_heat(w, 60)
	assert_true(Heat.vent(w), "vents with no enemy near")
	assert_eq(a.hp[0], 50, "nothing in the blast: no heal")
	w.add_dummy(Vector2(1, 0), 0.35, 100000)
	w.kit.vent_cd = 0
	_set_heat(w, 60)
	assert_true(Heat.vent(w))
	assert_eq(a.hp[0], 52, "an enemy in the blast: 2 % of 100 max HP")
	_set_heat(w, 60)
	assert_false(Heat.vent(w), "the Vent's cooldown is the heal's window")
	assert_eq(a.hp[0], 52)
	for k in 10:
		Stats.add_card(w, Stats.Stat.VENT_MEND, Stats.Rarity.EPIC)
	w.kit.vent_cd = 0
	_set_heat(w, 60)
	Heat.vent(w)
	assert_eq(a.hp[0], 62, "capped at 10 % a Vent")


func test_heat_shield_cuts_hits_taken_while_hot() -> void:
	var w := _world(true)
	var foe := w.add_dummy(Vector2(1, 0), 0.35, 100000)
	Stats.add_card(w, Stats.Stat.HEAT_SHIELD, Stats.Rarity.COMMON)
	w.actors.hp[0] = 10000
	w.actors.max_hp[0] = 10000
	var held := PlayerBuild.taken_permille(w)  # the Blade's own cut, before the card's
	assert_eq(_hurt(w, foe, 1000), held, "cool: no cut from the card")
	_set_heat(w, 50)
	assert_eq(Heat.tier_of(w), Heat.TIER_HOT)
	var hot := held * 850 / 1000
	assert_eq(_hurt(w, foe, 1000), hot, "Hot: -15 %")
	w.heat.stall = 10
	assert_eq(_hurt(w, foe, 1000), hot, "overheated counts as hot")
	w.heat.stall = 0
	for k in 10:
		Stats.add_card(w, Stats.Stat.HEAT_SHIELD, Stats.Rarity.EPIC)
	assert_eq(_hurt(w, foe, 1000), held * 500 / 1000, "never under half")
	assert_true(Stats.at_cap(w, Stats.Stat.HEAT_SHIELD), "offers stop")


func test_scavenger_pays_more_shards_for_a_crit_kill() -> void:
	var w := RunLab.new(_repo, 78, &"blade").floor_world()
	var id := w.add_enemy(KIND.CHARGER, w.player_pos() + Vector2(2, 0))
	var i := w.actors.index_of(id)
	var base := Rewards.shards_for_kill(w, KIND.CHARGER)
	assert_gt(base, 0, "a Charger pays shards")
	var before := w.shards
	RuleCards.on_kill(w, i, SimEvent.TAG_CRIT, w.take_root())
	assert_eq(w.shards, before, "no card: nothing")
	Stats.add_card(w, Stats.Stat.SCAVENGER, Stats.Rarity.EPIC)
	RuleCards.on_kill(w, i, SimEvent.TAG_MELEE, w.take_root())
	assert_eq(w.shards, before, "not a crit: nothing")
	RuleCards.on_kill(w, i, SimEvent.TAG_MELEE | SimEvent.TAG_CRIT, w.take_root())
	var want := Affinities.shards(w, Stats.shards(w, (base * 800 + 500) / 1000))
	assert_eq(w.shards, before + want, "a crit kill: +80 % of its shards")
