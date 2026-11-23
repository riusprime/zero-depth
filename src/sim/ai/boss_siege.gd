class_name BossSiege
extends RefCounted
## The Siege Engine's siege (BossTable.siege, a BossSiegeTable; BossFightStore.sg_*): its shells leave the boulders you
## hide behind. Beside the boss's attacks (they are not attacks: it goes on fighting). The Doom Shell's cart is
## BossDoom's.
## - The Target Lock, from lock_phase: the first lock_first_ticks into that phase, then one every lock_every_ticks
##   (start to start; never begun while the boss kneels at a phase change). A painted circle starts on the hero and
##   follows it at lock_follow per mille of the hero's run speed now (it lags), holds still for its last
##   lock_hold_ticks, then the shell lands: lock_hit per mille of max HP to a hero touching it (SafeArea ONCE: armour
##   and the dash's invulnerability apply). It destroys every turret of the boss's (turret_kind) it touches (they go
##   without a kill) and leaves a boulder on its centre.
## - A boulder is a square wall of half side boulder_half (World.add_barrier: bodies, both sides' shots, sight; the
##   flow field goes round it) standing boulder_ticks, boulder_max at most (the oldest crumbles when one more lands).
##   Fair (fits): it keeps the hero's width plus PASS_SLACK_M from every wall, every other boulder and the boss's own
##   body, and BODY_MARGIN_M from the ammo cart, every other boss and every body that is not an enemy, so it is an
##   island in the free floor and seals nobody in. Other enemies do not stop it (one hugging the hero would deny every
##   boulder): each one the boulder stands on takes the shell's hit (lock_hit per mille of the hero's max HP, from the
##   boss), and one that lives is pushed out to the nearest free spot as a hero it lands on is. Where it does not fit
##   the shell still lands but leaves none.
## - The Shockwave needs cover, from cover_phase: the boss's `slam_ring` attack hits the hero wherever it stands unless
##   the boss cannot see it (EnemyAi.sees_player from the boss's centre: a boulder, or any wall, on the line), at most
##   shock_cap per mille of max HP; each blast shatters the boulders on that line. Before cover_phase it keeps its
##   ring. It is held (may_use, unless_held) while a cart rolls or a Doom Shell is due, and while no boulder stands
##   unless a shell has landed since it was first held. The objective markers point at the boulders standing while it
##   winds up and while a Doom Shell comes (ObjectiveMarkers.SIEGE_BOULDER).
## - Everything ends with the boss (on_boss_gone); the lock, the boulders and the cart also end when the hero is dead
##   or has left the room (cancel).
## Pure: no stream is drawn; everything follows from the clock and the positions.

const M := BossAttackTable.Move
## STATUS_APPLY effects for the views and the tests (source the boss). LOCK: a Target Lock begins (target the hero,
## pos = its circle's centre, amount = ticks to the shell). SHELL: the shell lands (pos = the centre, amount = the HP
## it cost, amount_applied = the turrets it destroyed). BOULDER_UP: a boulder stands (pos = its centre, amount = its
## id, amount_applied = 1 when it pushed the hero out). BOULDER_DOWN: one goes (pos, amount = its id, amount_applied =
## why: END_*). TURRET: a shell destroyed a turret (target the turret). SHOCKWAVE: a Shockwave under the cover rule
## struck (amount = the HP it cost, 0 when covered; amount_applied = the boulders it shattered).
const LOCK := &"siege_lock"
const SHELL := &"siege_shell"
const BOULDER_UP := &"siege_boulder"
const BOULDER_DOWN := &"siege_boulder_down"
const TURRET := &"siege_turret_destroyed"
const SHOCKWAVE := &"siege_shockwave"
## The damage's effect id (the HIT and DAMAGE events) of a Target Lock's shell.
const SHELL_EFFECT := &"boss_siege_shell"
## Why a boulder went: its time, one more landed over the cap, a blast or the cart shattered it, the fight ended.
const END_EXPIRED := 0
const END_CAP := 1
const END_SHATTERED := 2
const END_CLEARED := 3
## The reader's "crumbling": a boulder this close to its end.
const CRUMBLE_TICKS := 60
## A boulder keeps this clear of the ammo cart, every other boss and every body that is not an enemy.
const BODY_MARGIN_M := 0.3
## It keeps the hero's width plus this from every wall, every other boulder and the boss's body.
const PASS_SLACK_M := 0.15
## A pushed-out hero stands this far clear of the boulder.
const PUSH_SLACK_M := 0.05
## Round the boss when the fight has no room (a test world): this far each way.
const NO_ROOM_HALF_M := 12.0
## drop(): the boulders whose time is up, or every boulder.
const DUE := -1
const ALL := -2

# --- the tick ---------------------------------------------------------------------------------------------------


## Tick phase 6 (BossSignatures.advance): boulders whose time is up crumble; the boss with a siege runs its lock,
## its cart (BossDoom) and the markers.
static func advance(w: World) -> void:
	if not w.boss_fight.sg_b_x.is_empty():
		drop(w, DUE)
	var i := _sieger(w)
	if i < 0:
		return
	if BossSlow.fight_over(w):
		cancel(w)
		return
	var st := BossAi.table_of(w, i).siege
	var b := BossAi.entry_of(w, i)
	var phase := w.bosses.phase[b]
	_lock(w, i, st, phase)
	BossDoom.advance(w, i, st, phase)
	_markers(w, i, b, st)


## The boss that runs the siege (its actor index), or -1. The first live one with a siege takes the clocks once it has
## risen; one at a time.
static func _sieger(w: World) -> int:
	var bs := w.bosses
	var fs := w.boss_fight
	var a := w.actors
	if fs.sg_boss >= 0:
		var i := a.index_of(fs.sg_boss)
		return i if i >= 0 and a.dead[i] == 0 else -1
	for b in bs.size():
		var t: BossTable = w.boss_tables[bs.table[b]]
		var i := a.index_of(bs.ids[b])
		if t.siege == null or i < 0 or a.dead[i] == 1 or a.state[i] == EnemyAi.State.SPAWN:
			continue
		fs.clear_siege()
		fs.sg_boss = bs.ids[b]
		return i
	return -1


## The floor the siege is on: the boss room's interior, or a square round the boss without one.
static func room_of(w: World, i: int) -> Rect2:
	var room := w.bosses.arena
	if room.has_area():
		return room
	var h := Vector2(NO_ROOM_HALF_M, NO_ROOM_HALF_M)
	return Rect2(w.actors.pos(i) - h, h * 2.0)


# --- the Target Lock --------------------------------------------------------------------------------------------


static func _lock(w: World, i: int, st: BossSiegeTable, phase: int) -> void:
	var bs := w.boss_fight
	if phase >= st.lock_phase and bs.sg_lock_due < 0:
		bs.sg_lock_due = w.tick + st.lock_first_ticks
	if bs.sg_lock_from < 0:
		if bs.sg_lock_due < 0 or w.tick < bs.sg_lock_due or w.actors.state[i] == BossAi.GATE:
			return
		bs.sg_lock_due = w.tick + st.lock_every_ticks
		bs.sg_lock_from = w.tick
		var p := w.player_pos()
		bs.sg_lock_x = p.x
		bs.sg_lock_y = p.y
		var e := _event(w, i, LOCK, p)
		e.target_id = w.actors.ids[0]
		e.amount = st.lock_ticks
		return
	var t := w.tick - bs.sg_lock_from
	if t < st.lock_ticks - st.lock_hold_ticks:
		var c := lock_centre(w)
		var to := w.player_pos() - c
		var d := Kin.length(to)
		var step := BossTide.run_speed(w) * st.lock_follow / 1000.0
		c = w.player_pos() if d <= step else c + to / d * step
		bs.sg_lock_x = c.x
		bs.sg_lock_y = c.y
	if t >= st.lock_ticks:
		_land(w, i, st)


## Where the lock's circle stands now.
static func lock_centre(w: World) -> Vector2:
	return Vector2(w.boss_fight.sg_lock_x, w.boss_fight.sg_lock_y)


## The shell lands on the lock's circle (the class comment's rule).
static func _land(w: World, i: int, st: BossSiegeTable) -> void:
	var bs := w.boss_fight
	var c := lock_centre(w)
	bs.sg_lock_from = -1
	bs.sg_landed = w.tick
	var got := 0
	var pr := w.player.radius_m
	if not w.player_dead() and AttackShapes.disc_touches(c, st.lock_radius_m, w.player_pos(), pr):
		got = SafeArea.hurt(w, i, st.lock_hit, SafeArea.Mode.ONCE, st.shell_cause, SHELL_EFFECT)
	var smashed := 0
	var a := w.actors
	for j in range(1, a.size()):
		if a.kinds[j] != st.turret_kind or a.dead[j] == 1 or j == i:
			continue
		if AttackShapes.disc_touches(c, st.lock_radius_m, a.pos(j), a.radius[j]):
			BossDoom.leave(w, j)
			smashed += 1
			var t := _event(w, i, TURRET, a.pos(j))
			t.target_id = a.ids[j]
	var e := _event(w, i, SHELL, c)
	e.amount = got
	e.amount_applied = smashed
	_raise(w, i, st, c)


# --- the boulders -----------------------------------------------------------------------------------------------


## Boulder k as the wall it is.
static func boulder_obb(bs: BossFightStore, k: int) -> Obb:
	var h := bs.sg_b_h[k]
	return Obb.make(Vector2(bs.sg_b_x[k], bs.sg_b_y[k]), Vector2(h, h), 0)


## Every standing boulder as a wall.
static func boulder_obbs(w: World) -> Array[Obb]:
	var out: Array[Obb] = []
	for k in w.boss_fight.sg_b_x.size():
		out.append(boulder_obb(w.boss_fight, k))
	return out


## A boulder of boss i at c where it fits; the oldest crumbles first when the cap is reached; the enemies under it
## take the shell's hit, and the hero and the enemies that live are pushed out.
static func _raise(w: World, i: int, st: BossSiegeTable, c: Vector2) -> void:
	var h := st.boulder_half
	if not fits(w, i, c, h):
		return
	var bs := w.boss_fight
	if bs.sg_b_x.size() >= st.boulder_max:
		_remove(w, [0], END_CAP)
	var under := _crush(w, i, st, Obb.make(c, Vector2(h, h), 0))
	bs.sg_b_id.append(bs.sg_next)
	bs.sg_b_from.append(w.tick)
	bs.sg_b_until.append(w.tick + st.boulder_ticks)
	bs.sg_b_boss.append(w.actors.ids[i])
	bs.sg_b_x.append(c.x)
	bs.sg_b_y.append(c.y)
	bs.sg_b_h.append(h)
	bs.sg_next += 1
	var box := boulder_obb(bs, bs.sg_b_x.size() - 1)
	w.add_barrier(box)
	BossSignatures.set_nav_extra(w)
	var e := _event(w, i, BOULDER_UP, c)
	e.amount = bs.sg_b_id[bs.sg_b_id.size() - 1]
	e.amount_applied = 1 if _push_out(w, i, box, 0) else 0
	for j: int in under:
		if w.actors.dead[j] == 0:
			_push_out(w, i, box, j)


## The enemies the boulder `sq` stands on (the ones fits() lets it land on) take the shell's hit from boss i, through
## the enemies' damage path. Returns the indices of those it hit.
static func _crush(w: World, i: int, st: BossSiegeTable, sq: Obb) -> Array[int]:
	var a := w.actors
	var under: Array[int] = []
	for j in range(1, a.size()):
		if a.dead[j] == 1 or _denies(w, i, j):
			continue
		if Collide.circle_vs_obb(a.pos(j), a.radius[j], sq) == Vector2.ZERO:
			continue
		under.append(j)
		var id := a.ids[i]
		var at := a.pos(j)
		Damage.hit(
			w,
			j,
			SafeArea.cost(w, st.lock_hit),
			id,
			id,
			w.take_root(),
			SimEvent.TAG_AREA,
			sq.center,
			at,
			SHELL_EFFECT
		)
	return under


## True when actor j (not the hero) keeps a boulder of boss i off: the boss itself, its ammo cart, another boss, or a
## body that is not an enemy.
static func _denies(w: World, i: int, j: int) -> bool:
	var a := w.actors
	return (
		j == i
		or a.state[j] == BossDoom.CART
		or BossAi.entry_of(w, j) >= 0
		or not EnemyAi.is_enemy_kind(a.kinds[j])
	)


## True when a boulder of half side h fits at c for boss i: the rule in the class comment. The closest points of two
## convex boxes include a corner of one of them, so the corners of both are tested (BossSignatures.fits).
static func fits(w: World, i: int, c: Vector2, h: float) -> bool:
	var sq := Obb.make(c, Vector2(h, h), 0)
	var gap := 2.0 * w.player.radius_m + PASS_SLACK_M
	var room := w.bosses.arena
	if room.has_area() and not room.grow(-(h + gap)).has_point(c):
		return false
	var a := w.actors
	for j in range(1, a.size()):
		if a.dead[j] == 1 or not _denies(w, i, j):
			continue
		var margin := gap if j == i else BODY_MARGIN_M
		if Collide.circle_vs_obb(a.pos(j), a.radius[j] + margin, sq) != Vector2.ZERO:
			return false
	var mine := BossSignatures.corners(sq)
	for k in w.walls_near(sq.bounds().grow(gap + 0.01)):
		var wall: Obb = w.walls[k]
		if Collide.circle_vs_obb(c, h, wall) != Vector2.ZERO:
			return false
		for q: Vector2 in mine:
			if Collide.circle_vs_obb(q, gap, wall) != Vector2.ZERO:
				return false
		for q: Vector2 in BossSignatures.corners(wall):
			if Collide.circle_vs_obb(q, gap, sq) != Vector2.ZERO:
				return false
	return true


## Actor j (the hero, or an enemy that lived through the shell) the new boulder `box` stands on goes to the nearest
## free spot outside it (BossRewind.free_spot from the shortest way out; an enemy with no free spot found stays at
## the way out, where the collision pass takes it). Returns true when it was moved.
static func _push_out(w: World, i: int, box: Obb, j: int) -> bool:
	var a := w.actors
	var p := a.pos(j)
	var r := w.player.radius_m if j == 0 else a.radius[j]
	var push := Collide.circle_vs_obb(p, r, box)
	if push == Vector2.ZERO:
		return false
	var off := p - box.center
	if Kin.length(off) < 0.001:
		off = a.pos(i) - box.center  # Dead centre: out toward the boss
	var out := push if Kin.length(push) > 0.001 else off
	var to := p + out + out / maxf(Kin.length(out), 0.001) * PUSH_SLACK_M
	var spot := BossRewind.free_spot(w, i, to)
	if j != 0 and not BossRewind.is_free(w, i, spot):
		spot = to
	a.set_pos(j, spot)
	return true


## Removes the boulders whose time is up (DUE), every boulder (ALL) or every boulder of boss `which`, walls and all.
static func drop(w: World, which: int = DUE) -> void:
	var bs := w.boss_fight
	var gone: Array[int] = []
	for k in bs.sg_b_x.size():
		var due := bs.sg_b_until[k] <= w.tick
		if which == ALL or bs.sg_b_boss[k] == which or (which == DUE and due):
			gone.append(k)
	if not gone.is_empty():
		_remove(w, gone, END_EXPIRED if which == DUE else END_CLEARED)


## Shatters the boulders a circle of radius r at p touches (the ammo cart's way). Returns how many.
static func smash_at(w: World, p: Vector2, r: float) -> int:
	var bs := w.boss_fight
	var gone: Array[int] = []
	for k in bs.sg_b_x.size():
		if Collide.circle_vs_obb(p, r, boulder_obb(bs, k)) != Vector2.ZERO:
			gone.append(k)
	if not gone.is_empty():
		_remove(w, gone, END_SHATTERED)
	return gone.size()


## Removes boulders `rows` (ascending indices), walls and all, each with a BOULDER_DOWN event.
static func _remove(w: World, rows: Array, why: int) -> void:
	var bs := w.boss_fight
	var walls: Array[Obb] = []
	for n in range(rows.size() - 1, -1, -1):
		var k: int = rows[n]
		walls.append(boulder_obb(bs, k))
		var id := bs.sg_b_boss[k]
		var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, boulder_obb(bs, k).center)
		e.effect_id = BOULDER_DOWN
		e.amount = bs.sg_b_id[k]
		e.amount_applied = why
		bs.remove_boulder(k)
	w.remove_barriers(walls)
	BossSignatures.set_nav_extra(w)


# --- the Shockwave's cover --------------------------------------------------------------------------------------


## True when boss i's attack atk falls under the cover rule now: a `slam_ring` of a boss with a siege, in cover_phase
## or later.
static func covers(w: World, i: int, atk: BossAttackTable) -> bool:
	var st := BossAi.table_of(w, i).siege
	if st == null or atk == null or atk.move != M.SLAM_RING:
		return false
	return w.bosses.phase[BossAi.entry_of(w, i)] >= st.cover_phase


## BossAi.ring_of: [centre, inner, outer] of boss i's ring attack atk; its inner radius is 0 under the cover rule
## (nowhere near the boss is safe).
static func ring(w: World, i: int, atk: BossAttackTable) -> Array:
	var inner := 0.0 if covers(w, i, atk) else atk.inner_radius_m
	return [Vector2(w.actors.lock_x[i], w.actors.lock_y[i]), inner, atk.radius_m]


## BossAi.resolve, boss i's ring attack atk strikes (its first active tick; r its ring, p and pr the hero): true when
## its ring touches the hero, which BossAi then hits; under the cover rule the blast is struck here instead (_strike)
## and this is false.
static func ring_hits(
	w: World, i: int, atk: BossAttackTable, r: Array, p: Vector2, pr: float
) -> bool:
	if not covers(w, i, atk):
		return AttackShapes.ring_touches(r[0], r[1], r[2], p, pr)
	_strike(w, i, atk)
	return false


static func _strike(w: World, i: int, atk: BossAttackTable) -> void:
	var b := BossAi.entry_of(w, i)
	var bs := w.bosses
	if bs.hit[b] == 1 or w.player_dead():
		return
	var shattered := take_cover(w, i)
	var got := 0
	if shattered < 0:
		bs.hit[b] = 1
		var st := BossAi.table_of(w, i).siege
		var dmg := mini(BossAi.powered(w, i, atk.damage), SafeArea.cost(w, st.shock_cap))
		var id := w.actors.ids[i]
		var from := w.actors.pos(i)
		got = Damage.hit(w, 0, dmg, id, id, w.take_root(), SimEvent.TAG_AREA, from, w.player_pos())
		if w.player_dead() and w.killer_attack < 0:
			w.killer_attack = bs.attack[b]
	var e := _event(w, i, SHOCKWAVE, w.actors.pos(i))
	e.amount = got
	e.amount_applied = maxi(0, shattered)


## True while boss i cannot see the hero (the cover a blast needs).
static func covered(w: World, i: int) -> bool:
	return not EnemyAi.sees_player(w, w.actors.pos(i))


## A blast from boss i under the cover rule: -1 when it sees the hero (the caller hurts it); else the boulders on the
## line that saved the hero shatter, and their count is returned.
static func take_cover(w: World, i: int) -> int:
	var from := w.actors.pos(i)
	if EnemyAi.sees_player(w, from):
		return -1
	var bs := w.boss_fight
	var p := w.player_pos()
	var on_line: Array[int] = []
	for k in bs.sg_b_x.size():
		if Collide.sweep_vs_obb(from, p, EnemyAi.SIGHT_R_M, boulder_obb(bs, k)) >= 0.0:
			on_line.append(k)
	if not on_line.is_empty():
		_remove(w, on_line, END_SHATTERED)
	return on_line.size()


## BossAi._choose (through BossGreatJavelin.may_use): false while the attack is held for want of cover (holds()).
static func may_use(w: World, i: int, atk: BossAttackTable) -> bool:
	return BossGreatJavelin.may_use(w, i, atk) and not holds(w, i, atk)


## BossChallenge.punish_due: attack k of boss entry b, or -1 while it is held (holds()).
static func unless_held(w: World, b: int, k: int) -> int:
	if k < 0:
		return k
	var i := w.actors.index_of(w.bosses.ids[b])
	return -1 if i >= 0 and holds(w, i, BossAi.table_of(w, i).attacks[k]) else k


## True while boss i's attack atk may not start under the cover rule: a cart rolls or a Doom Shell is due (never both
## at once), or no boulder stands and no shell has landed since the attack was first held (the first refusal starts
## that clock; a boulder standing ends it).
static func holds(w: World, i: int, atk: BossAttackTable) -> bool:
	if not covers(w, i, atk):
		return false
	var bs := w.boss_fight
	if BossDoom.busy(w):
		return true
	if not bs.sg_b_x.is_empty():
		bs.sg_held = -1
		return false
	if bs.sg_held < 0:
		bs.sg_held = w.tick
	return bs.sg_landed < bs.sg_held


## Damage.target_mult's boss multiplier (BossChallenge.hit_mult) and its ticks: what boss i takes while its armour is
## stripped (per mille; 1000 otherwise).
static func taken_permille(w: World, i: int) -> int:
	var bs := w.boss_fight
	if bs.sg_boss != w.actors.ids[i] or w.tick >= bs.sg_strip_until:
		return 1000
	return BossAi.table_of(w, i).siege.strip_taken


## The markers point at every boulder standing while a Shockwave under the cover rule winds up and while a Doom Shell
## comes (BossDoom.coming).
static func _markers(w: World, i: int, b: int, st: BossSiegeTable) -> void:
	var bs := w.bosses
	var fs := w.boss_fight
	var atk := BossAi.attack_of(w, i) if bs.attack[b] >= 0 else null
	var want := atk != null and w.actors.state[i] == EnemyAi.State.WINDUP and covers(w, i, atk)
	want = want or BossDoom.coming(w, st)
	if w.objectives.has(ObjectiveMarkers.SIEGE_BOULDER):
		w.objectives.clear(ObjectiveMarkers.SIEGE_BOULDER)
	if want:
		for k in fs.sg_b_x.size():
			w.objectives.point(ObjectiveMarkers.SIEGE_BOULDER, Vector2(fs.sg_b_x[k], fs.sg_b_y[k]))


# --- the end of a fight -----------------------------------------------------------------------------------------


## The hero is dead or outside the room: the lock ends, the boulders crumble, the cart and a Doom Shell due go (the
## clocks stay).
static func cancel(w: World) -> void:
	var bs := w.boss_fight
	bs.sg_lock_from = -1
	if not bs.sg_b_x.is_empty():
		drop(w, ALL)
	BossDoom.cancel(w)
	w.objectives.clear(ObjectiveMarkers.SIEGE_BOULDER)


## BossSignatures.on_boss_gone: the boss that ran the siege takes its boulders, its cart and its marker with it.
static func on_boss_gone(w: World, boss_id: int) -> void:
	var bs := w.boss_fight
	if bs.sg_b_boss.has(boss_id):
		drop(w, boss_id)
	if bs.sg_boss != boss_id:
		return
	BossDoom.cancel(w)
	bs.clear_siege()
	w.objectives.clear(ObjectiveMarkers.SIEGE_BOULDER)


static func _event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


# --- the view's read (WorldReader.boss_siege) -------------------------------------------------------------------


## {} with no boss running a siege; else "boss" (its actor index), "room" (Rect2), "lock" ({} or "centre", "radius",
## "locked" (it holds still now), "left" (ticks to the shell)), "lock_in" (ticks until the next may begin, -1 not in
## its phase yet), "boulders" ([{id, centre, half, size (m across), left (ticks), crumbling}], oldest first),
## "cover_rule" (a Shockwave now needs cover), "covered" (the boss cannot see the hero now), "cart", "cart_blast"
## (the cart's blast radius, m), "doom" and "doom_in" (BossDoom.state), "stripped" (ticks of armour stripped left, 0
## none).
static func state(w: World) -> Dictionary:
	var bs := w.bosses
	var fs := w.boss_fight
	var i := w.actors.index_of(fs.sg_boss) if fs.sg_boss >= 0 else -1
	if i < 0:
		return {}
	var st := BossAi.table_of(w, i).siege
	var out := {
		"boss": i,
		"room": room_of(w, i),
		"lock": _lock_state(w, st),
		"lock_in": maxi(0, fs.sg_lock_due - w.tick) if fs.sg_lock_due >= 0 else -1,
		"boulders": _boulder_rows(w),
		"cover_rule": bs.phase[BossAi.entry_of(w, i)] >= st.cover_phase,
		"covered": covered(w, i),
		"stripped": maxi(0, fs.sg_strip_until - w.tick),
	}
	out.merge(BossDoom.state(w, i, st))
	return out


static func _lock_state(w: World, st: BossSiegeTable) -> Dictionary:
	var bs := w.boss_fight
	if bs.sg_lock_from < 0:
		return {}
	var t := w.tick - bs.sg_lock_from
	return {
		"centre": lock_centre(w),
		"radius": st.lock_radius_m,
		"locked": t >= st.lock_ticks - st.lock_hold_ticks,
		"left": maxi(0, st.lock_ticks - t),
	}


static func _boulder_rows(w: World) -> Array:
	var out := []
	var bs := w.boss_fight
	for k in bs.sg_b_x.size():
		var left := bs.sg_b_until[k] - w.tick
		(
			out
			. append(
				{
					"id": bs.sg_b_id[k],
					"centre": Vector2(bs.sg_b_x[k], bs.sg_b_y[k]),
					"half": bs.sg_b_h[k],
					"size": bs.sg_b_h[k] * 2.0,
					"left": left,
					"crumbling": left <= CRUMBLE_TICKS,
				}
			)
		)
	return out
