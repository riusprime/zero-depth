extends GutTest
## Stat cards and crit (v0.4.0 BS, owner F9) with the shipped data: stacking in per mille (v0.8.0 SG: damage, attack
## speed and Glass Cannon add, the other multipliers compound), caps, each
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
	# v0.9.0 LG (owner C73, Q12): the legendary is the epic x data/legendary/boss.tres' multiplier for the card (Power
	# x1.3: +32.5 %), read from the data
	var leg: LegendaryDefinition = _repo.get_def(&"legendary", &"boss")
	var power := (250 * int(round(leg.multiplier_of(&"damage") * 1000.0)) + 500) / 1000
	assert_eq(
		tables[Stats.Stat.DAMAGE].amounts,
		PackedInt32Array([80, 150, 250, power]),
		"+8/15/25 % (legendary: the epic x the data's multiplier)"
	)
	assert_eq(
		tables[Stats.Stat.CRIT_CHANCE].amounts,
		PackedInt32Array([30, 50, 80, 128]),
		"+3/5/8 pts (v0.8.0 SG)"
	)
	assert_eq(
		tables[Stats.Stat.CRIT_DAMAGE].amounts,
		PackedInt32Array([100, 200, 350, 560]),
		"+10/20/35 pts (v0.8.0 SG)"
	)
	assert_eq(
		[tables[Stats.Stat.CRIT_CHANCE].weight, tables[Stats.Stat.CRIT_DAMAGE].weight],
		[8, 7],
		"crit weights 8 and 7 (v0.8.0 SG)"
	)
	for s in Stats.COUNT:
		assert_eq(
			tables[s].additive,
			Stats.ADDITIVE_STATS.has(s),
			"v0.8.0 SG: only damage, attack speed and Glass Cannon add (stat %d)" % s
		)
	assert_eq(tables[Stats.Stat.CRIT_CHANCE].cap, 750, "75 %")
	assert_eq(tables[Stats.Stat.CRIT_DAMAGE].cap, 4000, "x4.0")
	assert_eq(tables[Stats.Stat.COOLDOWNS].cap, 400, "-60 %")
	assert_eq(tables[Stats.Stat.ATTACK_SPEED].cap, 2500)
	assert_eq(tables[Stats.Stat.MOVE].cap, 1600)
	assert_eq(tables[Stats.Stat.REGEN].amounts, PackedInt32Array([3, 6, 10, 16]), "0.3/0.6/1.0 %/s")
	var p := ContentCompiler.compile_player(_repo.get_def(&"player", &"runner"))
	assert_eq([p.crit_chance_permille, p.crit_mult_permille], [50, 1500], "base 5 %, x1.5")


## v0.8.0 SG (owner O91): damage cards add (+8 + 8 + 25 = +41 %); a multiplier stat without the flag still compounds.
func test_damage_cards_add_and_other_multipliers_compound() -> void:
	var w := _world()
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1000)
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1160, "1 + 0.08 + 0.08")
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.EPIC)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1410, "+ 0.25")
	assert_eq(Stats.outgoing(w, 100, 0)[0], 141, "a 100 hit deals 141")
	Stats.add_card(w, Stats.Stat.AREA, Stats.Rarity.COMMON)
	Stats.add_card(w, Stats.Stat.AREA, Stats.Rarity.COMMON)
	assert_eq(Stats.value(w, Stats.Stat.AREA), 1166, "area still compounds: 1.08 x 1.08 (D64)")
	Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE)
	assert_eq(Stats.value(w, Stats.Stat.ATTACK_SPEED), 1240, "attack speed adds: +12 + 12 %")
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.COMMON)
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.EPIC)
	assert_eq(Stats.value(w, Stats.Stat.GLASS_CANNON), 1550, "Glass Cannon's cards add: +15 + 40 %")


## v0.8.0 SG: the bucket: damage + Onrush (while moving) + Hoarder add, then x Glass Cannon; a curse stays a
## multiplier on top (Stats.outgoing).
func test_damage_bucket_adds_onrush_and_hoarder_then_glass_cannon() -> void:
	var w := _world()
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.EPIC)  # +25 %
	Stats.add_card(w, Stats.Stat.ONRUSH, Stats.Rarity.COMMON)  # +10 % while moving
	Stats.add_card(w, Stats.Stat.HOARDER, Stats.Rarity.COMMON)  # +4 % per 100 shards
	w.shards = 250
	assert_eq(Stats.damage_bucket(w, false), 1330, "1 + 0.25 + 2 x 0.04")
	assert_eq(Stats.damage_bucket(w, true), 1430, "+ 0.10 Onrush while moving")
	assert_eq(Stats.damage_permille(w), 1330, "standing still")
	w.move_intent = Vector2i(1, 0)
	assert_eq(Stats.damage_permille(w), 1430, "moving: one sum, not 1.25 x 1.18")
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.COMMON)  # x1.15
	assert_eq(
		Stats.damage_permille(w), (1430 * 1150 + 500) / 1000, "Glass Cannon multiplies the bucket"
	)


## v0.8.0 SG: the gamble shrine's damage wins add into the same stat.
func test_gamble_damage_wins_add() -> void:
	var w := _world()
	Stats.add_amount(w, Stats.Stat.DAMAGE, 60)
	Stats.add_amount(w, Stats.Stat.DAMAGE, 60)
	Stats.add_card(w, Stats.Stat.DAMAGE, Stats.Rarity.COMMON)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1200, "1 + 0.06 + 0.06 + 0.08")


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
	var now := PlayerKit.current_step(w)
	assert_eq(
		now.ticks, AttackRate.scaled(step.ticks, 1180), "v0.8.0 SG: the whole swing at one rate"
	)
	assert_eq(
		now.active_tick, maxi(1, AttackRate.scaled(step.active_tick, 1180)), "its hit tick too"
	)


func test_max_hp_heals_by_the_gain_and_armour_cuts_hits_taken() -> void:
	var w := _world()
	w.actors.hp[0] = 50
	Stats.add_card(w, Stats.Stat.MAX_HP, Stats.Rarity.EPIC)
	assert_eq(w.actors.max_hp[0], 125, "+25 % max HP")
	assert_eq(w.actors.hp[0], 75, "and healed by the 25 gained")
	Stats.add_card(w, Stats.Stat.ARMOUR, Stats.Rarity.EPIC)
	assert_eq(
		Damage.hit(w, 0, 50, 9, 9, 9, 0, Vector2(3, 0), Vector2.ZERO),
		34,
		"-10 % damage taken, times the Blade's -25 % (v0.8.0 N1, D39): 50 x 0.675 = 33.75"
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
	assert_eq(Stats.crit_mult(w), 1850, "+35 pts (v0.8.0 SG): x1.85")


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
