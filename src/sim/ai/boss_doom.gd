class_name BossDoom
extends RefCounted
## The Siege Engine's Doom Shell (BossSiegeTable.doom_*, cart_*; BossStore.sg_doom_*, sg_cart_*): an ammo cart rolls
## across the room to the boss. Run by BossSiege, beside the boss's attacks.
## - From doom_phase, carts_in(phase) carts a phase: the first doom_first_ticks into the phase, then one every
##   doom_every_ticks; never while one is out, a Doom Shell is due, the boss kneels at a phase change or winds up a
##   Shockwave under the cover rule (and that Shockwave waits for the cart: BossSiege.holds).
## - The cart sets off from the room's wall farthest from the boss (the next farthest when a wall other than a
##   boulder stands in its way; none: it tries again a second later) and rolls straight to the boss's edge in
##   cart_ticks. It is an actor of cart_kind in the CART state (a script row; its HP cart_hp per mille of the boss's
##   max HP, its radius cart_radius_m), hittable at once; it moves only along its line, and shatters every boulder it
##   touches on the way, so it cannot be blocked.
## - It arrives: it is gone (no kill) and doom_ticks later the Doom Shell fires: doom_hit per mille of max HP to a hero
##   the boss can see; a hero in cover takes nothing and the boulders on the line shatter (BossSiege.take_cover).
## - Destroyed first (a kill like any), it blasts where it was: cart_blast_hit per mille of max HP to a hero within
##   cart_blast_m, and a boss within it takes strip_taken per mille for strip_ticks (BossSiege.taken_permille).
## Pure: no stream is drawn.

## The cart's own actor state (EnemyAi.State, BossAi's and the eggs' come first).
const CART := 10
## STATUS_APPLY effects (source the boss). SENT: a cart sets off (pos = where, amount = its roll's ticks). CART_UP: the
## cart's body arrived in the world (target the cart). DESTROYED: it was destroyed and blew (pos = where, amount = the
## HP it cost the hero, amount_applied = 1 when it stripped the boss's armour). ARRIVED: it reached the boss (amount =
## ticks to the Doom Shell). DOOM: the Doom Shell fired (amount = the HP it cost, amount_applied = the boulders it
## shattered, -1 when the hero stood in the open). STRIPPED: the boss's armour is off (amount = its ticks).
const SENT := &"siege_cart"
const CART_UP := &"siege_cart_up"
const DESTROYED := &"siege_cart_destroyed"
const ARRIVED := &"siege_cart_arrived"
const DOOM := &"siege_doom_shell"
const STRIPPED := &"siege_armour_stripped"
## The damage's effect ids of the Doom Shell and the cart's blast.
const DOOM_EFFECT := &"boss_doom_shell"
const BLAST_EFFECT := &"boss_cart_blast"
## The cart stops this far from the boss's edge, and sets off this far inside the wall.
const ARRIVE_GAP_M := 0.1
const EDGE_M := 0.5
## A way blocked by a wall: the next try this many ticks later.
const RETRY_TICKS := 60
## The markers point at the boulders while a cart has this little of its roll left (and while the shell is due).
const WARN_TICKS := 120


## BossSiege.advance: boss i's carts in `phase`.
static func advance(w: World, i: int, st: BossSiegeTable, phase: int) -> void:
	var bs := w.bosses
	if phase >= st.doom_phase and bs.sg_doom_phase != phase:
		bs.sg_doom_phase = phase
		bs.sg_doom_n = 0
		bs.sg_doom_due = w.tick + st.doom_first_ticks
	if bs.sg_doom_at >= 0:
		if w.tick >= bs.sg_doom_at:
			_fire(w, i, st)
		return
	if bs.sg_cart_from >= 0:
		_roll(w, i, st)
		return
	if bs.sg_doom_due < 0 or w.tick < bs.sg_doom_due or bs.sg_doom_n >= st.carts_in(phase):
		return
	var atk := BossAi.attack_of(w, i) if bs.attack[BossAi.entry_of(w, i)] >= 0 else null
	if w.actors.state[i] == BossAi.GATE or BossSiege.covers(w, i, atk):
		return
	_send(w, i, st)


## True while a cart is out or a Doom Shell is due.
static func busy(w: World) -> bool:
	return w.bosses.sg_cart_from >= 0 or w.bosses.sg_doom_at >= 0


## True while a Doom Shell comes: its cart has WARN_TICKS of its roll left or less, or it is due.
static func coming(w: World, st: BossSiegeTable) -> bool:
	var bs := w.bosses
	if bs.sg_doom_at >= 0:
		return true
	return bs.sg_cart_from >= 0 and w.tick - bs.sg_cart_from >= st.cart_ticks - WARN_TICKS


## Sends a cart along the farthest open way, or tries again RETRY_TICKS later.
static func _send(w: World, i: int, st: BossSiegeTable) -> void:
	var bs := w.bosses
	var way := way_of(w, i, st)
	if way.is_empty() or w.enemy_table(st.cart_kind) == null:
		bs.sg_doom_due = w.tick + RETRY_TICKS
		return
	bs.sg_doom_n += 1
	bs.sg_doom_due = w.tick + st.doom_every_ticks
	bs.sg_cart = -1
	bs.sg_cart_from = w.tick
	bs.sg_cart_ax = way[0].x
	bs.sg_cart_ay = way[0].y
	bs.sg_cart_bx = way[1].x
	bs.sg_cart_by = way[1].y
	w.queue_egg(st.cart_kind, way[0], [CART])
	var e := _event(w, i, SENT, way[0])
	e.amount = st.cart_ticks


## [where the cart sets off, where it arrives] for boss i: from the middle of the room's walls, farthest first, the
## first whose straight way to the boss crosses no wall but the boulders; [] when none does.
static func way_of(w: World, i: int, st: BossSiegeTable) -> PackedVector2Array:
	var room := BossSiege.room_of(w, i)
	var e := w.actors.pos(i)
	var r := st.cart_radius_m
	var inner := room.grow(-(r + EDGE_M))
	if not inner.has_area():
		return PackedVector2Array()
	var starts := PackedVector2Array(
		[
			Vector2(inner.position.x, e.y),
			Vector2(inner.end.x, e.y),
			Vector2(e.x, inner.position.y),
			Vector2(e.x, inner.end.y),
		]
	)
	var order: Array[int] = [0, 1, 2, 3]
	for n in range(1, 4):  # Farthest first, ties in the written order
		var k := n
		while k > 0 and Kin.length(starts[order[k]] - e) > Kin.length(starts[order[k - 1]] - e):
			var s := order[k]
			order[k] = order[k - 1]
			order[k - 1] = s
			k -= 1
	var stop := w.actors.radius[i] + r + ARRIVE_GAP_M
	for k in order:
		var a := Vector2(clampf(starts[k].x, inner.position.x, inner.end.x), starts[k].y)
		a.y = clampf(a.y, inner.position.y, inner.end.y)
		var to := e - a
		var d := Kin.length(to)
		if d <= stop + r:
			continue
		var b := a + to / d * (d - stop)
		if _open(w, a, b, r):
			return PackedVector2Array([a, b])
	return PackedVector2Array()


## True when a circle of radius r goes from a to b touching no wall but a boulder.
static func _open(w: World, a: Vector2, b: Vector2, r: float) -> bool:
	var rocks := BossSiege.boulder_obbs(w)
	for k in w.walls_along(a, b, r):
		var wall: Obb = w.walls[k]
		var rock := false
		for o in rocks:
			rock = rock or (o.center == wall.center and o.half == wall.half)
		if not rock and Collide.sweep_vs_obb(a, b, r, wall) >= 0.0:
			return false
	return true


## BossSignatures.make_egg: actor i (just added) is the cart when `egg` says so ([CART]): its HP, its radius, hittable
## at once. Returns false for any other egg.
static func make_cart(w: World, i: int, egg: Array) -> bool:
	if egg.size() != 1 or int(egg[0]) != CART:
		return false
	var bs := w.bosses
	var a := w.actors
	var boss := a.index_of(bs.sg_boss) if bs.sg_boss >= 0 else -1
	if boss < 0 or bs.sg_cart_from < 0:
		leave(w, i)
		return true
	var st := BossAi.table_of(w, boss).siege
	a.hp[i] = maxi(1, a.max_hp[boss] * st.cart_hp / 1000)
	a.max_hp[i] = a.hp[i]
	a.radius[i] = st.cart_radius_m
	a.invuln[i] = 0
	a.facing[i] = Kin.angle_of(
		Vector2(bs.sg_cart_bx - bs.sg_cart_ax, bs.sg_cart_by - bs.sg_cart_ay)
	)
	EnemyAi.enter_state(a, i, CART)
	bs.sg_cart = a.ids[i]
	var e := _event(w, boss, CART_UP, a.pos(i))
	e.target_id = a.ids[i]
	e.amount = st.cart_ticks
	return true


## Actor i goes without a kill (a cart that arrived or crumbled, a turret a shell destroyed).
static func leave(w: World, i: int) -> void:
	w.actors.dead[i] = 1
	w.actors.hp[i] = 0
	EnemyAi.enter_state(w.actors, i, BossSignatures.EGG_GONE)


## Where the cart stands `t` ticks into its roll.
static func cart_at(w: World, st: BossSiegeTable, t: int) -> Vector2:
	var bs := w.bosses
	var a := Vector2(bs.sg_cart_ax, bs.sg_cart_ay)
	var b := Vector2(bs.sg_cart_bx, bs.sg_cart_by)
	return a + (b - a) * (clampi(t, 0, st.cart_ticks) / float(st.cart_ticks))


static func _roll(w: World, i: int, st: BossSiegeTable) -> void:
	var bs := w.bosses
	var t := w.tick - bs.sg_cart_from
	if bs.sg_cart < 0:
		if t > 1:  # Its body never came (no room for it): no cart this time
			bs.sg_cart_from = -1
		return
	var ci := w.actors.index_of(bs.sg_cart)
	if ci < 0 or w.actors.dead[ci] == 1:
		_blast(w, i, st, cart_at(w, st, t - 1))
		return
	var at := cart_at(w, st, t)
	BossSiege.smash_at(w, at, st.cart_radius_m)
	w.actors.set_pos(ci, at)
	if t < st.cart_ticks:
		return
	leave(w, ci)
	bs.sg_cart = -1
	bs.sg_cart_from = -1
	bs.sg_doom_at = w.tick + st.doom_ticks
	var e := _event(w, i, ARRIVED, at)
	e.amount = st.doom_ticks


## The cart was destroyed at `at`: it blasts (the class comment's rule).
static func _blast(w: World, i: int, st: BossSiegeTable, at: Vector2) -> void:
	var bs := w.bosses
	bs.sg_cart = -1
	bs.sg_cart_from = -1
	var got := 0
	var pr := w.player.radius_m
	if not w.player_dead() and AttackShapes.disc_touches(at, st.cart_blast_m, w.player_pos(), pr):
		got = SafeArea.hurt(
			w, i, st.cart_blast_hit, SafeArea.Mode.ONCE, st.shell_cause, BLAST_EFFECT
		)
	var strip := AttackShapes.disc_touches(at, st.cart_blast_m, w.actors.pos(i), w.actors.radius[i])
	var e := _event(w, i, DESTROYED, at)
	e.amount = got
	e.amount_applied = 1 if strip else 0
	if strip:
		bs.sg_strip_until = w.tick + st.strip_ticks
		var s := _event(w, i, STRIPPED, w.actors.pos(i))
		s.amount = st.strip_ticks


## The Doom Shell fires (the class comment's rule).
static func _fire(w: World, i: int, st: BossSiegeTable) -> void:
	w.bosses.sg_doom_at = -1
	var got := 0
	var shattered := -1
	if not w.player_dead():
		shattered = BossSiege.take_cover(w, i)
		if shattered < 0:
			got = SafeArea.hurt(w, i, st.doom_hit, SafeArea.Mode.ONCE, st.shell_cause, DOOM_EFFECT)
	var e := _event(w, i, DOOM, w.actors.pos(i))
	e.target_id = w.actors.ids[0]
	e.amount = got
	e.amount_applied = shattered


## The hero is dead or outside the room, or the boss is gone: the cart crumbles (no blast) and a Doom Shell due goes.
static func cancel(w: World) -> void:
	var bs := w.bosses
	var ci := w.actors.index_of(bs.sg_cart) if bs.sg_cart >= 0 else -1
	if ci >= 0 and w.actors.dead[ci] == 0:
		leave(w, ci)
	bs.sg_cart = -1
	bs.sg_cart_from = -1
	bs.sg_doom_at = -1


static func _event(w: World, i: int, effect: StringName, at: Vector2) -> SimEvent:
	var id := w.actors.ids[i]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, id, id, id, at)
	e.effect_id = effect
	return e


## BossSiege.state's cart part: "cart" ({} or "id" (its actor id, -1 until its body arrives), "position", "from",
## "to", "hp", "max", "progress" (0..1000 along its way), "left" (ticks of its roll), "state" (&"rolling")), "doom"
## (ticks until the Doom Shell fires, -1 none due), "doom_in" (ticks until the next cart may roll, -1 none yet).
static func state(w: World, i: int, st: BossSiegeTable) -> Dictionary:
	var bs := w.bosses
	var cart := {}
	if bs.sg_cart_from >= 0:
		var t := w.tick - bs.sg_cart_from
		var ci := w.actors.index_of(bs.sg_cart) if bs.sg_cart >= 0 else -1
		cart = {
			"id": bs.sg_cart,
			"position": w.actors.pos(ci) if ci >= 0 else cart_at(w, st, t),
			"from": Vector2(bs.sg_cart_ax, bs.sg_cart_ay),
			"to": Vector2(bs.sg_cart_bx, bs.sg_cart_by),
			"hp": w.actors.hp[ci] if ci >= 0 else 0,
			"max": w.actors.max_hp[ci] if ci >= 0 else 0,
			"progress": clampi(t * 1000 / st.cart_ticks, 0, 1000),
			"left": maxi(0, st.cart_ticks - t),
			"state": &"rolling",
		}
	var more := bs.sg_doom_n < st.carts_in(bs.phase[BossAi.entry_of(w, i)])
	return {
		"cart": cart,
		"doom": maxi(0, bs.sg_doom_at - w.tick) if bs.sg_doom_at >= 0 else -1,
		"doom_in": maxi(0, bs.sg_doom_due - w.tick) if bs.sg_doom_due >= 0 and more else -1,
	}
