class_name BossTwin
extends RefCounted
## v0.9.0 NB2 (owner Q24, "ok go for those"; docs/roadmap/v0.9.0/BOSSES_4_5.md row N2; SIM_CONTRACTS §10k): the Twin
## Wardens, one boss in two bodies. Two linked actors, both boss kinds with their own BossStore entry (so each runs
## the boss framework: its windup, its markers, its shield, its stagger), but one boss:
## - The boss (the amber Warden, its table's kind) is what World.spawn_boss made: it is the boss bar
##   (WorldReader.boss_index, the first live boss), World.boss_id, the codex's fight, its BOSS_DEFEATED, its reward
##   and its legendary core. Its twin (the violet Warden, the table's twin_kind) rises beside it (on_spawn) with its
##   HP, max HP, catch-up and intro, and leaves with it without a defeat, a kill count or shards of its own (leaves).
## - One HP: every change to one body's HP is the other's too (Damage._apply: share_hp), so both cross the phase gates
##   (66 %, 33 %) on the same tick and fall on the same hit (fall_together: the twin's KILL after its boss's). Only
##   the boss's gate brings adds.
## - One mind: the twin never picks an attack; when its boss starts one the twin starts the same (on_start), if it is
##   free (not staggered, not in a gate), so their windups, shields and strikes keep time.
## - The chain: held between chain_min_m and chain_max_m (the twin is drawn in or out along it each tick: _tether);
##   it is not solid (it never pushes, so it can't pin the player on a wall) and burns a player touching its line
##   chain_burn every chain_burn_ticks (damage over time, the hurt iframes apply), never while they dash, never while
##   they stand against a wall, never during either body's rise or gate, and not while the Chain Sweep has it.
## - Anger: a hit from the player on one body angers the other for anger_ticks (its steps × anger_permille); at most
##   one is angry at a time (a hit on the angry one calms it and angers the other).
## - Steps: the boss pursues the player as any boss; the twin keeps flank_m from the player at a right angle from its
##   boss (on its own side), so the chain runs past the player, not through them.
## - Crossfire (`crossfire`, shielded, the signature pattern): its safe spot stands distance_m off the middle of the
##   chain on the player's side; each body fires its fan (its pattern) at the spot and leaves out the shots within
##   gap_m of it there, so the two gaps cross only at the spot, between them.
## - Chain Sweep (`chain_sweep`, a lock): the boss's line runs from it through the player and reach_m past them (held
##   between the chain's lengths, cut short by walls), tracking until the lock, then flashing; the twin swings to the
##   line's end; on the strike the chain lashes the lane (half_width_m each side). Its late cause names the burn.
## Pure: no stream is drawn here; everything follows from the bodies, the player and the attack's clock.

const M := BossAttackTable.Move
const S := EnemyAi.State
## The twin counts its flank (or the line's end) reached this close.
const ARRIVE_M := 0.25
## The twin swings into the Chain Sweep's line this many times its walking speed.
const SWING_MULT := 4.0
## STATUS_APPLY's effect when a body turns angry (its actor is the target; the views and the sound read it).
const EFFECT_ANGER := &"twin_anger"
## The chain's burn's effect id (Damage.tick_dot).
const EFFECT_BURN := &"twin_chain"


## The two Warden kinds (BossAi.is_boss_kind).
static func is_twin_kind(kind: int) -> bool:
	return kind == ActorStore.Kind.TWIN_WARDEN or kind == ActorStore.Kind.TWIN_WARDEN_VIOLET


static func is_move(move: int) -> bool:
	return move == M.CROSSFIRE or move == M.CHAIN_SWEEP


## The twin pair actor i belongs to (BossStore's twin entry), or -1.
static func pair_of(w: World, i: int) -> int:
	if w.bosses.twin_lead.is_empty() or i <= 0:
		return -1
	return w.bosses.twin_of(w.actors.ids[i])


## True for the twin body (not its boss).
static func is_twin(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	return k >= 0 and w.bosses.twin_body[k] == w.actors.ids[i]


## The other body's actor index (-1 with none).
static func partner_of(w: World, i: int) -> int:
	var k := pair_of(w, i)
	if k < 0:
		return -1
	var bs := w.bosses
	var other := bs.twin_body[k] if bs.twin_lead[k] == w.actors.ids[i] else bs.twin_lead[k]
	return w.actors.index_of(other)


# --- the pair -----------------------------------------------------------------------------------------------------


## World.spawn_boss: a boss with a twin kind gets its twin twin_m to the side (across the line to the player, the
## first clear side), with its HP, max HP, power, intro and facing; a BossStore entry of the same table; the pair.
static func on_spawn(w: World, i: int) -> void:
	var t := BossAi.table_of(w, i)
	if t.twin_kind < 0:
		return
	var a := w.actors
	var at := a.pos(i)
	var side := Kin.angle_of(w.player_pos() - at) + 1024
	var pos := at
	for turn in [0, 2048, 512, 1536, 3584, 2560]:
		pos = BossAi.spot(w, at, (side + turn) & 4095, t.twin_m)
		if Kin.length(pos - at) >= t.chain_min_m:
			break
	var id := w.take_id()
	var j := a.add(id, t.twin_kind, ActorStore.TEAM_ENEMY, pos, t.radius_m, a.hp[i], 0)
	a.max_hp[j] = a.max_hp[i]
	a.hp[j] = a.hp[i]
	a.power[j] = a.power[i]
	a.invuln[j] = a.invuln[i]
	a.freeze_immune[j] = 1
	a.facing[j] = Kin.angle_of(w.player_pos() - pos)
	w.bosses.add(id, w.bosses.table[BossAi.entry_of(w, i)])
	w.bosses.add_twin(a.ids[i], id)


## Damage._apply: the HP actor `target` holds now is its twin's too (one HP for the pair).
static func share_hp(w: World, target: int) -> void:
	if target == 0 or w.bosses.twin_lead.is_empty():
		return
	var j := partner_of(w, target)
	if j >= 0 and w.actors.dead[j] == 0:
		w.actors.hp[j] = w.actors.hp[target]


## Damage._apply: `target` died (its KILL `kill`): its twin falls with it, with its own KILL (the same hit's child).
static func fall_together(w: World, target: int, kill: SimEvent) -> void:
	if target == 0 or w.bosses.twin_lead.is_empty():
		return
	var j := partner_of(w, target)
	if j < 0 or w.actors.dead[j] == 1:
		return
	w.actors.hp[j] = mini(w.actors.hp[j], 0)
	w.actors.dead[j] = 1
	var e := w.emit_event(
		SimEvent.Kind.KILL, kill.source_id, kill.owner_id, w.actors.ids[j], w.actors.pos(j)
	)
	e.root_id = kill.root_id
	e.parent_seq = kill.seq
	e.depth = kill.depth + 1
	e.effect_id = kill.effect_id


## World._remove_dead: true for a twin body leaving (it goes with its boss: its entry goes, and no defeat, kill count,
## shards or core of its own; the boss's are the pair's).
static func leaves(w: World, i: int) -> bool:
	var a := w.actors
	var b := w.bosses.index_of(a.ids[i])
	if b < 0:
		return false
	var t: BossTable = w.boss_tables[w.bosses.table[b]]
	if t.twin_kind < 0 or a.kinds[i] != t.twin_kind or a.kinds[i] == t.kind:
		return false
	w.bosses.remove(b)
	BossSignatures.on_boss_gone(w, a.ids[i])
	return true


## BossSignatures.on_boss_gone: the pair goes with either body.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var k := w.bosses.twin_of(boss_id) if not w.bosses.twin_lead.is_empty() else -1
	if k >= 0:
		w.bosses.remove_twin(k)


## Damage._apply: a hit from the player on one body angers the other (the only angry one; STATUS_APPLY when it turns).
static func on_hit(w: World, target: int, applied: int, owner_id: int) -> void:
	if applied <= 0 or owner_id != w.actors.ids[0] or w.bosses.twin_lead.is_empty():
		return
	var k := pair_of(w, target)
	var j := partner_of(w, target)
	if k < 0 or j < 0 or w.actors.dead[j] == 1:
		return
	var bs := w.bosses
	var id := w.actors.ids[j]
	bs.twin_anger_t[k] = BossAi.table_of(w, target).anger_ticks
	if bs.twin_angry[k] != id:
		bs.twin_angry[k] = id
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, w.actors.pos(j))
		e.effect_id = EFFECT_ANGER


## True while body i is angry.
static func angry(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	return k >= 0 and w.bosses.twin_angry[k] == w.actors.ids[i] and w.bosses.twin_anger_t[k] > 0


# --- phase 3 ------------------------------------------------------------------------------------------------------


## BossAi.think, before its states: the boss runs the pair's clocks (the anger, the chain's burn); the twin, free,
## turns to the player and picks nothing (true: BossAi skips the rest).
static func think(w: World, i: int, aim: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var a := w.actors
	var bs := w.bosses
	if bs.twin_lead[k] == a.ids[i]:
		if bs.twin_anger_t[k] > 0:
			bs.twin_anger_t[k] -= 1
			if bs.twin_anger_t[k] == 0:
				bs.twin_angry[k] = 0
		if bs.twin_burn_cd[k] > 0:
			bs.twin_burn_cd[k] -= 1
		return false
	if a.state[i] != S.MOVE:
		return false
	var t := BossAi.table_of(w, i)
	a.facing[i] = aim if t.turn_rate <= 0 else Kin.turn_toward(a.facing[i], aim, t.turn_rate)
	return true


## BossAi.start_attack: the boss's attack is its free twin's too (the same one, the same tick); a Crossfire's safe spot
## and both fans' aims; a Chain Sweep's line from the start.
static func on_start(w: World, i: int, k: int) -> void:
	var pk := pair_of(w, i)
	if pk < 0:
		return
	var a := w.actors
	var atk := BossAi.table_of(w, i).attacks[k]
	if w.bosses.twin_lead[pk] == a.ids[i]:
		var j := partner_of(w, i)
		if j >= 0 and a.dead[j] == 0 and a.state[j] == S.MOVE:
			BossAi.start_attack(w, j, k)
	if atk.move == M.CROSSFIRE:
		var safe := w.player_pos() if atk.lines_turn_milli > 0 else safe_spot(w, i, atk)
		for body in [i, partner_of(w, i)]:
			if body < 0 or BossAi.attack_of(w, body) != atk:
				continue
			w.bosses.set_pt(BossAi.entry_of(w, body), 0, safe)
			w.bosses.pts_y[BossAi.entry_of(w, body) * BossStore.MAX_PTS + BossHard.REM_SLOT] = 0.0
			a.lock_a[body] = Kin.angle_of(safe - a.pos(body))
			a.facing[body] = a.lock_a[body]
	elif atk.move == M.CHAIN_SWEEP:
		track_sweep(w, i, atk)


## v0.9.5 BH3 (B8), tick phase 3, a tracking Crossfire's windup (BossAi, the boss's turn): for lines_ticks each body's
## line turns toward the player by at most lines_turn_milli (1/4096 turns x 1000, the fraction carried) a tick, and
## the safe spot is where the two lines cross (the midpoint of their ends when they run parallel or the crossing is
## behind a body); after that the lines hold and the fans fire along them.
static func track_crossfire(w: World, i: int, atk: BossAttackTable) -> void:
	var a := w.actors
	var j := partner_of(w, i)
	if atk.lines_turn_milli <= 0 or is_twin(w, i) or j < 0 or a.dead[j] == 1 or w.player_dead():
		return
	if a.state_t[i] >= atk.lines_ticks or BossAi.attack_of(w, j) != atk:
		return
	var p := w.player_pos()
	for body in [i, j]:
		var b := BossAi.entry_of(w, body)
		var rem := (
			int(w.bosses.pts_y[b * BossStore.MAX_PTS + BossHard.REM_SLOT]) + atk.lines_turn_milli
		)
		var step := rem / 1000
		w.bosses.pts_y[b * BossStore.MAX_PTS + BossHard.REM_SLOT] = rem - step * 1000
		a.lock_a[body] = Kin.turn_toward(a.lock_a[body], Kin.angle_of(p - a.pos(body)), step)
		a.facing[body] = a.lock_a[body]
	var spot := crossing_point(a.pos(i), a.lock_a[i], a.pos(j), a.lock_a[j], p)
	for body in [i, j]:
		w.bosses.set_pt(BossAi.entry_of(w, body), 0, spot)


## Where the line from p1 along angle a1 meets the line from p2 along a2 (both ahead of their bodies); else the
## midpoint of the two lines' points as far out as the player `p` is from each body.
static func crossing_point(p1: Vector2, a1: int, p2: Vector2, a2: int, p: Vector2) -> Vector2:
	var d1 := Kin.dir(a1)
	var d2 := Kin.dir(a2)
	var cross := d1.x * d2.y - d1.y * d2.x
	if absf(cross) > 0.05:
		var d := p2 - p1
		var s := (d.x * d2.y - d.y * d2.x) / cross
		var u := (d.x * d1.y - d.y * d1.x) / cross
		if s > 0.5 and u > 0.5:
			return p1 + d1 * s
	return (p1 + d1 * Kin.length(p - p1) + p2 + d2 * Kin.length(p - p2)) * 0.5


## Crossfire's safe spot: distance_m off the chain's middle on the player's side (pulled in toward the chain when a
## wall stands there); the player's own spot for a body alone.
static func safe_spot(w: World, i: int, atk: BossAttackTable) -> Vector2:
	var p := w.player_pos()
	var j := partner_of(w, i)
	if j < 0 or w.actors.dead[j] == 1:
		return p
	var at := w.actors.pos(i)
	var mid := (at + w.actors.pos(j)) * 0.5
	var along := w.actors.pos(j) - at
	var n := Vector2(-along.y, along.x) / maxf(Kin.length(along), 0.0001)
	if n.dot(p - mid) < 0.0:
		n = -n
	for f: float in [1.0, 0.75, 0.5]:
		var s := mid + n * (atk.distance_m * f)
		if EnemyAi.clear_of_walls(w, s, w.player.radius_m):
			return s
	return mid + n * (atk.distance_m * 0.5)


## Tick phase 3, a Chain Sweep's windup: the boss's line follows the player (from its body, through them, reach_m on,
## held to the chain's lengths and cut by walls) until the lock; the twin's copy only swings (moves).
static func track_sweep(w: World, i: int, atk: BossAttackTable) -> void:
	var a := w.actors
	if is_twin(w, i) or w.player_dead() or a.state_t[i] >= atk.windup_ticks - atk.lock_ticks:
		return
	var t := BossAi.table_of(w, i)
	var at := a.pos(i)
	var to := w.player_pos() - at
	var aim := Kin.angle_of(to)
	var want := clampf(Kin.length(to) + atk.reach_m, t.chain_min_m, t.chain_max_m)
	a.lock_x[i] = at.x
	a.lock_y[i] = at.y
	a.lock_a[i] = aim
	a.facing[i] = aim
	a.lock_len[i] = maxf(0.01, minf(want, EnemyAi.clear_run(w, at, aim, want, atk.half_width_m)))


## The Chain Sweep's lane (boss i's, as it tracks or as it locked).
static func sweep_lane(w: World, i: int, atk: BossAttackTable) -> Obb:
	var a := w.actors
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]), a.lock_a[i], maxf(a.lock_len[i], 0.01), atk.half_width_m
	)


## Where the Chain Sweep's line ends (boss i's): the twin swings there.
static func sweep_end(w: World, i: int) -> Vector2:
	var a := w.actors
	return Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(a.lock_a[i]) * a.lock_len[i]


# --- phase 5 ------------------------------------------------------------------------------------------------------


## BossAi.move for a Warden (true: nothing else moves it): free, the boss pursues the player and the twin keeps its
## flank, each the faster while angry; in a Chain Sweep the twin swings to the line's end; then the chain's length.
static func moves(w: World, i: int, slow: float) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var a := w.actors
	var t := BossAi.table_of(w, i)
	var lead := w.bosses.twin_lead[k] == a.ids[i]
	var speed := (
		t.speed
		* t.phase_speed_permille[w.bosses.phase[BossAi.entry_of(w, i)]]
		/ 1000.0
		* slow
		* (t.anger_permille / 1000.0 if angry(w, i) else 1.0)
	)
	if a.state[i] == S.MOVE and not w.player_dead():
		if lead:
			_pursue(w, i, t, speed)
		else:
			_go_to(w, i, flank_goal(w, i, t), speed, t)
	elif not lead and (a.state[i] == S.WINDUP or a.state[i] == S.ACTIVE):
		var atk := BossAi.attack_of(w, i)
		var j := partner_of(w, i)
		if atk != null and atk.move == M.CHAIN_SWEEP and j >= 0:
			_go_to(w, i, sweep_end(w, j), speed * SWING_MULT, t)
	if not lead:
		_tether(w, i, t)
	return true


## The twin's flank: flank_m from the player, at a right angle from its boss, on the side it stands.
static func flank_goal(w: World, i: int, t: BossTable) -> Vector2:
	var p := w.player_pos()
	var j := partner_of(w, i)
	if j < 0:
		return p
	var from := w.actors.pos(j) - p
	var d := Kin.length(from)
	if d < 0.0001:
		from = Vector2(1.0, 0.0)
		d = 1.0
	var perp := Vector2(-from.y, from.x) / d
	if perp.dot(w.actors.pos(i) - p) < 0.0:
		perp = -perp
	return p + perp * t.flank_m


static func _pursue(w: World, i: int, t: BossTable, speed: float) -> void:
	var at := w.actors.pos(i)
	var to := w.player_pos() - at
	var dist := Kin.length(to)
	if speed <= 0.0 or dist <= maxf(t.keep_distance_m, t.radius_m + w.player.radius_m + 0.1):
		return
	w.actors.set_pos(i, at + EnemyAi.steer(w, at, to / dist, t.radius_m) * speed)


static func _go_to(w: World, i: int, goal: Vector2, speed: float, t: BossTable) -> void:
	var at := w.actors.pos(i)
	var to := goal - at
	var dist := Kin.length(to)
	if speed <= 0.0 or dist <= ARRIVE_M:
		return
	w.actors.set_pos(i, at + EnemyAi.steer(w, at, to / dist, t.radius_m) * minf(speed, dist))


## The chain's length rule: the twin is drawn in or out along the chain to chain_min_m..chain_max_m from its boss; when
## a wall stands where the twin would go, the boss gives way instead (along the same line), else the two share it.
## Run after the steps (phase 5) and again after the walls and bodies have pushed (phase 6, resolve), so the length
## holds at every tick's end.
static func _tether(w: World, i: int, t: BossTable) -> void:
	var a := w.actors
	var j := partner_of(w, i)
	if j < 0 or a.dead[j] == 1:
		return
	var lp := a.pos(j)
	var at := a.pos(i)
	var v := at - lp
	var d := Kin.length(v)
	if d < 0.0001:
		v = Kin.dir((a.facing[j] + 1024) & 4095)
		d = 0.0001
	else:
		v /= d
	var want := clampf(d, t.chain_min_m, t.chain_max_m)
	if absf(want - d) < 0.0001:
		return
	var moved := lp + v * want
	if EnemyAi.clear_of_walls(w, moved, t.radius_m):
		a.set_pos(i, moved)
		return
	var lead_to := at - v * want
	if EnemyAi.clear_of_walls(w, lead_to, t.radius_m):
		a.set_pos(j, lead_to)
		return
	var half := (want - d) * 0.5
	a.set_pos(i, at + v * half)
	a.set_pos(j, lp - v * half)


# --- phase 6 ------------------------------------------------------------------------------------------------------


## BossAi.resolve for a Warden: the boss's chain burns; a Crossfire's waves and the Chain Sweep's lash (true: the
## attack was one of these, so BossAi's own resolve has nothing more to do).
static func resolve(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var a := w.actors
	var lead := w.bosses.twin_lead[k] == a.ids[i]
	if lead:
		_burn(w, i, k)
	else:
		_tether(w, i, BossAi.table_of(w, i))  # after the walls' and bodies' pushes
	var atk := BossAi.attack_of(w, i)
	if a.state[i] != S.ACTIVE or atk == null or not is_move(atk.move) or w.player_dead():
		return false
	if atk.move == M.CROSSFIRE:
		_fire_crossfire(w, i, atk, a.state_t[i])
	elif lead and a.state_t[i] == 0:
		var lane := sweep_lane(w, i, atk)
		if Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, lane) != Vector2.ZERO:
			BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, a.pos(i))
	return true


## Crossfire's wave from body i: its fan toward the safe spot, without the shots within gap_m of the spot there.
static func _fire_crossfire(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	var pat := atk.pattern
	if pat == null:
		return
	var wave := BulletPatterns.wave_at(pat, st)
	if wave < 0:
		return
	var at := w.actors.pos(i)
	var d := maxf(Kin.length(w.bosses.pt(BossAi.entry_of(w, i), 0) - at), 0.5)
	var gap := Vector2i(w.actors.lock_a[i], Kin.angle_of(Vector2(d, atk.gap_m)))
	var r := w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	var n := BulletPatterns.fire(
		w, i, pat, wave, at, w.actors.lock_a[i], r, BossAi.orb_damage(w, i, atk), -2, gap
	)
	if is_twin(w, i) and atk.twin_look != &"":
		w.relook_pending(n, atk.twin_look)  # the twin's embers in its own colour


## The chain's burn (tick phase 6, the boss's turn): a player touching its line, when it is hot and its clock allows.
static func _burn(w: World, i: int, k: int) -> void:
	var bs := w.bosses
	if bs.twin_burn_cd[k] > 0 or w.player_dead() or w.is_dashing() or not chain_hot(w, i):
		return
	var ends := chain_ends(w, i)
	var t := BossAi.table_of(w, i)
	var p := w.player_pos()
	if dist_to_chain(p, ends[0], ends[1]) > w.player.radius_m + t.chain_half_m:
		return
	if BossTide.press(w, p) > 0.0:
		return  # against a wall: the chain never pins the player there
	bs.twin_burn_cd[k] = t.chain_burn_ticks
	var id := w.actors.ids[i]
	Damage.tick_dot(w, 0, BossAi.powered(w, i, t.chain_burn), id, id, EFFECT_BURN)
	if w.player_dead() and w.killer_attack < 0:
		w.killer_attack = BossSignatures.LATE_CAUSE + sweep_index(t)


## The chain's two ends (the boss's centre, its twin's), or [] when either is gone. `i` is either body.
static func chain_ends(w: World, i: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var k := pair_of(w, i)
	if k < 0:
		return out
	var lead := w.actors.index_of(w.bosses.twin_lead[k])
	var body := w.actors.index_of(w.bosses.twin_body[k])
	if lead < 0 or body < 0 or w.actors.dead[lead] == 1 or w.actors.dead[body] == 1:
		return out
	out.append(w.actors.pos(lead))
	out.append(w.actors.pos(body))
	return out


## True while the chain burns: both bodies up (risen, not in a gate) and no Chain Sweep holding it.
static func chain_hot(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	if chain_ends(w, i).is_empty():
		return false
	var a := w.actors
	for id in [w.bosses.twin_lead[k], w.bosses.twin_body[k]]:
		var j := a.index_of(id)
		if a.state[j] == S.SPAWN or a.state[j] == BossAi.GATE:
			return false
	return not lifted(w, i)


## True while the boss's Chain Sweep has the chain (its windup and strike): it doesn't burn meanwhile.
static func lifted(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var lead := w.actors.index_of(w.bosses.twin_lead[k])
	if lead < 0:
		return false
	var s := w.actors.state[lead]
	var atk := BossAi.attack_of(w, lead)
	return atk != null and atk.move == M.CHAIN_SWEEP and (s == S.WINDUP or s == S.ACTIVE)


## The distance from p to the chain's line between a and b.
static func dist_to_chain(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.dot(ab)
	var f := 0.0 if l2 <= 0.0 else clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return Kin.length(p - (a + ab * f))


## The table's first Chain Sweep (the burn's late cause names it), or 0.
static func sweep_index(t: BossTable) -> int:
	for k in t.attacks.size():
		if t.attacks[k].move == M.CHAIN_SWEEP:
			return k
	return 0


# --- the view -----------------------------------------------------------------------------------------------------


## BossAi.telegraph for the two moves: Crossfire draws nothing on the ground (its gaps are boss_twin's); the boss's
## Chain Sweep its lane, tracked then locked, through its windup (the twin's copy nothing).
static func telegraph(w: World, i: int, atk: BossAttackTable, progress: int) -> Dictionary:
	if atk.move == M.CROSSFIRE:
		return {"shape": &"signature", "ground": false, "progress": progress, "move": atk.move}
	var a := w.actors
	if is_twin(w, i) or a.state[i] != S.WINDUP:
		return {}
	return {
		"shape": &"lane",
		"obb": sweep_lane(w, i, atk),
		"progress": progress,
		"move": atk.move,
		"tracked": true,
		"locked": a.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
	}


## WorldReader.boss_twin: {} for a body that isn't a Warden; else "lead" (the boss's body), "partner" (the other's
## index), "angry", "anger" (0..1000 of its anger left), "chain" ([] or [from, to]), "hot" (it burns), "lifted"
## (the Chain Sweep has it), "burned" (ticks since the chain last burned the player, or -1), and while a Crossfire
## runs "safe" (the spot) and "gap" ([from, to]: this body's gap lane through the spot), while the boss's Chain Sweep
## runs "sweep" ({"from", "to", "half_width", "locked", "progress", "struck"}).
static func state(w: World, i: int) -> Dictionary:
	var k := pair_of(w, i)
	if k < 0:
		return {}
	var a := w.actors
	var bs := w.bosses
	var t := BossAi.table_of(w, i)
	var lead := bs.twin_lead[k] == a.ids[i]
	var mad := angry(w, i)
	var out := {
		"lead": lead,
		"partner": partner_of(w, i),
		"angry": mad,
		"anger": bs.twin_anger_t[k] * 1000 / maxi(1, t.anger_ticks) if mad else 0,
		"chain": chain_ends(w, i),
		"hot": chain_hot(w, i),
		"lifted": lifted(w, i),
		"burned": t.chain_burn_ticks - bs.twin_burn_cd[k] if bs.twin_burn_cd[k] > 0 else -1,
	}
	var atk := BossAi.attack_of(w, i)
	var busy := a.state[i] == S.WINDUP or a.state[i] == S.ACTIVE
	if atk == null or not busy:
		return out
	var progress := clampi(a.state_t[i] * 1000 / maxi(1, atk.windup_ticks), 0, 1000)
	if atk.move == M.CROSSFIRE:
		var safe := bs.pt(BossAi.entry_of(w, i), 0)
		out["safe"] = safe
		var run := safe - a.pos(i)
		out["gap"] = [a.pos(i), safe + run * (2.0 / maxf(Kin.length(run), 0.0001))]
		if atk.lines_turn_milli > 0:  # v0.9.5 BH3 (B8): the line is the body's aim, the spot where the lines cross
			out["gap"] = [a.pos(i), a.pos(i) + Kin.dir(a.lock_a[i]) * (Kin.length(run) + 2.0)]
		out["progress"] = progress if a.state[i] == S.WINDUP else 1000
		out["firing"] = a.state[i] == S.ACTIVE
	elif atk.move == M.CHAIN_SWEEP and lead:
		out["sweep"] = {
			"from": Vector2(a.lock_x[i], a.lock_y[i]),
			"to": sweep_end(w, i),
			"half_width": atk.half_width_m,
			"locked": a.state[i] == S.ACTIVE or a.state_t[i] >= atk.windup_ticks - atk.lock_ticks,
			"progress": progress if a.state[i] == S.WINDUP else 1000,
			"struck": a.state[i] == S.ACTIVE,
		}
	return out
