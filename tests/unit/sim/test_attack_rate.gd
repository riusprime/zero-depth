extends GutTest
## v0.8.0 SG (owner O91): one attack-speed rule. The raw bonus (the stat's sum plus the attack's wand rate bonus)
## goes through AttackRate.curve (full to +50 %, half to +150 %, a quarter above; a negative bonus in full); the
## Gun's period, the Blade's whole swing and the drone's period read the one rate; the cards' forecast and the
## hidden catch-up read the same function; an older save rebuilds damage, attack speed and Glass Cannon additively.

const W := preload("res://tests/support/mx4_world.gd")


func _cards(w: World, s: int, rarity: int, n: int) -> void:
	for k in n:
		Stats.add_card(w, s, rarity)


func test_the_curve_has_two_knees_and_counts_a_cut_in_full() -> void:
	var t := SimTuning.new()
	assert_eq(AttackRate.curve(t, 0), 0)
	assert_eq(AttackRate.curve(t, 300), 300, "in full below the knee")
	assert_eq(AttackRate.curve(t, 500), 500, "the knee")
	assert_eq(AttackRate.curve(t, 600), 550, "half past it")
	assert_eq(AttackRate.curve(t, 1000), 750, "raw +100 % -> +75 %")
	assert_eq(AttackRate.curve(t, 1500), 1000, "knee2")
	assert_eq(AttackRate.curve(t, 2000), 1125, "raw +200 % -> +112.5 %")
	assert_eq(AttackRate.curve(t, -300), -300, "a negative bonus counts in full")
	t.attack_speed_knee_permille = 200
	t.attack_speed_slope_permille = 1000
	assert_eq(AttackRate.curve(t, 600), 600, "the curve reads its tuning")


func test_the_shipped_tuning_holds_the_curve() -> void:
	var def: SimTuningDefinition = W.repo().get_def(&"tuning", &"sim")
	var t := RunContentCompiler.compile_sim_tuning(def)
	assert_eq(
		[
			t.attack_speed_knee_permille,
			t.attack_speed_knee2_permille,
			t.attack_speed_slope_permille,
			t.attack_speed_slope2_permille
		],
		[500, 1500, 500, 250]
	)
	assert_eq(def.validate(), [])
	var bad := def.duplicate(true) as SimTuningDefinition
	bad.attack_speed_knee2_permille = 100
	bad.attack_speed_slope2_permille = 1200
	assert_eq(bad.validate().size(), 2, "knee2 under the knee, a slope over 1000")


func test_gun_period_adds_the_stat_and_the_wand_bonus_before_the_curve() -> void:
	var w := W.world(&"gun", [&"gun_rapid_fire"])
	var base := Modifiers.bolt(w).period_ticks
	assert_eq(Modifiers.bolt(w).rate_bonus_permille, 600)
	assert_eq(AttackRate.rate(w, 600), 1550, "+60 % -> +55 %")
	assert_eq(ItemEffects.shot_period_ticks(w), AttackRate.scaled(base, 1550))
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 4)  # +72 %
	assert_eq(AttackRate.stat_bonus(w), 720)
	var r := 1000 + 500 + (1320 - 500) * 500 / 1000  # raw +132 % -> +91 %
	assert_eq(AttackRate.rate(w, 600), r)
	assert_eq(
		ItemEffects.shot_period_ticks(w), AttackRate.scaled(base, r), "one rate, not 1.6 x 1.72"
	)
	assert_eq(
		WorldReader.new(w).shot_period_ticks(), ItemEffects.shot_period_ticks(w), "the HUD reads it"
	)


func test_a_negative_wand_bonus_slows_the_gun() -> void:
	var w := W.world(&"gun")
	var base := Modifiers.bolt(w).period_ticks
	assert_eq(ItemEffects.shot_period_ticks(w), base)
	Modifiers.bolt(w).rate_bonus_permille = -300  # a slowing card on the bolt (the compiled spec)
	assert_eq(ItemEffects.shot_period_ticks(w), AttackRate.scaled(base, 700), "it counts now")
	assert_gt(ItemEffects.shot_period_ticks(w), base)


func test_the_blade_swings_at_one_rate() -> void:
	var plain := W.world(&"blade")
	var w := W.world(&"blade", [&"flurry"])
	var bonus := Modifiers.step(w, 0).rate_bonus_permille
	assert_gt(bonus, 0, "Flurry speeds the swing")
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE, 2)  # +24 %
	var r := 1000 + AttackRate.curve(w.tuning, 240 + bonus)
	assert_eq(AttackRate.rate(w, bonus), r)
	var base: SwingStep = w.player.combo[0]
	var s := BladeForms.step(w, 0)
	assert_eq(s.active_tick, maxi(1, AttackRate.scaled(base.active_tick, r)), "the hit tick")
	assert_eq(
		s.ticks, maxi(s.active_tick + 1, AttackRate.scaled(base.ticks, r)), "and the recovery"
	)
	assert_eq(s.sweep_ticks, maxi(1, AttackRate.scaled(base.sweep_ticks, r)), "and the sweep")
	# The stat alone (no card) scales the whole swing too, where it used to touch the recovery only.
	_cards(plain, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 1)
	var p := BladeForms.step(plain, 0)
	assert_eq(p.ticks, maxi(p.active_tick + 1, AttackRate.scaled(base.ticks, 1180)))
	assert_eq(p.active_tick, maxi(1, AttackRate.scaled(base.active_tick, 1180)))
	# The swing ends on that tick (PlayerKit).
	plain.step(W.frame(InputFrame.PRIMARY))
	var n := 1
	while plain.swing_t > 0 and n < 200:
		plain.step(W.frame())
		n += 1
	assert_eq(n, p.ticks + 1, "the swing lasts its scaled ticks")


func test_heavy_slows_the_swing_and_the_stat_cannot_bypass_the_curve() -> void:
	var w := W.world(&"blade", [&"heavy"])
	var bonus := Modifiers.step(w, 0).rate_bonus_permille
	assert_lt(bonus, 0)
	assert_eq(AttackRate.rate(w, bonus), 1000 + bonus, "a cut counts in full")
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 20)
	assert_eq(Stats.value(w, Stats.Stat.ATTACK_SPEED), 2500, "the stat's cap holds")
	assert_eq(AttackRate.rate(w, 0), 2000, "raw +150 % -> +100 %")


func test_the_drone_reads_the_curve_with_the_stat_alone() -> void:
	var w := W.world(&"gun")
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 20)
	assert_eq(Stats.period(w, 100), 50, "x2.0 at the stat's cap, not x2.5")
	assert_eq(Stats.auto_period(w, 100), 50)


func test_crit_pickups_come_down() -> void:
	var w := W.world(&"gun")
	var c := Stats.crit_chance(w)
	Stats.add_card(w, Stats.Stat.CRIT_CHANCE, Stats.Rarity.COMMON)
	assert_eq(Stats.crit_chance(w), c + 30, "+3 points")
	var k := Stats.crit_mult(w)
	Stats.add_card(w, Stats.Stat.CRIT_DAMAGE, Stats.Rarity.RARE)
	assert_eq(Stats.crit_mult(w), k + 200, "+20 points")


# --- Cards show the real gain --------------------------------------------------------------------------------
func test_a_damage_card_forecasts_the_bucket() -> void:
	var w := W.world(&"gun")
	_cards(w, Stats.Stat.DAMAGE, Stats.Rarity.RARE, 3)  # +45 %
	Stats.add_card(w, Stats.Stat.ONRUSH, Stats.Rarity.COMMON)
	w.move_intent = Vector2i(1, 0)
	var f := CardForecast.of(w, Offers.stat_code(Stats.Stat.DAMAGE, Stats.Rarity.RARE))
	assert_eq(
		[f["old"], f["new"]], [1450, 1600], "+45 % -> +60 %: the bucket without Onrush's movement"
	)
	assert_eq(Offers.info(w, Offers.stat_code(Stats.Stat.DAMAGE, Stats.Rarity.RARE))["amount"], 150)


func test_an_attack_speed_card_forecasts_the_rate_after_the_curve() -> void:
	var w := W.world(&"gun", [&"gun_rapid_fire"])
	var code := Offers.stat_code(Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC)
	var f := CardForecast.of(w, code)
	assert_eq(f["old"], 1550, "Rapid Fire's +60 % after the curve")
	assert_eq(f["new"], 1000 + 500 + (780 - 500) * 500 / 1000, "+18 % more raw: +14 %")
	assert_eq(int(f["new"]), AttackRate.rate_at(w, 1180, 600), "the take's own function")
	assert_eq(Offers.info(w, code)["amount"], 90, "the sentence names the real +9 %")
	var plain := W.world(&"gun")
	assert_eq(Offers.info(plain, code)["amount"], 180, "under the knee the card's +18 % is real")
	assert_eq(WorldReader.new(w).card_forecast(code), f, "the reader forecasts the same")
	Offers.apply(w, code)
	assert_eq(AttackRate.weapon_rate(w), int(f["new"]), "the take gives what the card said")
	assert_eq(
		ItemEffects.shot_period_ticks(w),
		AttackRate.scaled(Modifiers.bolt(w).period_ticks, f["new"])
	)


# --- Old saves -------------------------------------------------------------------------------------------------
func test_an_older_world_rebuilds_damage_attack_speed_and_glass_cannon() -> void:
	var w := W.world(&"gun")
	w.gamble_table = ContentCompiler.compile_gamble(W.repo().get_def(&"gamble", &"shrine"))
	_cards(w, Stats.Stat.DAMAGE, Stats.Rarity.EPIC, 2)
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.RARE, 2)
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.GLASS_CANNON, Stats.Rarity.RARE)
	Stats.add_card(w, Stats.Stat.AREA, Stats.Rarity.RARE)
	Gamble.grant(w, GambleTable.Stat.MELEE)
	var melee := Gamble.gamble_permille(w, GambleTable.Stat.MELEE)
	var hp := Stats.value(w, Stats.Stat.MAX_HP)
	var area := Stats.value(w, Stats.Stat.AREA)
	# As a save from before SG holds them: compounded.
	w.stat_values[Stats.Stat.DAMAGE] = 1600
	w.stat_values[Stats.Stat.ATTACK_SPEED] = 1254
	w.stat_values[Stats.Stat.GLASS_CANNON] = 1563
	w.stat_values[Stats.Stat.MAX_HP] = hp - 50  # an event's cut: not recorded, kept
	w.stat_rules = 0
	Stats.migrate_rules(w)
	assert_eq(w.stat_rules, Stats.RULES)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1500 + melee, "two +25 % and the shrine's win add")
	assert_eq(Stats.value(w, Stats.Stat.ATTACK_SPEED), 1240)
	assert_eq(Stats.value(w, Stats.Stat.GLASS_CANNON), 1500)
	assert_eq(
		Stats.value(w, Stats.Stat.MAX_HP), hp - 50, "the other stats keep their stored values"
	)
	assert_eq(Stats.value(w, Stats.Stat.AREA), area)
	Stats.migrate_rules(w)
	assert_eq(Stats.value(w, Stats.Stat.DAMAGE), 1500 + melee, "once only")


func test_a_snapshot_without_stat_rules_rebuilds_on_apply() -> void:
	var w := SaveLab.floor_world(31, 1)
	_cards(w, Stats.Stat.DAMAGE, Stats.Rarity.EPIC, 2)
	var snap := WorldSnapshot.take(w)
	var data: Dictionary = snap["world"]
	assert_true(data.has(&"stat_rules"), "a new save holds its rules")
	data.erase(&"stat_rules")
	var vals: PackedInt32Array = data[&"stat_values"]
	vals[Stats.Stat.DAMAGE] = 1563  # compounded, as before SG
	data[&"stat_values"] = vals
	var base := SaveLab.floor_world(31, 1)
	assert_eq(WorldSnapshot.apply(base, snap), "")
	assert_eq(Stats.value(base, Stats.Stat.DAMAGE), 1500, "rebuilt from the stat cards")
	assert_eq(base.stat_rules, Stats.RULES)


func test_a_carry_without_stat_rules_rebuilds_at_floor_start() -> void:
	var w := W.world(&"gun")
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 3)
	var carry := RunCarry.take(w, 0)
	carry.erase(&"stat_rules")
	var vals: PackedInt32Array = carry[&"stat_values"]
	vals[Stats.Stat.ATTACK_SPEED] = 1643  # 1.18^3, as before SG
	carry[&"stat_values"] = vals
	var v := W.world(&"gun")
	RunCarry.apply(v, carry)
	assert_eq(v.stat_rules, 0)
	Abilities.start_floor(v)
	assert_eq(Stats.value(v, Stats.Stat.ATTACK_SPEED), 1540)
	assert_eq(v.stat_rules, Stats.RULES)


# --- The hidden catch-up -------------------------------------------------------------------------------------
func test_catch_up_reads_the_bucket_and_the_weapon_rate() -> void:
	var w := SaveLab.floor_world(31, 1, &"gun")
	var p0 := CatchUp.power(w)
	assert_eq(p0, 1000)
	_cards(w, Stats.Stat.ATTACK_SPEED, Stats.Rarity.EPIC, 5)  # +90 %
	assert_eq(CatchUp.rate_permille(w), 1000 + 500 + 200, "raw +90 % -> +70 %")
	assert_eq(CatchUp.power(w), 1700)
	var rf := SaveLab.floor_world(31, 1, &"gun")
	for k in rf.item_tables.size():
		if rf.item_tables[k].id == &"gun_rapid_fire":
			BuildSlots.take(rf, k)
	assert_eq(CatchUp.wand_rate_bonus(rf), 600, "Rapid Fire's +60 %, whatever its slot")
	assert_eq(CatchUp.wand_rate_bonus(rf), AttackRate.weapon_bonus(rf), "the bolt's own bonus")
	assert_eq(CatchUp.rate_permille(rf), 1550)
	var v := SaveLab.floor_world(31, 1, &"gun")
	_cards(v, Stats.Stat.DAMAGE, Stats.Rarity.RARE, 2)  # +30 %
	Stats.add_card(v, Stats.Stat.ONRUSH, Stats.Rarity.COMMON)  # +10 %, always counted
	Stats.add_card(v, Stats.Stat.HOARDER, Stats.Rarity.COMMON)  # never counted
	v.shards = 900
	assert_eq(CatchUp.power(v), 1400, "1 + 0.30 + 0.10, one sum")
	Stats.add_card(v, Stats.Stat.GLASS_CANNON, Stats.Rarity.RARE)
	assert_eq(CatchUp.power(v), 1400 * 1250 / 1000, "x Glass Cannon")
