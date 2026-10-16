# gdlint: disable=max-public-methods
extends GutTest
## v0.8.0 FB3 (owner F6 "Weapon + dash + 2-3 cards", F7 "Nemesis takes its HP and damage from your own build, an even
## duel"; FINAL_BOSS.md F6, F7; SIM_CONTRACTS "The final boss"): the Nemesis in the sim. It answers the player's dash a
## reaction later (the same way; the other way in its mirror stance; never mid-attack), walks the player's path an echo
## behind, stands mirrored across the arena; its weapon follows the run (a Blade run's combo arcs and crescents, a Gun
## run's own shot); it casts the strongest cards of the wand (picked by level, then rarity, then slot; compiled alone by
## the wand compiler into hostile copies in its own looks, never splitting, exploding or casting again); its shots keep
## the caps and never appear on the player; its HP and hit come from the build (the formula, its clamps; never a
## one-shot); every strike locks before it lands; deaths named; determinism; saves mid-phase-3 (an FB3 snapshot, and an
## FB2 save whose fight has no mimic state).

const BLADE_CARDS := [
	[&"echo_slash", 3], [&"double_slash", 2], [&"whirl", 4], [&"shared_explosive", 1]
]
const GUN_CARDS := [
	[&"gun_spread", 2], [&"split_shot", 5], [&"shared_explosive", 3], [&"halo_shot", 1]
]


func _body(w: World) -> int:
	return FinalLab.body(w)


func _table(w: World) -> BossTable:
	return BossAi.table_of(w, _body(w))


## Steps until the Nemesis is free to move (its MOVE state, no attack), at most `limit` ticks; holds it there by
## pushing its cooldown out.
func _free(w: World, limit: int = 600) -> void:
	var i := _body(w)
	for k in limit:
		if w.actors.state[i] == EnemyAi.State.MOVE and w.final_fight.dash_t == 0:
			break
		w.step(InputFrame.new())
	w.actors.cd[i] = 1 << 20


# --- data and the weapon --------------------------------------------------------------------------------------------


func test_the_nemesis_is_a_mimic_body_in_data() -> void:
	var w := NemesisLab.world(301)
	var t := _table(w)
	assert_true(t.mimic)
	assert_true(t.build_hp, "its HP from the build")
	assert_eq(t.echo_ticks, 30, "the echo: 0.5 s behind")
	assert_eq(t.dash_react_ticks, 15, "the dash answered 0.25 s later")
	assert_eq(t.stance_ticks, 90)
	assert_eq(t.card_casts, 3, "the strongest three cards")
	assert_eq(t.damage_cap_permille, 200, "never more than a fifth of your max HP a hit")
	for id: StringName in [
		&"nemesis_combo", &"nemesis_crescents", &"nemesis_volley", &"nemesis_point_blank"
	]:
		var a := t.attacks[t.attack_index(id)]
		assert_gt(a.lock_ticks, 0, "%s locks before it lands" % id)
	var cards := 0
	for a in t.attacks:
		if a.move == BossAttackTable.Move.CARD_CAST:
			assert_eq(a.card, cards, "card casts in order")
			cards += 1
	assert_eq(cards, 3)


func test_its_weapon_follows_the_run() -> void:
	var blade := NemesisLab.world(302, &"blade")
	var gun := NemesisLab.world(302, &"gun")
	assert_eq(blade.final_fight.weapon, BossAttackTable.WEAPON_BLADE)
	assert_eq(gun.final_fight.weapon, BossAttackTable.WEAPON_GUN)
	var t := _table(blade)
	for pair: Array in [
		[&"nemesis_combo", true, false],
		[&"nemesis_crescents", true, false],
		[&"nemesis_volley", false, true],
		[&"nemesis_point_blank", false, true],
	]:
		var a := t.attacks[t.attack_index(pair[0])]
		assert_eq(BossNemesis.allowed(blade, a), pair[1], "%s on a Blade run" % pair[0])
		assert_eq(BossNemesis.allowed(gun, a), pair[2], "%s on a Gun run" % pair[0])
	assert_eq(
		blade.final_fight.combo_half.size(), blade.player.combo.size(), "the Blade's combo steps"
	)
	assert_eq(gun.final_fight.combo_half.size(), 0, "no combo on a Gun run")
	assert_eq(gun.final_fight.shot.look, NemesisCast.LOOK_BOLT, "the Gun's shot, as a bolt")
	assert_eq(
		gun.final_fight.shot.vol_count, Modifiers.bolt(gun).count, "the Gun's shot's own count"
	)


func test_the_blade_combo_swings_your_own_steps() -> void:
	var w := NemesisLab.world(303, &"blade")
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.2, 0))
	var atk := NemesisLab.start(w, &"nemesis_combo")
	for k in atk.count:
		var arc := BossNemesis.combo_arc(w, i, k)
		var step := Modifiers.step(w, k % w.player.combo.size())
		assert_eq(arc[3], step.half_arc, "swing %d has step %d's arc" % [k, k])
		assert_almost_eq(float(arc[4]), Attacks.arc_reach_m(w, step), 0.001, "and its reach")


func test_a_gun_run_volley_is_your_shot() -> void:
	var w := NemesisLab.world(304, &"gun", [[&"gun_spread", 3]])
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(7, 0))
	var atk := NemesisLab.start(w, &"nemesis_volley")
	NemesisLab.to_active(w, 1)
	var shots := NemesisLab.shots(w, NemesisCast.LOOK_BOLT)
	assert_eq(shots.size(), Modifiers.bolt(w).count, "one volley of your spread")
	assert_eq(atk.volleys, 3)


# --- the dash -------------------------------------------------------------------------------------------------------


func test_it_dashes_when_you_dash_after_its_reaction() -> void:
	var w := NemesisLab.world(305)
	_free(w)
	var f := w.final_fight
	f.stance = BossTable.STANCE_ECHO
	f.stance_t = 1 << 20
	var i := _body(w)
	var t0 := w.tick
	w.step(NemesisLab.dash(Vector2(1, 0)))
	assert_gt(w.dash_ticks_left, 0, "the hero dashes")
	assert_eq(f.dash_due, t0 + _table(w).dash_react_ticks, "noted, to answer a reaction later")
	var started := -1
	var from := w.actors.pos(i)
	for k in 40:
		w.step(InputFrame.new())
		if f.dash_t > 0 and started < 0:
			started = w.tick - 1
			from = w.actors.pos(i)
	assert_eq(started, t0 + _table(w).dash_react_ticks, "its dash starts on that tick")
	var moved := w.actors.pos(i) - from
	assert_gt(moved.x, 1.0, "the same way as the hero's")
	assert_almost_eq(Kin.length(moved), w.player.dash_distance_m, 0.6, "about the hero's distance")


func test_in_its_mirror_stance_it_dashes_the_other_way() -> void:
	var w := NemesisLab.world(306)
	_free(w)
	var f := w.final_fight
	f.stance = BossTable.STANCE_MIRROR
	f.stance_t = 1 << 20
	var i := _body(w)
	w.step(NemesisLab.dash(Vector2(1, 0)))
	var from := Vector2.ZERO
	for k in 40:
		w.step(InputFrame.new())
		if f.dash_t > 0 and from == Vector2.ZERO:
			from = w.actors.pos(i)
	assert_ne(from, Vector2.ZERO, "it dashed")
	assert_lt((w.actors.pos(i) - from).x, -0.5, "mirrored: the other way")


func test_a_dash_due_mid_attack_is_dropped() -> void:
	var w := NemesisLab.world(307)
	_free(w)
	var f := w.final_fight
	w.step(NemesisLab.dash(Vector2(0, 1)))
	NemesisLab.start(w, &"nemesis_card_1")  # winding up when the dash comes due
	var dashed := false
	for k in 30:
		w.step(InputFrame.new())
		dashed = dashed or f.dash_t > 0
	assert_false(dashed, "no dash out of a windup")
	assert_eq(f.dash_due, -1, "the noted dash is spent")


func test_its_dash_never_hurts() -> void:
	var w := NemesisLab.world(308, &"blade", [], false)
	_free(w)
	var i := _body(w)
	w.final_fight.stance = BossTable.STANCE_ECHO
	w.final_fight.stance_t = 1 << 20
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.5, 0))
	var hurt := CombatLab.player_damage(w).size()
	w.step(NemesisLab.dash(Vector2(1, 0)))
	for k in 40:
		w.step(InputFrame.new())
	assert_eq(CombatLab.player_damage(w).size(), hurt, "a dash is movement only")


# --- the echo and the mirror ----------------------------------------------------------------------------------------


func test_the_echo_walks_your_path_a_moment_behind() -> void:
	var w := NemesisLab.world(309)
	_free(w)
	var f := w.final_fight
	var t := _table(w)
	var path: Array[Vector2] = []
	for k in 90:
		f.stance = BossTable.STANCE_ECHO
		f.stance_t = 1 << 20
		w.step(FinalLab.walk(w, Vector2(-8, 4) if k < 45 else Vector2(6, 6)))
		path.append(w.player_pos())
	var i := _body(w)
	assert_eq(
		BossNemesis.stance_point(w, i),
		path[path.size() - 1 - t.echo_ticks],
		"where the hero stood echo_ticks ago"
	)
	var before := Kin.length(BossNemesis.stance_point(w, i) - w.actors.pos(i))
	w.step(InputFrame.new())
	var after := Kin.length(f.echo_at(t.echo_ticks, w.player_pos()) - w.actors.pos(i))
	assert_lt(after, before + 0.05, "it walks that path")


func test_the_mirror_stands_across_the_arena() -> void:
	var w := NemesisLab.world(310)
	_free(w)
	var f := w.final_fight
	var i := _body(w)
	w.actors.set_pos(0, f.home + Vector2(5, 2))
	f.stance = BossTable.STANCE_MIRROR
	f.stance_t = 1 << 20
	assert_eq(BossNemesis.stance_point(w, i), f.home - Vector2(5, 2), "the hero's mirror image")
	for k in 240:
		f.stance_t = 1 << 20
		w.actors.set_pos(0, f.home + Vector2(5, 2))
		w.step(InputFrame.new())
	assert_lt(Kin.length(w.actors.pos(i) - (f.home - Vector2(5, 2))), 0.5, "and stands there")


func test_after_a_combo_it_backs_off() -> void:
	var w := NemesisLab.world(311, &"blade")
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.0, 0))
	NemesisLab.start(w, &"nemesis_combo")
	for k in 300:
		w.step(InputFrame.new())
		if w.actors.state[i] == EnemyAi.State.MOVE:
			break
	assert_eq(w.final_fight.stance, BossTable.STANCE_BACK, "it backs off")
	var p := BossNemesis.stance_point(w, i)
	assert_almost_eq(Kin.length(p - w.player_pos()), _table(w).back_off_m, 0.01)


# --- the cards ------------------------------------------------------------------------------------------------------


func test_the_strongest_cards_are_picked_by_level_then_rarity_then_slot() -> void:
	var w := NemesisLab.world(312, &"blade", BLADE_CARDS)
	var ids: Array[StringName] = []
	for c in w.final_fight.casts:
		ids.append(c.card_id)
	assert_eq(ids, [&"whirl", &"echo_slash", &"double_slash"] as Array[StringName], "4, 3, 2")
	var levels: Array[int] = []
	for c in w.final_fight.casts:
		levels.append(c.level)
	assert_eq(levels, [4, 3, 2] as Array[int])
	var tie := NemesisLab.world(
		313, &"gun", [[&"gun_spread", 2], [&"halo_shot", 2], [&"gun_twin", 2]]
	)
	var tie_ids: Array[StringName] = []
	for c in tie.final_fight.casts:
		tie_ids.append(c.card_id)
	assert_eq(
		tie_ids,
		[&"gun_twin", &"halo_shot", &"gun_spread"] as Array[StringName],
		"a tie: the rarest first (v0.8.0 RR: Twin is Epic, Halo Rare), then the slot"
	)


func test_the_pick_is_deterministic_and_ignores_what_isnt_a_wand_card() -> void:
	var a := NemesisLab.world(314, &"gun", GUN_CARDS)
	var b := NemesisLab.world(314, &"gun", GUN_CARDS)
	var h1 := StateHasher.new()
	var h2 := StateHasher.new()
	for c in a.final_fight.casts:
		c.hash_into(h1)
	for c in b.final_fight.casts:
		c.hash_into(h2)
	assert_eq(h1.finish_hex(), h2.finish_hex(), "the same build casts the same cards")
	var w := NemesisLab.world(315, &"gun")
	var trig := NemesisLab.card(w, &"trigger_on_hit")
	assert_false(CardLevels.is_card(w, trig), "a trigger is no wand card")
	assert_eq(NemesisBuild.pick_cards(w, 3).size(), 0, "no cards, no casts")


func test_each_card_is_compiled_into_a_hostile_copy() -> void:
	var g := NemesisLab.world(316, &"gun", GUN_CARDS)
	var by := {}
	for c in g.final_fight.casts:
		by[c.card_id] = c
	var split: NemesisCast = by[&"split_shot"]
	assert_true(split.has_volley(), "Split: a shot")
	assert_gt(split.vol_split, 0, "that splits")
	var boom: NemesisCast = by[&"shared_explosive"]
	assert_true(boom.has_blast(), "Explosive: a blast")
	assert_almost_eq(boom.blast_m, 1.4, 0.01, "its radius")
	var spread: NemesisCast = by[&"gun_spread"]
	var gun_spread := NemesisLab.card(g, &"gun_spread")
	var mods: Array[ModifierTable] = []
	for m in g.item_tables[gun_spread].modifiers:
		mods.append(m.at(2))
	var spec := WandCompile.for_world(g, mods).spec(Modifiers.base_bolt(g))
	assert_eq(spread.vol_count, spec.count, "Spread: the wand compiler's count")
	assert_eq(spread.vol_spread, spec.spread, "and fan")
	var b := NemesisLab.world(317, &"blade", BLADE_CARDS)
	var bb := {}
	for c in b.final_fight.casts:
		bb[c.card_id] = c
	assert_eq((bb[&"whirl"] as NemesisCast).arc_half, 2048, "Whirl: a full circle")
	var wave: NemesisCast = bb[&"echo_slash"]
	assert_true(wave.has_arc() and wave.has_volley(), "Wave: a slash that flies on")
	assert_eq(wave.look, NemesisCast.LOOK_CRESCENT, "as crescents")
	assert_eq((bb[&"double_slash"] as NemesisCast).arc_strikes, 3, "Double Slash: struck again")


func test_a_card_cast_locks_then_lands_its_parts() -> void:
	var w := NemesisLab.world(318, &"gun", GUN_CARDS)
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(6, 0))
	var k := -1
	for n in w.final_fight.casts.size():
		if w.final_fight.casts[n].card_id == &"shared_explosive":
			k = n
	var atk := NemesisLab.start(w, StringName("nemesis_card_%d" % (k + 1)))
	var locked_at := -1
	var spot := Vector2.ZERO
	for t in atk.windup_ticks:
		var tg := WorldReader.new(w).telegraph(i)
		assert_eq(tg.get("shape"), &"marks")
		assert_eq(tg.get("card"), &"shared_explosive", "the card it casts")
		if tg["locked"] and locked_at < 0:
			locked_at = t
			for item: Dictionary in tg["items"]:
				if item["shape"] == &"disc":
					spot = item["center"]
		w.actors.set_pos(0, w.player_pos() + Vector2(0, 0.03))
		w.step(InputFrame.new())
	assert_eq(locked_at, atk.windup_ticks - atk.lock_ticks, "locked for its lock before it lands")
	assert_eq(
		w.bosses.pt(BossAi.entry_of(w, i), BossNemesis.BLAST_PT), spot, "the blast where it locked"
	)
	assert_gt(
		NemesisLab.shots(w, NemesisCast.LOOK_BOLT).size() + w.pending_projectiles(), 0, "its shot"
	)


func test_hostile_copies_never_split_explode_or_cast_again() -> void:
	var w := NemesisLab.world(319, &"gun", GUN_CARDS)
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(8, 0))
	for k in 3:
		NemesisLab.start(w, StringName("nemesis_card_%d" % (k + 1)))
		for t in 120:
			w.step(InputFrame.new())
			for p in w.projectiles.size():
				if w.projectiles.team[p] != ActorStore.TEAM_PLAYER:
					assert_eq(
						w.projectiles.spec_key[p], "", "a hostile shot runs no spec (no hooks)"
					)
	for c in w.final_fight.casts:
		assert_lte(c.vol_split, 4, "one level of splits at most")


# --- fairness and caps ----------------------------------------------------------------------------------------------


func test_volleys_keep_the_caps_and_never_appear_on_the_player() -> void:
	var w := NemesisLab.world(
		320, &"gun", [[&"gun_spread", 5], [&"halo_shot", 5], [&"gun_twin", 5]]
	)
	var i := _body(w)
	var t := _table(w)
	for c in w.final_fight.casts:
		var roots := c.vol_count + (1 if c.vol_back else 0)
		assert_lte(roots * (1 + c.vol_split), t.shots_max, "%s within shots_max" % c.card_id)
		assert_lte(c.vol_speed, t.shot_speed_max + 0.0001, "and its speed")
	var shot := w.final_fight.shot
	assert_lte(shot.angles(0).size(), t.shots_max, "the weapon's own shot too")
	# The player right against it: no shot appears within the safe radius.
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(1.2, 0))
	w.actors.lock_x[i] = w.actors.pos_x[i]
	w.actors.lock_y[i] = w.actors.pos_y[i]
	w.actors.lock_a[i] = 0
	var before := w.pending_projectiles()
	var n := BossNemesis.fire_volley(w, i, shot, 5, -1)
	assert_eq(w.pending_projectiles() - before, n, "what it fired is queued")
	assert_lt(n, shot.angles(0).size(), "the shots on the player were left out")
	var safe := BossNemesis.SAFE_M + w.player.radius_m
	w.step(InputFrame.new())
	for p in w.projectiles.size():
		if w.projectiles.team[p] != ActorStore.TEAM_PLAYER:
			var d := Vector2(w.projectiles.pos_x[p], w.projectiles.pos_y[p]) - w.player_pos()
			assert_gt(d.length(), safe - 0.6, "none spawned on the hero")
	# The hostile cap: with this tick's shots full, nothing more is queued and one LIMIT is raised.
	var w2 := NemesisLab.world(321, &"gun", [[&"gun_spread", 5]])
	var j := _body(w2)
	w2.actors.set_pos(0, w2.actors.pos(j) + Vector2(9, 0))
	while w2.pending_projectiles() < BulletPatterns.MAX_SHOTS_PER_TICK:
		w2.queue_projectile(0, ActorStore.TEAM_ENEMY, Vector2(30, 30), Vector2.ZERO, 1, 0.1, 5, 0)
	var seq := w2.last_event_seq()
	assert_eq(BossNemesis.fire_volley(w2, j, w2.final_fight.shot, 5, -1), 0, "past the cap: none")
	var limits := 0
	for e in w2.events_since(seq):
		if e.kind == SimEvent.Kind.LIMIT and e.effect_id == BulletPatterns.EFFECT_CAP:
			limits += 1
	assert_eq(limits, 1, "one LIMIT")


func test_every_swing_locks_before_it_lands() -> void:
	var w := NemesisLab.world(322, &"blade")
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.2, 0))
	var atk := NemesisLab.start(w, &"nemesis_combo")
	var locked_for := 0
	var strikes := 0
	for t in atk.windup_ticks + atk.active_ticks + 1:
		var tg := WorldReader.new(w).telegraph(i)
		if tg.is_empty():
			break
		if tg["striking"]:
			assert_gte(locked_for, atk.lock_ticks, "swing %d locked first" % strikes)
			strikes += 1
			locked_for = 0
		elif tg["locked"]:
			locked_for += 1
		w.actors.set_pos(0, w.player_pos() + Vector2(0.0, 0.02))
		w.step(InputFrame.new())
	assert_eq(strikes, atk.count, "every swing struck")


# --- F7: HP and damage from the build -------------------------------------------------------------------------------


func test_its_hp_is_the_formula_of_your_build() -> void:
	var w := NemesisLab.world(323)
	var t := _table(w)
	assert_eq(
		NemesisBuild.hp_from(100, [0, 0] as Array[int], t), 400, "no meter: 250, at least 400"
	)
	assert_eq(NemesisBuild.hp_from(400, [0, 0] as Array[int], t), 1000, "max HP 400 × 2.5")
	assert_eq(
		NemesisBuild.hp_from(400, [2000, 20] as Array[int], t), 2200, "+ 100 dps × 12 s = 1,200"
	)
	assert_eq(
		NemesisBuild.hp_from(400, [2000, 4] as Array[int], t), 1000, "under 5 s measured: no dps"
	)
	assert_eq(NemesisBuild.hp_from(1, [0, 0] as Array[int], t), t.dps_hp_min, "the floor")
	assert_eq(
		NemesisBuild.hp_from(100000, [1 << 30, 20] as Array[int], t), t.dps_hp_max, "the ceiling"
	)
	var i := _body(w)
	assert_eq(
		w.actors.max_hp[i],
		NemesisBuild.hp_from(w.actors.max_hp[0], FinalBoss.measured(w, t), t),
		"its HP as it rose"
	)


func test_its_hit_is_your_weapon_and_never_a_one_shot() -> void:
	var w := NemesisLab.world(324)
	var t := _table(w)
	assert_eq(NemesisBuild.hit_from(11, 20, t), 16, "your 11 × 1.5")
	assert_eq(NemesisBuild.hit_from(2, 20, t), 8, "at least 8")
	assert_eq(NemesisBuild.hit_from(5000, 20, t), 20, "at most the cap")
	assert_eq(NemesisBuild.hit_from(5000, 3, t), 3, "the cap wins over the floor")
	assert_eq(w.final_fight.hit_cap, w.actors.max_hp[0] * 200 / 1000, "a fifth of your max HP")
	w.final_fight.hit = 1 << 20
	assert_eq(NemesisBuild.damage_of(w, 120, 2000), w.final_fight.hit_cap, "every hit capped")
	assert_lt(w.final_fight.hit_cap, w.actors.max_hp[0], "never your whole HP")


func test_a_full_hp_hero_survives_any_one_hit() -> void:
	var w := NemesisLab.world(325, &"blade", BLADE_CARDS, false)
	w.final_fight.hit = 1 << 20  # a monstrous build
	var i := _body(w)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(2.0, 0))
	NemesisLab.start(w, &"nemesis_combo")
	var hp0 := w.actors.hp[0]
	var first := -1
	for k in 200:
		w.step(InputFrame.new())
		var dmg := CombatLab.player_damage(w)
		if not dmg.is_empty():
			first = dmg[0]
			break
	assert_gt(first, 0, "it hit")
	assert_lte(first, w.final_fight.hit_cap)
	assert_gt(hp0 - first, 0, "still standing")


# --- deaths, determinism and saves ----------------------------------------------------------------------------------


func test_each_attack_names_its_death() -> void:
	var w := NemesisLab.world(326)
	var i := _body(w)
	w.killer_kind = w.actors.kinds[i]
	for pair: Array in [
		[&"nemesis_combo", &"CAUSE_NEMESIS_SLASH"],
		[&"nemesis_crescents", &"CAUSE_NEMESIS_CRESCENTS"],
		[&"nemesis_volley", &"CAUSE_NEMESIS_SHOTS"],
		[&"nemesis_card_2", &"CAUSE_NEMESIS_CARD"],
	]:
		w.killer_attack = NemesisLab.attack(w, pair[0])
		assert_eq(BossAi.cause_key(w), pair[1], "%s" % pair[0])


func test_phase_3_is_deterministic() -> void:
	var a := NemesisLab.world(327, &"gun", GUN_CARDS)
	var b := NemesisLab.world(327, &"gun", GUN_CARDS)
	assert_eq(a.state_hash(), b.state_hash())
	for k in 900:
		var f := FinalLab.walk(a, Vector2(-6, 6) if (k / 120) % 2 == 0 else Vector2(6, -2))
		if k % 97 == 13:
			f = NemesisLab.dash(Vector2(1, -1))
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash())


func test_a_snapshot_mid_phase_3_round_trips() -> void:
	var run := FinalLab.run_state(328, &"blade")
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = NemesisLab.LONG
	NemesisLab.grant(w, BLADE_CARDS)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 2)
	FinalLab.past_rise(w)
	for k in 200:
		w.step(FinalLab.walk(w, Vector2(4, 4)) if k != 50 else NemesisLab.dash(Vector2(-1, 0)))
	NemesisLab.start(w, &"nemesis_card_1")
	CombatLab.idle(w, 20)
	var snap := w.to_snapshot()
	var w2 := FinalLab.arena(run, false)
	assert_eq(WorldSnapshot.apply(w2, snap), "")
	assert_eq(w2.state_hash(), w.state_hash())
	assert_eq(w2.final_fight.casts.size(), 3, "its cards came back")
	assert_eq(w2.final_fight.echo_n, w.final_fight.echo_n, "and its echo")
	for k in 400:
		var f := FinalLab.walk(w, Vector2(-3, 2)) if k % 80 != 7 else NemesisLab.dash(Vector2(0, 1))
		w.step(f)
		w2.step(f)
	assert_eq(w2.state_hash(), w.state_hash(), "the duel goes on the same")


func test_a_save_from_before_fb3_mid_phase_3_restores() -> void:
	var run := FinalLab.run_state(329, &"gun")
	var w := FinalLab.arena(run)
	w.actors.invuln[0] = NemesisLab.LONG
	NemesisLab.grant(w, GUN_CARDS)
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 2)
	CombatLab.idle(w, 30)  # mid-rise, as a save at the body's start resumes
	var p := RunSaver.payload_of(w, run, 329, PackedByteArray())
	var ff: Dictionary = p["world"]["world"][&"final_fight"]
	for f: StringName in WorldSnapshot.ADDED_SINCE_V05[&"FinalFight"]:
		if not f in [&"home", &"dps_secs", &"dps_head", &"dps_closed", &"dps_acc", &"dps_t"]:
			ff.erase(f)  # as a payload written by FB2
	var table := ContentCompiler.compile_run(
		ContentRepository.load_all().get_def(&"run", SaveLab.RUN_ID)
	)
	var w2 := FinalLab.arena(RunSaver.run_from(p, table), false)
	assert_eq(WorldSnapshot.apply(w2, p["world"]), "", "an FB2 snapshot restores mid-phase-3")
	assert_false(w2.final_fight.ready, "with no mimic state")
	var w3 := FinalLab.arena(RunSaver.run_from(p, table), false)
	assert_eq(WorldSnapshot.apply(w3, p["world"]), "")
	for k in 300:
		w2.step(InputFrame.new())
		w3.step(InputFrame.new())
	assert_true(w2.final_fight.ready, "the build read at its next tick")
	assert_eq(w2.final_fight.weapon, BossAttackTable.WEAPON_GUN)
	assert_eq(w2.final_fight.casts.size(), 3, "its cards")
	assert_gt(w2.final_fight.echo_n, 0, "the echo records again")
	assert_eq(w2.state_hash(), w3.state_hash(), "and two restores go on the same")


func test_beating_it_wins_the_fight() -> void:
	var w := NemesisLab.world(330, &"gun", GUN_CARDS)
	FinalLab.hit(w, w.actors.hp[_body(w)] * 10)
	w.step(InputFrame.new())
	w.step(InputFrame.new())
	assert_true(w.final_fight.won, "the last body fell")
	assert_eq(WorldReader.new(w).outcome(), 1, "a victory")
