class_name WarlordLab
extends RefCounted
## Test helpers for the Warlord's charge, banner and duel: JudgeLab's walled 24 m boss room with the Warlord in it,
## and the reads the tests share.

const HALF_M := JudgeLab.HALF_M
const LONG := JudgeLab.LONG
## The phases (indices): plain, the banner's, the duel's; and one past the last (never).
const PLAIN := 0
const BANNER := 1
const DUEL := 2
const NEVER := 9


## The Warlord at `boss_at`, acting, with the hero at `hero_at` and too tough to die. Returns [world, its id].
static func fight(hero_at: Vector2, boss_at := Vector2.ZERO, seed_value: int = 11) -> Array:
	var w := JudgeLab.world(seed_value)
	var i := BossLab.ready_boss(w, &"warlord", boss_at)
	w.actors.set_pos(0, hero_at)
	w.actors.hp[0] = LONG
	w.actors.max_hp[0] = LONG
	return [w, w.actors.ids[i]]


static func table(w: World, aid: int) -> BossTable:
	return BossAi.table_of(w, w.actors.index_of(aid))


static func wl(w: World, aid: int) -> BossWarlordTable:
	return table(w, aid).warlord


## The Warlord starts nothing on its own and (with `still`) stands where it is: only its banner and duel run.
static func hush(w: World, aid: int, still := true) -> void:
	var t := table(w, aid)
	for k in t.phase_attacks.size():
		t.phase_attacks[k] = PackedInt32Array()
	t.punish_ticks = 0
	t.gap_ticks = 0
	if still:
		t.speed = 0.0


## Puts the Warlord in phase `phase` (an index) without its gate.
static func set_phase(w: World, aid: int, phase: int) -> void:
	JudgeLab.set_phase(w, aid, phase)


## A hushed, still Warlord at the centre in phase `phase`, the hero at `hero_at` with 1000 HP; one tick stepped, so
## its clocks run and its phase's first big mechanic is due now (with `due_now`). Returns [world, its id].
static func ready(hero_at: Vector2, phase: int, due_now := true, seed_value: int = 11) -> Array:
	var s := fight(hero_at, Vector2.ZERO, seed_value)
	var w: World = s[0]
	hush(w, s[1])
	set_phase(w, s[1], phase)
	w.actors.max_hp[0] = 1000
	w.actors.hp[0] = 1000
	w.step(InputFrame.new())
	if due_now:
		w.boss_fight.wl_next = w.tick
	return s


## Steps `n` ticks, the hero idle (or moving by `mv`) and refilled each tick. Returns the HP it lost.
static func idle(w: World, n: int, mv := Vector2i.ZERO) -> int:
	var lost := 0
	for k in n:
		w.step(InputFrame.make(mv, 0, 0, 0, 0))
		lost += take_lost(w)
	return lost


## Steps until the banner stands (at most `limit` ticks). Returns the ticks stepped, -1 if it never did.
static func to_banner(w: World, limit: int = 600) -> int:
	for k in limit:
		if w.boss_fight.wl_bn_stage == BossWarlord.STANDS:
			return k
		w.step(InputFrame.new())
		take_lost(w)
	return -1


## Steps until the cage stands (at most `limit` ticks). Returns the ticks stepped, -1 if it never did.
static func to_cage(w: World, limit: int = 600) -> int:
	for k in limit:
		if w.boss_fight.wl_du_stage == BossDuel.CAGE:
			return k
		w.step(InputFrame.new())
		take_lost(w)
	return -1


## The HP the hero has lost since it was last refilled; refills it.
static func take_lost(w: World) -> int:
	var lost := w.actors.max_hp[0] - w.actors.hp[0]
	w.actors.hp[0] = w.actors.max_hp[0]
	return lost


## The STATUS_APPLY events with `effect` after event `seq`.
static func effects(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	return JudgeLab.effects(w, effect, seq)


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


## The read.
static func state(w: World) -> Dictionary:
	return WorldReader.new(w).boss_warlord()
