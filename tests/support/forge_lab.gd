class_name ForgeLab
extends RefCounted
## Test helpers for the Foundry's forge: JudgeLab's walled 24 m boss room with the Foundry in it, and the reads the
## tests share.

const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG


## The Foundry at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, its id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"foundry", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func forge(w: World, aid: int) -> BossForgeTable:
	return table(w, aid).forge


## The Foundry starts nothing on its own and (with `still`) stands where it is: only its forge runs.
static func hush(w: World, aid: int, still := true) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	t.sig_every_ticks = 0
	if still:
		t.speed = 0.0


## Puts the Foundry in phase `phase` (an index) without its gate.
static func set_phase(w: World, aid: int, phase: int) -> void:
	JudgeLab.set_phase(w, aid, phase)


## A slab of the Foundry's at c (its pools' radius) that crumbles `life` ticks from now. Returns its index.
static func slab(w: World, aid: int, c: Vector2, life: int = 480) -> int:
	var bs := w.boss_fight
	bs.slab_id.append(bs.fg_slab_next)
	bs.fg_slab_next += 1
	bs.slab_boss.append(aid)
	bs.slab_from.append(w.tick)
	bs.slab_until.append(w.tick + life)
	bs.slab_broke.append(0)
	bs.slab_x.append(c.x)
	bs.slab_y.append(c.y)
	bs.slab_r.append(table(w, aid).hazard.radius_m)
	return bs.slab_id.size() - 1


## The HP the hero has lost since it was last refilled; refills it.
static func take_lost(w: World) -> int:
	var lost := w.actors.max_hp[0] - w.actors.hp[0]
	w.actors.hp[0] = w.actors.max_hp[0]
	return lost


## The DAMAGE events to the hero with `effect` after event `seq`.
static func hurts(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(seq):
		if (
			e.kind == SimEvent.Kind.DAMAGE
			and e.target_id == w.actors.ids[0]
			and e.effect_id == effect
		):
			out.append(e)
	return out
