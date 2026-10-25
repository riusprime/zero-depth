class_name Collectibles
extends RefCounted
## v0.9.0 CL (owner: "collectibles are fine", COLLECTIBLES.md as drafted; PLAN W38-W40, W47; CollectState): the
## collectibles a floor can hold. The app arms them at setup (CollectibleBook.arm: the ones the profile hasn't found
## whose source this floor has); each shows as a small pickup at its source the tick the source gives it, and the
## hero takes it by walking over it (PICK_M), a COLLECTIBLE event naming it (the app records it in the profile at
## once: MetaHooks). A final body's piece comes to the hero as the body falls (taken the tick it shows: the fight's
## end leaves no time to walk to it). Where each shows (the source's spot, then a free spot SPOT_M from it):
## - HIDDEN_ROOM, RUNE_ALIGNMENT, TIMED_DOOR: the cracked wall broken / the rune puzzle solved / the timed door opened:
##   in its secret room, between the room's reward and its doorway (the timed door can shut on it again: its switches
##   reopen it);
## - HAZARD_LOCKDOWN: a Hazard Lockdown cleared (not opened by its cap): beside its reward altar;
## - PURPLE_PORTAL: the floor the Purple Portal led to: beside the hero once the floor's arrival ends;
## - BLOOD_SHRINE: the Blood Shrine paid; FOUNTAIN: the fountain drunk (armed on a run's last floor only): beside it;
## - MARKINGS: the run's secrets behind rune markings (the timed door, the rune puzzle, the cracked wall: marked) reach
##   `param` (the finished floors' in marked_before): in the room of the secret that made it;
## - FINAL_BODY: body `param` of the final fight falls (shattered, or the last one beaten).
## Pure sim code: no random draw (where each lies follows from the floor), nothing else reads it.

enum Source {
	HIDDEN_ROOM,
	RUNE_ALIGNMENT,
	TIMED_DOOR,
	HAZARD_LOCKDOWN,
	PURPLE_PORTAL,
	BLOOD_SHRINE,
	FOUNTAIN,
	MARKINGS,
	FINAL_BODY,
}

## How near (m) the hero takes a pickup.
const PICK_M := 1.0
## How far from its source's spot (m) a pickup lies, its clearance from walls and from rewards.
const SPOT_M := 1.5
const CLEAR_M := 0.5
const REWARD_GAP_M := 1.0
const HERO_GAP_M := 0.6
## The free directions tried around a spot when the first doesn't fit (unit vectors, no trig).
const DIRS: Array[Vector2] = [
	Vector2(1, 0),
	Vector2(0.70710678, 0.70710678),
	Vector2(0, 1),
	Vector2(-0.70710678, 0.70710678),
	Vector2(-1, 0),
	Vector2(-0.70710678, -0.70710678),
	Vector2(0, -1),
	Vector2(0.70710678, -0.70710678),
]


## Arms collectible `id` on `w` (setup): it can show from `source` (Source) with the source's number `param`.
static func arm(w: World, id: StringName, source: int, param: int = 0) -> void:
	if w.collect == null:
		w.collect = CollectState.new()
	w.collect.add(id, source, param)


## After the floor's sources each tick: a source that gives its collectible shows it; the hero takes those in reach.
static func advance(w: World) -> void:
	var c := w.collect
	if c == null:
		return
	for k in c.size():
		if c.taken_tick[k] >= 0:
			continue
		if c.shown_tick[k] < 0:
			var at := _shows_at(w, k)
			if at.x == INF:
				continue
			c.pos[k] = at
			c.shown_tick[k] = w.tick
			if c.source[k] == Source.FINAL_BODY:
				_take(w, k)
			continue
		if not w.player_dead() and Kin.length(w.player_pos() - c.pos[k]) <= PICK_M:
			_take(w, k)


static func _take(w: World, k: int) -> void:
	var c := w.collect
	c.taken_tick[k] = w.tick
	var me := w.actors.ids[0]
	var e := w.emit_event(SimEvent.Kind.COLLECTIBLE, me, me, me, c.pos[k])
	e.amount = k
	e.effect_id = StringName(c.ids[k])


## The secrets behind hidden rune markings `w` has found (the timed door opened, the rune puzzle solved, the cracked
## wall broken: WorldReader.secret_doors' three).
static func marked(w: World) -> int:
	var n := 0
	if w.timed != null and w.timed.opened > 0:
		n += 1
	if w.runes != null and w.runes.solved > 0:
		n += 1
	if w.breakables != null and w.breakables.has_crack() and w.breakables.crack_broken > 0:
		n += 1
	return n


## Where entry k shows now (Vector2(INF, INF): its source hasn't given it yet).
static func _shows_at(w: World, k: int) -> Vector2:
	var c := w.collect
	var out := Vector2(INF, INF)
	var f := w.floor_layout
	match c.source[k]:
		Source.HIDDEN_ROOM:
			var b := w.breakables
			if b != null and b.has_crack() and b.crack_broken > 0 and f != null:
				out = _in_secret_room(w, b.crack_reward_id, f.crack_room, f.crack_door)
		Source.RUNE_ALIGNMENT:
			if w.runes != null and w.runes.solved > 0 and f != null:
				out = _in_secret_room(w, w.runes.reward_id, f.rune_room, f.rune_door)
		Source.TIMED_DOOR:
			if w.timed != null and w.timed.opened > 0 and f != null:
				out = _in_secret_room(w, w.timed.reward_id, f.timed_room, f.timed_door)
		Source.HAZARD_LOCKDOWN:
			var room := _hazard_cleared(w)
			if room >= 0:
				var at := Lockdowns.reward_spot(f, room)
				out = spot_near(w, at, f.rooms[room].get_center(), SPOT_M)
		Source.PURPLE_PORTAL:
			if w.boss_flow == null or w.boss_flow.arrive_left <= 0:
				out = spot_near(w, w.player_pos(), w.player_pos() + Vector2(1, 1), SPOT_M + 0.7)
		Source.BLOOD_SHRINE:
			var s := w.shrine
			if s != null and s.kind == ShrineTable.Kind.BLOOD and s.used_tick >= 0:
				out = spot_near(w, s.pos, s.pos * 2.0 - w.player_pos(), SPOT_M + 0.5)
		Source.FOUNTAIN:
			var s := w.shrine
			if s != null and s.fountain_entry >= 0 and s.fountain_tick >= 0:
				out = spot_near(
					w, s.fountain_pos, s.fountain_pos * 2.0 - w.player_pos(), SPOT_M + 0.5
				)
		Source.MARKINGS:
			if c.marked_before + marked(w) >= c.param[k] and f != null:
				out = _last_marked(w)
		Source.FINAL_BODY:
			var ff := w.final_fight
			var body := c.param[k]
			if ff != null and (ff.phase > body or (ff.won and body >= ff.tables.size() - 1)):
				out = w.player_pos()
	return out


## A Hazard Lockdown room cleared by a fight (not its cap), or -1.
static func _hazard_cleared(w: World) -> int:
	var s := w.lockdown
	var f := w.floor_layout
	if s == null or f == null:
		return -1
	for room in s.cleared:
		if s.forced.has(room):
			continue
		var i := f.lockdown_rooms.find(room)
		if (
			i >= 0
			and i < f.lockdown_kinds.size()
			and f.lockdown_kinds[i] == LockdownTable.Kind.HAZARD
		):
			return room
	return -1


## The spot in the room of the marked secret found last (the timed door's, the rune puzzle's, the cracked wall's).
static func _last_marked(w: World) -> Vector2:
	var f := w.floor_layout
	var best := -2
	var at := w.player_pos()
	if w.timed != null and w.timed.opened > 0 and w.timed.open_tick > best:
		best = w.timed.open_tick
		at = _in_secret_room(w, w.timed.reward_id, f.timed_room, f.timed_door)
	if w.runes != null and w.runes.solved > 0 and w.runes.solve_tick > best:
		best = w.runes.solve_tick
		at = _in_secret_room(w, w.runes.reward_id, f.rune_room, f.rune_door)
	var b := w.breakables
	if b != null and b.has_crack() and b.crack_broken > 0 and b.crack_break_tick > best:
		at = _in_secret_room(w, b.crack_reward_id, f.crack_room, f.crack_door)
	return at


## A secret room's spot: from its reward (reward id `reward_id`; the room's middle without one) toward its doorway.
static func _in_secret_room(w: World, reward_id: int, room: int, door: int) -> Vector2:
	var f := w.floor_layout
	var at := f.rooms[room].get_center() if room >= 0 else w.player_pos()
	var i := w.rewards.index_of(reward_id) if reward_id >= 0 else -1
	if i >= 0:
		at = w.rewards.pos(i)
	var toward := f.door_centers[door] if door >= 0 and door < f.door_centers.size() else at
	return spot_near(w, at, toward, SPOT_M)


## A free spot `dist` m from `at` (first toward `toward`, then around it), clear of walls and rewards, out of the
## hero's reach (so it is seen before it is taken) and in `at`'s room; `at` itself when none fits.
static func spot_near(w: World, at: Vector2, toward: Vector2, dist: float) -> Vector2:
	var tries: Array[Vector2] = []
	var d := toward - at
	var n := Kin.length(d)
	if n > 0.001:
		tries.append(d / n)
	tries.append_array(DIRS)
	var f := w.floor_layout
	var room := f.room_of(at) if f != null else -1
	for u in tries:
		var q := at + u * dist
		if room >= 0 and f.room_of(q) != room:
			continue
		if _free(w, q):
			return q
	return at


static func _free(w: World, q: Vector2) -> bool:
	var r := CLEAR_M
	for k in w.walls_near(Rect2(q.x - r, q.y - r, r * 2.0, r * 2.0)):
		if Collide.circle_vs_obb(q, r, w.walls[k]) != Vector2.ZERO:
			return false
	for i in w.rewards.size():
		if Kin.length(w.rewards.pos(i) - q) < REWARD_GAP_M:
			return false
	return Kin.length(w.player_pos() - q) >= PICK_M + HERO_GAP_M
