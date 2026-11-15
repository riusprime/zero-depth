class_name LensLab
extends RefCounted
## Test helpers for the Hive Lens's lattice: JudgeLab's walled 24 m boss room with the Hive Lens in it, and the reads
## the tests share.

const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG


## The Hive Lens at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, its id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"hive_lens", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func lens(w: World, aid: int) -> BossLensTable:
	return table(w, aid).lens


## The Hive Lens starts nothing on its own and (with `still`) stands where it is: only its lattice runs (and the
## split it casts for it).
static func hush(w: World, aid: int, still := true) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	if still:
		t.speed = 0.0


## Puts the Hive Lens in phase `phase` (an index) without its gate.
static func set_phase(w: World, aid: int, phase: int) -> void:
	JudgeLab.set_phase(w, aid, phase)


## A lens drone at `at`, past its spawn-in. Returns its actor id.
static func drone(w: World, aid: int, at: Vector2) -> int:
	var id := w.add_enemy(lens(w, aid).drone_kind, at)
	var j := w.actors.index_of(id)
	w.actors.invuln[j] = 0
	EnemyAi.enter_state(w.actors, j, EnemyAi.State.MOVE)
	return id


## Steps n empty frames.
static func idle(w: World, n: int) -> void:
	for k in n:
		w.step(InputFrame.new())


## The DAMAGE events to the hero with `effect` after event `seq`.
static func hurts(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return ForgeLab.hurts(w, effect, seq)
