# gdlint: disable=max-public-methods
extends GutTest
## The Twin Wardens as two separate fighters (TwinsLab: the real compiled pair in a 24 m walled room). The amber
## Warden's fast kit: the charge that bursts where it ends (BossChargeBurst), the three-hit sword combo and the side
## dash (BossWardenAmber). The violet Warden's: the Mirror Ward that sends shots back (BossWard) and Shadow Swords with
## the rifts they leave (BossShadowSwords). Phase 3: her whole ward, broken only by his charge; and Through the Rift
## (BossRift). Then the hash, a mid-fight save and the end of the fight.

const S := EnemyAi.State
const M := BossAttackTable.Move


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


## The pair hushed and still with the amber Warden at `amber`, the violet one at `violet`, the hero at `hero`, in
## phase `phase`.
func _stage(hero: Vector2, amber: Vector2, violet: Vector2, phase := 0, seed_value := 11) -> Array:
	var s := TwinsLab.fight(hero, amber, seed_value)
	var w: World = s[0]
	TwinsLab.hush(w, s[1])
	if phase > 0:
		TwinsLab.set_phase(w, s[1], phase)
	w.actors.set_pos(_i(w, s[1]), amber)
	w.actors.set_pos(_i(w, s[2]), violet)
	w.actors.set_pos(0, hero)
	return s


## Steps until body `aid` is in `state`, the hero held at `hero` (INF: left alone), at most `limit` ticks.
func _until_state(w: World, aid: int, state: int, limit := 400, hero := Vector2.INF) -> int:
	for k in limit:
		if w.actors.state[_i(w, aid)] == state:
			return k
		if hero != Vector2.INF:
			w.actors.set_pos(0, hero)
		w.step(InputFrame.new())
	return limit


func test_the_data_is_the_brief_s_numbers() -> void:
	var s := TwinsLab.fight(Vector2(-8, 0))
	var w: World = s[0]
	var t := TwinsLab.table(w, s[1])
	var charge := t.attacks[t.attack_index(&"warden_charge")]
	assert_eq(
		[charge.windup_ticks, charge.lock_ticks],
		[36, 24],
		"0.6 s wind-up, the aim locks at the floor"
	)
	assert_almost_eq(charge.speed * 60.0, 26.0, 0.001, "26 m/s")
	assert_eq([charge.length_m, charge.burst_radius_m, charge.burst_ticks], [12.0, 3.5, 15])
	var long := t.attacks[t.attack_index(&"warden_charge_long")]
	assert_eq(
		[long.windup_ticks, long.lock_ticks], [84, 30], "1.4 s wind-up, locked the last 0.5 s"
	)
	var combo := t.attacks[t.attack_index(&"sword_combo")]
	assert_eq([combo.windup_ticks, combo.gap_ticks, combo.count], [30, 21, 3])
	assert_eq(combo.active_ticks, 43, "active until its last hit")
	assert_almost_eq(combo.reach_m, 2.6, 0.001)
	assert_eq(combo.half_arc, 683, "a 120 degree arc")
	var over := t.attacks[t.attack_index(&"overhead")]
	assert_eq([over.windup_ticks, over.half_arc, over.damage], [78, 967, 50], "1.3 s, 170 degrees")
	assert_almost_eq(over.reach_m, 3.4, 0.001)
	var wt := t.wardens
	assert_eq([wt.dash_ticks, wt.dash_every_ticks], [15, 180])
	assert_eq([wt.mirror_ticks, wt.mirror_half_arc, wt.mirror_permille], [240, 910, 500])
	assert_eq([wt.sword_count, wt.sword_gap_ticks], [5, 12])
	assert_eq(t.attacks[t.attack_index(&"shadow_swords")].windup_ticks, 48, "the lines show 0.8 s")
	assert_eq(t.attacks[t.attack_index(&"shadow_swords")].active_ticks, 49)
	assert_eq([wt.ward_phase, wt.stun_ticks, wt.stun_permille], [2, 300, 1500])
	assert_eq([wt.stagger_ticks, wt.return_ticks], [120, 720])
	assert_eq([wt.rift_open_ticks, wt.rift_inside_ticks, wt.rift_mark_ticks], [60, 90, 30])
	assert_eq(wt.rift_attack, t.attack_index(&"rift_charge"))
	assert_eq(t.attacks[wt.rift_attack].damage, 40, "40 % of the base hero's HP at most")
	assert_eq(wt.mirror_cause_key, &"CAUSE_TWIN_MIRROR")
	assert_eq(t.hazard.radius_m, 1.5, "a sword's rift")
	assert_eq([t.hazard.life_ticks, t.hazard.max_count], [480, 5])


func test_bad_wardens_numbers_are_errors() -> void:
	var repo := ContentRepository.load_all()
	var fresh := func() -> BossDefinition:
		return (repo.get_def(&"bosses", &"twin_wardens") as BossDefinition).duplicate(true)
	var codes := func(d: BossDefinition) -> Array:
		return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	var def: BossDefinition = fresh.call()
	assert_eq(codes.call(def), [], "the shipped data is valid")
	def.wardens["nope"] = 1
	assert_has(codes.call(def), &"unknown_field")
	def = fresh.call()
	def.wardens["mirror_seconds"] = 60.0
	assert_has(codes.call(def), &"range")
	def = fresh.call()
	def.wardens["ward_return_seconds"] = 5.0
	assert_has(codes.call(def), &"duration", "the ward returns after the stun")
	def = fresh.call()
	def.wardens.erase("mirror_cause_key")
	assert_has(codes.call(def), &"missing", "a returned shot needs its death line")
	def = fresh.call()
	def.attack(&"rift_charge").damage = 41
	assert_has(codes.call(def), &"range", "the rift's charge takes at most 40 %")
	def = fresh.call()
	def.wardens["rift_attack"] = "overhead"
	assert_has(codes.call(def), &"missing", "the rift's exit is a charge")
	def = fresh.call()
	def.wardens = {}
	assert_has(codes.call(def), &"missing", "the sword combo, the ward and the swords need them")
	var warlord := (repo.get_def(&"bosses", &"warlord") as BossDefinition).duplicate(true)
	warlord.wardens = {"mirror_cause_key": "X"}
	assert_has(codes.call(warlord), &"missing", "only a twin boss has them")


# --- the charge that bursts ---------------------------------------------------------------------------------------


func test_the_charge_tracks_then_locks_runs_at_26_and_bursts_where_it_ends() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(-8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"warden_charge")
	var atk := BossAi.attack_of(w, i)
	var r := WorldReader.new(w)
	# It follows the hero until the lock
	for k in atk.windup_ticks - atk.lock_ticks - 1:
		w.actors.set_pos(0, Vector2(6, -4))
		w.step(InputFrame.new())
		var tg := r.telegraph(i)
		assert_false(tg.get("locked", true), "still tracking at wind-up tick %d" % (k + 1))
		assert_true(tg.has("burst"), "the end circle shows from the start")
	var want := Kin.angle_of(Vector2(6, -4) - Vector2(-8, 0))
	assert_eq(w.actors.lock_a[i], want, "aimed at where the hero is")
	w.actors.set_pos(0, Vector2(6, 4))
	w.step(InputFrame.new())
	assert_true(r.telegraph(i).get("locked", false), "locked for the last 0.4 s")
	assert_eq(w.actors.lock_a[i], want, "and the aim holds")
	var seen: Dictionary = r.telegraph(i)["burst"]
	var end := BossChargeBurst.end_of(w, i)
	assert_eq(seen["center"], end, "the circle is where the run will end")
	assert_almost_eq((end - Vector2(-8, 0)).length(), 12.0, 0.001, "12 m on")
	assert_eq(seen["radius"], 3.5)
	assert_eq(r.boss_wardens()["charge"]["end"], end, "and in the Wardens' read")
	# The run
	w.actors.set_pos(0, Vector2(-11, 11))  # out of everything
	_until_state(w, s[1], S.ACTIVE, 60)
	var from := w.actors.pos(i)
	w.step(InputFrame.new())
	assert_almost_eq((w.actors.pos(i) - from).length(), 26.0 / 60.0, 0.0005, "26 m/s")
	var armed := TwinsLab.until_effect(w, BossChargeBurst.ARMED, 60)
	assert_not_null(armed, "the burst is armed as the run stops")
	if armed == null:
		return
	assert_almost_eq(armed.pos, end, Vector2(0.01, 0.01), "at the end shown")
	assert_eq(armed.amount, 15, "0.25 s later")
	assert_eq(r.boss_charge_bursts().size(), 1)
	assert_eq(r.boss_charge_bursts()[0]["left"], armed.tick + 15 - w.tick, "counting down")
	# Standing on the end as it bursts costs the charge's damage; the amber Warden has moved on by then
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 100
	w.actors.invuln[0] = 0
	w.actors.set_pos(0, end + Vector2(0, 3.0))
	var burst := TwinsLab.until_effect(w, BossChargeBurst.BURST, 30)
	assert_not_null(burst)
	if burst == null:
		return
	assert_eq(burst.tick - armed.tick, 15, "tick-exact")
	assert_eq(burst.amount, 50, "the charge's damage")
	assert_eq(w.actors.hp[0], 50)
	assert_eq(r.boss_charge_bursts(), [], "gone once it burst")


func test_the_burst_misses_outside_its_circle_and_a_wall_cuts_the_run_short() -> void:
	var s := _stage(Vector2(11, 0), Vector2(4, 0), Vector2(-8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"warden_charge")
	var atk := BossAi.attack_of(w, i)
	TwinsLab.idle(w, atk.windup_ticks - atk.lock_ticks + 1)  # locked on the hero by the wall
	var end := BossChargeBurst.end_of(w, i)
	assert_almost_eq(end.x, 11.0, 0.01, "the wall at 12 m stops the body 7 m on")
	w.actors.set_pos(0, Vector2(0, -11))
	var hp := w.actors.hp[0]
	var burst := TwinsLab.until_effect(w, BossChargeBurst.BURST, 200)
	assert_not_null(burst)
	if burst == null:
		return
	assert_almost_eq(burst.pos, end, Vector2(0.01, 0.01))
	assert_eq(burst.amount, 0, "nobody in it")
	assert_eq(w.actors.hp[0], hp)


func test_a_charge_without_the_option_does_not_burst() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-8, 0), Vector2(-8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	var t := TwinsLab.table(w, s[1])
	t.attacks[t.attack_index(&"warden_charge")].burst_radius_m = 0.0
	BossLab.start(w, i, &"warden_charge")
	w.step(InputFrame.new())
	assert_false(WorldReader.new(w).telegraph(i).has("burst"))
	w.actors.set_pos(0, Vector2(-11, 11))
	_until_state(w, s[1], S.RECOVER, 200)
	TwinsLab.idle(w, 30)
	assert_eq(TwinsLab.effects(w, BossChargeBurst.ARMED), [], "nothing armed")
	assert_true(w.boss_fight.cb_boss.is_empty())


# --- the sword combo and the dash ---------------------------------------------------------------------------------


func test_the_combo_hits_three_times_15_15_20_stepping_in() -> void:
	var s := _stage(Vector2(-4, 0), Vector2(-8, 0), Vector2(8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	w.actors.max_hp[0] = 1000
	w.actors.hp[0] = 1000
	BossLab.start(w, i, &"sword_combo")
	var atk := BossAi.attack_of(w, i)
	var hits := []
	var at_hit := []
	var from := w.actors.pos(i)
	# The hero keeps 3 m ahead of where it started, in reach of every step, and its hurt i-frames are cleared so
	# every hit is counted
	for k in 200:
		if w.actors.state[i] == S.RECOVER:
			break
		w.actors.invuln[0] = 0
		var hp := w.actors.hp[0]
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp:
			hits.append(hp - w.actors.hp[0])
			at_hit.append([w.actors.state[i], w.actors.state_t[i]])
	assert_eq(hits, [15, 15, 20], "30 / 30 / 40 % of 50")
	assert_eq(
		at_hit, [[S.ACTIVE, 0], [S.ACTIVE, 21], [S.ACTIVE, 42]], "0.35 s apart after the wind-up"
	)
	assert_eq(atk.windup_ticks, 30, "a 0.5 s first wind-up")
	var moved := (w.actors.pos(i) - from).length()
	assert_gt(moved, 1.4, "it stepped toward the hero")
	assert_lte(moved, 4.5 + 0.001, "at most 1.5 m a hit")
	var gap := (w.player_pos() - w.actors.pos(i)).length()
	assert_gte(gap, w.actors.radius[i] + w.player.radius_m, "never into the hero")


func test_the_combo_steps_1_5_m_before_each_hit_and_shows_its_arc() -> void:
	var s := _stage(Vector2(11, 0), Vector2(-8, 0), Vector2(8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	BossLab.start(w, i, &"sword_combo")
	var atk := BossAi.attack_of(w, i)
	var r := WorldReader.new(w)
	var xs := []
	for k in atk.windup_ticks + atk.active_ticks:
		w.step(InputFrame.new())
		var tg := r.telegraph(i)
		if w.actors.state[i] == S.ACTIVE and w.actors.state_t[i] % atk.gap_ticks == 0:
			xs.append(w.actors.pos(i).x)
			assert_true(tg.get("striking", false), "striking on the tick it lands")
		if tg.is_empty():
			continue
		assert_eq(tg["shape"], &"arc")
		assert_eq(tg["center"], w.actors.pos(i), "cut round where the body stands")
		assert_eq(tg["strikes"], 3)
	assert_eq(xs.size(), 3)
	assert_almost_eq(xs[0], -6.5, 0.001, "1.5 m before the first hit")
	assert_almost_eq(xs[1], -5.0, 0.001, "1.5 m before the second")
	assert_almost_eq(xs[2], -3.5, 0.001, "1.5 m before the third")
	assert_eq(w.actors.hp[0], TwinsLab.LONG, "out of reach: no hit")


func test_the_amber_dashes_sideways_between_attacks() -> void:
	var s := _stage(Vector2(4, 0), Vector2(-2, 0), Vector2(-8, 9))
	var w: World = s[0]
	var i := _i(w, s[1])
	var wt := TwinsLab.wardens(w, s[1])
	wt.dash_every_ticks = 180
	w.boss_fight.wd_dash_cd = 0
	w.actors.cd[i] = 0
	TwinsLab.idle(w, 5)
	assert_eq(TwinsLab.effects(w, BossWardenAmber.DASH), [], "not while it could attack")
	w.actors.cd[i] = 60  # between two attacks
	var from := w.actors.pos(i)
	var hp := w.actors.hp[0]
	var e := TwinsLab.until_effect(w, BossWardenAmber.DASH, 5)
	assert_not_null(e, "it dashes")
	if e == null:
		return
	assert_eq(e.amount, 15, "0.25 s")
	assert_gt(WorldReader.new(w).boss_wardens()["dash"], 0)
	TwinsLab.idle(w, 15)
	var moved := w.actors.pos(i) - from
	assert_almost_eq(moved.length(), 4.0, 0.01, "4 m")
	assert_almost_eq(moved.x, 0.0, 0.01, "to the side of the line to the hero")
	assert_eq(w.actors.hp[0], hp, "no damage")
	assert_eq(w.boss_fight.wd_dash_t, 0)
	w.actors.cd[i] = 600
	TwinsLab.idle(w, 150)
	assert_eq(TwinsLab.effects(w, BossWardenAmber.DASH).size(), 1, "once every 3 s")
	var first_side := signf(moved.y)
	from = w.actors.pos(i)
	TwinsLab.idle(w, 60)
	assert_eq(TwinsLab.effects(w, BossWardenAmber.DASH).size(), 2, "then again")
	assert_eq(signf((w.actors.pos(i) - from).y), -first_side, "the other side this time")


# --- the Mirror Ward ----------------------------------------------------------------------------------------------


## Phase 2 with the violet Warden at the origin, her Mirror Ward up facing the hero at (6, 0). Returns the fight.
func _warded() -> Array:
	var s := _stage(Vector2(6, 0), Vector2(-9, 0), Vector2.ZERO, 1)
	var w: World = s[0]
	BossLab.start(w, _i(w, s[2]), &"mirror_ward")
	assert_not_null(TwinsLab.until_effect(w, BossWard.UP, 80), "the ward goes up")
	return s


## A hero's bolt of `damage` from `from` flying at the violet Warden at 0.3 m a tick.
func _shoot(w: World, from: Vector2, damage: int) -> void:
	var v := -from / from.length() * 0.3
	w.queue_projectile(
		w.actors.ids[0], ActorStore.TEAM_PLAYER, from, v, damage, 0.2, 200, SimEvent.TAG_PROJECTILE
	)


func test_the_mirror_ward_is_a_1_s_cast_then_4_s_on_160_degrees() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-9, 0), Vector2.ZERO, 1)
	var w: World = s[0]
	var j := _i(w, s[2])
	var start := w.tick
	BossLab.start(w, j, &"mirror_ward")
	var up := TwinsLab.until_effect(w, BossWard.UP, 80)
	assert_not_null(up)
	if up == null:
		return
	assert_eq(up.tick - start + 1, 60, "a 1.0 s cast: it ends on its 60th tick")
	assert_eq([up.amount, up.amount_applied], [240, 0], "4 s, an arc")
	var ward: Dictionary = WorldReader.new(w).boss_wardens()["ward"]
	assert_eq([ward["kind"], ward["who"], ward["half_arc"]], [&"mirror", j, 910])
	assert_eq(ward["centre"], 0, "it faces where the hero stood as the cast ended")
	assert_eq(ward["left"], up.tick + 240 - w.tick)
	assert_true(BossWard.faces(w, j, Vector2(5, 4)), "inside 80 degrees of it")
	assert_false(BossWard.faces(w, j, Vector2(0, 5)), "at 90 degrees: outside")
	assert_false(BossWard.faces(w, j, Vector2(-5, 0)), "behind her")
	assert_false(BossTwin.may_use(w, j, BossAi.attack_of(w, j)), "one ward at a time")
	w.actors.set_pos(0, Vector2(0, 7))
	var down := TwinsLab.until_effect(w, BossWard.DOWN, 300)
	assert_not_null(down)
	if down == null:
		return
	assert_eq(down.tick - up.tick, 240, "4 s, and it did not turn after the hero")
	assert_eq(WorldReader.new(w).boss_wardens()["ward"]["kind"], &"")


func test_a_shot_into_the_ward_comes_back_for_half_and_one_round_it_lands() -> void:
	var s := _warded()
	var w: World = s[0]
	var j := _i(w, s[2])
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 100
	var boss_hp := w.actors.hp[j]
	_shoot(w, Vector2(4, 0), 30)
	var seq := TwinsLab.mark(w)
	var back := TwinsLab.until_effect(w, BossWard.REFLECT, 30, seq)
	assert_not_null(back, "sent back")
	if back == null:
		return
	assert_eq(back.amount, 15, "50 % of its damage")
	assert_eq(w.actors.hp[j], boss_hp, "the Warden takes nothing")
	w.step(InputFrame.new())
	var ps := w.projectiles
	assert_eq(ps.size(), 1, "the hero's shot is gone, its return flies")
	assert_eq([ps.team[0], ps.owner[0], ps.damage[0]], [ActorStore.TEAM_ENEMY, s[2], 15])
	assert_almost_eq(Vector2(ps.vel_x[0], ps.vel_y[0]), Vector2(0.3, 0), Vector2(0.0001, 0.0001))
	assert_eq(ps.cause_of(0), BossWard.MIRROR_CAUSE)
	w.actors.invuln[0] = 0
	for k in 40:
		w.step(InputFrame.new())
	assert_eq(w.actors.hp[0], 85, "it hits the hero as any hostile shot")
	# From behind her the same shot lands
	_shoot(w, Vector2(-4, 0), 30)
	seq = TwinsLab.mark(w)
	TwinsLab.idle(w, 30)
	assert_eq(TwinsLab.effects(w, BossWard.REFLECT, seq), [], "not turned")
	assert_lt(w.actors.hp[j], boss_hp, "it lands")


func test_a_returned_shot_is_capped_and_names_the_ward_when_it_kills() -> void:
	var s := _warded()
	var w: World = s[0]
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 100
	_shoot(w, Vector2(4, 0), 900)
	var back := TwinsLab.until_effect(w, BossWard.REFLECT, 30)
	assert_not_null(back)
	if back == null:
		return
	assert_eq(back.amount, 20, "at most 20 % of the hero's max HP")
	w.actors.hp[0] = 5
	w.actors.invuln[0] = 0
	TwinsLab.idle(w, 40)
	assert_true(w.player_dead())
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_MIRROR")


func test_a_swing_into_the_ward_is_blocked_and_pushes_back_and_a_beam_is_blocked() -> void:
	var s := _warded()
	var w: World = s[0]
	var j := _i(w, s[2])
	w.actors.set_pos(0, Vector2(2, 0))
	var boss_hp := w.actors.hp[j]
	var seq := TwinsLab.mark(w)
	assert_eq(TwinsLab.hit(w, s[2], 80, w.player_pos(), SimEvent.TAG_MELEE), 0, "blocked")
	assert_almost_eq(w.player_pos(), Vector2(4, 0), Vector2(0.001, 0.001), "pushed back 2 m")
	var blocks := TwinsLab.effects(w, BossWard.BLOCK, seq)
	assert_eq(blocks.size(), 1)
	assert_eq(blocks[0].amount, 2000, "mm")
	assert_eq(TwinsLab.hit(w, s[2], 80, w.player_pos(), SimEvent.TAG_MELEE), 0)
	assert_almost_eq(w.player_pos(), Vector2(4, 0), Vector2(0.001, 0.001), "once a tick")
	assert_eq(TwinsLab.hit(w, s[2], 80, w.player_pos(), 0), 0, "a beam from the front is blocked")
	assert_eq(TwinsLab.hit(w, s[2], 80, w.player_pos(), SimEvent.TAG_AREA), 0, "and a blast")
	assert_eq(w.projectiles.size(), 0, "nothing is sent back for them")
	assert_eq(w.actors.hp[j], boss_hp)
	var tagged := false
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.HIT and e.target_id == s[2]:
			tagged = (e.tags & SimEvent.TAG_BLOCKED) != 0
	assert_true(tagged, "the hit sparks off (TAG_BLOCKED)")
	assert_gt(TwinsLab.hit(w, s[2], 80, Vector2(0, -3), SimEvent.TAG_MELEE), 0, "from the side")


# --- Shadow Swords ------------------------------------------------------------------------------------------------


func test_five_swords_show_0_8_s_then_cut_0_2_s_apart_and_leave_rifts() -> void:
	var s := _stage(Vector2(3, 0), Vector2(-9, 9), Vector2(-6, 0), 1)
	var w: World = s[0]
	var j := _i(w, s[2])
	var start := w.tick
	BossLab.start(w, j, &"shadow_swords")
	var r := WorldReader.new(w)
	w.step(InputFrame.new())
	var rows: Array = r.boss_wardens()["swords"]
	assert_eq(rows.size(), 5)
	var tg := r.telegraph(j)
	assert_eq(tg["shape"], &"lanes")
	assert_eq((tg["obbs"] as Array).size(), 5, "every line shows")
	for k in 5:
		var row: Dictionary = rows[k]
		var from: Vector2 = row["from"]
		var to: Vector2 = row["to"]
		assert_almost_eq((from - Vector2(3, 0)).length(), 5.0, 0.001, "5 m from the hero")
		assert_almost_eq((to - from).length(), 8.0, 0.001, "8 m long")
		var along := (to - from).normalized()
		var off := (Vector2(3, 0) - from) - along * (Vector2(3, 0) - from).dot(along)
		assert_almost_eq(off.length(), 0.0, 0.001, "through where the hero stood")
		assert_eq(row["half_width"], 0.45)
		assert_eq(row["cut_in"], 48 - 1 + k * 12, "its cut counts down")
	assert_almost_eq(
		rows[2]["from"], Vector2(-2, 0), Vector2(0.001, 0.001), "the middle one her side"
	)
	# The hero walks off the lanes: no cut lands; each leaves its rift
	w.actors.set_pos(0, Vector2(11, 11))
	var cuts := []
	var seq := TwinsLab.mark(w)
	for k in 120:
		w.step(InputFrame.new())
		for e in TwinsLab.effects(w, BossShadowSwords.CUT, seq):
			seq = e.seq
			cuts.append([e.amount, e.tick - start + 1, e.amount_applied])
	assert_eq(cuts, [[0, 48, 0], [1, 60, 0], [2, 72, 0], [3, 84, 0], [4, 96, 0]], "tick-exact")
	assert_eq(r.telegraph(j), {}, "no line left")
	var rifts := r.boss_hazards()
	assert_eq(rifts.size(), 5, "one rift a lane")
	for h: Dictionary in rifts:
		assert_eq(h["radius"], 1.5)
		assert_true(EnemyAi.clear_of_walls(w, h["centre"], 1.5), "clear of walls")
	assert_almost_eq(
		rifts[2]["centre"], Vector2(6, 0), Vector2(0.001, 0.001), "at the lane's far end"
	)
	# A second cast keeps the cap of 5
	BossLab.start(w, _i(w, s[2]), &"shadow_swords")
	TwinsLab.idle(w, 100)
	assert_eq(r.boss_hazards().size(), 5, "at most 5 rifts")


func test_a_sword_cuts_30_and_its_rift_burns_then_goes() -> void:
	var s := _stage(Vector2(3, 0), Vector2(-9, 9), Vector2(-6, 0), 1)
	var w: World = s[0]
	w.actors.max_hp[0] = 1000
	w.actors.hp[0] = 1000
	BossLab.start(w, _i(w, s[2]), &"shadow_swords")
	var lost := []
	for k in 140:
		w.actors.invuln[0] = 0
		var hp := w.actors.hp[0]
		w.step(InputFrame.new())
		if w.actors.hp[0] < hp:
			lost.append(hp - w.actors.hp[0])
	assert_eq(lost, [30, 30, 30, 30, 30], "standing where they cross, every blade cuts")
	# A rift: it warns, then burns the hero standing in it, then is gone after 8 s
	var rift: Dictionary = WorldReader.new(w).boss_hazards()[2]
	w.actors.set_pos(0, rift["centre"])
	w.actors.hp[0] = 1000
	var burned := 0
	for k in 60:
		w.actors.invuln[0] = 0
		w.actors.set_pos(0, rift["centre"])
		w.step(InputFrame.new())
	burned = 1000 - w.actors.hp[0]
	assert_gt(burned, 0, "it burns")
	assert_eq(burned % 8, 0, "8 a burn")
	w.actors.set_pos(0, Vector2(-11, -11))
	TwinsLab.idle(w, 480)
	assert_eq(WorldReader.new(w).boss_hazards(), [], "gone after 8 s")


# --- phase 3: the ward only his charge breaks ---------------------------------------------------------------------


func test_in_phase_three_the_violet_takes_nothing_and_the_amber_takes_hits() -> void:
	var s := _stage(Vector2(6, 0), Vector2(-9, 0), Vector2(0, 6), 2)
	var w: World = s[0]
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	w.step(InputFrame.new())
	var ups := TwinsLab.effects(w, BossWard.UP)
	assert_eq(ups.size(), 1, "the whole ward is told once")
	assert_eq([ups[0].source_id, ups[0].amount_applied], [s[2], 1])
	var r := WorldReader.new(w)
	assert_eq(r.boss_wardens()["ward"]["kind"], &"full")
	assert_true(r.boss_twin(j)["warded"])
	var hp := w.actors.hp[i]
	for from: Vector2 in [Vector2(6, 6), Vector2(-6, 6), Vector2(0, 0), Vector2(0, 12)]:
		assert_eq(TwinsLab.hit(w, s[2], 100, from), 0, "from anywhere")
	assert_eq(Damage.tick_dot(w, j, 50, w.actors.ids[0], w.actors.ids[0], &"burn"), 0, "nor a tick")
	assert_eq(w.actors.hp[i], hp)
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0
	w.actors.set_pos(0, Vector2(-7, 2))  # close: no ranged armour
	assert_eq(TwinsLab.hit(w, s[1], 100, Vector2(-7, 2)), 100, "the amber Warden: as ever")
	assert_false(
		BossTwin.may_use(w, j, TwinsLab.table(w, s[1]).attacks[13]), "no Mirror Ward under it"
	)
	assert_eq(TwinsLab.table(w, s[1]).attacks[13].move, M.MIRROR_WARD)
	TwinsLab.idle(w, 30)
	assert_eq(w.bosses.twin_focus[0], s[1], "the one to hit")


func test_the_long_charge_through_the_violet_breaks_her_ward() -> void:
	# He is at (-9, 0), she at the origin, the hero behind her on his line
	var s := _stage(Vector2(5, 0), Vector2(-9, 0), Vector2.ZERO, 2)
	var w: World = s[0]
	var i := _i(w, s[1])
	var wt := TwinsLab.wardens(w, s[1])
	w.step(InputFrame.new())
	BossLab.start(w, i, &"warden_charge_long")
	w.step(InputFrame.new())
	assert_true(w.objectives.has(ObjectiveMarkers.TWINS_WARD), "the hint, while he winds it up")
	var r := WorldReader.new(w)
	assert_true(r.boss_wardens()["charge"]["breaks"], "she stands on the lane")
	var k := 0
	for m in w.objectives.size():
		if w.objectives.reason_at(m) == ObjectiveMarkers.TWINS_WARD:
			k = m
	assert_eq(w.objectives.entity[k], s[2], "it follows her")
	var broke := TwinsLab.until_effect(w, BossWard.BREAK, 200)
	assert_not_null(broke, "the ward breaks")
	if broke == null:
		return
	assert_eq([broke.source_id, broke.target_id, broke.amount], [s[1], s[2], 300])
	assert_false(w.objectives.has(ObjectiveMarkers.TWINS_WARD))
	i = _i(w, s[1])
	var j := _i(w, s[2])
	assert_eq([w.actors.state[i], w.actors.state[j]], [BossAi.STAGGERED, BossAi.STAGGERED])
	assert_eq(w.bosses.stagger_t[BossAi.entry_of(w, i)], 120, "he is staggered 2 s")
	assert_eq(w.bosses.stagger_t[BossAi.entry_of(w, j)], 300, "she is stunned 5 s")
	assert_true(w.boss_fight.cb_boss.is_empty(), "the charge ended on her: no burst")
	var ward: Dictionary = r.boss_wardens()["ward"]
	assert_eq([ward["kind"], ward["broken"]], [&"", true])
	assert_eq(ward["stun_left"], broke.tick + 300 - w.tick)
	assert_eq(ward["return_in"], broke.tick + 720 - w.tick)
	assert_eq(TwinsLab.effects(w, BossWard.DOWN).size(), 0, "the break is its own event")
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0
	assert_eq(TwinsLab.hit(w, s[2], 100, Vector2(0, 5)), 150, "stunned, she takes 150 %")
	assert_true(r.boss_twin(j)["exposed"])
	w.step(InputFrame.new())
	assert_eq(w.bosses.twin_focus[0], s[2], "she is the one to hit now")
	TwinsLab.idle(w, 119)
	assert_eq(w.actors.state[_i(w, s[1])], S.MOVE, "he is up after 2 s")
	assert_eq(w.actors.state[_i(w, s[2])], BossAi.STAGGERED)
	TwinsLab.idle(w, 180)
	assert_eq(w.actors.state[_i(w, s[2])], S.MOVE, "she is up after 5 s")
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0
	assert_eq(
		TwinsLab.hit(w, s[2], 100, Vector2(0, 5)), 100, "then plain hits until the ward is back"
	)
	var seq := TwinsLab.mark(w)
	var back := TwinsLab.until_effect(w, BossWard.UP, 500, seq)
	assert_not_null(back)
	if back == null:
		return
	assert_eq(back.tick - broke.tick, wt.return_ticks, "the ward returns 12 s after the break")
	assert_eq(TwinsLab.hit(w, s[2], 100, Vector2(0, 5)), 0)


func test_a_charge_that_misses_her_breaks_nothing() -> void:
	var s := _stage(Vector2(5, 0), Vector2(-9, 0), Vector2(0, 6), 2)
	var w: World = s[0]
	var i := _i(w, s[1])
	w.step(InputFrame.new())
	BossLab.start(w, i, &"warden_charge_long")
	w.step(InputFrame.new())
	assert_false(WorldReader.new(w).boss_wardens()["charge"]["breaks"])
	w.actors.set_pos(0, Vector2(5, -11))
	_until_state(w, s[1], S.RECOVER, 300, Vector2(5, -11))
	assert_eq(TwinsLab.effects(w, BossWard.BREAK), [])
	assert_eq(TwinsLab.hit(w, s[2], 100, Vector2(0, 0)), 0, "still warded")
	assert_eq(
		TwinsLab.effects(w, BossChargeBurst.ARMED).size(), 1, "and it bursts at its end as ever"
	)


# --- Through the Rift ---------------------------------------------------------------------------------------------


## Phase 3 at half its bar with the set piece on. Returns the fight.
func _rift_fight(hero := Vector2(0, -8)) -> Array:
	var s := _stage(hero, Vector2(-9, 0), Vector2(9, 6), 2)
	var w: World = s[0]
	TwinsLab.wardens(w, s[1]).rift_hp_permille = 500
	return s


func test_the_rifts_open_once_at_half_the_last_bar() -> void:
	var s := _rift_fight()
	var w: World = s[0]
	TwinsLab.idle(w, 30)
	assert_eq(TwinsLab.effects(w, BossRift.OPENED), [], "not above half the last bar")
	TwinsLab.set_hp(w, s[1], 166)
	var opened := TwinsLab.until_effect(w, BossRift.OPENED, 5)
	assert_not_null(opened, "at half the last bar")
	if opened == null:
		return
	assert_eq(opened.source_id, s[2], "the violet Warden opens them")
	var rift: Dictionary = WorldReader.new(w).boss_wardens()["rift"]
	assert_eq(rift["stage"], BossRift.OPEN)
	var rifts: Array = rift["rifts"]
	assert_eq(rifts.size(), 3)
	for a in 3:
		var ca: Vector2 = rifts[a]["centre"]
		assert_true(EnemyAi.clear_of_walls(w, ca, 1.2 + 1.0), "clear of walls")
		assert_true(w.bosses.arena.has_point(ca))
		assert_false(rifts[a]["exit"], "no exit shown")
		for b in range(a + 1, 3):
			assert_gte(ca.distance_to(rifts[b]["centre"]), 8.0, "at least 8 m apart")


func test_he_runs_in_comes_out_of_another_and_the_exit_shows_for_the_last_half_second() -> void:
	var s := _rift_fight()
	var w: World = s[0]
	var wt := TwinsLab.wardens(w, s[1])
	w.actors.max_hp[0] = 100
	w.actors.hp[0] = 100
	TwinsLab.set_hp(w, s[1], 166)
	var opened := TwinsLab.until_effect(w, BossRift.OPENED, 5)
	assert_not_null(opened)
	if opened == null:
		return
	var r := WorldReader.new(w)
	var i := _i(w, s[1])
	var entered := TwinsLab.until_effect(w, BossRift.ENTER, 300)
	assert_not_null(entered, "he runs into a rift")
	if entered == null:
		return
	assert_gte(entered.tick - opened.tick, wt.rift_open_ticks, "after they have shown 1 s")
	var rift: Dictionary = r.boss_wardens()["rift"]
	var entry := -1
	var nearest := 0
	for k in 3:
		var c: Vector2 = rift["rifts"][k]["centre"]
		if rift["rifts"][k]["entry"]:
			entry = k
		if (
			c.distance_to(Vector2(-9, 0))
			< (rift["rifts"][nearest]["centre"] as Vector2).distance_to(Vector2(-9, 0))
		):
			nearest = k
	assert_eq(entry, nearest, "the nearest one")
	assert_true(rift["inside"])
	assert_true(r.boss_hidden(i), "he is gone")
	assert_true(BossAi.passes_through(w, i), "and in nobody's way")
	assert_eq(TwinsLab.hit(w, s[1], 100, Vector2(0, 0)), 0, "untouchable")
	# The exit is not shown until the last 0.5 s
	var shown_at := -1
	var exit := -1
	for k in wt.rift_inside_ticks + 2:
		w.actors.set_pos(0, Vector2(0, -8))
		w.step(InputFrame.new())
		rift = r.boss_wardens()["rift"]
		if rift.is_empty() or rift["stage"] != BossRift.INSIDE:
			break
		for n in 3:
			if rift["rifts"][n]["exit"] and shown_at < 0:
				shown_at = w.tick
				exit = n
	assert_eq(
		shown_at - entered.tick, wt.rift_inside_ticks - wt.rift_mark_ticks, "0.5 s before he is out"
	)
	assert_ne(exit, entry, "another rift")
	var marks := TwinsLab.effects(w, BossRift.MARK)
	assert_eq(marks.size(), 1)
	var out := TwinsLab.until_effect(w, BossRift.EXIT, 5)
	assert_not_null(out)
	if out == null:
		return
	assert_eq(out.tick - entered.tick, wt.rift_inside_ticks, "1.5 s inside")
	assert_eq(out.tick - marks[0].tick, 30)
	i = _i(w, s[1])
	var from: Vector2 = rift["rifts"][exit]["centre"]
	assert_almost_eq(out.pos, from, Vector2(0.001, 0.001), "out of the marked rift")
	assert_eq(
		w.actors.lock_a[i], Kin.angle_of(Vector2(0, -8) - from), "toward where the hero stood"
	)
	assert_eq(BossAi.attack_of(w, i).id, &"rift_charge")
	assert_eq(w.actors.state[i], S.ACTIVE, "charging at once")
	assert_false(r.boss_hidden(i))
	# The hero stays put: the charge and its burst, and neither takes more than 40 % of its HP
	var biggest := 0
	for k in 120:
		w.actors.invuln[0] = 0
		w.actors.set_pos(0, Vector2(0, -8))
		var hp := w.actors.hp[0]
		w.step(InputFrame.new())
		biggest = maxi(biggest, hp - w.actors.hp[0])
		w.actors.hp[0] = 100
	assert_eq(biggest, 40, "one hit: 40 % of max HP")
	assert_eq(TwinsLab.effects(w, BossChargeBurst.BURST).size(), 1, "the exit charge bursts")
	assert_eq(TwinsLab.effects(w, BossRift.CLOSED).size(), 1, "then the rifts close")
	assert_eq(r.boss_wardens()["rift"], {})
	TwinsLab.idle(w, 600)
	assert_eq(TwinsLab.effects(w, BossRift.OPENED).size(), 1, "once a fight")


func test_the_exit_charge_through_her_breaks_the_ward() -> void:
	var s := _rift_fight()
	var w: World = s[0]
	TwinsLab.set_hp(w, s[1], 166)
	assert_not_null(TwinsLab.until_effect(w, BossRift.MARK, 600), "the exit is marked")
	var rift: Dictionary = WorldReader.new(w).boss_wardens()["rift"]
	assert_true(rift.has("lane"), "its lane shows with the mark")
	var lane: Array = rift["lane"]
	# She is put on the exit's lane, 4 m along it
	var along := ((lane[1] as Vector2) - (lane[0] as Vector2)).normalized()
	w.actors.set_pos(_i(w, s[2]), (lane[0] as Vector2) + along * 4.0)
	assert_not_null(
		TwinsLab.until_effect(w, BossWard.BREAK, 200), "the ward breaks as in a long charge"
	)
	assert_eq(w.actors.state[_i(w, s[2])], BossAi.STAGGERED)


func test_the_exit_is_drawn_from_the_ai_stream() -> void:
	var exits := {}
	for sv in [3, 4, 5, 6, 7, 8, 9, 10]:
		var s := _stage(Vector2(0, -8), Vector2(-9, 0), Vector2(9, 6), 2, sv)
		var w: World = s[0]
		TwinsLab.wardens(w, s[1]).rift_hp_permille = 500
		TwinsLab.set_hp(w, s[1], 166)
		assert_not_null(TwinsLab.until_effect(w, BossRift.ENTER, 400), "seed %d" % sv)
		assert_ne(w.boss_fight.wd_rift_out, w.boss_fight.wd_rift_in)
		exits[w.boss_fight.wd_rift_out] = true
	assert_eq(exits.size(), 2, "either of the other two, by the seed")


# --- the hash, a save and the end ---------------------------------------------------------------------------------


## A fight left to itself with a hero that walks and shoots, through all three phases.
func _free_fight(seed_value: int, ticks: int) -> World:
	var s := TwinsLab.fight(Vector2(-6, 2), Vector2.ZERO, seed_value)
	var w: World = s[0]
	for k in ticks:
		var i := _i(w, s[1])
		if i < 0:
			break
		if k == 600:
			TwinsLab.set_hp(w, s[1], 668)
		elif k == 1500:
			TwinsLab.set_hp(w, s[1], 334)
		elif k == 2400:
			TwinsLab.set_hp(w, s[1], 166)
		var to := w.actors.pos(BossTwin.partner_of(w, i)) - w.player_pos()
		var mv := Vector2i(60, 40) if k % 180 < 90 else Vector2i(-60, -30)
		w.step(InputFrame.make(mv, Kin.angle_of(to), 600, InputFrame.SHOOT, 0))
	return w


func test_the_whole_fight_is_deterministic_and_its_state_is_hashed() -> void:
	var a := _free_fight(21, 3000)
	var b := _free_fight(21, 3000)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree through the three phases")
	assert_gte(a.boss_fight.wd_boss, 0, "the Wardens run their mechanics")
	for f: StringName in [&"wd_mirror_until", &"wd_break_at", &"wd_dash_cd", &"wd_rift_stage"]:
		var before := a.state_hash()
		var was: int = a.boss_fight.get(f)
		a.boss_fight.set(f, was + 7)
		assert_ne(a.state_hash(), before, "%s is hashed" % f)
		a.boss_fight.set(f, was)
	var plain := BossLab.world()
	var h := plain.state_hash()
	plain.boss_fight.wd_dash_cd = 5
	assert_eq(plain.state_hash(), h, "a world without the Wardens hashes as before")


func test_a_save_mid_fight_restores_every_piece() -> void:
	# Saved in the middle of phase 2 and in phase 3 just after the last bar reached its half
	for at: int in [1100, 2530]:
		var a := _free_fight(21, at)
		var snap := WorldSnapshot.take(a)
		var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), _free_fight(21, 1))
		assert_not_null(restored, "restores at tick %d" % at)
		if restored == null:
			return
		assert_eq(restored.state_hash(), a.state_hash(), "same hash restored")
		for f: StringName in BossFightStore.WD_FIELDS:
			assert_eq(restored.boss_fight.get(f), a.boss_fight.get(f), String(f))
		assert_eq(restored.boss_fight.wd_rift_x, a.boss_fight.wd_rift_x)
		assert_eq(restored.boss_fight.cb_at, a.boss_fight.cb_at)
		for k in 400:
			var f := (
				InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
			)
			a.step(f)
			restored.step(f)
		assert_eq(restored.state_hash(), a.state_hash(), "same hash 400 ticks on (from %d)" % at)


func test_everything_goes_when_the_fight_ends() -> void:
	var s := _rift_fight()
	var w: World = s[0]
	TwinsLab.set_hp(w, s[1], 166)
	assert_not_null(TwinsLab.until_effect(w, BossRift.OPENED, 5))
	BossHazard.place(w, _i(w, s[2]), Vector2(4, 4))
	BossChargeBurst.arm(
		w, _i(w, s[1]), TwinsLab.table(w, s[1]).attack_index(&"warden_charge"), Vector2(2, 2)
	)
	w.boss_fight.wd_mirror_until = w.tick + 100
	w.boss_fight.wd_mirror_on = 1
	assert_false(w.boss_fight.wd_rift_x.is_empty())
	TwinsLab.set_hp(w, s[1], 1)
	TwinsLab.hit(w, s[1], 50, Vector2(-9, 3))
	w.step(InputFrame.new())
	assert_false(w.boss_alive(), "the pair fell")
	var bs := w.bosses
	var fs := w.boss_fight
	assert_eq(fs.wd_boss, -1)
	assert_eq([fs.wd_rift_stage, fs.wd_mirror_on, fs.wd_full, fs.wd_dash_t], [0, 0, 0, 0])
	assert_true(fs.wd_rift_x.is_empty() and fs.cb_boss.is_empty() and bs.hz_x.is_empty())
	assert_true(bs.twin_lead.is_empty())
	assert_eq(w.objectives.size(), 0, "no hint left")
	var r := WorldReader.new(w)
	assert_eq(r.boss_wardens(), {})
	assert_eq(r.boss_charge_bursts(), [])


func test_the_hero_s_death_ends_the_set_piece_and_the_bursts() -> void:
	var s := _rift_fight()
	var w: World = s[0]
	TwinsLab.set_hp(w, s[1], 166)
	assert_not_null(TwinsLab.until_effect(w, BossRift.ENTER, 400))
	BossChargeBurst.arm(
		w, _i(w, s[1]), TwinsLab.table(w, s[1]).attack_index(&"warden_charge"), Vector2(2, 2)
	)
	w.actors.hp[0] = 0
	w.actors.dead[0] = 1
	w.step(InputFrame.new())
	assert_eq(w.boss_fight.wd_rift_stage, BossRift.NONE)
	assert_true(w.boss_fight.cb_boss.is_empty())
	assert_false(BossAi.hidden(w, _i(w, s[1])), "he is back")
