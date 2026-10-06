class_name World
extends RefCounted
## The whole simulation state, mutated in place one tick at a time (SIM_CONTRACTS §2).
## Determinism: the same (seed, content, loadout, InputFrame log) gives the same state_hash() at every tick.

const EVENT_LOG_CAP := 4096
const BUTTON_BITS: Array[int] = [
	InputFrame.PRIMARY, InputFrame.UTILITY, InputFrame.DASH, InputFrame.INTERACT
]
const DASH_SLOT := 2

var tick := 0
var freeze_ticks := 0
var seed_value := 0

var rng_map: RngStream
var rng_loot: RngStream
var rng_combat: RngStream
var rng_ai: RngStream

var player: PlayerTable
var actors := ActorStore.new()
var projectiles := ProjectileStore.new()
var walls: Array[Obb] = []

## Player state.
var aim_angle := 0
var aim_dist_cm := 0
var move_intent := Vector2i.ZERO
var dash_ticks_left := 0
var dash_cooldown_left := 0
var dash_dir := Vector2.ZERO
## Remaining ticks per button slot (BUTTON_BITS order) for buffered presses.
var input_buffer := PackedInt32Array([0, 0, 0, 0])

## Dummy movers (kernel scenario): speed in metres per tick, shot period and life in ticks.
var dummy_speed := 3.0 / SimTick.TICKS_PER_SECOND
var dummy_fire_period := 0
var projectile_speed := 10.0 / SimTick.TICKS_PER_SECOND
var projectile_life := 120
var projectile_radius := 0.1
## Bench knobs (0 = off, the golden's behaviour): movers hold this distance from the player, and shots
## get up to this much random aim error (1/4096 turns, from the ai stream).
var dummy_keep_distance := 0.0
var dummy_aim_spread := 0
## Damage of a dummy's shot: 0 keeps the kernel scenario harmless.
var dummy_shot_damage := 0

var _next_id := 1
var _event_seq := 0
var _events: Array[SimEvent] = []
var _wall_grid := UniformGrid.new()
var _actor_grid := UniformGrid.new()
## Projectile spawns wait until phase 9 of the tick: [owner, team, pos, vel, damage, radius, life, tags].
var _pending_projectiles: Array[Array] = []


func _init(p_seed: int, p_player: PlayerTable, player_pos: Vector2 = Vector2.ZERO) -> void:
	seed_value = p_seed
	rng_map = RngStream.derive(p_seed, "map")
	rng_loot = RngStream.derive(p_seed, "loot")
	rng_combat = RngStream.derive(p_seed, "combat")
	rng_ai = RngStream.derive(p_seed, "ai")
	player = p_player
	var id := _take_id()
	actors.add(
		id,
		ActorStore.Kind.PLAYER,
		ActorStore.TEAM_PLAYER,
		player_pos,
		player.radius_m,
		player.hp,
		0
	)


## Static walls; call before the first step.
func set_walls(p_walls: Array[Obb]) -> void:
	walls = p_walls
	_wall_grid.clear()
	for i in walls.size():
		_wall_grid.insert_rect(i, walls[i].bounds())


## Adds a dummy mover immediately (setup only; during a tick, spawns are queued).
func add_dummy(p: Vector2, radius_m: float, hp: int) -> int:
	var id := _take_id()
	var first_shot := dummy_fire_period + (id % maxi(dummy_fire_period, 1))
	actors.add(id, ActorStore.Kind.DUMMY, ActorStore.TEAM_ENEMY, p, radius_m, hp, first_shot)
	emit_event(SimEvent.Kind.SPAWN, id, id, id, p)
	return id


## Queues a projectile for phase 9 of this tick.
func queue_projectile(
	owner_id: int,
	team: int,
	at: Vector2,
	vel: Vector2,
	damage: int,
	radius_m: float,
	life: int,
	tags: int
) -> void:
	_pending_projectiles.append([owner_id, team, at, vel, damage, radius_m, life, tags])


## Advances exactly one tick. The phase order is part of the contract (SIM_CONTRACTS §2).
func step(frame: InputFrame) -> void:
	# 1. Freeze check: hit-stop holds everything except buffering new presses.
	if freeze_ticks > 0:
		freeze_ticks -= 1
		_buffer_presses(frame.pressed)
		tick += 1
		return
	# 2. Input (a dead player's input is ignored).
	_age_buffer()
	if player_dead():
		frame = InputFrame.new()
	_buffer_presses(frame.pressed)
	move_intent = frame.move
	aim_angle = frame.aim_angle
	aim_dist_cm = frame.aim_dist_cm
	actors.facing[0] = aim_angle
	# 3. AI.
	_run_ai()
	# 4. Action states.
	_advance_actions()
	# 5. Move and collide.
	_move_and_collide()
	# 6. Hits (projectile sweeps).
	_projectile_hits()
	# 7. Effect queue and 8. statuses arrive in v0.2.0.
	# 9. Deaths and spawns.
	_remove_dead()
	_apply_spawns()
	# 10. Cues are already in the event log. 11. Hashing is on demand (state_hash).
	tick += 1


func add_freeze(ticks: int) -> void:
	freeze_ticks = mini(freeze_ticks + ticks, SimTick.FREEZE_CAP_TICKS)


func player_pos() -> Vector2:
	return actors.pos(0)


func player_dead() -> bool:
	return actors.dead[0] == 1


## The player's guard is up (v0.1.0 Step 3).
func guarding() -> bool:
	return false


## Compiled numbers for an enemy kind (v0.1.0 Step 4); null for kinds without a table.
func enemy_table(_kind: int) -> EnemyTable:
	return null


func dash_iframes_active() -> bool:
	return dash_ticks_left > 0 and player.dash_ticks - dash_ticks_left < player.dash_iframe_ticks


func is_dashing() -> bool:
	return dash_ticks_left > 0


func buffered(bit: int) -> int:
	return input_buffer[BUTTON_BITS.find(bit)]


func last_event_seq() -> int:
	return _event_seq


## Events with seq > after_seq, oldest first. The log keeps the most recent EVENT_LOG_CAP events.
func events_since(after_seq: int) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in _events:
		if e.seq > after_seq:
			out.append(e)
	return out


func state_hash() -> String:
	var h := StateHasher.new()
	h.add_int(tick)
	h.add_int(freeze_ticks)
	h.add_int(seed_value)
	h.add_int(_next_id)
	h.add_int(_event_seq)
	for s in [rng_map, rng_loot, rng_combat, rng_ai]:
		h.add_int(s.state)
	h.add_int(aim_angle)
	h.add_int(aim_dist_cm)
	h.add_int(move_intent.x)
	h.add_int(move_intent.y)
	h.add_int(dash_ticks_left)
	h.add_int(dash_cooldown_left)
	h.add_f32(dash_dir.x)
	h.add_f32(dash_dir.y)
	h.add_ints(input_buffer)
	actors.hash_into(h)
	projectiles.hash_into(h)
	h.add_int(walls.size())
	for w in walls:
		h.add_f32(w.center.x)
		h.add_f32(w.center.y)
		h.add_f32(w.half.x)
		h.add_f32(w.half.y)
		h.add_int(w.angle)
	return h.finish_hex()


## Plain-data copy for inspectors and desync diffs; never used for gameplay.
func snapshot() -> Dictionary:
	return {
		"tick": tick,
		"freeze_ticks": freeze_ticks,
		"next_id": _next_id,
		"event_seq": _event_seq,
		"rng": [rng_map.state, rng_loot.state, rng_combat.state, rng_ai.state],
		"player":
		{"aim": aim_angle, "dash_ticks_left": dash_ticks_left, "dash_cd": dash_cooldown_left},
		"actors": {"ids": actors.ids, "x": actors.pos_x, "y": actors.pos_y, "hp": actors.hp},
		"projectiles": {"ids": projectiles.ids, "x": projectiles.pos_x, "y": projectiles.pos_y},
	}


func _take_id() -> int:
	var id := _next_id
	_next_id += 1
	return id


func emit_event(kind: SimEvent.Kind, source: int, owner: int, target: int, at: Vector2) -> SimEvent:
	_event_seq += 1
	var e := SimEvent.new()
	e.seq = _event_seq
	e.tick = tick
	e.kind = kind
	e.root_id = source
	e.source_id = source
	e.owner_id = owner
	e.target_id = target
	e.pos = at
	_events.append(e)
	if _events.size() > EVENT_LOG_CAP * 2:
		_events = _events.slice(_events.size() - EVENT_LOG_CAP)
	return e


func _age_buffer() -> void:
	for i in input_buffer.size():
		if input_buffer[i] > 0:
			input_buffer[i] -= 1


func _buffer_presses(pressed: int) -> void:
	for i in BUTTON_BITS.size():
		if pressed & BUTTON_BITS[i]:
			input_buffer[i] = SimTick.INPUT_BUFFER_TICKS


func _run_ai() -> void:
	var target := player_pos()
	for i in range(1, actors.size()):
		if actors.kinds[i] != ActorStore.Kind.DUMMY:
			continue
		var id := actors.ids[i]
		if (tick + id) % SimTick.AI_HEAVY_PERIOD == 0:
			actors.jitter_x[i] = rng_ai.range_int(-300, 300) / 100.0
			actors.jitter_y[i] = rng_ai.range_int(-300, 300) / 100.0
		if dummy_fire_period > 0:
			actors.fire_cd[i] -= 1
			if actors.fire_cd[i] <= 0:
				actors.fire_cd[i] = dummy_fire_period
				var from := actors.pos(i)
				var shot_angle := Kin.angle_of(target - from)
				if dummy_aim_spread > 0:
					shot_angle += rng_ai.range_int(-dummy_aim_spread, dummy_aim_spread)
				var dir := Kin.dir(shot_angle)
				var muzzle := from + dir * (actors.radius[i] + projectile_radius + 0.05)
				queue_projectile(
					id,
					ActorStore.TEAM_ENEMY,
					muzzle,
					dir * projectile_speed,
					dummy_shot_damage,
					projectile_radius,
					projectile_life,
					SimEvent.TAG_PROJECTILE
				)


func _advance_actions() -> void:
	for i in actors.size():
		if actors.invuln[i] > 0:
			actors.invuln[i] -= 1
	if player_dead():
		dash_ticks_left = 0
		return
	if dash_cooldown_left > 0:
		dash_cooldown_left -= 1
	if dash_ticks_left > 0:
		dash_ticks_left -= 1
		return
	if input_buffer[DASH_SLOT] > 0 and dash_cooldown_left == 0:
		input_buffer[DASH_SLOT] = 0
		var mv := Vector2(move_intent.x, move_intent.y)
		dash_dir = Kin.dir(Kin.angle_of(mv)) if mv != Vector2.ZERO else Kin.dir(aim_angle)
		dash_ticks_left = player.dash_ticks
		dash_cooldown_left = player.dash_cooldown_ticks


func _move_and_collide() -> void:
	# Player.
	var p := player_pos()
	if player_dead():
		pass
	elif dash_ticks_left > 0:
		p += dash_dir * (player.dash_distance_m / player.dash_ticks)
	elif move_intent != Vector2i.ZERO:
		var mv := Vector2(move_intent.x, move_intent.y) / float(SimTick.MOVE_MAX)
		var len := Kin.length(mv)
		if len > 1.0:
			mv /= len
		p += mv * player.move_speed
	actors.set_pos(0, p)
	# Dummies steer toward the player plus their jitter.
	var target := p
	for i in range(1, actors.size()):
		var at := actors.pos(i)
		var goal := target + Vector2(actors.jitter_x[i], actors.jitter_y[i])
		if dummy_keep_distance > 0.0:
			var away := at - target
			var away_len := Kin.length(away)
			if away_len > 0.0:
				goal += away * (dummy_keep_distance / away_len)
		var to := goal - at
		var dist := Kin.length(to)
		if dist > dummy_speed:
			at += to * (dummy_speed / dist)
		actors.set_pos(i, at)
	# Resolve: walls first, then actor pairs in ascending index order.
	for _iter in SimTick.COLLIDE_ITERS:
		for i in actors.size():
			var ap := actors.pos(i)
			var r := actors.radius[i]
			for w in _wall_grid.query_rect(Rect2(ap.x - r, ap.y - r, r * 2.0, r * 2.0)):
				ap += Collide.circle_vs_obb(ap, r, walls[w])
			actors.set_pos(i, ap)
		_actor_grid.clear()
		for i in actors.size():
			var r := actors.radius[i]
			_actor_grid.insert_rect(
				i, Rect2(actors.pos_x[i] - r, actors.pos_y[i] - r, r * 2.0, r * 2.0)
			)
		for a in actors.size():
			var ra := actors.radius[a]
			var pa := actors.pos(a)
			for b in _actor_grid.query_rect(Rect2(pa.x - ra, pa.y - ra, ra * 2.0, ra * 2.0)):
				if b <= a:
					continue
				var push := Collide.circle_vs_circle(
					actors.pos(a), ra, actors.pos(b), actors.radius[b]
				)
				if push != Vector2.ZERO:
					actors.set_pos(a, actors.pos(a) + push)
					actors.set_pos(b, actors.pos(b) - push)


func _projectile_hits() -> void:
	var dead := PackedInt32Array()
	for i in projectiles.size():
		var a := Vector2(projectiles.pos_x[i], projectiles.pos_y[i])
		var v := Vector2(projectiles.vel_x[i], projectiles.vel_y[i])
		var b := a + v
		var r := projectiles.radius[i]
		# Walls and actors are inserted with their full extent, so the segment only grows by its own radius.
		var span := Rect2(a, Vector2.ZERO).expand(b).grow(r)
		var best_t := 2.0
		var best_actor := -1
		for w in _wall_grid.query_rect(span):
			var t := Collide.sweep_vs_obb(a, b, r, walls[w])
			if t >= 0.0 and t < best_t:
				best_t = t
				best_actor = -1
		for k in _actor_grid.query_rect(span):
			if actors.teams[k] == projectiles.team[i] or actors.dead[k] == 1:
				continue
			var t := Collide.sweep_vs_circle(a, b, r, actors.pos(k), actors.radius[k])
			if t >= 0.0 and (t < best_t or (t == best_t and best_actor >= 0 and k < best_actor)):
				best_t = t
				best_actor = k
		if best_t <= 1.0:
			if best_actor >= 0:
				Damage.hit(
					self,
					best_actor,
					projectiles.damage[i],
					projectiles.ids[i],
					projectiles.owner[i],
					projectiles.root_id[i],
					projectiles.tags[i],
					a,
					a + v * best_t
				)
			dead.append(i)
			continue
		projectiles.pos_x[i] = b.x
		projectiles.pos_y[i] = b.y
		projectiles.life[i] -= 1
		if projectiles.life[i] <= 0:
			dead.append(i)
	projectiles.remove_sorted(dead)


func _remove_dead() -> void:
	var gone := PackedInt32Array()
	for i in range(1, actors.size()):
		if actors.dead[i] == 1:
			gone.append(i)
	actors.remove_sorted(gone)


func _apply_spawns() -> void:
	for s in _pending_projectiles:
		var id := _take_id()
		projectiles.add(id, s[0], s[1], s[2], s[3], s[5], s[6], s[4], s[7])
		emit_event(SimEvent.Kind.SPAWN, id, s[0], id, s[2])
	_pending_projectiles.clear()
