class_name TideLab
extends RefCounted
## Test helpers for the Tidecaller's dance: JudgeLab's walled 24 m boss room with the Tidecaller in it, and the
## reads the tests share. Square, so its Riptide strips run along x and are stacked along y, 6 m each.

const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG


## The Tidecaller at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, its id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"tidecaller", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func dance(w: World, aid: int) -> BossDanceTable:
	return table(w, aid).dance


## The Tidecaller starts nothing on its own, fires no stream and (with `still`) stands where it is: only its dance
## runs.
static func hush(w: World, aid: int, still := true) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	t.streams = false
	if still:
		t.speed = 0.0


## Puts the Tidecaller in phase `phase` (an index) without its gate.
static func set_phase(w: World, aid: int, phase: int) -> void:
	JudgeLab.set_phase(w, aid, phase)


## The HP the hero has lost since it was last refilled; refills it.
static func take_lost(w: World) -> int:
	var lost := w.actors.max_hp[0] - w.actors.hp[0]
	w.actors.hp[0] = w.actors.max_hp[0]
	return lost


## The strip (0..3, from the room's low y) the point p lies in.
static func strip_at(w: World, p: Vector2) -> int:
	return SafeArea.strip_of(w.bosses.arena, BossDanceTable.STRIPS, p)


## A point at x in the middle of strip k.
static func in_strip(k: int, x: float = 0.0) -> Vector2:
	return Vector2(x, -HALF_M + (k + 0.5) * HALF_M * 2.0 / BossDanceTable.STRIPS)
