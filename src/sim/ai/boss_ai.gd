class_name BossAi
extends RefCounted
## The boss framework (PLAN v0.3.0 C; BLUEPRINT §F). A boss is an actor (its own ActorStore kind) with a BossStore
## entry. Movements: pursuit (MOVE), an attack (WINDUP -> ACTIVE) and recovery (RECOVER, the punish window). Hits
## fill a stagger meter; a full meter staggers it (STAGGERED) and resets. Phases start at HP thresholds; a phase may
## open with an entry attack. think() runs in tick phase 3, move() in 5, resolve() in 6.
## Every attack's area comes from one function here (ring_of, lane_of, arc_of, EnemyAi.charge_lane, leap_disc,
## burrow_disc, spots_of, rail_of, fan_lane_of, flood_lane_of), which telegraph() hands the view and resolve() hits
## with (EI-07).
## Randomness only from the ai stream.
## Boss challenge (v0.3.0 BX; BossChallenge): the far timer starts the punish attack, an attack may chain into its
## follow-up instead of recovering, some recoveries open the weak point, aimed attacks lead the player, a pull drags
## the player during its windup, and the closing band hurts in phase 6.
## v0.5.5 DS (D7): each phase after the first opens with a gate (BossGates: a short invulnerable transition, the HP
## can't fall past it in one burst, adds rise); the hidden catch-up scales the boss (CatchUp.on_boss, powered).
## v0.7.5 BF1 (owner N15; BOSS_FIGHTS.md; SIM_CONTRACTS §10d): dodge-first fights. A `pattern` attack fires a bullet
## pattern (BulletPatterns) over its active time; `marks` and `row_lanes` lay ground markers that follow the player's
## exact position, lock for the attack's lock_ticks and strike (mark_of, row_lanes_of); any aimed attack with a lock
## tracks the exact position the same way (no lead) and its telegraph says when it locked; a shielded attack (the
## signature pattern) keeps the boss shielded while it runs (BossDodge: hits spark off, Damage).
## v0.7.5 BF2: a burrow with a lock lays its eruption circle on the player's exact position while it tracks, locks it,
## burrows to it and may burst a ring of shots from it; a `marks` attack with a pattern bursts it from each circle
## as it strikes (eggs; BossDodge.burst_mark).
## v0.7.5 BF3: `grid` (a checkerboard of tracked circles struck in alternating colours) and `row_flood` (molten
## lanes along the player's row, tracked then locked, standing like a flood): BossDodge.grid_discs, row_flood_of.
## v0.8.0 BS1 (owner O5): each boss's signature mechanic (BossSignatures): the Gatekeeper's pillars, the Warlord's
## recalled javelins, the Brood Mother's eggs. v0.8.0 BS2: `gaze` (the Hive Lens's sweeping beam, BossGaze) and
## `melt` (the Foundry's meltdown, BossLava); the Siege Engine's ricochets (BossRicochet) and the Foundry's lava are
## params on `pattern`, `deploy` and `row_flood`.
## v0.8.0 FB1 (owner O16-O17; FINAL_BOSS.md F3-F4): the final boss's bodies are bosses (is_boss_kind); the Colossus's
## `combo`, `spike_chase` and `spike_burst` (BossColossus), and a `leap` with a pattern fires it where it lands. A body
## whose segment ran out shatters (FinalBoss.SHATTER): it stands still, invulnerable, until FinalBoss replaces it.
## v0.8.0 FB2 (FINAL_BOSS.md F5, F7): the Prism's `cross` (BossPrism: the turning beams, her shards' orbs and bolts, the
## window between spins); a body with a Cross floats home instead of pursuing (BossPrism.drift).
## v0.8.0 FB3 (FINAL_BOSS.md F6, F7): a mimic body (the Nemesis) is BossNemesis's: its dash, stance and three moves.

## Appended after EnemyAi.State (SPAWN, MOVE, WINDUP, ACTIVE, RECOVER).
const STAGGERED := 5
## v0.5.5 DS (D7): a phase gate's transition (BossGates): invulnerable, still, the adds rising.
const GATE := 6
## A boss rises for this long before it acts (invulnerable meanwhile; starting value, 1.0 s).
const INTRO_TICKS := 60
## After a stagger, a short pause before it attacks again.
const AFTER_STAGGER_CD := 30
## A spawned egg or turret keeps this far from walls.
const SPOT_CLEARANCE := 0.45

const S := EnemyAi.State
const M := BossAttackTable.Move
## Moves whose windup follows the player until it commits (v0.3.5 AI); the rest lock where they start.
const TRACKING_MOVES: Array[int] = [
	BossAttackTable.Move.LANES,
	BossAttackTable.Move.SWEEP,
	BossAttackTable.Move.CHARGE,
	BossAttackTable.Move.LEAP,
	BossAttackTable.Move.BARRAGE,
	BossAttackTable.Move.RAIL,
	BossAttackTable.Move.BOLT_FAN,
	BossAttackTable.Move.FLOOD,
	BossAttackTable.Move.PATTERN,  # v0.7.5 BF1: a pattern's aim (and a burst's landing) follows until it commits
	BossAttackTable.Move.GRID,  # v0.7.5 BF3: the board's centre, then the flood's row, follow until they lock
	BossAttackTable.Move.ROW_FLOOD,
]


static func is_boss_kind(kind: int) -> bool:
	return (
		kind == ActorStore.Kind.GATEKEEPER
		or kind == ActorStore.Kind.BROOD_MOTHER
		or kind == ActorStore.Kind.SIEGE_ENGINE
		or (kind >= ActorStore.Kind.WARLORD and kind <= ActorStore.Kind.FOUNDRY)  # v0.4.0 BO
		or (kind >= ActorStore.Kind.COLOSSUS and kind <= ActorStore.Kind.NEMESIS)
	)  # v0.8.0 FB1


## The BossStore entry of actor i (-1 if it isn't a boss).
static func entry_of(w: World, i: int) -> int:
	return w.bosses.index_of(w.actors.ids[i])


static func table_of(w: World, i: int) -> BossTable:
	return w.boss_tables[w.bosses.table[entry_of(w, i)]]


## The attack in progress (null if none).
static func attack_of(w: World, i: int) -> BossAttackTable:
	var b := entry_of(w, i)
	if b < 0 or w.bosses.attack[b] < 0:
		return null
	return w.boss_tables[w.bosses.table[b]].attacks[w.bosses.attack[b]]


# --- phase 3 ----------------------------------------------------------------------------------------------------


static func think(w: World, i: int) -> void:
	var a := w.actors
	var bs := w.bosses
	var b := entry_of(w, i)
	var t: BossTable = w.boss_tables[bs.table[b]]
	a.state_t[i] += 1
	if a.cd[i] > 0:
		a.cd[i] -= 1
	if a.state[i] != GATE and a.state[i] != FinalBoss.SHATTER and a.dead[i] == 0:
		_update_phase(w, i, b, t)  # v0.5.5 DS: a boss killed between ticks opens no gate (FB1: nor a shattering one)
	BossChallenge.think(w, i, b, t)
	if a.state[i] != STAGGERED:
		bs.meter[b] = maxi(0, bs.meter[b] - t.stagger_decay_milli)
	if t.mimic and w.final_fight != null:  # v0.8.0 FB3: the build read, a dash due, the stance's clock
		BossNemesis.think(w, i, t)
	var to_player := w.player_pos() - a.pos(i)
	var aim := Kin.angle_of(to_player)
	match a.state[i]:
		S.SPAWN:
			if a.state_t[i] >= w.tuning.boss_intro_ticks:
				EnemyAi.enter_state(a, i, S.MOVE)
		GATE:
			BossGates.advance(w, i, b)
		FinalBoss.SHATTER:
			pass  # v0.8.0 FB1: FinalBoss runs the shatter (tick phase 9)
		STAGGERED:
			bs.stagger_t[b] -= 1
			if bs.stagger_t[b] <= 0:
				bs.stagger_t[b] = 0
				EnemyAi.enter_state(a, i, S.MOVE)
				a.cd[i] = maxi(a.cd[i], w.tuning.boss_after_stagger_cd)
		S.MOVE:
			a.facing[i] = (
				aim if t.turn_rate <= 0 else Kin.turn_toward(a.facing[i], aim, t.turn_rate)
			)
			var punish := BossChallenge.punish_due(w, b, t)
			var gap := BossChallenge.gap_close_due(w, b, t)  # v0.3.5 AI (F3): the gap-closer
			if punish >= 0:
				start_attack(w, i, punish)
				bs.far_t[b] = 0
			elif gap >= 0:
				start_attack(w, i, gap)
				bs.gap_t[b] = 0
			elif not w.player_dead() and a.cd[i] == 0 and not BossNemesis.dashing(w, i):
				var k := _choose(w, b, t, Kin.length(to_player))
				if k >= 0:
					start_attack(w, i, k)
		S.WINDUP:
			var atk: BossAttackTable = t.attacks[bs.attack[b]]
			if BossDodge.is_marker_move(atk.move):  # v0.7.5 BF1: each marker tracks, then locks
				BossDodge.track_marks(w, b, atk, a.state_t[i])
			elif atk.move == M.GAZE:  # v0.8.0 BS2 (S4): it starts aimed away from you, wherever you go
				BossGaze.keep_away(w, i)
			elif atk.move == M.CROSS:  # v0.8.0 FB2: the arms keep you between two of them
				BossPrism.keep_away(w, i)
			elif atk.move == M.COMBO:  # v0.8.0 FB1: the swing follows you until it locks
				BossColossus.combo_think(w, i, atk, a.state_t[i])
			elif atk.move == M.SPIKE_CHASE:  # v0.8.0 FB1: the chasing spikes are laid
				BossColossus.chase_think(w, i, b, atk, a.state_t[i])
			elif BossNemesis.is_move(atk.move):  # v0.8.0 FB3: its swing, lines and card follow, then lock
				BossNemesis.think_attack(w, i, b, atk, a.state_t[i])
			elif tracking(w, i, t, atk):  # v0.3.5 AI (F3): aim follows the player until it commits
				_track(w, i, b, atk)
			if a.state_t[i] >= atk.windup_ticks:
				EnemyAi.enter_state(a, i, S.ACTIVE)
				a.fire_cd[i] = 0
				if atk.move == M.LEAP or atk.move == M.BURROW:
					a.invuln[i] = maxi(a.invuln[i], 2)
				if BossDodge.tracked_burrow(atk):  # v0.7.5 BF2: its eruption circle starts on you
					bs.set_pt(b, 0, w.player_pos())
		S.ACTIVE:
			var atk: BossAttackTable = t.attacks[bs.attack[b]]
			if BossDodge.is_marker_move(atk.move):  # v0.7.5 BF1: the later markers keep tracking
				BossDodge.track_marks(w, b, atk, atk.windup_ticks + a.state_t[i])
			elif atk.move == M.COMBO:  # v0.8.0 FB1: each later swing (and the slam) follows, then locks
				BossColossus.combo_think(w, i, atk, atk.windup_ticks + a.state_t[i])
			elif atk.move == M.SPIKE_CHASE:
				BossColossus.chase_think(w, i, b, atk, atk.windup_ticks + a.state_t[i])
			elif BossNemesis.is_move(atk.move):  # v0.8.0 FB3: each later swing follows, then locks
				BossNemesis.think_attack(w, i, b, atk, atk.windup_ticks + a.state_t[i])
			_think_active(w, i, b, atk)
		S.RECOVER:
			var atk: BossAttackTable = t.attacks[bs.attack[b]]
			BossColossus.leap_late_waves(w, i, atk, a.state_t[i])  # v0.8.0 N2: a ring's later waves
			if a.state_t[i] >= atk.recover_ticks:
				EnemyAi.enter_state(a, i, S.MOVE)
				a.cd[i] = atk.cooldown_ticks * t.phase_cd_permille[bs.phase[b]] / 1000
				bs.attack[b] = -1
				BossNemesis.after_attack(w, i, atk)  # v0.8.0 FB3: after a combo it backs off


static func _think_active(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var a := w.actors
	var bs := w.bosses
	match atk.move:
		M.CHARGE:
			if a.lock_len[i] <= 0.0:
				_finish(w, i, b, atk)
		M.LEAP:
			a.invuln[i] = maxi(a.invuln[i], 2)  # airborne
			if a.state_t[i] >= atk.active_ticks:
				if bs.step[b] + 1 < atk.chain and not w.player_dead():
					bs.step[b] += 1
					bs.hit[b] = 0
					EnemyAi.enter_state(a, i, S.WINDUP)
					_lock(w, i, b, atk)
				else:
					a.invuln[i] = 0
					_finish(w, i, b, atk)
		M.BURROW:
			if bs.step[b] < 2:
				a.invuln[i] = maxi(a.invuln[i], 2)  # underground
			var tracked := BossDodge.tracked_burrow(atk)
			if tracked and bs.step[b] == 0 and not w.player_dead():
				bs.set_pt(b, 0, w.player_pos())  # v0.7.5 BF2: the eruption circle is on you
			if bs.step[b] == 0 and a.state_t[i] >= atk.track_ticks:
				bs.step[b] = 1
				a.state_t[i] = 0
				var at := bs.pt(b, 0) if tracked else a.pos(i)
				a.lock_x[i] = at.x
				a.lock_y[i] = at.y
			elif bs.step[b] == 1 and a.state_t[i] >= atk.erupt_ticks:
				bs.step[b] = 2
				a.state_t[i] = 0
				a.invuln[i] = 0
			elif bs.step[b] == 2 and a.state_t[i] >= BossDodge.eruption_ticks(atk):
				_finish(w, i, b, atk)  # v0.7.5 BF2: after its eruption's burst
		M.RAIL:
			a.facing[i] = rail_angle(w, i, mini(a.state_t[i] + 1, atk.active_ticks)) & 4095
			if a.state_t[i] >= atk.active_ticks:
				_finish(w, i, b, atk)
		M.BOLT_FAN:
			if bs.step[b] >= atk.volleys and a.state_t[i] >= atk.active_ticks:
				_finish(w, i, b, atk)
		M.GAZE:  # v0.8.0 BS2 (S4): the eye looks along its beam
			a.facing[i] = BossGaze.angle_at(w, i, mini(a.state_t[i] + 1, atk.active_ticks - 1))
			if a.state_t[i] >= atk.active_ticks:
				_finish(w, i, b, atk)
		M.CROSS:  # v0.8.0 FB2: she watches the player while her Cross turns
			if not w.player_dead():
				a.facing[i] = Kin.angle_of(w.player_pos() - a.pos(i))
			if a.state_t[i] >= atk.active_ticks:
				_finish(w, i, b, atk)
		_:
			if a.state_t[i] >= atk.active_ticks:
				_finish(w, i, b, atk)


## The end of an attack (BX, L26): its follow-up starts at once when one is set, the roll (ai stream) passes and the
## player is in its range band (a follow-up never chains again); otherwise the boss recovers, and the recovery of an
## attack that opens the weak point opens it (L17).
static func _finish(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var a := w.actors
	var bs := w.bosses
	var t: BossTable = w.boss_tables[bs.table[b]]
	if atk.follow_up >= 0 and bs.chained[b] == 0 and not w.player_dead():
		var nxt := t.attacks[atk.follow_up]
		var dist := Kin.length(w.player_pos() - a.pos(i))
		if (
			dist >= nxt.min_range_m
			and dist <= nxt.max_range_m
			and w.rng_ai.range_int(0, 999) < atk.follow_up_permille
		):
			start_attack(w, i, atk.follow_up)
			bs.chained[b] = 1
			return
	EnemyAi.enter_state(a, i, S.RECOVER)
	if atk.opens_weak and t.weak_ticks > 0:
		bs.exposed_t[b] = t.weak_ticks


## The phase for the current HP: the last one whose threshold the HP has fallen to. Phases only advance, and (v0.5.5
## DS, D7) one at a time: each new phase opens with its gate (BossGates.begin), its entry attack after it.
static func _update_phase(w: World, i: int, b: int, t: BossTable) -> void:
	var a := w.actors
	var target := 0
	for k in t.phase_threshold.size():
		if a.hp[i] * 1000 <= t.phase_threshold[k] * a.max_hp[i]:
			target = k
	if target > w.bosses.phase[b]:
		var next := w.bosses.phase[b] + 1
		w.bosses.phase[b] = next
		w.bosses.entry[b] = t.phase_entry[next]
		BossGates.begin(w, i, b, next)


## The next attack: the phase's entry attack if one waits, else a weighted pick (ai stream) among the phase's attacks
## whose range band holds the player, not repeating the last one when there is a choice. -1 = none in range.
static func _choose(w: World, b: int, t: BossTable, dist: float) -> int:
	var bs := w.bosses
	if bs.entry[b] >= 0:
		var e := bs.entry[b]
		bs.entry[b] = -1
		return e
	var open := PackedInt32Array()
	for k in t.phase_attacks[bs.phase[b]]:
		var atk := t.attacks[k]
		if dist < atk.min_range_m or dist > atk.max_range_m:
			continue
		if atk.move == M.BROOD and _alive_of(w, atk.enemy_kind) >= atk.max_alive:
			continue
		if t.mimic and not BossNemesis.allowed(w, atk):  # v0.8.0 FB3: the run's weapon, the cards held
			continue
		open.append(k)
	if open.size() > 1 and open.has(bs.last_attack[b]):
		open.remove_at(open.find(bs.last_attack[b]))
	if open.is_empty():
		return -1
	var weights := PackedInt32Array()
	for k in open:
		weights.append(t.attacks[k].weight)
	var pick := w.rng_ai.pick_weighted(weights)
	return open[pick] if pick >= 0 else -1


## Starts attack k now (its windup), locking its aim and areas. Public for tests and the dev panel.
static func start_attack(w: World, i: int, k: int) -> void:
	var a := w.actors
	var bs := w.bosses
	var b := entry_of(w, i)
	var atk: BossAttackTable = w.boss_tables[bs.table[b]].attacks[k]
	EnemyAi.enter_state(a, i, S.WINDUP)
	bs.attack[b] = k
	bs.last_attack[b] = k
	bs.step[b] = 0
	bs.hit[b] = 0
	bs.chained[b] = 0
	_lock(w, i, b, atk)


## Locks where the attack goes, from where the boss and the player are now.
static func _lock(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var a := w.actors
	var bs := w.bosses
	var at := a.pos(i)
	var target := _target(w, b, atk)  # BX (L26): aimed moves lead the player (v0.7.5 BF1: not a locked one).
	var aim := Kin.angle_of(target - at)
	a.lock_x[i] = at.x
	a.lock_y[i] = at.y
	a.lock_a[i] = aim
	a.lock_len[i] = 0.0
	a.facing[i] = aim
	match atk.move:
		M.LANES:
			for k in atk.count:
				var ang := lane_angle(atk, aim, k)
				var start := at + Kin.dir(ang) * a.radius[i]
				bs.pts_x[b * BossStore.MAX_PTS + k] = EnemyAi.clear_run(
					w, start, ang, atk.length_m, atk.half_width_m
				)
		M.FLOOD:  # v0.4.0 BO: each parallel lane's length, cut short by walls.
			for k in atk.count:
				bs.pts_x[b * BossStore.MAX_PTS + k] = EnemyAi.clear_run(
					w, _flood_start(w, i, atk, aim, k), aim, atk.length_m, atk.half_width_m
				)
		M.BOLT_FAN:
			for k in atk.count:
				var ang := lane_angle(atk, aim, k)
				var start := at + Kin.dir(ang) * (a.radius[i] + atk.radius_m + 0.05)
				bs.pts_x[b * BossStore.MAX_PTS + k] = EnemyAi.clear_run(
					w, start, ang, atk.speed * atk.bolt_life_ticks, atk.radius_m
				)
		M.CHARGE:
			a.lock_len[i] = EnemyAi.clear_run(w, at, aim, atk.length_m, a.radius[i])
		M.LEAP:
			var to := target - at
			var d := Kin.length(to)
			if d > atk.length_m and d > 0.0:
				target = at + to * (atk.length_m / d)
			bs.set_pt(b, 0, target)
		M.BROOD, M.DEPLOY:
			var base := aim + 1024 if atk.move == M.DEPLOY else aim + 2048 / atk.count
			for k in atk.count:
				bs.set_pt(b, k, spot(w, at, base + k * 4096 / atk.count, atk.distance_m))
		M.BARRAGE:
			bs.set_pt(b, 0, target)
			var s := int(atk.spread_m * 100.0)
			for k in range(1, atk.count):
				var off := Vector2(w.rng_ai.range_int(-s, s), w.rng_ai.range_int(-s, s)) / 100.0
				bs.set_pt(b, k, target + off)
		M.RAIL:
			var dir := 1 if w.rng_ai.range_int(0, 1) == 0 else -1
			a.lock_a[i] = (aim - dir * atk.half_arc) & 4095
			a.facing[i] = a.lock_a[i]
			bs.span[b] = dir * atk.half_arc * 2
		M.PATTERN, M.GRID, M.ROW_FLOOD:  # v0.7.5 BF1/BF3: a burst's landing, a board's or a row's centre
			bs.set_pt(b, 0, target)
		M.MARKS, M.ROW_LANES:  # v0.7.5 BF1: every marker starts on the player
			for k in atk.count:
				bs.set_pt(b, k, w.player_pos())
		M.GAZE:  # v0.8.0 BS2 (S4): aimed away from the player; the way it turns
			BossGaze.lock(w, i, b)
		M.CROSS:  # v0.8.0 FB2: its way (the other way from her last), its speed (her HP), off the player
			BossPrism.lock(w, i, b)
		M.SPIKE_CHASE, M.SPIKE_BURST:  # v0.8.0 FB1: no chase line has stopped yet
			BossColossus.spikes_lock(w, b)
		M.MIMIC_COMBO, M.MIMIC_SHOTS, M.CARD_CAST:  # v0.8.0 FB3: at the player; a card's blast on them
			BossNemesis.lock(w, i, b, atk)


## True while boss i's windup still follows the player (v0.3.5 AI, F3): an aimed move, before its last
## commit_ticks.
static func tracking(w: World, i: int, t: BossTable, atk: BossAttackTable) -> bool:
	var commit := atk.lock_ticks if atk.lock_ticks > 0 else t.commit_ticks  # v0.7.5 BF1: the attack's lock
	if commit <= 0 or w.player_dead() or w.actors.state[i] != S.WINDUP:
		return false
	if w.actors.state_t[i] >= atk.windup_ticks - commit:
		return false
	return TRACKING_MOVES.has(atk.move)


## v0.7.5 BF1: where an attack aims: the player's exact position for a locked attack (owner N15: "follow exact
## position of the player"), else BossChallenge.aim_point (the lead and the dash read).
static func _target(w: World, b: int, atk: BossAttackTable) -> Vector2:
	return w.player_pos() if atk.lock_ticks > 0 else BossChallenge.aim_point(w, b, atk.move)


## Re-aims the windup in progress at the player (aim_point), keeping what was drawn at random: a barrage's
## scatter moves with its centre, a rail keeps its sweep direction.
static func _track(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var a := w.actors
	var bs := w.bosses
	match atk.move:
		M.BARRAGE:
			var shift := _target(w, b, atk) - bs.pt(b, 0)
			for k in atk.count:
				bs.set_pt(b, k, bs.pt(b, k) + shift)
		M.RAIL:
			var aim := Kin.angle_of(_target(w, b, atk) - a.pos(i))
			var dir := 1 if bs.span[b] > 0 else -1
			a.lock_a[i] = (aim - dir * atk.half_arc) & 4095
			a.facing[i] = a.lock_a[i]
		_:
			_lock(w, i, b, atk)


## v0.5.5 DS (D4, D7): an attack's damage under boss i's hidden catch-up (ActorStore.power, per mille; CatchUp.on_boss
## sets it, 0 = unscaled). The enemies' rule, rounded half up (audit G-12).
static func powered(w: World, i: int, amount: int) -> int:
	return EnemyAi.powered(w, i, amount)


## v0.8.0 BP (owner O27): the damage of each orb or shot attack `atk`'s bullet pattern fires (its orb_damage when set,
## else its damage), under boss i's catch-up.
static func orb_damage(w: World, i: int, atk: BossAttackTable) -> int:
	return powered(w, i, atk.orb_damage if atk.orb_damage > 0 else atk.damage)


## A spawn spot `dist` from `at` along `angle`, pulled in until it is clear of walls (or `at` itself). Public:
## BossGates' adds use it too.
static func spot(w: World, at: Vector2, angle: int, dist: float) -> Vector2:
	for k in 4:
		var p := at + Kin.dir(angle) * (dist * (4 - k) / 4.0)
		if EnemyAi.clear_of_walls(w, p, SPOT_CLEARANCE):
			return p
	return at


# --- phase 5 ----------------------------------------------------------------------------------------------------


static func move(w: World, i: int) -> void:
	var a := w.actors
	var at := a.pos(i)
	var slow := ItemProcs.slow_factor(w, i)
	if BossPrism.floats(w, i):  # v0.8.0 FB2: the Prism floats home, whatever she does
		BossPrism.drift(w, i, slow)
		return
	if BossNemesis.moves(w, i, slow):  # v0.8.0 FB3: its dash, its stance, its combo's steps in
		return
	match a.state[i]:
		S.MOVE:
			var b := entry_of(w, i)
			var t: BossTable = w.boss_tables[w.bosses.table[b]]
			var speed := t.speed * t.phase_speed_permille[w.bosses.phase[b]] / 1000.0 * slow
			var to := w.player_pos() - at
			var dist := Kin.length(to)
			if speed <= 0.0 or w.player_dead() or dist <= 0.0001:
				return
			if dist <= maxf(t.keep_distance_m, t.radius_m + w.player.radius_m + 0.1):
				return
			a.set_pos(i, at + EnemyAi.steer(w, at, to / dist, t.radius_m) * speed)
			if not w.bosses.melt_boss.is_empty():  # v0.8.0 BS2 (S6): the Foundry keeps to cool ground
				BossLava.keep_on_ground(w, i)
		S.WINDUP:
			var atk := attack_of(w, i)
			if atk != null and atk.move == M.PULL:
				BossChallenge.drag(w, i, atk)  # BX (L17): the vortex drags the player in.
			elif atk != null and atk.move == M.COMBO:  # v0.8.0 FB1: it steps in as the swing follows
				BossColossus.combo_move(w, i, atk, slow)
		S.ACTIVE:
			var atk := attack_of(w, i)
			match atk.move:
				M.COMBO:  # v0.8.0 FB1
					BossColossus.combo_move(w, i, atk, slow)
				M.CHARGE:
					if a.lock_len[i] > 0.0:
						var step := minf(atk.speed * slow, a.lock_len[i])
						a.lock_len[i] -= step
						a.set_pos(i, at + Kin.dir(a.lock_a[i]) * step)
				M.LEAP:
					var from := Vector2(a.lock_x[i], a.lock_y[i])
					var f := minf(1.0, float(a.state_t[i] + 1) / atk.active_ticks)
					a.set_pos(i, from + (leap_disc(w, i)[0] - from) * f)
				M.BURROW:
					var step := w.bosses.step[entry_of(w, i)]
					if step == 1 and BossDodge.tracked_burrow(atk):  # v0.7.5 BF2: to its locked eruption
						var to := Vector2(a.lock_x[i], a.lock_y[i]) - at
						var dist := Kin.length(to)
						if dist > 0.0001:
							a.set_pos(i, at + to * (minf(atk.speed * slow, dist) / dist))
					elif step == 0 and not w.player_dead():
						var to := w.player_pos() - at
						var dist := Kin.length(to)
						if dist > 0.0001:
							a.set_pos(i, at + to * (minf(atk.speed * slow, dist) / dist))


## True while the boss is in the air (a leap) or underground (a burrow): walls and bodies don't stop it.
static func passes_through(w: World, i: int) -> bool:
	if not is_boss_kind(w.actors.kinds[i]) or w.actors.state[i] != S.ACTIVE:
		return false
	var atk := attack_of(w, i)
	if atk == null:
		return false
	if atk.move == M.LEAP:
		return true
	return atk.move == M.BURROW and w.bosses.step[entry_of(w, i)] < 2


## Underground (a burrow before it erupts): the view hides the body.
static func hidden(w: World, i: int) -> bool:
	var atk := attack_of(w, i)
	return (
		atk != null
		and atk.move == M.BURROW
		and w.actors.state[i] == S.ACTIVE
		and w.bosses.step[entry_of(w, i)] < 2
	)


# --- phase 6 ----------------------------------------------------------------------------------------------------


static func resolve(w: World, i: int) -> void:
	var a := w.actors
	BossChallenge.resolve_arena(w, i)  # BX (L17): the closing band.
	if a.state[i] != S.ACTIVE or w.player_dead():
		return
	var b := entry_of(w, i)
	var atk := attack_of(w, i)
	var p := w.player_pos()
	var pr := w.player.radius_m
	var st := a.state_t[i]
	match atk.move:
		M.SLAM_RING, M.PULL:
			var r := ring_of(w, i)
			if st == 0 and AttackShapes.ring_touches(r[0], r[1], r[2], p, pr):
				hit_player(w, i, atk, SimEvent.TAG_AREA, r[0])
		M.LANES:
			if st < atk.active_ticks:
				for k in atk.count:
					var s := lane_slice(w, i, k, st)
					if s != null and Collide.circle_vs_obb(p, pr, s) != Vector2.ZERO:
						hit_player(w, i, atk, SimEvent.TAG_AREA, a.pos(i))
						break
		M.SWEEP:
			var c := arc_of(w, i)
			if st == 0 and AttackShapes.arc_touches(c[0], c[1], c[2], c[3], c[4], p, pr):
				hit_player(w, i, atk, SimEvent.TAG_MELEE, c[0])
		M.CHARGE:
			# v0.3.5 AI: within a contact slop, because phase 5 has already pushed the bodies exactly apart.
			if Kin.length(p - a.pos(i)) <= a.radius[i] + pr + EnemyAi.CONTACT_SLOP_M:
				hit_player(w, i, atk, SimEvent.TAG_MELEE, a.pos(i))
		M.LEAP:
			var d := leap_disc(w, i)
			if st == atk.active_ticks - 1 and AttackShapes.disc_touches(d[0], d[1], p, pr):
				hit_player(w, i, atk, SimEvent.TAG_AREA, d[0])
			if st == atk.active_ticks - 1 and atk.pattern != null:  # v0.8.0 FB1: its shockwave ring
				BossColossus.leap_wave(w, i, atk, d[0])
		M.BURROW:
			var d := burrow_disc(w, i)
			if w.bosses.step[b] == 2 and st == 0 and AttackShapes.disc_touches(d[0], d[1], p, pr):
				hit_player(w, i, atk, SimEvent.TAG_AREA, d[0])
			if w.bosses.step[b] == 2:  # v0.7.5 BF2: its ring of globs bursts out of the eruption
				BossDodge.burst_eruption(w, i, atk, d[0], st)
		M.BROOD, M.DEPLOY, M.BARRAGE:
			if st == 0:
				var spots := spots_of(w, i)
				for c: Vector2 in spots:
					if AttackShapes.disc_touches(c, atk.radius_m, p, pr):
						hit_player(w, i, atk, SimEvent.TAG_AREA, c)
						break
				if atk.move != M.BARRAGE:
					_hatch(w, atk, spots)
		M.RAIL:
			if st < atk.active_ticks:
				var r := rail_of(w, i)
				var a0 := rail_angle(w, i, st)
				var a1 := rail_angle(w, i, st + 1)
				if AttackShapes.span_touches(r[0], r[1], a0, a1 - a0, r[4], p, pr):
					hit_player(w, i, atk, SimEvent.TAG_AREA, r[0])
		M.FLOOD, M.ROW_FLOOD:  # v0.4.0 BO: the lanes stay for the active time and hurt every burn_ticks.
			if st < atk.active_ticks:
				if st % atk.burn_ticks == 0:
					w.bosses.hit[b] = 0
				for k in atk.count:
					var o := (
						flood_lane_of(w, i, k)
						if atk.move == M.FLOOD
						else BossDodge.row_flood_of(w, i, k)
					)
					if Collide.circle_vs_obb(p, pr, o) != Vector2.ZERO:
						hit_player(w, i, atk, SimEvent.TAG_AREA, a.pos(i))
						break
				if st == atk.active_ticks - 1 and atk.lava_ticks > 0:  # v0.8.0 BS2 (S6): it stays molten
					BossLava.lay(w, i, atk)
		M.BOLT_FAN:
			if w.bosses.step[b] < atk.volleys and st % atk.gap_ticks == 0:
				w.bosses.step[b] += 1
				_fire_fan(w, i, b, atk)
		M.PATTERN:  # v0.7.5 BF1
			BossDodge.resolve_pattern(w, i, b, atk, st)
		M.MARKS, M.ROW_LANES:  # v0.7.5 BF1: each marker strikes once, where it locked
			BossDodge.resolve_marks(w, i, b, atk, st)
		M.GRID:  # v0.7.5 BF3: each volley strikes its colour of the locked board
			BossDodge.resolve_grid(w, i, b, atk, st)
		M.GAZE:  # v0.8.0 BS2 (S4): the beam turns round the room; its orbs fly
			BossGaze.resolve(w, i, b, atk, st)
		M.CROSS:  # v0.8.0 FB2: the Cross turns, the orbs fly, the bolts aim and fire
			BossPrism.resolve(w, i, b, atk, st)
		M.MELT:  # v0.8.0 BS2 (S6): the outer ring melts for good
			if st == 0:
				BossLava.begin_melt(w, i)
		M.COMBO:  # v0.8.0 FB1: each swing, then the slam, where it locked
			BossColossus.combo_resolve(w, i, b, atk, st)
		M.SPIKE_CHASE, M.SPIKE_BURST:  # v0.8.0 FB1: the spikes due erupt
			BossColossus.spikes_resolve(w, i, b, atk, st)
		M.MIMIC_COMBO, M.MIMIC_SHOTS, M.CARD_CAST:  # v0.8.0 FB3: its swings, volleys and cards
			BossNemesis.resolve(w, i, b, atk, st)


static func _fire_fan(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	var a := w.actors
	for k in atk.count:
		var ang := lane_angle(atk, a.lock_a[i], k)
		var dir := Kin.dir(ang)
		var muzzle := Vector2(a.lock_x[i], a.lock_y[i]) + dir * (a.radius[i] + atk.radius_m + 0.05)
		w.queue_projectile(
			a.ids[i],
			ActorStore.TEAM_ENEMY,
			muzzle,
			dir * atk.speed,
			powered(w, i, atk.damage),
			atk.radius_m,
			atk.bolt_life_ticks,
			SimEvent.TAG_PROJECTILE
		)
	w.bosses.hit[b] = 1


## Eggs hatch and turrets land: one enemy per spot, a brood capped at max_alive.
static func _hatch(w: World, atk: BossAttackTable, spots: PackedVector2Array) -> void:
	if w.enemy_table(atk.enemy_kind) == null:
		return
	var room := (
		atk.max_alive - _alive_of(w, atk.enemy_kind) if atk.move == M.BROOD else spots.size()
	)
	for k in mini(room, spots.size()):
		w.queue_enemy(atk.enemy_kind, spots[k])


## v0.8.0 BS1: actors of `kind` alive or arriving this tick (eggs count; BossSignatures caps its eggs with it).
static func alive_of(w: World, kind: int) -> int:
	return _alive_of(w, kind)


static func _alive_of(w: World, kind: int) -> int:
	var n := w.pending_enemies_of(kind)
	for i in range(1, w.actors.size()):
		if w.actors.kinds[i] == kind and w.actors.dead[i] == 0:
			n += 1
	return n


## Hits the player with boss i's attack, once per attack (BossStore.hit); public for BossDodge (v0.7.5 BF1).
static func hit_player(w: World, i: int, atk: BossAttackTable, tags: int, from: Vector2) -> void:
	var b := entry_of(w, i)
	if w.bosses.hit[b] == 1:
		return
	w.bosses.hit[b] = 1
	var a := w.actors
	var dmg := powered(w, i, atk.damage)  # v0.5.5 DS: the hidden catch-up
	Damage.hit(w, 0, dmg, a.ids[i], a.ids[i], w.take_root(), tags, from, w.player_pos())
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = w.bosses.attack[b]


# --- stagger ----------------------------------------------------------------------------------------------------


## Damage (not damage over time) on a boss fills its stagger meter; a full meter staggers it: its attack stops,
## it can't act for stagger_ticks, and the meter resets. Emits STATUS_APPLY (effect &"boss_stagger").
static func on_damage(w: World, i: int, applied: int, tags: int = 0) -> void:
	var a := w.actors
	if not is_boss_kind(a.kinds[i]) or a.dead[i] == 1 or applied <= 0:
		return
	if a.state[i] == STAGGERED or a.state[i] == S.SPAWN or a.state[i] == GATE:
		return
	if a.state[i] == FinalBoss.SHATTER:  # v0.8.0 FB1
		return
	var b := entry_of(w, i)
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	w.bosses.meter[b] += applied * BossChallenge.stagger_permille(w, i, tags)  # BX: the weak point
	if w.bosses.meter[b] < t.stagger_size_milli:
		return
	w.bosses.meter[b] = 0
	w.bosses.stagger_t[b] = t.stagger_ticks
	w.bosses.attack[b] = -1
	a.lock_len[i] = 0.0
	EnemyAi.enter_state(a, i, STAGGERED)
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[i], a.ids[0], a.ids[i], a.pos(i))
	e.effect_id = &"boss_stagger"
	e.amount = t.stagger_ticks


# --- shapes (one function per area; the view draws them, resolve() hits with them) ----------------------------


## [center, inner, outer] of a spike ring.
static func ring_of(w: World, i: int) -> Array:
	var atk := attack_of(w, i)
	return [Vector2(w.actors.lock_x[i], w.actors.lock_y[i]), atk.inner_radius_m, atk.radius_m]


## Lane k's angle in a fan of `count` centred on `aim`.
static func lane_angle(atk: BossAttackTable, aim: int, k: int) -> int:
	return (aim + (2 * k - (atk.count - 1)) * atk.spread / 2) & 4095


## Shock lane k, whole: from the boss's edge along its angle, cut short by walls.
static func lane_of(w: World, i: int, k: int) -> Obb:
	var a := w.actors
	var atk := attack_of(w, i)
	var b := entry_of(w, i)
	var ang := lane_angle(atk, a.lock_a[i], k)
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(ang) * a.radius[i]
	var len := maxf(w.bosses.pts_x[b * BossStore.MAX_PTS + k], 0.01)
	return AttackShapes.lane(start, ang, len, atk.half_width_m)


## The part of shock lane k the wave crosses on active tick `st` (null once past the lane's end). The slices of
## every active tick join into exactly lane_of(k).
static func lane_slice(w: World, i: int, k: int, st: int) -> Obb:
	var a := w.actors
	var atk := attack_of(w, i)
	var b := entry_of(w, i)
	var ang := lane_angle(atk, a.lock_a[i], k)
	var len := maxf(w.bosses.pts_x[b * BossStore.MAX_PTS + k], 0.01)
	var f0 := atk.length_m * st / atk.active_ticks
	var f1 := atk.length_m * (st + 1) / atk.active_ticks
	if st == atk.active_ticks - 1:
		f1 = maxf(f1, len)
	if f0 >= len:
		return null
	f1 = minf(f1, len)
	var start := Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(ang) * (a.radius[i] + f0)
	return AttackShapes.lane(start, ang, f1 - f0, atk.half_width_m)


## [center, own_r, angle, half_arc, reach] of a melee sweep.
static func arc_of(w: World, i: int) -> Array:
	var a := w.actors
	var atk := attack_of(w, i)
	return [Vector2(a.lock_x[i], a.lock_y[i]), a.radius[i], a.lock_a[i], atk.half_arc, atk.reach_m]


## [center, radius] where a leap lands.
static func leap_disc(w: World, i: int) -> Array:
	return [w.bosses.pt(entry_of(w, i), 0), attack_of(w, i).radius_m]


## [center, radius] of a burrow's eruption (where the ripple stopped).
static func burrow_disc(w: World, i: int) -> Array:
	return [Vector2(w.actors.lock_x[i], w.actors.lock_y[i]), attack_of(w, i).radius_m]


## The spots of a brood's eggs, a barrage's shells or a deploy's turrets (each a disc of the attack's radius_m).
static func spots_of(w: World, i: int) -> PackedVector2Array:
	var b := entry_of(w, i)
	var out := PackedVector2Array()
	for k in attack_of(w, i).count:
		out.append(w.bosses.pt(b, k))
	return out


## [center, own_r, start, span, reach] of a rail sweep.
static func rail_of(w: World, i: int) -> Array:
	var a := w.actors
	return [
		Vector2(a.lock_x[i], a.lock_y[i]),
		a.radius[i],
		a.lock_a[i],
		w.bosses.span[entry_of(w, i)],
		attack_of(w, i).reach_m
	]


## The beam's angle after `st` active ticks (st = 0: the start; st = active_ticks: the end).
static func rail_angle(w: World, i: int, st: int) -> int:
	var atk := attack_of(w, i)
	return w.actors.lock_a[i] + w.bosses.span[entry_of(w, i)] * st / atk.active_ticks


## Bolt line k of a fan, as wide as its bolts, cut short by walls.
static func fan_lane_of(w: World, i: int, k: int) -> Obb:
	var a := w.actors
	var atk := attack_of(w, i)
	var b := entry_of(w, i)
	var ang := lane_angle(atk, a.lock_a[i], k)
	var start := (
		Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(ang) * (a.radius[i] + atk.radius_m + 0.05)
	)
	var len := maxf(w.bosses.pts_x[b * BossStore.MAX_PTS + k], 0.01)
	return AttackShapes.lane(start, ang, len, atk.radius_m)


## Where flood lane k starts (v0.4.0 BO): beside the boss's edge, offset sideways from the aim line by its place in
## the row (lanes gap_m apart, centred on the aim).
static func _flood_start(w: World, i: int, atk: BossAttackTable, aim: int, k: int) -> Vector2:
	var d := Kin.dir(aim)
	var side := Vector2(-d.y, d.x) * (atk.gap_m * (k - (atk.count - 1) * 0.5))
	return Vector2(w.actors.lock_x[i], w.actors.lock_y[i]) + d * w.actors.radius[i] + side


## Flood lane k, whole (v0.4.0 BO): parallel to the aim, as long as EnemyAi.clear_run allowed when it locked.
static func flood_lane_of(w: World, i: int, k: int) -> Obb:
	var a := w.actors
	var atk := attack_of(w, i)
	var len := maxf(w.bosses.pts_x[entry_of(w, i) * BossStore.MAX_PTS + k], 0.01)
	return AttackShapes.lane(
		_flood_start(w, i, atk, a.lock_a[i], k), a.lock_a[i], len, atk.half_width_m
	)


## What the view draws for boss i: {} or a shape with "progress" (0..1000). Shapes: &"ring" (center, inner,
## outer), &"lanes" (obbs), &"arc" (center, own_r, angle, half_arc, reach), &"lane" (obb), &"disc" (center,
## radius), &"discs" (centers, radius), &"sweep" (center, own_r, start, span, reach, beam) and the harmless
## &"ripple" (center, radius) that marks a burrowing boss; a flood (v0.4.0 BO) draws &"lanes", and while its lanes
## stand a "style" (&"spears" or &"molten"). A pull (BX) draws a &"ring" with "pull_m", the vortex's
## reach from the boss's centre. "move" names the attack's move (BossAttackTable.Move).
## v0.7.5 BF1: a locked attack's telegraph carries "tracked" (true) and "locked" (it stopped following and flashes);
## marker moves draw &"marks": "items", one {"shape" (&"disc" with center and radius, or &"lanes" with obbs),
## "locked", "progress"} per marker showing now; a burst pattern draws its landing &"disc" (tracked, then locked)
## and, while its shell flies, "lob" {from, to, progress}. Other patterns draw nothing on the ground (owner: "Shots
## draw no line on the ground"): v0.7.5 BF2: their windup and firing are a &"cast" with "ground": false (BossDodge).
static func telegraph(w: World, i: int) -> Dictionary:
	var a := w.actors
	var atk := attack_of(w, i)
	if atk == null or (a.state[i] != S.WINDUP and a.state[i] != S.ACTIVE):
		return {}
	var b := entry_of(w, i)
	var windup := a.state[i] == S.WINDUP
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
	var out := {}
	if BossDodge.is_marker_move(atk.move):
		return BossDodge.marks_telegraph(w, i, atk)
	if atk.move == M.PATTERN:
		return BossDodge.pattern_telegraph(w, i, b, atk, windup, progress)
	if atk.move == M.GRID:
		return BossDodge.grid_telegraph(w, i, atk)
	if atk.move == M.COMBO:  # v0.8.0 FB1: the swing (or the slam) pending
		return BossColossus.combo_telegraph(w, i, atk)
	if atk.move == M.SPIKE_CHASE or atk.move == M.SPIKE_BURST:  # v0.8.0 FB1: the spikes showing
		return BossColossus.spikes_telegraph(w, i, b, atk)
	if BossNemesis.is_move(atk.move):  # v0.8.0 FB3: a swing, a volley's lines, a card's parts
		return BossNemesis.telegraph(w, i, b, atk)
	if atk.move == M.GAZE or atk.move == M.MELT or atk.move == M.CROSS:
		# v0.8.0 BS2: nothing on the ground here; the eye, its aim line and the beam, and the glowing ring, are drawn
		# from WorldReader.boss_gaze / boss_melts (BossSignatureViews); v0.8.0 FB2: the Cross from boss_cross
		# (PrismViews).
		return {"shape": &"signature", "ground": false, "progress": progress, "move": atk.move}
	match atk.move:
		M.SLAM_RING, M.PULL:
			var r := ring_of(w, i)
			out = {"shape": &"ring", "center": r[0], "inner": r[1], "outer": r[2]}
			if atk.move == M.PULL:
				out["pull_m"] = atk.pull_range_m + a.radius[i]  # BX: how far the vortex reaches
		M.LANES, M.BOLT_FAN:
			var obbs: Array[Obb] = []
			for k in atk.count:
				obbs.append(lane_of(w, i, k) if atk.move == M.LANES else fan_lane_of(w, i, k))
			out = {"shape": &"lanes", "obbs": obbs}
		M.SWEEP:
			var c := arc_of(w, i)
			out = {
				"shape": &"arc",
				"center": c[0],
				"own_r": c[1],
				"angle": c[2],
				"half_arc": c[3],
				"reach": c[4]
			}
		M.CHARGE:
			out = {"shape": &"lane", "obb": EnemyAi.charge_lane(w, i)}
		M.LEAP:
			var d := leap_disc(w, i)
			out = {"shape": &"disc", "center": d[0], "radius": d[1]}
			if not windup:
				progress = 1000
				windup = true
		M.BURROW:
			if not windup and BossDodge.tracked_burrow(atk) and w.bosses.step[b] < 2:
				# v0.7.5 BF2: the eruption circle on the player (dull), then locked where it will erupt.
				var tracking_now := w.bosses.step[b] == 0
				return {
					"shape": &"disc",
					"center": w.bosses.pt(b, 0) if tracking_now else burrow_disc(w, i)[0],
					"radius": atk.radius_m,
					"progress":
					clampi(
						(
							a.state_t[i]
							* 1000
							/ maxi(1, atk.track_ticks if tracking_now else atk.erupt_ticks)
						),
						0,
						1000
					),
					"move": atk.move,
					"tracked": true,
					"locked": not tracking_now
				}
			if windup or w.bosses.step[b] == 0:
				return {
					"shape": &"ripple",
					"center": a.pos(i),
					"radius": a.radius[i],
					"progress": progress if windup else 0,
					"move": atk.move
				}
			if w.bosses.step[b] == 1:
				var d := burrow_disc(w, i)
				return {
					"shape": &"disc",
					"center": d[0],
					"radius": d[1],
					"progress": clampi(a.state_t[i] * 1000 / maxi(1, atk.erupt_ticks), 0, 1000),  # audit G-20
					"move": atk.move
				}
			return {}
		M.BROOD, M.DEPLOY, M.BARRAGE:
			out = {"shape": &"discs", "centers": spots_of(w, i), "radius": atk.radius_m}
		M.FLOOD, M.ROW_FLOOD:  # v0.4.0 BO: marked for the windup, then standing (spears, molten floor).
			var obbs: Array[Obb] = []
			for k in atk.count:
				obbs.append(
					(
						flood_lane_of(w, i, k)
						if atk.move == M.FLOOD
						else BossDodge.row_flood_of(w, i, k)
					)
				)
			out = {"shape": &"lanes", "obbs": obbs}
			if not windup:
				out["style"] = &"spears" if a.kinds[i] == ActorStore.Kind.WARLORD else &"molten"
				progress = 1000
				windup = true
		M.RAIL:
			var r := rail_of(w, i)
			out = {
				"shape": &"sweep",
				"center": r[0],
				"own_r": r[1],
				"start": r[2],
				"span": r[3],
				"reach": r[4],
				"beam":
				r[2] if windup else rail_angle(w, i, mini(a.state_t[i] + 1, atk.active_ticks))
			}
			if not windup:
				progress = 1000
				windup = true
	if not windup:
		return {}
	out["progress"] = progress
	out["move"] = atk.move
	if atk.lock_ticks > 0:  # v0.7.5 BF1: dull while it tracks, bright once it locks
		out["tracked"] = true
		out["locked"] = (
			a.state[i] != S.WINDUP or a.state_t[i] >= atk.windup_ticks - atk.lock_ticks
		)
	return out


## The death recap line for a boss kill (BossCauses.key; v0.8.0 FB3 moved it there, this file's length).
static func cause_key(w: World) -> StringName:
	return BossCauses.key(w)
