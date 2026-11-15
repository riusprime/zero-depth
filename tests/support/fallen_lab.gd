class_name FallenLab
extends RefCounted
## The final arena with The Fallen fighting and its remembered mechanics (BossRemembered), for the tests: NemesisLab's
## world (the fight jumped to its last body), the run's killed bosses set, and helpers that make a mechanic due now
## and step it to a stage. No source boss stands in this world: the mechanics run on The Fallen's own numbers.
## Test-side only.

const R := preload("res://src/sim/ai/boss_remembered.gd")


## The arena of a `build` run of seed `seed_value` with `beaten` (boss ids) killed in the run. With `held` the hero
## is invulnerable; with `windows` The Fallen keeps its mimic windows as shipped (else none).
static func world(
	seed_value: int,
	build: StringName = &"blade",
	beaten: Array = [],
	held: bool = true,
	windows: bool = false
) -> World:
	var w := NemesisLab.world(seed_value, build, [], held, not windows)
	w.boss_fight.fl_beaten = PackedStringArray(beaten)
	return w


static func body(w: World) -> int:
	return FinalLab.body(w)


static func table(w: World) -> FallenRememberedTable:
	return R.table_of(w)


## Makes a mechanic of `kind` due now: the pool holds only it, its clock and the calm are over.
static func due(w: World, kind: int) -> void:
	var fs := w.boss_fight
	fs.fl_beaten = PackedStringArray([String(R.SOURCES[kind])])
	fs.fl_open = w.tick
	fs.fl_next = w.tick
	fs.fl_end = -1
	fs.fl_last = R.NONE


## Steps until the remembered stage is `stage` (R.STAGE_*), at most `limit` ticks; the ticks stepped, or -1.
static func until_stage(
	w: World, stage: int, limit: int = 600, frame: Callable = Callable()
) -> int:
	for k in limit:
		if w.boss_fight.fl_stage == stage:
			return k
		w.step(frame.call(w) if frame.is_valid() else InputFrame.new())
	return -1


## Makes `kind` due and steps into its running stage; the tick it began running, or -1.
static func run(w: World, kind: int) -> int:
	due(w, kind)
	if until_stage(w, R.STAGE_RUN, 900) < 0:
		return -1
	return w.boss_fight.fl_from


## The STATUS_APPLY events of `effect` since `seq`.
static func events(w: World, effect: StringName, seq: int = 0) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(seq):
		if e.kind == SimEvent.Kind.STATUS_APPLY and e.effect_id == effect:
			out.append(e)
	return out


## The live actors of a source boss's kind (none should stand in The Fallen's fight).
static func source_bosses(w: World) -> int:
	var n := 0
	for i in w.actors.size():
		var t := w.boss_table_of_kind(w.actors.kinds[i])
		if t != null and R.SOURCES.values().has(t.id):
			n += 1
	return n
