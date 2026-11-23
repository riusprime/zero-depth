class_name JudgeLab
extends RefCounted
## Test helpers for the Clockwork Judge's time mechanics: a BossLab world with a walled boss room (the real room is
## open floor inside four walls too), the Judge in it, and the reads the tests share.

const S := EnemyAi.State
## The room's interior: 24 m a side round the origin, behind walls WALL_M thick.
const HALF_M := 12.0
const WALL_M := 1.0
const LONG := 1 << 20


## A world whose boss room is the square above (BossStore.arena set, as the run flow sets it when the door seals).
static func world(seed_value: int = 11) -> World:
	var w := BossLab.world(seed_value)
	var h := HALF_M
	var t := WALL_M * 0.5
	var walls: Array[Obb] = [
		Obb.make(Vector2(0.0, -h - t), Vector2(h + WALL_M, t), 0),
		Obb.make(Vector2(0.0, h + t), Vector2(h + WALL_M, t), 0),
		Obb.make(Vector2(-h - t, 0.0), Vector2(t, h + WALL_M), 0),
		Obb.make(Vector2(h + t, 0.0), Vector2(t, h + WALL_M), 0),
	]
	w.set_walls(walls)
	w.bosses.arena = Rect2(-h, -h, h * 2.0, h * 2.0)
	return w


## The Judge at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, the Judge's id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := world(seed_value)
	var i := BossLab.ready_boss(w, &"clockwork_judge", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


## The Judge keeps only its Time Wave: no other attack by the pick, no echo, no punish, no gap-closer.
static func only_wave(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, w.actors.index_of(aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array([t.attack_index(&"time_wave")])
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0


## The Judge starts nothing on its own.
static func hush(w: World, aid: int) -> void:
	var t := BossAi.table_of(w, w.actors.index_of(aid))
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0


## Puts the Judge in phase `phase` (an index) without its gate.
static func set_phase(w: World, aid: int, phase: int) -> void:
	var i := w.actors.index_of(aid)
	var t := BossAi.table_of(w, i)
	w.bosses.phase[BossAi.entry_of(w, i)] = phase
	w.actors.hp[i] = maxi(1, t.phase_threshold[phase] * w.actors.max_hp[i] / 1000 - 1)


## The STATUS_APPLY events with `effect` after event `seq`.
static func effects(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == effect:
			out.append(e)
	return out


## Steps (the hero idle) until an event with `effect` exists, at most `limit` ticks. Returns it, or null.
static func until_effect(w: World, effect: StringName, limit: int, seq: int = 0) -> SimEvent:
	for k in limit:
		var found := effects(w, effect, seq)
		if not found.is_empty():
			return found[0]
		w.step(InputFrame.new())
	var last := effects(w, effect, seq)
	return last[0] if not last.is_empty() else null


## True when a body of radius `r` can walk from `from` to within `reach` of `to` inside the room: a flood over a
## grid of `cell` metres whose cells are free where the body touches no wall.
static func reachable(
	w: World, from: Vector2, to: Vector2, r: float, cell: float, reach: float
) -> bool:
	var n := int(HALF_M * 2.0 / cell)
	var seen := PackedByteArray()
	seen.resize(n * n)
	var start := Vector2i(int((from.x + HALF_M) / cell), int((from.y + HALF_M) / cell))
	start = start.clamp(Vector2i.ZERO, Vector2i(n - 1, n - 1))
	var queue: Array[Vector2i] = [start]
	seen[start.y * n + start.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var at := Vector2(-HALF_M + (c.x + 0.5) * cell, -HALF_M + (c.y + 0.5) * cell)
		if at.distance_to(to) <= reach:
			return true
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or seen[q.y * n + q.x] == 1:
				continue
			seen[q.y * n + q.x] = 1
			var p := Vector2(-HALF_M + (q.x + 0.5) * cell, -HALF_M + (q.y + 0.5) * cell)
			if EnemyAi.clear_of_walls(w, p, r):
				queue.append(q)
	return false
