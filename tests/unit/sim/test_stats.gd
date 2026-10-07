extends GutTest
## Stat cards and crit (v0.4.0 BS, owner F9) with the shipped data: multiplicative stacking in per mille, caps, each
## stat where the sim reads it, crit's rate and determinism on the `crit` stream, DoT never critting, and the gamble
## shrine paying into the same stats.

var _repo: ContentRepository


func before_all() -> void:
	_repo = ContentRepository.load_all()


func _world(crit: int = 0) -> World:
	var t := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, _repo.get_def(&"build", &"blade"))
	t.crit_chance_permille = crit
	var w := World.new(23, t)
	w.dummy_speed = 0.0
	w.ability_tables = ContentCompiler.compile_abilities(_repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(_repo)
	w.add_dummy(Vector2(2, 0), 0.35, 1000000)
	return w


func test_the_shipped_stat_cards() -> void:
	var tables := ContentCompiler.compile_stat_cards(_repo)
	assert_eq(tables.size(), Stats.COUNT)
	for s in Stats.COUNT:
		assert_not_null(tables[s], "stat %d has a card" % s)
	assert_eq(tables[Stats.Stat.DAMAGE].amounts, PackedInt32Array([80, 150, 250]), "+8/15/25 %")
	assert_eq(
		tables[Stats.Stat.CRIT_CHANCE].amounts, PackedInt32Array([40, 80, 120]), "+4/8/12 pts"
	)
	assert_eq(tables[Stats.Stat.CRIT_CHANCE].cap, 750, "75 %")
	assert_eq(tables[Stats.Stat.CRIT_DAMAGE].cap, 4000, "x4.0")
	assert_eq(tables[Stats.Stat.COOLDOWNS].cap, 400, "-60 %")
	assert_eq(tables[Stats.Stat.ATTACK_SPEED].cap, 2500)
	assert_eq(tables[Stats.Stat.MOVE].cap, 1600)
	assert_eq(tables[Stats.Stat.REGEN].amounts, PackedInt32Array([3, 6, 10]), "0.3/0.6/1.0 %/s")
	var p := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	assert_eq([p.crit_chance_permille, p.crit_mult_permille], [50, 1500], "base 5 %, x1.5")


func test_cards_stack_multiplicatively() -> void:
	var w := _world()
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1000)
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1166, "1.08 x 1.08 = 1.1664")
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.EPIC)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1458, "x 1.25")
	assert_eq(Stats.outgoing(w, 100, 0)[0], 146, "a 100 hit deals 146")


func test_caps_hold() -> void:
	var w := _world()
	for k in 40:
		Stats.add_card(w, Stats.Stat.COOLDOWNS, Stats.Rarity.EPIC)
		Stats.add_card(w, Stats.Stat.MOVE, Stats.Rarity.EPIC)
		Stats.add_card(w, Stats.Stat.CRIT_CHANCE, Stats.Rarity.EPIC)
		Stats.add_card(w, Stats.Stat.ARMOUR, Stats.Rarity.EPIC)
	assert_eq(Stats.value(w, Stats.Stat.COOLDOWNS), 400, "cooldowns never under 40 %")
	assert_eq(Stats.value(w, Stats.Stat.MOVE), 1600, "move speed at most x1.6")
	assert_eq(Stats.value(w, Stats.Stat.ARMOUR), 400, "armour at most -60 %")
	assert_eq(Stats.crit_chance(w), 750, "crit chance at most 75 %")
	for s in [Stats.Stat.COOLDOWNS, Stats.Stat.MOVE, Stats.Stat.CRIT_CHANCE, Stats.Stat.ARMOUR]:
		assert_true(Stats.at_cap(w, s), "stat %d is capped, so offers skip it" % s)
	assert_false(Stats.at_cap(w, Stats.Stat.DAMAGE), "damage has no cap")


func test_each_stat_reaches_its_hook() -> void:
	var w := _world()
	var dash := ItemProcs.dash_cooldown_ticks(w)
	var speed := ItemProcs.move_speed(w)
	var reach := ItemEffects.swing_reach_m(w, 0)
	Stats.add_card(w, Stats.Stat.COOLDOWNS, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.MOVE, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.AREA, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.SHARDS, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.PICKUP, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	assert_eq(ItemProcs.dash_cooldown_ticks(w), (dash * 910 + 500) / 1000, "-9 % dash cooldown")
	assert_almost_eq(ItemProcs.move_speed(w), speed * 1.07, 1e-6, "+7 % move speed")
	assert_almost_eq(ItemEffects.swing_reach_m(w, 0), reach * 1.15, 1e-5, "+15 % area on the swing")
	assert_eq(Stats.shards(w, 10), 12, "+20 % shards")
	assert_almost_eq(Stats.reach(w, 1.6), 1.6 * 1.3, 1e-5, "+30 % pickup range")
	assert_eq(Stats.period(w, 118), 100, "x1.18 attack speed: 118 ticks -> 100")
	var step: SwingStep = w.player.combo[0]
	assert_lt(Stats.swing_end(w, step), step.ticks, "a swing recovers faster")
	assert_eq(Stats.swing_end(w, step) >= step.active_tick, true, "its hit tick doesn't move")


func test_max_hp_heals_by_the_gain_and_armour_cuts_hits_taken() -> void:
	var w := _world()
	w.actors.hp[0] = 50
	Stats.add_card(w, Stats.Stat.MAX_HP, Stats.Rarity.EPIC)
	assert_eq(w.actors.max_hp[0], 125, "+25 % max HP")
	assert_eq(w.actors.hp[0], 75, "and healed by the 25 gained")
	Stats.add_card(w, Stats.Stat.ARMOUR, Stats.Rarity.EPIC)
	assert_eq(
		Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO), 45, "-10 % damage taken"
	)


func test_regen_heals_in_combat() -> void:
	var w := _world()
	w.actors.hp[0] = 50
	Stats.add_card(w, Stats.Stat.REGEN, Stats.Rarity.EPIC)
	for k in 60:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	assert_eq(w.actors.hp[0], 51, "1 % of 100 HP in one second")


# --- Crit -------------------------------------------------------------------------------------------------
func test_crit_rate_over_many_hits() -> void:
	var w := _world(50)
	var crits := 0
	var n := 4000
	for k in n:
		var out := Stats.outgoing(w, 100, 0)
		if out[1] & SimEvent.TAG_CRIT:
			crits += 1
			assert_eq(out[0], 150, "a crit deals x1.5")
		else:
			assert_eq(out[0], 100)
	assert_between(crits, 160, 240, "about 5 percent of %d hits (%d)" % [n, crits])
	Stats.add_card(w, Stats.Stat.CRIT_DAMAGE, Stats.Rarity.EPIC)
	assert_eq(Stats.crit_mult(w), 2000, "+50 pts: x2.0")


func test_crit_is_deterministic_and_on_its_own_stream() -> void:
	var a := _world(300)
	var b := _world(300)
	var loot := a.rng_loot.state
	var seq_a := []
	var seq_b := []
	for k in 200:
		seq_a.append(Stats.outgoing(a, 10, 0)[1])
		seq_b.append(Stats.outgoing(b, 10, 0)[1])
	assert_eq(seq_a, seq_b, "the same seed rolls the same crits")
	assert_eq(a.rng_loot.state, loot, "the other streams don't move")
	var c := _world(0)
	var crit := c.rng_crit.state
	Stats.outgoing(c, 10, 0)
	assert_eq(c.rng_crit.state, crit, "no chance: no roll")


func test_dot_never_crits_and_hits_are_tagged() -> void:
	var w := _world(1000)
	assert_eq(Stats.crit_chance(w), 750, "even a 100 % base is held to the 75 % cap")
	var out := Stats.outgoing(w, 10, SimEvent.TAG_DOT)
	assert_eq(out, [10, 0], "a DoT tick never crits")
	var pid := w.actors.ids[0]
	for k in 20:
		Damage.hit(w, 1, 10, pid, pid, k + 1, SimEvent.TAG_MELEE, Vector2.ZERO, Vector2(2, 0))
	var crits := 0
	for e in w.events_since(0):
		if e.kind != SimEvent.Kind.DAMAGE:
			continue
		var crit := (e.tags & SimEvent.TAG_CRIT) != 0
		assert_eq(e.amount, 15 if crit else 10, "a crit's DAMAGE carries TAG_CRIT and x1.5")
		crits += 1 if crit else 0
	assert_gt(crits, 0, "some of 20 hits at 75 % crit")


# --- Gamble shrine ----------------------------------------------------------------------------------------
func test_gamble_pays_into_the_same_stats() -> void:
	var w := _world()
	w.gamble_table = ContentCompiler.compile_gamble(_repo.get_def(&"gamble", &"shrine"))
	var melee := w.gamble_table.amount[GambleTable.Stat.MELEE]
	Gamble.grant(w, GambleTable.Stat.MELEE)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1000 + melee, "a melee win raises the damage stat")
	assert_eq(Gamble.melee_damage(w, 100), 100, "and its old hook adds nothing more")
	Gamble.grant(w, GambleTable.Stat.HEAT)
	assert_eq(Gamble.heat_capacity_bonus_permille(w), w.gamble_table.amount[GambleTable.Stat.HEAT])
	var hp := w.actors.max_hp[0]
	Gamble.grant(w, GambleTable.Stat.MAX_HP)
	assert_eq(
		w.actors.max_hp[0], hp + w.gamble_table.amount[GambleTable.Stat.MAX_HP], "+8 HP as before"
	)
