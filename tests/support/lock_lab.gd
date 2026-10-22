class_name LockLab
extends RefCounted
## v0.9.0 LK: a run floor holding a Lockdown, for the sim and view tests: SaveLab's floor (as Main builds it, so
## FloorPlan.add_secrets marked its Lockdowns), the first run seed from `first_seed` whose floor `floor` holds one. The
## hero unhurt, no arrival hold. `horde` keeps the spawner (the formations need it); without it nothing spawns.

const LONG := 1 << 24


static func world(floor: int = 2, first_seed: int = 1, tries: int = 60) -> World:
	for s in range(first_seed, first_seed + tries):
		var w := SaveLab.floor_world(s, floor)
		if w.lockdown != null:
			calm(w)
			return w
	return null


## The hero unhurt and the floor started (no arrival hold).
static func calm(w: World) -> void:
	w.actors.invuln[0] = LONG
	if w.boss_flow != null:
		w.boss_flow.arrive_left = 0
	w.step(InputFrame.new())  # the first tick (the boss door's slab joins the walls)


## The floor's first Lockdown room.
static func room(w: World) -> int:
	return w.floor_layout.lockdown_rooms[0]


## Stands the hero inside Lockdown room `r` (its spawn point nearest the middle, clear of walls) and steps once: the
## seal.
static func enter(w: World, r: int) -> void:
	w.actors.set_pos(0, Lockdowns.reward_spot(w.floor_layout, r))
	w.vel = Vector2.ZERO
	w.step(InputFrame.new())


## Steps until the next formation has spawned (or `limit` ticks).
static func to_wave(w: World, limit: int = 300) -> void:
	var s := w.lockdown
	var n := s.wave
	for k in limit:
		if s.wave > n or not s.sealed():
			return
		w.step(InputFrame.new())


## Kills every fighter now (a hit far over their HP).
static func kill_all(w: World) -> void:
	for i in Lockdowns.fighters(w):
		var p := w.actors.pos(i)
		Damage.hit(w, i, 1 << 20, 0, 0, w.take_root(), 0, p, p)


## Clears the sealed Lockdown: each formation spawned, then killed, until it opens (or `limit` ticks). Returns the
## ticks it took.
static func clear(w: World, limit: int = 3000) -> int:
	var t0 := w.tick
	while w.lockdown.sealed() and w.tick - t0 < limit:
		kill_all(w)
		w.step(InputFrame.new())
	return w.tick - t0
