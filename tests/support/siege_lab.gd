class_name SiegeLab
extends RefCounted
## Test helpers for the Siege Engine's siege (BossSiege, BossDoom): JudgeLab's walled 24 m boss room with the Engine
## in it, and the reads the tests share.

const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG
## A phase index past the Engine's last: never.
const NEVER := 9


## The Engine at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, its id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"siege_engine", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func siege(w: World, aid: int) -> BossSiegeTable:
	return table(w, aid).siege


## The Engine starts nothing on its own and stands where it is: only its siege runs.
static func hush(w: World, aid: int) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.speed = 0.0


## A hushed, still Engine at `boss_at` in phase index `phase`, with only the named parts of its siege on ("lock",
## "doom").
static func only(
	hero_at: Vector2, boss_at: Vector2, phase: int, parts: Array, seed_value := 11
) -> Array:
	var s := fight(hero_at, boss_at, seed_value)
	var w: World = s[0]
	hush(w, s[1])
	var st := siege(w, s[1])
	if not parts.has("lock"):
		st.lock_phase = NEVER
	if not parts.has("doom"):
		st.doom_phase = NEVER
	JudgeLab.set_phase(w, s[1], phase)
	return s


## The HP the hero has lost since it was last refilled; refills it.
static func take_lost(w: World) -> int:
	var lost := w.actors.max_hp[0] - w.actors.hp[0]
	w.actors.hp[0] = w.actors.max_hp[0]
	return lost


## A boulder of the Engine's at c, as a landed shell leaves it (the tests' shortcut past the lock). Returns its row.
static func boulder(w: World, aid: int, c: Vector2) -> int:
	var bs := w.boss_fight
	var st := siege(w, aid)
	bs.sg_b_id.append(bs.sg_next)
	bs.sg_b_from.append(w.tick)
	bs.sg_b_until.append(w.tick + st.boulder_ticks)
	bs.sg_b_boss.append(aid)
	bs.sg_b_x.append(c.x)
	bs.sg_b_y.append(c.y)
	bs.sg_b_h.append(st.boulder_half)
	bs.sg_next += 1
	w.add_barrier(BossSiege.boulder_obb(bs, bs.sg_b_x.size() - 1))
	BossSignatures.set_nav_extra(w)
	return bs.sg_b_x.size() - 1


## The cart's actor index, or -1.
static func cart(w: World) -> int:
	return w.actors.index_of(w.boss_fight.sg_cart) if w.boss_fight.sg_cart >= 0 else -1


## The hero destroys the cart with one hit.
static func break_cart(w: World) -> void:
	var ci := cart(w)
	var hero := w.actors.ids[0]
	Damage.hit(w, ci, 1 << 20, hero, hero, w.take_root(), 0, w.player_pos(), w.actors.pos(ci))


## The ticks of `effect` events after `seq`.
static func ticks_of(w: World, effect: StringName, seq: int = 0) -> Array[int]:
	var out: Array[int] = []
	for e in JudgeLab.effects(w, effect, seq):
		out.append(e.tick)
	return out


## How many cells of `cell` m inside the room a body of radius r can stand on, and how many of them it can walk to
## from `from` (a flood over the free cells): [free, reached].
static func flood(w: World, from: Vector2, r: float, cell: float) -> Array[int]:
	var n := int(HALF_M * 2.0 / cell)
	var free := PackedByteArray()
	free.resize(n * n)
	var count := 0
	for y in n:
		for x in n:
			var p := Vector2(-HALF_M + (x + 0.5) * cell, -HALF_M + (y + 0.5) * cell)
			if EnemyAi.clear_of_walls(w, p, r):
				free[y * n + x] = 1
				count += 1
	var start := Vector2i(int((from.x + HALF_M) / cell), int((from.y + HALF_M) / cell))
	start = start.clamp(Vector2i.ZERO, Vector2i(n - 1, n - 1))
	if free[start.y * n + start.x] == 0:  # The nearest free cell to a hero between cells
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := (start + d).clamp(Vector2i.ZERO, Vector2i(n - 1, n - 1))
			if free[q.y * n + q.x] == 1:
				start = q
				break
	var seen := PackedByteArray()
	seen.resize(n * n)
	var queue: Array[Vector2i] = [start]
	seen[start.y * n + start.x] = 1
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if q.x < 0 or q.y < 0 or q.x >= n or q.y >= n or seen[q.y * n + q.x] == 1:
				continue
			seen[q.y * n + q.x] = 1
			if free[q.y * n + q.x] == 1:
				queue.append(q)
	return [count, queue.size()]
