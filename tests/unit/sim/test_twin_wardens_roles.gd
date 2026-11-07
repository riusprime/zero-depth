# gdlint: disable=max-public-methods
extends GutTest
## v0.11.0 O5 (owner L7; Q11 a: "P1 should be yellow p2 purple p3 both at the same time"; Q29: "a full bar per
## phase … total paced to 1–2 min"; BossTwin's roles): the Twin Wardens' two movesets and three phases. Phase 1 the
## amber Warden leads with its physical moveset and the violet stands back (hits on it spark off, it casts a bolt every
## 4 s); phase 2 they swap; phase 3 both fight, their attacks alternating and never overlapping, and every 10 s the
## exposed Warden swaps (×1.5 taken, the other ×0.5). Each phase starts on a full bar. Deterministic. TEST_MATRIX (a
## boss step): a scripted player beats it two ways, a melee Blade and a ranged Gun; the fight lengths are printed.

const S := EnemyAi.State
const LONG := 1 << 20
const Pace := preload("res://tests/unit/sim/test_boss_pace.gd")
## The duels' limit (ticks): 4 minutes.
const LIMIT_TICKS := 60 * 240
const YELLOW := [
	&"shield_bash", &"chain_sweep", &"chain_sweep_fast", &"warden_charge", &"ground_slam"
]
const VIOLET := [&"crossfire", &"crossfire_3", &"orb_volley", &"rune_ring", &"blink"]


## The Wardens at boss_at past their rise in the boss lab, the player at player_at (huge HP): [world, boss, twin].
func _fight(player_at: Vector2, boss_at := Vector2.ZERO, room := 10.0, seed_value := 11) -> Array:
	var w := BossLab.world(seed_value)
	if room > 0.0:
		var t := 0.5
		var walls: Array[Obb] = [
			Obb.make(Vector2(room + t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(-room - t, 0), Vector2(t, room + 2.0 * t), 0),
			Obb.make(Vector2(0, room + t), Vector2(room + 2.0 * t, t), 0),
			Obb.make(Vector2(0, -room - t), Vector2(room + 2.0 * t, t), 0),
		]
		w.set_walls(walls)
		w.bosses.arena = Rect2(-room, -room, room * 2.0, room * 2.0)
	w.actors.set_pos(0, player_at)
	var i := BossLab.ready_boss(w, &"twin_wardens", boss_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i], w.actors.ids[BossTwin.partner_of(w, i)]]


func _i(w: World, aid: int) -> int:
	return w.actors.index_of(aid)


func _hit(w: World, target_id: int, amount: int) -> int:
	var me := w.actors.ids[0]
	var i := _i(w, target_id)
	return Damage.hit(
		w, i, amount, me, me, w.take_root(), 0, w.actors.pos(i) + Vector2(-1, 0), w.actors.pos(i)
	)


## Drops the pair onto phase `phase`'s gate (its HP at that threshold), then steps through the gate.
func _to_phase(w: World, boss_id: int, phase: int) -> void:
	var i := _i(w, boss_id)
	var t := BossAi.table_of(w, i)
	var hp := t.phase_threshold[phase] * w.actors.max_hp[i] / 1000
	w.actors.hp[i] = hp
	w.actors.hp[BossTwin.partner_of(w, i)] = hp
	w.step(InputFrame.new())
	BossLab.through_gate(w, boss_id)


## [boss starts, twin starts] over `ticks` ticks of a player standing at `at`, each [tick, attack id, first windup
## tick, last active tick]; and the overlapping windups+strikes as ticks where both were busy.
func _starts(w: World, ids: Array, ticks: int, at: Vector2) -> Array:
	var out := [[], []]
	var last := [-1, -1]
	var both := 0
	for k in ticks:
		w.actors.set_pos(0, at)
		w.step(InputFrame.new())
		var busy := 0
		for n in 2:
			var j := _i(w, ids[n])
			if j < 0:
				return [out[0], out[1], both]
			var b := BossAi.entry_of(w, j)
			var now := w.bosses.attack[b]
			var s := w.actors.state[j]
			if now >= 0 and (s == S.WINDUP or s == S.ACTIVE):
				busy += 1
				if s == S.WINDUP and w.actors.state_t[j] == 1:
					out[n].append(BossAi.table_of(w, j).attacks[now].id)
			last[n] = now
		if busy == 2:
			both += 1
	return [out[0], out[1], both]


func test_the_two_movesets_are_the_owner_rows() -> void:
	var repo := ContentRepository.load_all()
	var def: BossDefinition = repo.get_def(&"bosses", &"twin_wardens")
	assert_eq(def.validate(), [], "valid")
	var t := ContentCompiler.compile_boss(def, repo)
	assert_eq(t.phase_threshold, PackedInt32Array([1000, 667, 333]), "three bars of a third")
	for id: StringName in YELLOW:
		assert_false(t.attacks[t.attack_index(id)].twin_body, "%s: the amber Warden's" % id)
	for id: StringName in VIOLET:
		assert_true(t.attacks[t.attack_index(id)].twin_body, "%s: the violet Warden's" % id)
	var moves := {}
	for id: StringName in YELLOW + VIOLET:
		moves[id] = t.attacks[t.attack_index(id)].move
	assert_eq(moves[&"warden_charge"], BossAttackTable.Move.CHARGE, "the charge: the Warlord's run")
	assert_eq(moves[&"ground_slam"], BossAttackTable.Move.MARKS, "the slam: the Gatekeeper's mark")
	assert_eq(moves[&"orb_volley"], BossAttackTable.Move.PATTERN, "the volley: a fan pattern")
	assert_eq(
		moves[&"rune_ring"], BossAttackTable.Move.SLAM_RING, "the rune ring: a ring, safe inside"
	)
	assert_gt(t.attacks[t.attack_index(&"rune_ring")].inner_radius_m, 0.0)
	assert_eq(moves[&"blink"], BossAttackTable.Move.LEAP, "the blink: a short hop")
	assert_false(t.attacks[t.attack_index(&"crossfire")].shielded, "owner L3: no shield")
	assert_eq(t.twin_bolt, t.attack_index(&"warden_bolt"), "the bolt from the one standing back")
	assert_eq(t.twin_bolt_ticks, 240, "every 4 s")
	assert_eq(
		[t.twin_expose_ticks, t.twin_expose_permille, t.twin_guard_permille], [600, 1500, 500]
	)
	for k in t.phase_attacks.size():
		var ids := Array(t.phase_attacks[k]).map(func(x: int) -> StringName: return t.attacks[x].id)
		assert_false(ids.has(&"warden_bolt"), "the bolt is never picked")
	var en := TranslationServer.get_translation_object("en")
	var es := TranslationServer.get_translation_object("es")
	for id: StringName in YELLOW + VIOLET + [&"warden_bolt"]:
		var key := t.attacks[t.attack_index(id)].cause_key
		assert_ne(String(en.get_message(key)), "", "%s: en line" % id)
		assert_ne(String(es.get_message(key)), "", "%s: es line" % id)
		assert_ne(String(es.get_message(key)), String(key), "%s: es line" % id)


func test_bad_role_numbers_are_errors() -> void:
	var repo := ContentRepository.load_all()
	var fresh := func() -> BossDefinition:
		return (repo.get_def(&"bosses", &"twin_wardens") as BossDefinition).duplicate(true)
	var codes := func(d: BossDefinition) -> Array:
		return d.validate().map(func(v: ValidationIssue) -> StringName: return v.code)
	var def: BossDefinition = fresh.call()
	def.twin_bolt_attack = &""
	assert_has(codes.call(def), &"missing", "the bolt")
	def = fresh.call()
	def.twin_guard_permille = 1000
	assert_has(codes.call(def), &"range", "guarded takes less")
	def = fresh.call()
	def.twin_attack_ids = PackedStringArray(["nope"])
	assert_has(codes.call(def), &"unknown_attack")


func test_phase_one_amber_leads_with_its_moveset_only() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	var r := _starts(w, [s[1], s[2]], 60 * 30, Vector2(-6, 2))
	assert_gte(r[0].size(), 5, "the amber Warden attacks")
	for id in r[0]:
		assert_has(YELLOW, id, "physical only")
	assert_eq(r[1], [], "the violet stands back")
	assert_eq(w.bosses.twin_focus[0], s[1], "the one to hit")


func test_phase_two_violet_leads_with_its_moveset_only() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	_to_phase(w, s[1], 1)
	var r := _starts(w, [s[1], s[2]], 60 * 30, Vector2(-6, 2))
	assert_eq(r[0], [], "the amber stands back")
	assert_gte(r[1].size(), 5, "the violet attacks")
	for id in r[1]:
		assert_has(VIOLET, id, "magic only")
	assert_eq(w.bosses.twin_focus[0], s[2])


func test_phase_three_both_alternate_and_never_overlap() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	_to_phase(w, s[1], 1)
	_to_phase(w, s[1], 2)
	var r := _starts(w, [s[1], s[2]], 60 * 40, Vector2(-6, 2))
	assert_gte(r[0].size(), 3, "the amber attacks")
	assert_gte(r[1].size(), 3, "the violet attacks")
	for id in r[0]:
		assert_has(YELLOW, id)
	for id in r[1]:
		assert_has(VIOLET, id)
	assert_eq(r[2], 0, "never both winding up or striking at once")
	assert_lte(absi(r[0].size() - r[1].size()), 1, "they take turns")


func test_the_exposed_warden_swaps_every_10_s() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	_to_phase(w, s[1], 1)
	_to_phase(w, s[1], 2)
	var i := _i(w, s[1])
	var swaps := []
	var focus := w.bosses.twin_focus[0]
	var seq := w.last_event_seq()
	for k in 60 * 31:
		w.step(InputFrame.new())
		if w.bosses.twin_focus[0] != focus:
			focus = w.bosses.twin_focus[0]
			swaps.append([w.bosses.twin_clock[0], focus])
	assert_eq(swaps, [[600, s[2]], [1200, s[1]], [1800, s[2]]], "every 10 s, the amber first")
	var flagged := 0
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossTwin.EFFECT_FOCUS:
			flagged += 1
	assert_eq(flagged, 3, "each swap is flagged for the views")
	# ×1.5 on the exposed one, ×0.5 on the other (one shared HP).
	i = _i(w, s[1])
	var exposed := w.bosses.twin_focus[0]
	var other: int = s[1] if exposed == s[2] else s[2]
	for e in w.bosses.exposed_t.size():
		w.bosses.exposed_t[e] = 0  # no weak point open (its own ×2): the swap's multipliers alone
	var hp := w.actors.hp[i]
	_hit(w, exposed, 100)
	assert_eq(hp - w.actors.hp[i], 150, "the exposed Warden takes ×1.5")
	hp = w.actors.hp[i]
	_hit(w, other, 100)
	assert_eq(hp - w.actors.hp[i], 50, "the other ×0.5")
	assert_eq(w.objectives.size(), 1, "the hint follows the exposed one")
	assert_eq(w.objectives.entity[0], exposed)


func test_each_phase_starts_on_a_full_bar_and_the_bar_names_its_warden() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	var reader := WorldReader.new(w)
	var i := _i(w, s[1])
	assert_eq(reader.boss_phase_permille(i), 1000, "phase 1: full")
	assert_eq(reader.boss_twin(i).get("phase"), BossTwin.P_YELLOW)
	for p in [1, 2]:
		_to_phase(w, s[1], p)
		i = _i(w, s[1])
		assert_eq(reader.boss_phase_permille(i), 1000, "phase %d: a new full bar" % (p + 1))
		assert_eq(reader.boss_twin(i).get("phase"), p)
	var t := BossAi.table_of(w, i)
	var bars := []
	var th := t.phase_threshold
	for p in 3:
		var hi := th[p] * w.actors.max_hp[i] / 1000
		var lo := th[p + 1] * w.actors.max_hp[i] / 1000 if p + 1 < 3 else 0
		bars.append(hi - lo)
	assert_lte(
		absi(bars[0] - bars[2]), w.actors.max_hp[i] / 500, "three bars of a third: %s" % [bars]
	)
	assert_lte(absi(bars[1] - bars[2]), w.actors.max_hp[i] / 500)


func test_the_one_standing_back_sparks_off_and_casts_a_bolt_every_4_s() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	var i := _i(w, s[1])
	var j := _i(w, s[2])
	assert_true(BossTwin.resting(w, j), "the violet stands back")
	var hp := w.actors.hp[i]
	var seq := w.last_event_seq()
	assert_eq(_hit(w, s[2], 100), 0, "not now: nothing")
	assert_eq(w.actors.hp[i], hp)
	var blocked := false
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.HIT and e.target_id == s[2]:
			blocked = (e.tags & SimEvent.TAG_BLOCKED) != 0
	assert_true(blocked, "the hit sparks off (TAG_BLOCKED)")
	assert_gt(_hit(w, s[1], 100), 0, "the leader takes it")
	seq = w.last_event_seq()
	var bolts := []
	for k in 60 * 13:
		w.step(InputFrame.new())
		for e in w.events_since(seq):
			seq = e.seq
			if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == BossTwin.EFFECT_BOLT:
				bolts.append([e.source_id, w.bosses.twin_clock[0]])
	assert_eq(bolts.size(), 3, "every 4 s: %s" % [bolts])
	for b: Array in bolts:
		assert_eq(b[0], s[2], "the violet casts it")
		assert_eq(int(b[1]) % 240, 0)
	var t := BossAi.table_of(w, i)
	var shots := 0
	for k in w.projectiles.size():
		if w.projectiles.owner[k] == s[2]:
			shots += 1
	assert_gt(shots, 0, "its bolt flies")
	w.killer_kind = ActorStore.Kind.TWIN_WARDEN_VIOLET
	w.killer_attack = t.twin_bolt
	assert_eq(BossAi.cause_key(w), &"CAUSE_TWIN_BOLT", "its death line")
	# Phase 2: the amber stands back and sparks off.
	_to_phase(w, s[1], 1)
	assert_true(BossTwin.resting(w, _i(w, s[1])))
	assert_eq(_hit(w, s[1], 100), 0, "the amber now")
	assert_gt(_hit(w, s[2], 100), 0, "the violet takes it")


func test_the_hint_follows_the_leader_and_clears_when_they_fall() -> void:
	var s := _fight(Vector2(-6, 2))
	var w: World = s[0]
	w.step(InputFrame.new())
	assert_true(w.objectives.has(ObjectiveMarkers.TWINS_ACTIVE))
	assert_eq(w.objectives.entity[0], s[1], "phase 1: the amber")
	_to_phase(w, s[1], 1)
	assert_eq(w.objectives.size(), 1)
	assert_eq(w.objectives.entity[0], s[2], "phase 2: the violet")
	_to_phase(w, s[1], 2)
	assert_eq(w.objectives.entity[0], s[1], "phase 3: the exposed one, the amber first")
	var i := _i(w, s[1])
	w.actors.hp[i] = 5
	w.actors.hp[BossTwin.partner_of(w, i)] = 5
	_hit(w, s[1], 50)
	w.step(InputFrame.new())
	assert_false(w.boss_alive())
	assert_false(w.objectives.has(ObjectiveMarkers.TWINS_ACTIVE), "cleared with the fight")


func test_deterministic_through_the_phases() -> void:
	var make := func() -> World:
		var s := _fight(Vector2(-6, 2))
		var w: World = s[0]
		_to_phase(w, s[1], 1)
		_to_phase(w, s[1], 2)
		return w
	var a: World = make.call()
	var b: World = make.call()
	for k in 60 * 12:
		var f := (
			InputFrame.make(Vector2i(60, 40), 0, 300, 0, 0) if k % 90 < 45 else InputFrame.new()
		)
		a.step(f)
		b.step(f)
	assert_eq(a.state_hash(), b.state_hash(), "two runs agree")
	var before := a.state_hash()
	a.bosses.twin_clock[0] += 1
	assert_ne(a.state_hash(), before, "the roles' clock is hashed")
	a.bosses.twin_clock[0] -= 1
	var restored := World.from_snapshot(
		bytes_to_var(var_to_bytes(WorldSnapshot.take(a))), make.call()
	)
	assert_not_null(restored)
	if restored == null:
		return
	for k in 600:
		a.step(InputFrame.new())
		restored.step(InputFrame.new())
	assert_eq(restored.state_hash(), a.state_hash(), "a save mid phase 3 restores")


# --- TEST_MATRIX: a scripted player beats it two ways -----------------------------------------------------------


## The base hero (runner + `build`), the real tables, unscaled (the data's HP), as test_boss_pace's world.
static func _world(seed_value: int, build: StringName) -> World:
	var repo := ContentRepository.load_all()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", build))
	var w := World.new(seed_value, t)
	w.set_enemy_tables(ContentCompiler.compile_enemies(repo))
	w.set_boss_tables(ContentCompiler.compile_bosses(repo))
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.wand_table = WandCompiler.from_repo(repo)
	w.blade_table = BladeCompiler.from_repo(repo)
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	Heat.enable(w, ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock")))
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	return w


static func _bigs() -> Dictionary:
	var out := {}
	var def: BossDefinition = ContentRepository.load_all().get_def(&"bosses", &"twin_wardens")
	for a in def.attacks:
		if a.hit_class == &"big":
			out[a.id] = true
	return out


## The melee duel: test_boss_pace's BladeRun (it stands at its target's side and swings, dashing out of the big
## attacks), its target the Warden to hit (the hint's). [ticks to kill or -1, [phase 1, 2, 3 lengths], ticks it was
## hit].
static func melee_duel(seed_value: int = 5) -> Array:
	var w := _world(seed_value, &"blade")
	var i := BossLab.ready_boss(w, &"twin_wardens", Vector2(6, 0))
	var boss := w.actors.ids[i]
	var bot = Pace.BladeRun.new(boss, _bigs())
	var phases := [0, 0, 0]
	var n := 0
	var hits := 0
	while n < LIMIT_TICKS:
		i = w.actors.index_of(boss)
		if i < 0 or w.actors.dead[i] == 1:
			return [n, phases, hits]
		var k := BossTwin.pair_of(w, i)
		phases[clampi(w.bosses.twin_phase[k], 0, 2)] += 1
		bot.aid = w.bosses.twin_focus[k] if w.bosses.twin_focus[k] > 0 else boss
		w.actors.hp[0] = w.actors.max_hp[0]
		w.step(bot.frame(w))
		if w.actors.hp[0] < w.actors.max_hp[0]:
			hits += 1
		n += 1
	return [-1, phases, hits]


## The ranged duel: the Gun hero holds Shoot at the Warden to hit from RANGE_M (backing off or closing in), side-steps
## with a dash every 1.5 s; healed every tick like the Blade. Same result shape.
static func ranged_duel(seed_value: int = 5) -> Array:
	var w := _world(seed_value, &"gun")
	var i := BossLab.ready_boss(w, &"twin_wardens", Vector2(6, 0))
	var boss := w.actors.ids[i]
	var phases := [0, 0, 0]
	var n := 0
	var hits := 0
	while n < LIMIT_TICKS:
		i = w.actors.index_of(boss)
		if i < 0 or w.actors.dead[i] == 1:
			return [n, phases, hits]
		var k := BossTwin.pair_of(w, i)
		phases[clampi(w.bosses.twin_phase[k], 0, 2)] += 1
		var target := w.actors.index_of(w.bosses.twin_focus[k])
		if target < 0:
			target = i
		var to := w.actors.pos(target) - w.player_pos()
		var d := maxf(Kin.length(to), 0.001)
		var dir := to / d
		var mv := Vector2.ZERO
		if d > 7.0:
			mv = dir
		elif d < 5.0:
			mv = -dir
		var pressed := 0
		if n % 90 == 45:
			pressed = InputFrame.DASH
			mv = Vector2(-dir.y, dir.x) * (1.0 if (n / 90) % 2 == 0 else -1.0)
		var f := InputFrame.make(
			Vector2i(roundi(mv.x * 127.0), roundi(mv.y * 127.0)),
			Kin.angle_of(to),
			int(d * 100.0),
			InputFrame.SHOOT,
			pressed
		)
		w.actors.hp[0] = w.actors.max_hp[0]
		w.step(f)
		if w.actors.hp[0] < w.actors.max_hp[0]:
			hits += 1
		n += 1
	return [-1, phases, hits]


func test_a_melee_player_beats_it_in_one_to_two_minutes() -> void:
	var r := melee_duel()
	var ph: Array = r[1]
	print(
		(
			"TWIN_DUEL| melee ticks=%d seconds=%.1f phases_s=[%.1f, %.1f, %.1f] hits_taken=%d"
			% [r[0], r[0] / 60.0, ph[0] / 60.0, ph[1] / 60.0, ph[2] / 60.0, r[2]]
		)
	)
	assert_gt(int(r[0]), 0, "the Blade beats the Wardens")
	assert_between(int(r[0]), 60 * 60, 60 * 120, "owner Q29: 1-2 minutes")
	for p in 3:
		assert_gt(int(ph[p]), 60 * 10, "phase %d is fought" % (p + 1))


func test_a_ranged_player_beats_it_too() -> void:
	var r := ranged_duel()
	var ph: Array = r[1]
	print(
		(
			"TWIN_DUEL| ranged ticks=%d seconds=%.1f phases_s=[%.1f, %.1f, %.1f] hits_taken=%d"
			% [r[0], r[0] / 60.0, ph[0] / 60.0, ph[1] / 60.0, ph[2] / 60.0, r[2]]
		)
	)
	assert_gt(int(r[0]), 0, "the Gun beats the Wardens")
	assert_lte(int(r[0]), LIMIT_TICKS)
