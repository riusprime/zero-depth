# gdlint: disable=max-public-methods
extends GutTest
## v0.6.0 CU (PLAN v0.5.5 S7, C1-C8, G1 approved): every trade-off curse's drawback and upside apply where the sim
## computes them, each raises threat T by 1, and the cleanse lifts both halves. Real floors (EventLab, built as Main);
## the curses are held from the floor's start (a carry) unless the test takes them in play.

const SEED := 616
const TRADE_OFFS: Array[StringName] = [
	&"rooted",
	&"heavy_hands",
	&"glass_heart",
	&"blood_price",
	&"fevered",
	&"tunnel_vision",
	&"brittle",
	&"marked_hunt",
]
## A source id that isn't the player: an enemy's hit.
const ENEMY := 999999


func _world(curses: Array = [], build: StringName = &"blade") -> World:
	return EventLab.world(SEED, 1, build, curses)


func _c(w: World, id: StringName) -> int:
	return EventLab.curse_index(w, id)


## An enemy hit of `amount` on the player, i-frames cleared first (test setup). Returns the HP it removed.
func _enemy_hit(w: World, amount: int) -> int:
	w.actors.invuln[0] = 0
	var p := w.player_pos()
	return Damage.hit(w, 0, amount, ENEMY, ENEMY, w.take_root(), 0, p + Vector2(1, 0), p)


func _move(x: int) -> InputFrame:
	var f := InputFrame.new()
	f.move = Vector2i(x, 0)
	return f


func test_each_trade_off_raises_threat_by_one_and_the_cleanse_lifts_it_whole() -> void:
	for id in TRADE_OFFS:
		var w := _world()
		var c := _c(w, id)
		assert_gte(c, 0, "%s ships" % id)
		var t := w.ev.curses[c]
		assert_true(t.is_trade_off(), "%s has an upside" % id)
		assert_eq(Curses.threat(w), 0)
		assert_true(Curses.add(w, c))
		assert_eq(Curses.threat(w), 1, "%s: T + 1" % id)
		assert_gt(Curses.total(w, t.effect), 0, "%s: the drawback is held" % id)
		assert_gt(Curses.total(w, t.up_effect), 0, "%s: the upside is held" % id)
		assert_true(Curses.cleanse(w))
		assert_eq(Curses.threat(w), 0, "%s: lifted" % id)
		assert_eq(Curses.total(w, t.effect), 0, "%s: the drawback is gone" % id)
		assert_eq(Curses.total(w, t.up_effect), 0, "%s: and the upside with it" % id)
		assert_eq(w.threat_peak, 1, "the peak keeps what was chosen")


func test_c1_rooted_no_dash_and_a_quarter_of_hits_dodged() -> void:
	for cursed in [false, true]:
		var w := _world([&"rooted"] if cursed else [])
		var f := _move(SimTick.MOVE_MAX)
		f.pressed = InputFrame.DASH
		w.step(f)
		if cursed:
			assert_eq(w.dash_ticks_left, 0, "Rooted: the dash press does nothing")
		else:
			assert_gt(w.dash_ticks_left, 0, "a dash without the curse")
	var w := _world([&"rooted"])
	var dodged := 0
	var n := 800
	for k in n:
		w.actors.hp[0] = w.actors.max_hp[0]
		var before := w.cs.dodges
		var got := _enemy_hit(w, 5)
		if w.cs.dodges > before:
			dodged += 1
			assert_eq(got, 0, "a dodge negates the hit")
			assert_eq(w.actors.invuln[0], w.player.hurt_iframe_ticks, "with the hurt i-frames")
	gut.p("Rooted dodged %d of %d hits" % [dodged, n])
	assert_between(dodged, 160, 240, "about 25 %")
	var cue := 0
	for e in w.events_since(0):
		cue += (
			1 if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == Curses.EFFECT_DODGE else 0
		)
	assert_eq(cue, dodged, "every dodge has its cue")
	var v := _world()
	var rng := v.rng_combat.state
	_enemy_hit(v, 5)
	assert_eq(v.cs.dodges, 0, "no dodge without the curse")
	assert_eq(v.rng_combat.state, rng, "and no combat draw")


func test_c2_heavy_hands_slower_attacks_and_a_heavy_fourth_hit() -> void:
	var w := _world([&"heavy_hands"])
	var v := _world()
	assert_eq(Stats.period(v, 30), 30)
	assert_eq(Stats.period(w, 30), 38, "attack speed x0.8: 30 ticks -> 37.5, half up")
	var step := w.player.combo[0]
	assert_gt(Stats.swing_end(w, step), Stats.swing_end(v, step), "the swing's recovery is longer")
	for s in 4:
		w.combo_step = s
		assert_eq(Curses.swing_damage(w, 100), 160 if s == 3 else 100, "Blade step %d" % (s + 1))
	var shots := []
	for k in 8:
		shots.append(Curses.shot_damage(w, 100))
	assert_eq(shots, [100, 100, 100, 160, 100, 100, 100, 160], "every 4th Gun shot +60 %")
	v.combo_step = 3
	assert_eq(Curses.swing_damage(v, 100), 100, "no boost without the curse")


func test_c2_the_fourth_swing_of_a_real_combo_hits_harder() -> void:
	var hits := []
	for cursed in [false, true]:
		var w := _world([&"heavy_hands"] if cursed else [])
		w.actors.invuln[0] = 1 << 20
		var id := w.add_enemy(ActorStore.Kind.WARDEN, w.player_pos() + Vector2(1.2, 0))
		var i := w.actors.index_of(id)
		w.actors.invuln[i] = 0
		w.actors.hp[i] = 100000
		w.actors.max_hp[i] = 100000
		w.build_state.facing_angle = 0  # test setup: face the Warden's side
		var seq := w.last_event_seq()
		for t in 240:
			var f := InputFrame.new()
			f.pressed = InputFrame.PRIMARY if t % 6 == 0 else 0
			w.step(f)
		var per_step := []
		for e in w.events_since(seq):
			if e.kind == SimEvent.Kind.HIT and e.target_id == id and e.owner_id == w.actors.ids[0]:
				per_step.append(e.amount)
		hits.append(per_step)
	gut.p("Blade hits plain %s, cursed %s" % [hits[0].slice(0, 8), hits[1].slice(0, 8)])
	assert_gte(hits[1].size(), 4, "a full combo landed")
	assert_gt(int(hits[1][3]), int(hits[0][3]), "the 4th hit is the heavy one")


func test_c3_glass_heart_less_max_hp_and_more_crit() -> void:
	var w := _world([&"glass_heart"])
	var v := _world()
	assert_eq(
		w.actors.max_hp[0],
		(v.actors.max_hp[0] * 700 + 500) / 1000,
		"max HP x0.7 from the floor's start"
	)
	assert_eq(Stats.crit_chance(w), Stats.crit_chance(v) + 150, "+15 % crit chance")
	var u := _world()
	var full := u.actors.max_hp[0]
	Curses.add(u, _c(u, &"glass_heart"))
	assert_eq(u.actors.max_hp[0], (full * 700 + 500) / 1000, "taken in play: max HP falls at once")
	assert_lte(u.actors.hp[0], u.actors.max_hp[0])
	Curses.cleanse(u)
	assert_eq(u.actors.max_hp[0], full, "lifted: max HP comes back")
	assert_eq(Stats.crit_chance(u), Stats.crit_chance(v))


func test_c4_blood_price_skill_costs_hp_and_skills_hit_harder() -> void:
	var w := _world([&"blood_price"])
	var full := w.actors.max_hp[0]
	var f := InputFrame.new()
	f.pressed = InputFrame.SKILL
	w.step(f)
	assert_gt(w.kit.skill_tick, -1, "the skill went off")
	assert_eq(w.actors.hp[0], full - maxi(1, full * 20 / 1000), "a Skill costs 2 % of max HP")
	w.actors.hp[0] = 1
	Curses.on_ability_use(w)
	assert_eq(w.actors.hp[0], 1, "never lethal")
	assert_eq(Curses.ability_damage_permille(w, SimEvent.TAG_SKILL), 1350, "skills +35 %")
	assert_eq(Curses.ability_damage_permille(w, SimEvent.TAG_ABILITY), 1350, "abilities +35 %")
	assert_eq(
		Curses.ability_damage_permille(w, SimEvent.TAG_MELEE), 1000, "the weapon's plain hits don't"
	)
	var v := _world()
	f = InputFrame.new()
	f.pressed = InputFrame.SKILL
	v.step(f)
	assert_eq(v.actors.hp[0], v.actors.max_hp[0], "free without the curse")


func test_c5_fevered_heat_lingers_and_overclock_hits_harder() -> void:
	var drops := []
	var mults := []
	for curses in [[], [&"fevered"]]:
		var w := _world(curses)
		w.heat.milli = 40 * HeatTable.MILLI  # test setup
		w.heat.idle = w.heat.table.decay_delay_ticks + 1
		var before := w.heat.milli
		Heat.advance(w)
		drops.append(before - w.heat.milli)
		w.heat.milli = 90 * HeatTable.MILLI  # test setup: Overclock
		mults.append(Heat.attacker_mult(w, 1, w.actors.ids[0], SimEvent.TAG_MELEE, &""))
	assert_eq(drops[1], drops[0] / 2, "heat decays 50 % slower")
	assert_eq(mults[1] - mults[0], 400, "Overclock +40 %")


func test_c6_tunnel_vision_no_minimap_and_more_shards() -> void:
	var w := _world([&"tunnel_vision"])
	var v := _world()
	assert_true(WorldReader.new(w).minimap_blind(), "the minimap is off")
	assert_false(WorldReader.new(v).minimap_blind())
	assert_eq(Stats.shards(w, 100), 125, "+25 % shards")
	assert_eq(Stats.shards(v, 100), 100)
	var id := w.add_enemy(ActorStore.Kind.CHARGER, w.player_pos() + Vector2(3, 0))
	var vid := v.add_enemy(ActorStore.Kind.CHARGER, v.player_pos() + Vector2(3, 0))
	var paid := []
	for pair: Array in [[v, vid], [w, id]]:
		var x: World = pair[0]
		var i := x.actors.index_of(pair[1])
		x.actors.invuln[i] = 0
		var before := x.shards
		Damage.hit(
			x,
			i,
			100000,
			x.actors.ids[0],
			x.actors.ids[0],
			x.take_root(),
			0,
			x.player_pos(),
			x.actors.pos(i)
		)
		x.step(InputFrame.new())
		paid.append(x.shards - before)
	gut.p("a kill pays %d shards, %d under Tunnel Vision" % paid)
	assert_eq(paid[1], (paid[0] * 1250 + 500) / 1000, "a kill pays x1.25")


func test_c7_brittle_a_hit_stuns_and_you_move_faster() -> void:
	var w := _world([&"brittle"])
	w.actors.hp[0] = w.actors.max_hp[0]
	assert_gt(_enemy_hit(w, 3), 0, "the hit hurt")
	assert_eq(w.cs.stun_t, 12, "0.2 s stun")
	while w.freeze_ticks > 0:
		w.step(_move(SimTick.MOVE_MAX))
	var at := w.player_pos()
	var f := _move(SimTick.MOVE_MAX)
	f.pressed = InputFrame.DASH | InputFrame.PRIMARY
	w.step(f)
	assert_eq(w.player_pos(), at, "stunned: no move")
	assert_eq(w.dash_ticks_left, 0, "no dash")
	assert_eq(w.swing_t, 0, "no swing")
	while Curses.stunned(w):
		w.step(_move(SimTick.MOVE_MAX))
	w.step(_move(SimTick.MOVE_MAX))
	assert_ne(w.player_pos(), at, "it ends, and you move again")
	var speeds := []
	for curses in [[], [&"brittle"]]:
		var x := _world(curses)
		x.actors.invuln[0] = 1 << 20
		for t in 90:
			x.step(_move(SimTick.MOVE_MAX))
		speeds.append(x.vel.length())
	gut.p("top speed %.4f m/tick, %.4f under Brittle" % speeds)
	assert_almost_eq(speeds[1] / speeds[0], 1.2, 0.01, "+20 % move speed")
	var v := _world()
	_enemy_hit(v, 3)
	assert_eq(v.cs.stun_t, 0, "no stun without the curse")


func test_c8_marked_elites_hunt_you_and_drop_a_rare_card() -> void:
	var w := _world([&"marked_hunt"])
	assert_eq(
		Curses.total(w, Curses.Effect.ELITE_CHANCE), 120, "12 % elite chance, as Marked Hunt had"
	)
	var near := w.add_enemy(ActorStore.Kind.CHARGER, w.player_pos() + Vector2(4, 0))
	var far := w.add_enemy(ActorStore.Kind.CHARGER, w.player_pos() + Vector2(40, 0))
	var plain := w.add_enemy(ActorStore.Kind.CHARGER, w.player_pos() + Vector2(0, 4))
	Curses.make_elite(w, w.actors.index_of(near))
	Curses.make_elite(w, w.actors.index_of(far))
	assert_almost_eq(
		Curses.hunt_factor(w, w.actors.index_of(near)), 1.3, 0.001, "an elite in range: +30 %"
	)
	assert_eq(Curses.hunt_factor(w, w.actors.index_of(far)), 1.0, "out of range")
	assert_eq(Curses.hunt_factor(w, w.actors.index_of(plain)), 1.0, "not an elite")
	var i := w.actors.index_of(near)
	var at := w.actors.pos(i)
	w.actors.invuln[i] = 0
	var drops := w.rewards.size()
	Damage.hit(
		w, i, 1000000, w.actors.ids[0], w.actors.ids[0], w.take_root(), 0, w.player_pos(), at
	)
	w.step(InputFrame.new())
	var found := -1
	for r in w.rewards.size():
		if CoreTheft.drop_kind(w, w.rewards.ids[r]) == CoreState.Drop.ELITE_CARD:
			found = r
	assert_gte(found, 0, "the elite dropped Marked's card")
	assert_eq(w.rewards.size(), drops + 1, "only that (killed in one blow: no window, no core)")
	var card := w.rewards.offer_of(found)[0]
	if Offers.type_of(card) == Offers.STAT:
		assert_eq(Offers.rarity_of(card), Stats.Rarity.RARE, "a rare card")
	else:
		assert_eq(Offers.type_of(card), Offers.MOD, "or a mod")
	var v := _world()
	var id := v.add_enemy(ActorStore.Kind.CHARGER, v.player_pos() + Vector2(4, 0))
	var j := v.actors.index_of(id)
	Curses.make_elite(v, j)
	v.actors.invuln[j] = 0
	var before := v.rewards.size()
	Damage.hit(
		v,
		j,
		1000000,
		v.actors.ids[0],
		v.actors.ids[0],
		v.take_root(),
		0,
		v.player_pos(),
		v.actors.pos(j)
	)
	v.step(InputFrame.new())
	assert_eq(v.rewards.size(), before, "no card without Marked")


func test_c8_marked_elites_close_in_faster() -> void:
	var walked := []
	for curses in [[], [&"marked_hunt"]]:
		var w := _world(curses)
		w.actors.invuln[0] = 1 << 20
		var id := w.add_enemy(ActorStore.Kind.WARDEN, w.player_pos() + Vector2(8, 0))
		Curses.make_elite(w, w.actors.index_of(id))
		CombatLab.idle(w, SimTick.SPAWN_IN_TICKS + 4)
		var a := w.actors.pos(w.actors.index_of(id))
		CombatLab.idle(w, 10)
		walked.append(w.actors.pos(w.actors.index_of(id)).distance_to(a))
	gut.p("an elite Warden walks %.3f m in 10 ticks, %.3f m Marked" % walked)
	assert_gt(walked[0], 0.05, "it walked")
	assert_almost_eq(walked[1] / walked[0], 1.3, 0.03, "x1.3")
