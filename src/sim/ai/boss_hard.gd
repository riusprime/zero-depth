class_name BossHard
extends RefCounted
## v0.9.5 BH2 (owner, 2026-10-25: "we have to modify 1 spell for each that will be hard to dodge, bosses should feel
## like a challeng"; docs/roadmap/v0.9.5/BOSSES_HARD.md rows B1-B5): one spell of each of five bosses that takes a
## read and a well-timed dash, not more damage. Every number is data (BossAttackDefinition shape_params, compiled by
## HardCompiler):
## - B1, the Gatekeeper's Shock Lanes: with second_ticks, each cross is followed second_ticks after it strikes by a
##   second cross, shifted second_offset_m on each axis toward where the player is heading (toward the boss when still
##   on that axis). The second cross is shown from the tick the first locks (>= the telegraph rule), so the safe lane
##   moves. Markers k < count are the first crosses; markers count + k their seconds (BossDodge: marker_count).
## - B2, the Warlord's Javelin Fan: with lead_ticks the first fan is aimed where the player will be lead_ticks on
##   (their sim velocity, cut short by walls), at the tick it fires; every later fan is aimed at where they stand then.
## - B3, the Brood Mother's Leap Chain: the last leap of the chain aims last_lead_ticks ahead of the player's movement
##   and lands on a disc last_radius_bonus_permille per mille wider.
## - B4, the Hive Lens's Focus Beam: with beam_turn_milli (1/4096 turns a tick x 1000) the beam burns the whole active
##   time and turns toward the player while it does.
## - B5, the Siege Engine's Mortar Grid: with safe_cells every volley strikes the whole board but that many cells,
##   inside its outer ring; the cells come from one draw of the ai stream at the attack's start (a permutation of the
##   inner cells), and from the second half of the volleys on they are other cells (the later volley shows for its
##   lock, the swap's warning).
## Pure: integer maths and the ai stream (one draw per Mortar Grid); no sin, cos or atan2.

## The BossStore point slots these use: the grid's permutation code (x of slot 1), the beam's turn remainder (y of 7).
const PERM_SLOT := 1
const REM_SLOT := 7
## A safe cell's centre keeps this far from every wall.
const WALL_MARGIN_M := 1.0

# --- shared ---------------------------------------------------------------------------------------------------------


## Where the player will be `ticks` on at their current velocity, cut short where a wall (the room) stops them.
static func lead_point(w: World, ticks: int) -> Vector2:
	var p := w.player_pos()
	var d := w.vel * ticks
	var dist := Kin.length(d)
	if dist <= 0.0001:
		return p
	var run := EnemyAi.clear_run(w, p, Kin.angle_of(d), dist, w.player.radius_m)
	return p + d * (run / dist)


# --- B1: the second cross -------------------------------------------------------------------------------------------


## Markers a `marks` / `row_lanes` attack lays: its crosses, and (with second_ticks) a second one after each.
static func marker_count(atk: BossAttackTable) -> int:
	return atk.count * (2 if atk.second_ticks > 0 else 1)


## The active tick marker k strikes on (k >= count: a second cross, second_ticks after the one it follows).
static func strike_at(atk: BossAttackTable, k: int) -> int:
	if k < atk.count:
		return k * atk.mark_gap_ticks
	return (k - atk.count) * atk.mark_gap_ticks + atk.second_ticks


## Second marker k's state `t` ticks into the attack (BossDodge.mark_state's codes): shown (locked) from the tick the
## cross it follows locks, struck second_ticks after that cross.
static func second_state(atk: BossAttackTable, k: int, t: int) -> int:
	var j := k - atk.count
	var shown := j * atk.mark_gap_ticks + atk.windup_ticks - atk.lock_ticks
	var strike := strike_at(atk, k) + atk.windup_ticks
	if t < shown:
		return -1
	if t < strike:
		return 1
	return 2 if t == strike else 3


## The second cross of one laid on `p`: shifted second_offset_m on each axis the way the player is moving, toward the
## boss on an axis they are still on.
static func second_point(w: World, b: int, atk: BossAttackTable, p: Vector2) -> Vector2:
	var bi := w.actors.index_of(w.bosses.ids[b])
	var to := w.actors.pos(bi) - p if bi >= 0 else Vector2.ZERO
	var v := w.vel
	var sx := signf(v.x) if absf(v.x) > 0.0001 else signf(to.x)
	var sy := signf(v.y) if absf(v.y) > 0.0001 else signf(to.y)
	return p + Vector2(sx, sy) * atk.second_offset_m


# --- B2: the fans -----------------------------------------------------------------------------------------------------


## BossDodge.resolve_pattern, just before wave k fires: a fan with lead_ticks aims its first wave where the player will
## be, every later one where they are.
static func aim_fan(w: World, i: int, atk: BossAttackTable, k: int) -> void:
	if atk.lead_ticks <= 0 or w.player_dead():
		return
	var at := w.actors.pos(i)
	var to := lead_point(w, atk.lead_ticks) if k == 0 else w.player_pos()
	w.actors.lock_a[i] = Kin.angle_of(to - at)


# --- B3: the last leap ------------------------------------------------------------------------------------------------


## True while boss entry b is on the last leap of a chain whose last leap leads (or lands wider).
static func is_last_leap(w: World, b: int, atk: BossAttackTable) -> bool:
	return atk.move == BossAttackTable.Move.LEAP and w.bosses.step[b] == atk.chain - 1


## The disc radius of the leap in progress: the last leap of the chain lands last_radius_bonus_permille wider.
static func leap_radius(w: World, b: int, atk: BossAttackTable) -> float:
	if atk.last_radius_bonus_permille > 0 and is_last_leap(w, b, atk):
		return atk.radius_m * (1000 + atk.last_radius_bonus_permille) / 1000.0
	return atk.radius_m


## Where the leap in progress aims, or ZERO-with-false when it is not a leading last leap: [leads, point].
static func leap_target(w: World, b: int, atk: BossAttackTable) -> Array:
	if atk.last_lead_ticks > 0 and is_last_leap(w, b, atk):
		return [true, lead_point(w, atk.last_lead_ticks)]
	return [false, Vector2.ZERO]


# --- B4: the turning beam ---------------------------------------------------------------------------------------------


## Tick phase 3, a `lanes` attack with beam_turn_milli in its active time: the beam turns toward the player by at most
## that much a tick (the fraction carried from tick to tick), and its lanes are cut short by the walls afresh.
static func turn_beam(w: World, i: int, b: int, atk: BossAttackTable) -> void:
	if atk.beam_turn_milli <= 0 or w.player_dead():
		return
	var a := w.actors
	var rem := int(w.bosses.pts_y[b * BossStore.MAX_PTS + REM_SLOT]) + atk.beam_turn_milli
	var step := rem / 1000
	w.bosses.pts_y[b * BossStore.MAX_PTS + REM_SLOT] = rem - step * 1000
	var from := Vector2(a.lock_x[i], a.lock_y[i])
	a.lock_a[i] = Kin.turn_toward(a.lock_a[i], Kin.angle_of(w.player_pos() - from), step)
	a.facing[i] = a.lock_a[i]
	for k in atk.count:
		var ang := BossAi.lane_angle(atk, a.lock_a[i], k)
		var start := from + Kin.dir(ang) * a.radius[i]
		w.bosses.pts_x[b * BossStore.MAX_PTS + k] = EnemyAi.clear_run(
			w, start, ang, atk.length_m, atk.half_width_m
		)


## BossAi._lock: a new beam starts with no turn carried over.
static func reset_beam(w: World, b: int) -> void:
	w.bosses.pts_y[b * BossStore.MAX_PTS + REM_SLOT] = 0.0


# --- B5: the safe cells -----------------------------------------------------------------------------------------------


## The inner cells of a count x count board (offsets from its centre cell), in a fixed order: none on the outer ring.
static func inner_cells(atk: BossAttackTable) -> Array[Vector2i]:
	var h := maxi(0, atk.count / 2 - 1)
	var out: Array[Vector2i] = []
	for y in range(-h, h + 1):
		for x in range(-h, h + 1):
			out.append(Vector2i(x, y))
	return out


## The number of orderings of the inner cells (n!), the range of the one draw.
static func orderings(atk: BossAttackTable) -> int:
	var n := inner_cells(atk).size()
	var f := 1
	for k in range(2, n + 1):
		f *= k
	return f


## BossAi._lock, a Mortar Grid with safe_cells: draws the order the safe cells come in (ai stream, one draw).
static func draw_safe(w: World, b: int, atk: BossAttackTable) -> void:
	w.bosses.pts_x[b * BossStore.MAX_PTS + PERM_SLOT] = float(
		w.rng_ai.range_int(0, orderings(atk) - 1)
	)


## The inner cells in the drawn order (the factorial number system: code -> a permutation).
static func _order(w: World, b: int, atk: BossAttackTable) -> Array[Vector2i]:
	var pool := inner_cells(atk)
	var code := int(w.bosses.pts_x[b * BossStore.MAX_PTS + PERM_SLOT])
	var out: Array[Vector2i] = []
	var f := orderings(atk)
	var n := pool.size()
	while n > 0:
		f /= n
		var k := code / f
		code -= k * f
		out.append(pool[k])
		pool.remove_at(k)
		n -= 1
	return out


## The two safe sets of the board centred at `c` as [first, second] arrays of cell offsets: the first from the four
## cells beside the centre (never the player's own cell, never a corner), the second from the other inner cells with at
## least one beside a first cell (a way across); a cell whose centre is in or near a wall is skipped, and a set the
## walls leave short falls back to the centre cell. Pure of the board's centre and the drawn order.
static func safe_sets(w: World, b: int, atk: BossAttackTable, c: Vector2) -> Array:
	var order := _order(w, b, atk)
	var ok: Array[Vector2i] = []
	for o in order:
		if EnemyAi.clear_of_walls(w, c + Vector2(o) * atk.cell_m, WALL_MARGIN_M):
			ok.append(o)
	var first: Array[Vector2i] = []
	for o in ok:
		if absi(o.x) + absi(o.y) == 1 and first.size() < atk.safe_cells:
			first.append(o)
	for o in ok:
		if first.size() < atk.safe_cells and o != Vector2i.ZERO and not first.has(o):
			first.append(o)
	if first.is_empty():
		first.append(Vector2i.ZERO)
	var second: Array[Vector2i] = []
	for o in ok:  # one beside a first cell (the way across), then the rest in the drawn order
		if second.is_empty() and not first.has(o) and _beside(first, o):
			second.append(o)
	for o in ok:
		if second.size() < atk.safe_cells and not first.has(o) and not second.has(o):
			second.append(o)
	if second.is_empty():
		second = first
	return [first, second]


static func _beside(cells: Array[Vector2i], o: Vector2i) -> bool:
	for q in cells:
		if maxi(absi(q.x - o.x), absi(q.y - o.y)) <= 1:
			return true
	return false


## The safe cells of volley k: the first set up to the halfway point, the second from there on.
static func safe_cells_of(w: World, b: int, atk: BossAttackTable, c: Vector2, k: int) -> Array:
	var sets := safe_sets(w, b, atk, c)
	return sets[1] if k * 2 >= atk.volleys else sets[0]
