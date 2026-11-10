class_name CritterAi
extends RefCounted
## The horde critters' fast path. A surge brings up to its alive_cap of them,
## and each ran the general enemy code three times a tick (EnemyAi.think, move, resolve: a kind check chain, a table
## lookup, a store property read per field, per critter). World now hands its critter rows (actor indices, ascending)
## to these tight loops instead, once per phase:
## - think_all (tick phase 3): the rise-in, then the walk; the cooldown ticks down; the facing turns to the hero on its
##   plan ticks. The plan is EnemyAi.plan's walk (the straight run at the hero, pushed off its neighbours within the
##   spread radius through the actor grid World built this tick, the flow field around walls), on the same id-staggered
##   ticks, in one tight loop after the others (it reads only places, which nothing in the loop moves);
## - move_all (phase 5): each walking critter steps along its plan at its speed (ItemProcs.slow_factor only when a slow,
##   a freeze, a pair or a spell could apply), stopping the tick it touches the hero;
## - touch_all (phase 6): a walking critter touching the hero hurts it (EnemyAi._critter_touch's rule).
## The same values and arithmetic as the general code; what changes is the order: the critters' thinking, moving and
## touching now come after every other actor's in each phase (they read only their own rows and the hero's), so a world
## with critters may hash differently from before O9c, one without hashes the same (the loops are skipped). Pure sim
## (EI-02): no nodes, no engine calls, no randomness.

const FIRST := ActorStore.Kind.DUST_MITE
const LAST := ActorStore.Kind.STAR_MOTE


static func takes(kind: int) -> bool:
	return kind >= FIRST and kind <= LAST


## Phase 3 for critter rows `rows`.
static func think_all(w: World, rows: PackedInt32Array) -> void:
	var a := w.actors
	var period := EnemyAi.PLAN_PERIOD
	var phase := posmod(w.tick, period)
	var ids := a.ids
	var frozen := a.frozen_t
	var holds := not w.spell_hold_id.is_empty()
	var spawn_in := w.tuning.spawn_in_ticks
	var spawn := EnemyAi.State.SPAWN
	var walk := EnemyAi.State.MOVE
	var target := w.player_pos()
	var px := a.pos_x
	var py := a.pos_y
	var state := a.state
	var st := a.state_t
	var cd := a.cd
	var facing := a.facing
	var plans := PackedInt32Array()
	for i in rows:
		var planning := posmod(ids[i], period) == phase
		if planning:
			plans.append(i)
		if frozen[i] > 0 or (holds and Spells.held_still(w, i)):
			continue
		st[i] += 1
		if cd[i] > 0:
			cd[i] -= 1
		if state[i] == spawn:
			if st[i] >= spawn_in:
				state[i] = walk
				st[i] = 0
		elif state[i] == walk and planning:
			facing[i] = Kin.angle_of(target - Vector2(px[i], py[i]))
	a.state = state
	a.state_t = st
	a.cd = cd
	a.facing = facing
	if plans.is_empty():
		return
	var pp := w.phase_probe
	if pp != null:
		pp.begin(&"ai.plan")
	for i in plans:
		plan(w, i)
	if pp != null:
		pp.end(&"ai.plan")


## A critter's plan (EnemyAi.plan's walk without its kind checks): straight at the hero (stopping short of a touch),
## pushed off the enemies within the spread radius (the actor grid World built this tick), along the flow field while
## a wall or a solid blocks the straight line.
static func plan(w: World, i: int) -> void:
	var a := w.actors
	var t := w.enemy_table(a.kinds[i])
	var at := a.pos(i)
	var dir := Vector2.ZERO
	var to := w.player_pos() - at
	var dist := Kin.length(to)
	if dist > 0.0001 and not w.player_dead() and dist > t.radius_m + w.player.radius_m + 0.1:
		dir = to / dist
	if dir != Vector2.ZERO:
		var push := _spread(w, i, at)
		dir = EnemyAi._unit(dir + push * w.tuning.ai_spread_weight)
		a.plan_block[i] = 1 if EnemyAi._blocked(w, at, dir, t.radius_m) else 0
		if a.plan_block[i] == 1:
			var flow := w.nav.direction(at)
			if flow != Vector2.ZERO:
				dir = flow
	a.plan_x[i] = dir.x
	a.plan_y[i] = dir.y


## The push off the enemies within the spread radius of critter i at `at` (EnemyAi._spread_over's rule).
static func _spread(w: World, i: int, at: Vector2) -> Vector2:
	var a := w.actors
	var px := a.pos_x
	var py := a.pos_y
	var dead := a.dead
	var kinds := a.kinds
	var push := Vector2.ZERO
	var spread := w.tuning.ai_spread_radius_m
	var reach := Vector2(spread, spread)
	for j in w.actors_near(Rect2(at - reach, reach * 2.0)):
		if j == 0 or j == i or dead[j] == 1 or kinds[j] < ActorStore.Kind.CHARGER:
			continue
		var d := at - Vector2(px[j], py[j])
		if absf(d.x) >= spread or absf(d.y) >= spread:
			continue
		var l := Kin.length(d)
		if l >= spread:
			continue
		if l <= 0.0001:  # stacked exactly: the higher id steps aside, along +x or -x
			push += Vector2(1.0 if a.ids[i] > a.ids[j] else -1.0, 0.0)
			continue
		push += d / l * (1.0 - l / spread)
	return push


## Phase 5 (the steer) for critter rows `rows`.
static func move_all(w: World, rows: PackedInt32Array) -> void:
	if w.player_dead():
		return
	var a := w.actors
	var target := w.player_pos()
	var pr := w.player.radius_m
	var walk := EnemyAi.State.MOVE
	var state := a.state
	var kinds := a.kinds
	var plan_x := a.plan_x
	var plan_y := a.plan_y
	var frozen := a.frozen_t
	var slow_t := a.slow_t
	var plain := w.pair_mask == 0 and w.spell_hold_id.is_empty()
	var px := a.pos_x
	var py := a.pos_y
	var kind := -1
	var speed := 0.0
	var stop := 0.0
	for i in rows:
		if state[i] != walk:
			continue
		var dir := Vector2(plan_x[i], plan_y[i])
		if dir == Vector2.ZERO:
			continue
		if kinds[i] != kind:
			kind = kinds[i]
			var t := w.enemy_table(kind)
			speed = t.speed
			stop = t.radius_m + pr + 0.1
		var at := Vector2(px[i], py[i])
		if Kin.length(target - at) <= stop:
			continue
		var slow := 1.0
		if not plain or frozen[i] > 0 or slow_t[i] > 0:
			slow = ItemProcs.slow_factor(w, i)
		var p := at + dir * (speed * slow)
		px[i] = p.x
		py[i] = p.y
	a.pos_x = px
	a.pos_y = py


## Phase 6 for critter rows `rows`: the touch.
static func touch_all(w: World, rows: PackedInt32Array) -> void:
	var a := w.actors
	var walk := EnemyAi.State.MOVE
	var pr := w.player.radius_m
	var kind := -1
	var reach := 0.0
	var damage := 0
	var wait := 0
	var dead := a.dead
	var state := a.state
	var cd := a.cd
	var frozen := a.frozen_t
	var kinds := a.kinds
	var px := a.pos_x
	var py := a.pos_y
	for i in rows:
		if dead[0] == 1:
			return
		if dead[i] == 1 or state[i] != walk or cd[i] > 0 or frozen[i] > 0:
			continue
		if kinds[i] != kind:
			kind = kinds[i]
			var t := w.enemy_table(kind)
			damage = t.damage if t != null else 0
			reach = (t.radius_m if t != null else 0.0) + pr + EnemyAi.CRITTER_TOUCH_M
			wait = t.contact_cd_ticks if t != null else 0
		if damage <= 0:
			continue
		if Kin.length(Vector2(px[0], py[0]) - Vector2(px[i], py[i])) > reach:
			continue
		a.cd[i] = wait
		EnemyAi._hit_player(w, i, damage, SimEvent.TAG_MELEE)
		# The hit may change any row (the hero's guard, a reflex, a kill): read the columns again.
		dead = a.dead
		state = a.state
		cd = a.cd
		frozen = a.frozen_t
		px = a.pos_x
		py = a.pos_y
