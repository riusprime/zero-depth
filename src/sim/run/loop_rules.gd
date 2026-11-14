class_name LoopRules
extends RefCounted
## v0.10.5 O5b (owner P13, "go for it": each loop remixes rules instead of only inflating numbers;
## docs/roadmap/v0.10.5/O5_LOOPS.md M1-M5): from loop 2, each loop adds one rule drawn from the run's pool
## (RunTable.loop_rules) without repeats, on the named stream `loop_rule_<loop>` of the run seed
## (RunState.finish_floor -> draw). The rules held so far are RunState.loop_rules (saved; a run saved before O5b has
## none) and, on each floor, World.loop_rules (their indices into POOL, set by RunState.prepare). What each does:
## - SWIFT: normal enemies' move and charge speed × RunTable.loop_swift_permille (RunState.scale_enemies);
## - LEAN_MENDING: the heal-orb meter ÷ loop_heal_chance_permille, heal × loop_heal_amount_permille (RunState.prepare);
## - ELITE_HUNT: every floor marks its elite rooms at the loop's last floor's rate (elite_floor);
## - SHIELDED: every normal enemy guards its front: a hit from within World.loop_shield_half_arc of its facing deals
##   World.loop_shield_permille, tagged ARMOURED (Damage.target_mult);
## - POINT_BLANK: ranged enemies' bolt and spread speed × loop_bolt_permille, their keep distance ×
##   loop_keep_permille (RunState.scale_enemies).
## Pure: integers and a named stream.

## Appended, never inserted: World.loop_rules holds indices into it (hashed).
const POOL: Array[StringName] = [
	&"swift", &"lean_mending", &"elite_hunt", &"shielded", &"point_blank"
]
const SWIFT := 0
const LEAN_MENDING := 1
const ELITE_HUNT := 2
const SHIELDED := 3
const POINT_BLANK := 4


## The rule loop `run.loop` adds (call once, when the loop starts): one of the pool's rules the run doesn't hold,
## drawn from `loop_rule_<loop>`; appended to run.loop_rules. Returns it (&"" when the pool is spent or empty).
static func draw(run: RunState) -> StringName:
	var left: Array[StringName] = []
	for id in run.table.loop_rules:
		if POOL.has(id) and not run.loop_rules.has(id):
			left.append(id)
	if left.is_empty():
		return &""
	var rng := RngStream.derive(run.run_seed, "loop_rule_%d" % run.loop)
	var id := left[rng.range_int(0, left.size() - 1)]
	run.loop_rules.append(id)
	run.loop_rule_loop = run.loop
	return id


## The rules `ids` as indices into POOL (World.loop_rules), in the order held.
static func indices(ids: Array[StringName]) -> PackedInt32Array:
	var out := PackedInt32Array()
	for id in ids:
		var k := POOL.find(id)
		if k >= 0:
			out.append(k)
	return out


static func held(w: World, rule: int) -> bool:
	return w.loop_rules.has(rule)


## The run holds rule `rule` (an index into POOL).
static func run_holds(run: RunState, rule: int) -> bool:
	return run.loop_rules.has(POOL[rule])


## The rule the run's current loop added (&"" on loop 1, or a loop that drew none: the pool spent, or a run saved
## before O5b mid-loop): the newest, when RunState.loop_rule_loop is the current loop.
static func newest(run: RunState) -> StringName:
	if run.loop <= 1 or run.loop_rule_loop != run.loop or run.loop_rules.is_empty():
		return &""
	return run.loop_rules[run.loop_rules.size() - 1]


## A rule's name and sentence keys (locale/strings.csv).
static func name_key(id: StringName) -> String:
	return "LOOP_RULE_%s_NAME" % String(id).to_upper()


static func desc_key(id: StringName) -> String:
	return "LOOP_RULE_%s_DESC" % String(id).to_upper()


## The Codex's Lore entry of a rule (CodexStore.LORE_IDS).
static func lore_id(id: StringName) -> StringName:
	return StringName("rule_%s" % id)


## ELITE_HUNT: the floor whose elite-room rate `run`'s current floor uses (FloorPlan.add_secrets): the loop's last
## under the rule, else its own.
static func elite_floor(run: RunState) -> int:
	return run.table.floors if run_holds(run, ELITE_HUNT) else run.floor_index
