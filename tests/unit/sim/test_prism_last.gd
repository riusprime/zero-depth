extends GutTest
## v0.10.5 O3 (owner L6, 2026-11-01: "we still have to work on the last phase"; "Needs something cooler while he's
## down and not on the dodging pattern"; "Boring pattern"; O3_PRISM.md): the Prism's last phase in the sim. From 50 %
## HP her rotation brings the Facet Lances (each lance tracks, holds locked at least the telegraph minimum, then
## strikes once along its lane; she is shielded throughout) and right after them the Shattered Kneel (down, open,
## hits on her core up close ×1.5; her crack fills with the HP she loses and bursts for bonus damage, and she rises).

const LONG := 1 << 24
const LAST: Array[StringName] = [
	&"cross_ring",
	&"crown_spiral",
	&"facet_lances",
	&"prism_kneel",
	&"cross_flower",
	&"crown_flower"
]


func _prism(seed_value: int = 41) -> World:
	var w := FinalLab.arena(FinalLab.run_state(seed_value))
	w.actors.invuln[0] = LONG
	FinalLab.past_rise(w)
	FinalBoss.jump(w, 1)
	FinalLab.past_rise(w)
	return w


func _start(w: World, id: StringName) -> BossAttackTable:
	var i := FinalLab.body(w)
	BossAi.start_attack(w, i, BossAi.table_of(w, i).attack_index(id))
	return BossAi.attack_of(w, i)


## Steps until the attack in progress is `st` ticks into its active time.
func _to_active(w: World, st: int = 0, f: InputFrame = null) -> void:
	var i := FinalLab.body(w)
	for k in 600:
		if w.actors.state[i] == EnemyAi.State.ACTIVE and w.actors.state_t[i] >= st:
			return
		w.step(f if f != null else InputFrame.new())


func _poke(w: World, i: int) -> int:
	var pid := w.actors.ids[0]
	var at := w.actors.pos(i)
	var before := w.actors.hp[i]
	w.actors.invuln[i] = 0
	Damage.hit(w, i, 20, pid, pid, w.take_root(), 0, at, at)
	return before - w.actors.hp[i]


# --- the data ---------------------------------------------------------------------------------------------------


func test_her_last_phase_is_in_data() -> void:
	var w := _prism()
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 500]), "her last phase from 50 % HP")
	var listed: Array[StringName] = []
	for k in t.phase_attacks[1]:
		listed.append(t.attacks[k].id)
	assert_eq(listed, LAST, "the lances and the kneel replace the plain orb ring")
	var l := t.attacks[t.attack_index(&"facet_lances")]
	assert_eq(l.move, BossAttackTable.Move.LANCES)
	assert_eq(l.count, 6, "one lance per shard")
	assert_true(l.shielded, "shielded while she throws them")
	assert_gte(
		l.lock_ticks, BehaviourSchemas.MIN_TELEGRAPH_TICKS, "each lance shows locked long enough"
	)
	assert_gt(l.mark_gap_ticks, l.strike_ticks, "one lance strikes at a time")
	assert_gte(l.active_ticks, BossPrismLast.strike_tick(l, l.count - 1) + l.strike_ticks)
	var k := t.attacks[t.attack_index(&"prism_kneel")]
	assert_eq(k.move, BossAttackTable.Move.KNEEL)
	assert_false(k.shielded, "the kneel is her opening")
	assert_eq([k.crack_permille, k.burst_permille, k.core_mult_permille], [80, 50, 1500])


func test_the_last_phase_starts_at_half_hp_with_no_gate() -> void:
	var w := _prism(42)
	var i := FinalLab.body(w)
	var b := BossAi.entry_of(w, i)
	w.actors.hp[i] = w.actors.max_hp[i] / 2 - 1
	w.step(InputFrame.new())
	assert_eq(w.bosses.phase[b], 1, "her last phase")
	assert_ne(w.actors.state[i], BossAi.GATE, "no gate: no pause, no adds")
	var order: Array[StringName] = []
	var last := -1
	for n in 6000:
		w.step(FinalLab.walk(w, Vector2(-4, 3) if (n / 240) % 2 == 0 else Vector2(3, 4)))
		var k := w.bosses.attack[b]
		if k >= 0 and k != last and w.actors.state[i] == EnemyAi.State.WINDUP:
			order.append(BossAi.table_of(w, i).attacks[k].id)
			last = k
		if order.size() >= LAST.size() + 1:
			break
	gut.p("O3 last-phase order: %s" % [order])
	for n in LAST.size():
		assert_eq(order[n], LAST[n], "spell %d of her last rotation" % n)


# --- the Facet Lances -------------------------------------------------------------------------------------------


func test_each_lance_tracks_then_holds_locked_then_strikes() -> void:
	var w := _prism(43)
	var i := FinalLab.body(w)
	var b := BossAi.entry_of(w, i)
	var atk := _start(w, &"facet_lances")
	assert_true(BossPrismLast.state(w, i)["winding"])
	assert_true((BossPrismLast.state(w, i)["lances"] as Array).is_empty(), "no lance in the gather")
	assert_eq((BossPrismLast.state(w, i)["rims"] as PackedVector2Array).size(), 6)
	_to_active(w)
	var spot := Vector2(-3, 2)
	w.actors.set_pos(0, spot)
	for k in atk.count:
		assert_eq(BossPrismLast.lance_phase(atk, k, k * atk.mark_gap_ticks), BossPrismLast.TRACKING)
		var locked := k * atk.mark_gap_ticks + atk.track_ticks
		assert_eq(BossPrismLast.lance_phase(atk, k, locked), BossPrismLast.LOCKED)
		assert_eq(BossPrismLast.strike_tick(atk, k) - locked, atk.lock_ticks)
		assert_gte(
			atk.lock_ticks, BehaviourSchemas.MIN_TELEGRAPH_TICKS, "lance %d locked >= 0.4 s" % k
		)
		assert_eq(
			BossPrismLast.lance_phase(atk, k, BossPrismLast.strike_tick(atk, k)),
			BossPrismLast.STRIKING
		)
	# lance 0 follows the player while it tracks, then holds where it locked
	for n in atk.track_ticks - 2:
		w.actors.set_pos(0, spot + Vector2(0.02 * n, 0))
		w.step(InputFrame.new())
	assert_almost_eq(w.bosses.pt(b, 0).x, w.player_pos().x, 0.05, "it follows")
	var held := w.bosses.pt(b, 0)
	_to_active(w, atk.track_ticks + 3)
	w.actors.set_pos(0, spot + Vector2(3, 3))
	w.step(InputFrame.new())
	assert_eq(w.bosses.pt(b, 0), held, "it holds where it locked")
	var s := BossPrismLast.state(w, i)
	var phases: Array = (s["lances"] as Array).map(func(x: Dictionary) -> int: return x["phase"])
	assert_has(phases, BossPrismLast.LOCKED, "a locked line shows")
	assert_true(BossDodge.shielded(w, i), "shielded while the lances fly")


func test_a_lance_hits_on_its_line_and_misses_a_sidestep() -> void:
	for dodge: bool in [false, true]:
		var w := _prism(44)
		var i := FinalLab.body(w)
		var atk := _start(w, &"facet_lances")
		var spot := Vector2(-4, 1)
		w.actors.set_pos(0, spot)
		_to_active(w, 0, FinalLab.walk(w, spot))
		_to_active(w, atk.track_ticks + 1)
		var o := BossPrismLast.lane(w, i, atk, 0)
		var side := Kin.dir((o.angle + 1024) & 4095)
		var to := (
			w.player_pos() + side * (o.half.y + w.player.radius_m + 0.3)
			if dodge
			else w.player_pos()
		)
		w.actors.invuln[0] = 0
		var hp := w.actors.hp[0]
		var hits := 0
		for n in BossPrismLast.strike_tick(atk, 0) + atk.strike_ticks - w.actors.state_t[i]:
			w.actors.set_pos(0, to)
			w.step(InputFrame.new())
			if w.actors.hp[0] < hp:
				hits += 1
				hp = w.actors.hp[0]
		if dodge:
			assert_eq(hits, 0, "a sidestep out of the locked lane is safe")
		else:
			assert_eq(hits, 1, "the lance hits once on its line")


func test_the_lances_name_their_death() -> void:
	var w := _prism(45)
	var t := BossAi.table_of(w, FinalLab.body(w))
	assert_eq(t.attacks[t.attack_index(&"facet_lances")].cause_key, &"CAUSE_PRISM_LANCE")
	assert_ne(tr("CAUSE_PRISM_LANCE"), "CAUSE_PRISM_LANCE", "the line is in strings.csv")


# --- the Shattered Kneel ----------------------------------------------------------------------------------------


func test_she_is_down_and_open_while_she_kneels_and_her_core_takes_more() -> void:
	var w := _prism(46)
	var i := FinalLab.body(w)
	var atk := _start(w, &"prism_kneel")
	assert_eq(BossPrismLast.kneel_state(w, i)["stage"], 0, "she falls")
	_to_active(w, 2)
	assert_true(BossPrismLast.kneeling(w, i))
	assert_false(BossDodge.shielded(w, i), "open while she kneels")
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(w.actors.radius[i] + 1.0, 0))
	assert_eq(
		BossChallenge.hit_mult(w, i),
		[1500, SimEvent.TAG_EXPOSED] as Array[int],
		"her core, up close"
	)
	w.actors.set_pos(0, w.actors.pos(i) + Vector2(w.actors.radius[i] + 6.0, 0))
	assert_eq(BossChallenge.hit_mult(w, i)[0], 1000, "not from afar")
	assert_gt(_poke(w, i), 0)
	var st := w.actors.state_t[i]
	while w.actors.state[i] == EnemyAi.State.ACTIVE:
		w.step(InputFrame.new())
		st += 1
	assert_eq(st, atk.active_ticks, "without the crack filled she stays down the whole time")
	assert_eq(BossPrismLast.kneel_state(w, i)["stage"], 2, "then rises")
	assert_eq(BossPrismLast.kneel_state(w, i)["burst_tick"], -1, "no burst")


func test_the_crack_fills_and_her_core_bursts() -> void:
	var w := _prism(47)
	var i := FinalLab.body(w)
	var atk := _start(w, &"prism_kneel")
	_to_active(w, 1)
	var max_hp := w.actors.max_hp[i]
	var need := max_hp * atk.crack_permille / 1000
	FinalLab.hit(w, need / 2)
	assert_almost_eq(BossPrismLast.crack(w, i), 500, 2, "half cracked")
	assert_true(BossPrismLast.kneeling(w, i))
	FinalLab.hit(w, need - need / 2)
	var hp := w.actors.hp[i]
	w.step(InputFrame.new())
	var burst := false
	for e in w.events_since(-1):
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossPrismLast.EFFECT_BURST:
			burst = true
	assert_true(burst, "the burst's event for the views")
	assert_eq(hp - w.actors.hp[i], max_hp * atk.burst_permille / 1000, "the burst's bonus damage")
	assert_eq(BossPrismLast.crack(w, i), 1000)
	w.step(InputFrame.new())
	assert_eq(w.actors.state[i], EnemyAi.State.RECOVER, "she rises at once")
	assert_gte(BossPrismLast.kneel_state(w, i)["burst_tick"], 0)


func test_the_last_phase_is_deterministic() -> void:
	var a := _prism(48)
	var b := _prism(48)
	for w: World in [a, b]:
		var i := FinalLab.body(w)
		w.actors.hp[i] = w.actors.max_hp[i] / 2 - 1
	for k in 2400:
		var f := FinalLab.walk(a, Vector2(-6, 6) if (k / 120) % 2 == 0 else Vector2(6, -2))
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash())
