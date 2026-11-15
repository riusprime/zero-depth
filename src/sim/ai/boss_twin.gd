class_name BossTwin
extends RefCounted
## The Twin Wardens, one boss in two bodies that fight apart (nothing joins them). Two linked actors, both boss kinds
## with their own BossStore entry (so each runs the boss framework: its windup, its markers, its stagger), but one
## boss:
## - The boss (the amber Warden, its table's kind) is what World.spawn_boss made: it is the boss bar
##   (WorldReader.boss_index, the first live boss), World.boss_id, the codex's fight, its BOSS_DEFEATED, its reward
##   and its legendary core. Its twin (the violet Warden, the table's twin_kind) rises beside it (on_spawn) with its
##   HP, max HP, catch-up and intro, and leaves with it without a defeat, a kill count or shards of its own (leaves).
## - One HP: every change to one body's HP is the other's too (Damage._apply: share_hp), so both cross the phase gates
##   on the same tick and fall on the same hit (fall_together: the twin's KILL after its boss's). Only the boss's gate
##   brings adds.
## - Two roles, three phases, each a full bar (the thresholds split the HP in
##   thirds; the gate's floor holds each bar, and the boss bar shows the phase's own: WorldReader.boss_phase_permille).
##   Two movesets: the boss's (amber, physical: the sword combo, the Sword Lane, the charge that bursts, the
##   overhead; BossWardenAmber, BossChargeBurst) and the twin's (BossAttackTable.twin_body; violet, magic: Crossfire,
##   Orb Volley, Rune Ring, Blink, the Mirror Ward, Shadow Swords; BossWard, BossShadowSwords); each picks only its own.
##   Phase 1 the boss leads and its twin stands back; phase 2 they swap; phase 3 both fight, taking turns (twin_turn:
##   a body starts an attack only on its turn and while the other isn't winding up or striking, so their attacks
##   alternate and never overlap). The body standing back keeps behind the leader (REST_M), casts one bolt (the
##   table's twin_bolt) every twin_bolt_ticks, and can be hit but takes nothing: the hit sparks off (Damage._blocked,
##   TAG_BLOCKED: "not now"). Phase 3: the amber Warden takes hits as ever and the violet one stands under a whole
##   ward until his charge breaks it (BossWard); once, Through the Rift (BossRift). The body to hit now (twin_focus:
##   the leader; in phase 3 the amber Warden, or the violet one while she is stunned) gets STATUS_APPLY
##   EFFECT_FOCUS when it changes.
## - Anger: a hit from the player on one body angers the other for anger_ticks (its steps × anger_permille); at most
##   one is angry at a time (a hit on the angry one calms it and angers the other).
## - Steps: the leading boss pursues the player as any boss; the leading twin keeps flank_m from the player at a right
##   angle from its boss (on its own side); a body standing back keeps REST_M behind the leader, away from the player.
## - Crossfire (`crossfire`, the twin's): the fan (its pattern) is fired at the player, and its gap faces directly
##   away from the other Warden: the safe spot stands on the far side of the caster from the other body, as far out
##   as the player (at least distance_m), and the shots within gap_m of it there are left out. Keep the caster
##   between you and the other Warden. A body alone leaves the gap on the player.
## - The Sword Lane (`chain_sweep`, a lock, the boss's): its line runs from the body through the player and reach_m
##   past them (at most BossWardensTable.lane_max_m, cut short by walls), tracking until the lock, then flashing; on
##   the strike the sword cuts the lane (half_width_m each side).
## Pure: no stream is drawn here; everything follows from the bodies, the player and the attack's clock.

const M := BossAttackTable.Move
const S := EnemyAi.State
## The twin counts its flank (or the line's end) reached this close.
const ARRIVE_M := 0.25
## A body standing back keeps this far behind the leader (away from the player).
const REST_M := 4.0
## The roles' phases.
const P_YELLOW := 0
const P_VIOLET := 1
const P_BOTH := 2
## A Sword Lane's longest run for a pair without BossWardensTable.
const LANE_MAX_M := 9.0
## STATUS_APPLY's effect when a body turns angry (its actor is the target; the views and the sound read it).
const EFFECT_ANGER := &"twin_anger"
## STATUS_APPLY's effect on the body to hit now when it changes (amount: the phase).
const EFFECT_FOCUS := &"twin_focus"
## STATUS_APPLY's effect when the body standing back casts its bolt.
const EFFECT_BOLT := &"twin_bolt"


## The two Warden kinds (BossAi.is_boss_kind).
static func is_twin_kind(kind: int) -> bool:
	return kind == ActorStore.Kind.TWIN_WARDEN or kind == ActorStore.Kind.TWIN_WARDEN_VIOLET


static func is_move(move: int) -> bool:
	return (
		move == M.CROSSFIRE
		or move == M.CHAIN_SWEEP
		or move == M.SWORD_COMBO
		or move == M.MIRROR_WARD
		or move == M.SHADOW_SWORDS
	)


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
		if Kin.length(pos - at) >= t.twin_m * 0.6:
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
	BossWardens.begin(w, i)  # The pair's own clocks


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
		BossWardens.on_boss_gone(w, boss_id)  # Its wards, its set piece
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


# --- the roles ---------------------------------------------------------------------------------------------------


## True while body i leads (fights): the boss in phase 1, its twin in phase 2, both in phase 3 (and any other boss).
static func leads(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return true
	var ph := w.bosses.twin_phase[k]
	if ph >= P_BOTH:
		return true
	return (w.bosses.twin_lead[k] == w.actors.ids[i]) == (ph == P_YELLOW)


## True while body i stands back (the other leads): a hit on it sparks off and does nothing (Damage._blocked).
static func resting(w: World, i: int) -> bool:
	return pair_of(w, i) >= 0 and not leads(w, i)


## BossAi._choose and its punish and gap-closer: true when body i may use attack `atk` (its own moveset; any attack for
## every other boss).
static func may_use(w: World, i: int, atk: BossAttackTable) -> bool:
	if pair_of(w, i) < 0:
		return true
	if atk.move == M.MIRROR_WARD and (BossWard.mirror_up(w) or BossWard.full(w, i)):
		return false  # One ward at a time
	return atk.twin_body == is_twin(w, i)


## BossChallenge's punish and gap-closer: attack k for boss entry b, or -1 when it is the other Warden's.
static func own(w: World, b: int, k: int) -> int:
	if k < 0 or w.bosses.twin_lead.is_empty():
		return k
	var i := w.actors.index_of(w.bosses.ids[b])
	if i < 0 or may_use(w, i, w.boss_tables[w.bosses.table[b]].attacks[k]):
		return k
	return -1


## True when body i (leading, free) may start an attack now: always in phases 1-2; in phase 3 only on its turn and
## while the other body isn't winding up or striking (their attacks alternate, never overlap).
static func may_start(w: World, i: int, k: int) -> bool:
	var bs := w.bosses
	if bs.twin_phase[k] < P_BOTH:
		return true
	var j := partner_of(w, i)
	if j >= 0 and w.actors.dead[j] == 0:
		var s := w.actors.state[j]
		if s == S.WINDUP or s == S.ACTIVE:
			return false
	return bs.twin_turn[k] == 0 or bs.twin_turn[k] == w.actors.ids[i]


## Damage.hit and tick_dot: the per-mille body i takes from the player: the violet Warden stunned by her broken ward
## BossWardensTable.stun_permille; 1000 otherwise (and for every other actor).
static func taken_permille(w: World, i: int) -> int:
	if w.boss_fight.wd_break_at < 0 or not BossWard.stunned(w, i):
		return 1000
	return BossAi.table_of(w, i).wardens.stun_permille


## The body to hit now (an actor id): the leader; in phase 3 the amber Warden, or the violet one while her broken
## ward leaves her stunned.
static func focus_id(w: World, k: int) -> int:
	var bs := w.bosses
	var ph := bs.twin_phase[k]
	if ph == P_VIOLET:
		return bs.twin_body[k]
	if ph >= P_BOTH:
		var j := w.actors.index_of(bs.twin_body[k])
		if j >= 0 and BossWard.stunned(w, j):
			return bs.twin_body[k]
	return bs.twin_lead[k]


## The boss's turn (tick phase 3): the roles' clocks. A new phase resets the clock (phase 3 opens on the twin's turn);
## the body to hit is flagged when it changes.
static func _roles(w: World, i: int, k: int) -> void:
	var bs := w.bosses
	var ph := bs.phase[BossAi.entry_of(w, i)]
	if ph != bs.twin_phase[k]:
		bs.twin_phase[k] = ph
		bs.twin_clock[k] = 0
		bs.twin_turn[k] = bs.twin_body[k] if ph >= P_BOTH else 0
	else:
		bs.twin_clock[k] += 1
	var focus := focus_id(w, k)
	if focus == bs.twin_focus[k]:
		return
	bs.twin_focus[k] = focus
	var j := w.actors.index_of(focus)
	if j >= 0:
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, focus, focus, focus, w.actors.pos(j))
		e.effect_id = EFFECT_FOCUS
		e.amount = ph


## The body standing back (free, facing the player) casts its bolt every twin_bolt_ticks of the phase: the table's
## twin_bolt attack's pattern, aimed at the player, its shots carrying that attack (the recap's line).
static func _bolt(w: World, i: int, k: int, t: BossTable, aim: int) -> void:
	var c := w.bosses.twin_clock[k]
	if t.twin_bolt < 0 or w.player_dead() or c <= 0 or c % t.twin_bolt_ticks != 0:
		return
	var atk := t.attacks[t.twin_bolt]
	if atk.pattern == null:
		return
	var at := w.actors.pos(i)
	var r := w.actors.radius[i] + atk.pattern.radius_m + BulletPatterns.MUZZLE_M
	var n := BulletPatterns.fire(
		w, i, atk.pattern, 0, at, aim, r, BossAi.orb_damage(w, i, atk), t.twin_bolt
	)
	if is_twin(w, i) and atk.twin_look != &"":
		w.relook_pending(n, atk.twin_look)  # the violet twin's bolt in its own colour
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = EFFECT_BOLT


# --- phase 3 ------------------------------------------------------------------------------------------------------


## BossAi.think, before its states: the boss runs the pair's clocks (the anger, the roles, its side dash). A free
## body standing back, or one whose turn it isn't, or one the set piece holds or that dashes, turns to the player and
## picks nothing (true: BossAi skips the rest); standing back it casts its bolt.
static func think(w: World, i: int, aim: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var a := w.actors
	var bs := w.bosses
	var fs := w.boss_fight
	if bs.twin_lead[k] == a.ids[i]:
		if bs.twin_anger_t[k] > 0:
			bs.twin_anger_t[k] -= 1
			if bs.twin_anger_t[k] == 0:
				bs.twin_angry[k] = 0
		_roles(w, i, k)
		if fs.wd_boss == a.ids[i] and leads(w, i) and not BossRift.holds(w):
			BossWardenAmber.dash_think(w, i, BossAi.table_of(w, i).wardens)
	if a.state[i] != S.MOVE:
		return false
	var rest := resting(w, i)
	var held := fs.wd_boss >= 0 and (BossRift.holds(w) or (lead_body(w, i) and fs.wd_dash_t > 0))
	if not rest and not held and may_start(w, i, k):
		return false
	var t := BossAi.table_of(w, i)
	a.facing[i] = aim if t.turn_rate <= 0 else Kin.turn_toward(a.facing[i], aim, t.turn_rate)
	if rest and not held:
		_bolt(w, i, k, t, aim)
	return true


## True for the pair's boss body (the amber Warden).
static func lead_body(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	return k >= 0 and w.bosses.twin_lead[k] == w.actors.ids[i]


## BossAi.start_attack: a Crossfire's safe spot and its fan's aim; a Sword Lane's line from the start; the Shadow
## Swords' spots; in phase 3 the turn passes to the other body.
static func on_start(w: World, i: int, k: int) -> void:
	var pk := pair_of(w, i)
	if pk < 0:
		return
	var a := w.actors
	var atk := BossAi.table_of(w, i).attacks[k]
	if w.bosses.twin_phase[pk] >= P_BOTH:
		var j := partner_of(w, i)
		w.bosses.twin_turn[pk] = a.ids[j] if j >= 0 else 0
	if atk.move == M.CROSSFIRE:
		var safe := w.player_pos() if atk.lines_turn_milli > 0 else safe_spot(w, i, atk)
		for body in [i, partner_of(w, i)]:
			if body < 0 or BossAi.attack_of(w, body) != atk:
				continue
			w.bosses.set_pt(BossAi.entry_of(w, body), 0, safe)
			w.bosses.pts_y[BossAi.entry_of(w, body) * BossStore.MAX_PTS + BossHard.REM_SLOT] = 0.0
			a.lock_a[body] = Kin.angle_of(w.player_pos() - a.pos(body))  # The fan flies at the player
			a.facing[body] = a.lock_a[body]
	elif atk.move == M.CHAIN_SWEEP:
		track_sweep(w, i, atk)
	elif atk.move == M.SHADOW_SWORDS:
		BossShadowSwords.lock(w, i)


## v0.9.5 BH3, tick phase 3, a tracking Crossfire's windup (BossAi, the boss's turn): for lines_ticks each body's
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


## Crossfire's safe spot: on the far side of body i from the other Warden, as far out as the player stands (at least
## distance_m); the player's own spot for a body alone, or when the two stand on one spot.
static func safe_spot(w: World, i: int, atk: BossAttackTable) -> Vector2:
	var p := w.player_pos()
	var j := partner_of(w, i)
	if j < 0 or w.actors.dead[j] == 1:
		return p
	var at := w.actors.pos(i)
	var away := at - w.actors.pos(j)
	var d := Kin.length(away)
	if d < 0.0001:
		return p
	return at + away / d * maxf(Kin.length(p - at), atk.distance_m)


## Tick phase 3, a Sword Lane's windup: the boss's line follows the player (from its body, through them, reach_m on,
## at most the table's lane_max_m and cut by walls) until the lock.
static func track_sweep(w: World, i: int, atk: BossAttackTable) -> void:
	var a := w.actors
	if is_twin(w, i) or w.player_dead() or a.state_t[i] >= atk.windup_ticks - atk.lock_ticks:
		return
	var t := BossAi.table_of(w, i)
	var at := a.pos(i)
	var to := w.player_pos() - at
	var aim := Kin.angle_of(to)
	var most := t.wardens.lane_max_m if t.wardens != null else LANE_MAX_M
	var want := minf(Kin.length(to) + atk.reach_m, most)
	a.lock_x[i] = at.x
	a.lock_y[i] = at.y
	a.lock_a[i] = aim
	a.facing[i] = aim
	a.lock_len[i] = maxf(0.01, minf(want, EnemyAi.clear_run(w, at, aim, want, atk.half_width_m)))


## The Sword Lane's lane (boss i's, as it tracks or as it locked).
static func sweep_lane(w: World, i: int, atk: BossAttackTable) -> Obb:
	var a := w.actors
	return AttackShapes.lane(
		Vector2(a.lock_x[i], a.lock_y[i]), a.lock_a[i], maxf(a.lock_len[i], 0.01), atk.half_width_m
	)


## Where the Sword Lane's line ends (boss i's).
static func sweep_end(w: World, i: int) -> Vector2:
	var a := w.actors
	return Vector2(a.lock_x[i], a.lock_y[i]) + Kin.dir(a.lock_a[i]) * a.lock_len[i]


# --- phase 5 ------------------------------------------------------------------------------------------------------


## BossAi.move for a Warden (true: nothing else moves it): the set piece's steps and the amber Warden's dash and
## combo steps first; else free and leading, the boss pursues the player and the twin keeps its flank; standing back,
## behind the leader; each the faster while angry.
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
	if t.wardens != null and w.boss_fight.wd_boss >= 0:
		if (
			BossRift.moves(w, i, t.wardens, slow)
			or (lead and BossWardenAmber.dash_move(w, i, slow))
		):
			return true
		var now := BossAi.attack_of(w, i)
		if now != null and now.move == M.SWORD_COMBO and a.state[i] in [S.WINDUP, S.ACTIVE]:
			BossWardenAmber.combo_move(w, i, now, slow)
			return true
	if a.state[i] == S.ACTIVE:
		var atk := BossAi.attack_of(w, i)
		if atk != null and (atk.move == M.CHARGE or atk.move == M.LEAP):
			return false  # The Charge's run and the Blink's hop are BossAi's own steps
	if a.state[i] == S.MOVE and not w.player_dead():
		if resting(w, i):  # Standing back, behind the leader
			_go_to(w, i, rest_goal(w, i), speed, t)
		elif lead:
			_pursue(w, i, t, speed)
		else:
			_go_to(w, i, flank_goal(w, i, t), speed, t)
	return true


## Where a body standing back goes: REST_M behind the leader, on the far side from the player.
static func rest_goal(w: World, i: int) -> Vector2:
	var j := partner_of(w, i)
	if j < 0 or w.actors.dead[j] == 1:
		return w.actors.pos(i)
	var lp := w.actors.pos(j)
	var away := lp - w.player_pos()
	var d := Kin.length(away)
	if d < 0.0001:
		away = w.actors.pos(i) - lp
		d = maxf(Kin.length(away), 0.0001)
	return lp + away / d * REST_M


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


# --- phase 6 ------------------------------------------------------------------------------------------------------


## BossAi.resolve for a Warden: the amber one's charge against the violet one's ward; a Crossfire's waves, the Sword
## Lane's cut, the sword combo's hits, the Mirror Ward's cast and the Shadow Swords' cuts (true: the attack was one of
## these, so BossAi's own resolve has nothing more to do).
static func resolve(w: World, i: int) -> bool:
	var k := pair_of(w, i)
	if k < 0:
		return false
	var a := w.actors
	var lead := w.bosses.twin_lead[k] == a.ids[i]
	if lead and w.boss_fight.wd_boss == a.ids[i]:
		BossWard.charge_check(w, i, partner_of(w, i))
	var atk := BossAi.attack_of(w, i)
	if a.state[i] != S.ACTIVE or atk == null or not is_move(atk.move) or w.player_dead():
		return false
	var st := a.state_t[i]
	match atk.move:
		M.CROSSFIRE:
			_fire_crossfire(w, i, atk, st)
		M.CHAIN_SWEEP:
			var lane := sweep_lane(w, i, atk)
			var touch := Collide.circle_vs_obb(w.player_pos(), w.player.radius_m, lane)
			if lead and st == 0 and touch != Vector2.ZERO:
				BossAi.hit_player(w, i, atk, SimEvent.TAG_AREA, a.pos(i))
		M.SWORD_COMBO:
			BossWardenAmber.combo_resolve(w, i, atk, st)
		M.MIRROR_WARD:
			if st == 0:
				BossWard.cast(w, i)
		M.SHADOW_SWORDS:
			BossShadowSwords.resolve(w, i, atk, st)
	return true


## Crossfire's wave from body i: its fan along its aim, without the shots within gap_m of the safe spot there.
static func _fire_crossfire(w: World, i: int, atk: BossAttackTable, st: int) -> void:
	var pat := atk.pattern
	if pat == null:
		return
	var wave := BulletPatterns.wave_at(pat, st)
	if wave < 0:
		return
	var at := w.actors.pos(i)
	var to_safe := w.bosses.pt(BossAi.entry_of(w, i), 0) - at
	var d := maxf(Kin.length(to_safe), 0.5)
	var toward := Kin.angle_of(to_safe) if atk.lines_turn_milli <= 0 else w.actors.lock_a[i]
	var gap := Vector2i(toward, Kin.angle_of(Vector2(d, atk.gap_m)))
	var r := w.actors.radius[i] + pat.radius_m + BulletPatterns.MUZZLE_M
	var n := BulletPatterns.fire(
		w, i, pat, wave, at, w.actors.lock_a[i], r, BossAi.orb_damage(w, i, atk), -2, gap
	)
	if is_twin(w, i) and atk.twin_look != &"":
		w.relook_pending(n, atk.twin_look)  # the twin's embers in its own colour


# --- the view -----------------------------------------------------------------------------------------------------


## BossAi.telegraph for the pair's moves: Crossfire and the Mirror Ward's cast draw nothing on the ground (the gap
## is boss_twin's, the ward BossWardens'); the sword combo its pending arc; Shadow Swords the lanes not cut yet; the
## Sword Lane its lane, tracked then locked, through its windup.
static func telegraph(w: World, i: int, atk: BossAttackTable, progress: int) -> Dictionary:
	if atk.move == M.SWORD_COMBO:
		return BossWardenAmber.combo_telegraph(w, i, atk)
	if atk.move == M.SHADOW_SWORDS:
		return BossShadowSwords.telegraph(w, i, atk, progress)
	if atk.move == M.CROSSFIRE or atk.move == M.MIRROR_WARD:
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
## index), "angry", "anger" (0..1000 of its anger left), "phase" (the roles': P_YELLOW, P_VIOLET, P_BOTH), "resting"
## (standing back), "focus" (the body to hit now), "exposed" (the violet Warden stunned by her broken ward, taking
## more), "warded" (under her whole ward, taking nothing), and while a Crossfire runs "safe" (the spot) and "gap"
## ([from, to]: this body's gap lane through the spot), while the boss's Sword Lane runs "sweep" ({"from", "to",
## "half_width", "locked", "progress", "struck"}).
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
		"phase": bs.twin_phase[k],  # The roles
		"resting": resting(w, i),
		"focus": bs.twin_focus[k] == a.ids[i],
		"exposed": BossWard.stunned(w, i),
		"warded": BossWard.full(w, i),
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
		if atk.lines_turn_milli > 0:  # The line is the body's aim, the spot where the lines cross
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
