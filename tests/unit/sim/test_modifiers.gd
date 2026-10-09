extends GutTest
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §1–§2, §7): the attack specs and their compile. The fixed stage order and
## pick order inside a stage, target filters, the form-layering rule, the v0.5 riders, the hook recursion guard
## (depth, proc coefficient, ancestry, the per-tick launch cap), the spec digest in the state hash, and a save that
## recompiles the specs on load with equal hashes.

const STAGE := ModifierTable.Stage
const OP := ModifierOp.Op
const FORM := AttackSpec.Form
const TRIGGER := AttackSpec.Trigger

var _tables: Array[ItemTable] = []


func before_all() -> void:
	_tables = ContentCompiler.compile_items(AttackScenario.repo())


# --- Helpers --------------------------------------------------------------------------------------------------
static func _mod(id: StringName, target: Array, ops: Array[ModifierOp]) -> ModifierTable:
	var m := ModifierTable.new()
	m.id = id
	m.target = PackedStringArray(target)
	m.ops = ops
	return m


static func _num(op: int, stage: int, field: StringName, value: float) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = op
	o.stage = stage
	o.field = field
	o.value = value
	return o


static func _form(form: int) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = OP.SET_FORM
	o.stage = STAGE.FORM
	o.form = form
	return o


static func _burst_hook(trigger: int, tags: Array, radius: float, permille: int) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = OP.HOOK
	o.stage = STAGE.HOOK
	o.form = FORM.BURST
	o.trigger = trigger
	o.hook_tags = PackedStringArray(tags)
	o.radius_m = radius
	o.damage_permille = permille
	return o


func _world(dummies: Array = []) -> World:
	var w := World.new(3, PlayerTable.starting_values())
	w.dummy_speed = 0.0
	w.set_item_tables(_tables)
	for at: Vector2 in dummies:
		w.add_dummy(at, 0.35, 500)
	return w


func _idx(id: StringName) -> int:
	return AttackScenario.item_index(_tables, id)


func _hits(w: World, effect: StringName) -> Array[SimEvent]:
	var out: Array[SimEvent] = []
	for e in w.events_since(0):
		if e.kind == SimEvent.Kind.HIT and e.effect_id == effect:
			out.append(e)
	return out


# --- Compile order and filters --------------------------------------------------------------------------------
func test_without_modifiers_the_specs_are_the_player_tables() -> void:
	var w := _world()
	var b := Modifiers.book(w)
	assert_eq(
		b.order,
		PackedStringArray(
			["blade_step_0", "blade_step_1", "blade_step_2", "blade_step_3", "gun_bolt"]
		)
	)
	for k in w.player.combo.size():
		var s := b.spec(Modifiers.step_id(k))
		var st: SwingStep = w.player.combo[k]
		assert_eq(
			[s.form, s.half_arc, s.damage, s.hitstop_ticks],
			[FORM.ARC, st.half_arc, st.damage, st.hitstop_ticks]
		)
		assert_eq(s.reach_m, st.reach_m)
	var bolt := b.spec(Modifiers.GUN_BOLT)
	assert_eq(
		[bolt.form, bolt.count, bolt.damage, bolt.period_ticks],
		[FORM.BOLT, 1, w.player.bolt_damage, w.player.shot_period_ticks]
	)
	assert_true(b.modifier_ids.is_empty())


func test_stages_run_in_the_fixed_order_whatever_the_pick_order() -> void:
	var w := _world()
	var pattern := _mod(&"pattern_first", [], [_num(OP.ADD, STAGE.PATTERN, &"count", 2)])
	var form := _mod(&"form_second", [], [_form(FORM.BOLT)])
	var b := Modifiers.compile_for(w, [pattern, form] as Array[ModifierTable])
	var s := b.spec(&"blade_step_0")
	assert_eq(
		s.modifier_ids, PackedStringArray(["form_second", "pattern_first"]), "FORM before PATTERN"
	)
	assert_eq([s.form, s.count], [FORM.BOLT, 3])


func test_inside_a_stage_the_pick_order_holds() -> void:
	var w := _world()
	var dbl := _mod(&"double", [], [_num(OP.MUL_PERMILLE, STAGE.SCALE, &"reach_m", 2000)])
	var plus := _mod(&"plus_one", [], [_num(OP.ADD, STAGE.SCALE, &"reach_m", 1.0)])
	var a := Modifiers.compile_for(w, [dbl, plus] as Array[ModifierTable]).spec(&"blade_step_0")
	var b := Modifiers.compile_for(w, [plus, dbl] as Array[ModifierTable]).spec(&"blade_step_0")
	assert_almost_eq(a.reach_m, 1.6 * 2.0 + 1.0, 1e-5, "×2 then +1")
	assert_almost_eq(b.reach_m, (1.6 + 1.0) * 2.0, 1e-5, "+1 then ×2")


func test_the_numeric_ops() -> void:
	var w := _world()
	var mods: Array[ModifierTable] = [
		_mod(&"a", [], [_num(OP.SET, STAGE.BEHAVIOUR, &"bounces", 4)]),
		_mod(&"b", [], [_num(OP.MIN, STAGE.BEHAVIOUR, &"bounces", 2)]),
		_mod(&"c", [], [_num(OP.MAX, STAGE.BEHAVIOUR, &"pierce", 1)]),
		_mod(&"d", [], [_num(OP.MUL_PERMILLE, STAGE.PAYLOAD, &"damage", 1500)]),
	]
	var s := Modifiers.compile_for(w, mods).spec(Modifiers.GUN_BOLT)
	assert_eq([s.bounces, s.pierce, s.damage], [2, 1, w.player.bolt_damage * 1500 / 1000])


func test_a_target_filter_needs_every_tag() -> void:
	var repo := AttackScenario.repo()
	var t := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, repo.get_def(&"build", &"blade"))
	var w := World.new(3, t)
	var weapon_bolt := _mod(
		&"bolt_only", ["weapon", "projectile"], [_num(OP.ADD, STAGE.BEHAVIOUR, &"bounces", 1)]
	)
	var melee := _mod(&"melee_only", ["melee"], [_num(OP.ADD, STAGE.PAYLOAD, &"damage", 1)])
	var all := _mod(&"all", [], [_num(OP.ADD, STAGE.BEHAVIOUR, &"pierce", 1)])
	var b := Modifiers.compile_for(w, [weapon_bolt, melee, all] as Array[ModifierTable])
	assert_eq(b.spec(Modifiers.GUN_BOLT).bounces, 1)
	assert_eq(b.spec(&"blade_step_0").bounces, 0, "a step is no projectile")
	assert_eq(b.spec(&"blade_step_0").damage, w.player.combo[0].damage + 1)
	var skill := b.spec(Modifiers.SKILL)
	assert_eq(skill.damage, w.player.skill.damage + 1, "Lunge Cleave is melee too")
	assert_eq(
		skill.modifier_ids, PackedStringArray(["all", "melee_only"]), "PAYLOAD after BEHAVIOUR"
	)
	for id in b.order:
		assert_eq(b.spec(StringName(id)).pierce, 1, "%s: an empty target is every spec" % id)


# --- The form-layering rule (design §2) -----------------------------------------------------------------------
func test_a_second_form_layers_where_the_first_ends() -> void:
	var w := _world()
	var bolt := _mod(&"shooting_sword", ["melee"], [_form(FORM.BOLT)])
	var ring := _mod(&"shock_end", ["melee"], [_form(FORM.BURST)])
	var dmg := _mod(&"heavy", ["melee"], [_num(OP.ADD, STAGE.PAYLOAD, &"damage", 5)])
	var s := Modifiers.compile_for(w, [bolt, ring, dmg] as Array[ModifierTable]).spec(
		&"blade_step_0"
	)
	assert_eq(s.form, FORM.BOLT, "the first form op sets the form, the second never replaces it")
	assert_eq(s.hooks.size(), 1)
	var k := s.hooks[0]
	assert_eq(
		[k.id, k.trigger, k.child.form, k.child.depth],
		[&"shock_end", TRIGGER.ON_END, FORM.BURST, 1]
	)
	assert_eq(s.damage, w.player.combo[0].damage + 5)
	assert_eq(k.child.damage, w.player.combo[0].damage + 5, "later payload ops reach the layer too")
	var r := Modifiers.compile_for(w, [ring, bolt] as Array[ModifierTable]).spec(&"blade_step_0")
	assert_eq(
		[r.form, r.hooks[0].child.form], [FORM.BURST, FORM.BOLT], "pick order is the layer order"
	)


func test_an_ember_status_and_element_stack_without_repeats() -> void:
	var w := _world()
	w.add_item(_idx(&"ember_edge"))
	w.add_item(_idx(&"serrated_edge"))
	var s := Modifiers.step(w, 0)
	assert_eq(s.elements, PackedStringArray(["ember", "bleed"]), "in pick order")
	assert_eq([s.stacks_of(&"burn"), s.stacks_of(&"bleed")], [1, 1])


# --- Riders (the v0.5 rules kept exact) -----------------------------------------------------------------------
func test_the_burn_engine_rides_on_the_blade_and_the_slow_on_the_bolt() -> void:
	var w := _world()
	w.add_item(_idx(&"wildfire"))
	var s := Modifiers.step(w, 0)
	assert_true(s.has_status(&"burn"), "Wildfire alone: a step's hits still burn, as in v0.5")
	assert_eq(s.status_rider[s.status_index(&"burn")], 1)
	assert_true(s.elements.is_empty(), "a rider is never drawn as an element")
	var g := _world()
	g.add_item(_idx(&"glacial_edge"))
	assert_true(Modifiers.bolt(g).has_status(&"slow"), "Glacial Edge alone: bolt hits still slow")
	assert_false(Modifiers.bolt(_world()).has_status(&"slow"))


# --- The hook guard -------------------------------------------------------------------------------------------
func test_hooks_recurse_to_depth_two_with_a_falling_proc_coefficient() -> void:
	var w := _world([Vector2(1.2, 0), Vector2(1.2, 0.9), Vector2(0.4, 1.4)])
	var pulse := _mod(
		&"pulse", ["weapon", "melee"], [_burst_hook(TRIGGER.ON_HIT, ["area"], 3.0, 500)]
	)
	pulse.ops[0].effect_id = &"pulse"
	var echo := _mod(&"after_burst", ["area"], [_burst_hook(TRIGGER.ON_HIT, ["area"], 3.0, 500)])
	echo.ops[0].effect_id = &"after_burst"
	w.attack_book = Modifiers.compile_for(w, [pulse, echo] as Array[ModifierTable])
	var step := w.attack_book.spec(&"blade_step_0")
	var child := step.hooks[0].child
	assert_eq([child.depth, child.hooks.size()], [1, 1], "the burst got the area modifier's hook")
	var grand := child.hooks[0].child
	assert_eq([grand.depth, grand.hooks.size()], [2, 0], "nothing compiles below depth 2")
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
	for i in 20:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	var roots := _hits(w, &"")
	assert_gt(roots.size(), 0, "the swing landed")
	assert_eq(roots[0].proc_pct, 100)
	var level1 := _hits(w, &"pulse")
	var level2 := _hits(w, &"after_burst")
	assert_gt(level1.size(), 0)
	assert_gt(level2.size(), 0)
	for e in level1:
		assert_eq(e.proc_pct, 50, "depth 1: half")
	for e in level2:
		assert_eq(e.proc_pct, 25, "depth 2: a quarter")
	assert_true(w.hook_chain.is_empty(), "the chain closes")
	for e in w.events_since(0):
		assert_ne(e.kind, SimEvent.Kind.LIMIT, "no watchdog")


func test_a_hook_never_runs_inside_its_own_chain() -> void:
	var w := _world([Vector2(2.0, 0), Vector2(2.5, 0)])
	var loop := _mod(&"loop", ["area"], [_burst_hook(TRIGGER.ON_HIT, ["area"], 3.0, 500)])
	loop.ops[0].effect_id = &"loop"
	var base := AttackSpec.new()
	base.id = &"probe"
	base.form = FORM.BURST
	base.tags = PackedStringArray(["area"])
	base.radius_m = 4.0
	var s := Modifiers.compile_spec(base, [loop] as Array[ModifierTable])
	assert_eq(s.hooks[0].child.hooks.size(), 1, "the child carries the same hook (depth allows it)")
	var ctx := AttackContext.make(Vector2.ZERO, 0, 10, w.take_root(), SimEvent.TAG_AREA, &"probe")
	assert_true(Attacks.launch(w, s, ctx))
	assert_eq(_hits(w, &"probe").size(), 2)
	# Each of the probe's two hits runs the hook once (its burst hits both dummies); inside that burst the same hook
	# is refused (ancestry), so no depth-2 burst ever launches although the compile allowed one.
	assert_eq(_hits(w, &"loop").size(), 4)
	for e in _hits(w, &"loop"):
		assert_eq(e.proc_pct, 50, "all at depth 1: never again inside itself")


func test_launches_per_tick_are_capped_with_one_limit_event() -> void:
	var w := _world()
	var base := AttackSpec.new()
	base.form = FORM.BURST
	base.radius_m = 1.0
	var ok := 0
	for i in Attacks.MAX_LAUNCHES_PER_TICK + 40:
		Attacks.launch(
			w, base, AttackContext.make(Vector2(50, 50), 0, 1, 1, SimEvent.TAG_AREA, &"")
		)
		ok += 1 if w.launch_count <= Attacks.MAX_LAUNCHES_PER_TICK else 0
	assert_eq(ok, Attacks.MAX_LAUNCHES_PER_TICK)
	var limits := w.events_since(0).filter(
		func(e: SimEvent) -> bool: return e.kind == SimEvent.Kind.LIMIT
	)
	assert_eq(limits.size(), 1)
	assert_eq(limits[0].effect_id, Attacks.EFFECT_LAUNCH_CAP)
	w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, 0))
	Attacks.launch(w, base, AttackContext.make(Vector2(50, 50), 0, 1, 1, SimEvent.TAG_AREA, &""))
	assert_eq(w.launch_count, 1, "a new tick starts a new count")


# --- Hash and saves -------------------------------------------------------------------------------------------
func test_the_spec_digest_is_hashed_once_the_build_has_a_modifier() -> void:
	var plain := _world()
	var h := plain.state_hash()
	plain.attack_book.digest = "changed"
	assert_eq(
		plain.state_hash(), h, "no modifier: the digest stays out (kernel goldens keep their hash)"
	)
	var w := _world()
	w.add_item(_idx(&"long_edge"))
	var with := w.state_hash()
	w.attack_book.digest = "changed"
	assert_ne(w.state_hash(), with, "with a modifier the digest is in the hash")
	Modifiers.invalidate(w)
	assert_eq(w.state_hash(), with, "a recompile gives the same digest")


func test_picking_an_item_recompiles() -> void:
	var w := _world()
	var before := Modifiers.book(w)
	assert_eq(Modifiers.bolt(w).bounces, 0)
	w.add_item(_idx(&"ricochet_core"))
	assert_null(w.attack_book, "the pick dropped the cache")
	assert_eq(Modifiers.bolt(w).bounces, 1)
	assert_ne(Modifiers.book(w), before)
	assert_eq(Modifiers.book(w).modifier_ids, PackedStringArray(["ricochet_core"]))


func test_a_save_stores_the_items_and_the_specs_recompile_on_load() -> void:
	var w := SaveLab.floor_world(44, 2, &"gun")
	for id: StringName in [&"splinter_shot", &"static_chain", &"ricochet_core", &"cinder_shot"]:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	SaveLab.run(w, FightBot.new(44), 500)
	var digest := Modifiers.book(w).digest
	var snap := WorldSnapshot.take(w)
	assert_false((snap["world"] as Dictionary).has(&"attack_book"), "the specs are not saved")
	var base := SaveLab.floor_world(44, 2, &"gun")
	var restored := World.from_snapshot(bytes_to_var(var_to_bytes(snap)), base)
	assert_not_null(restored)
	assert_eq(Modifiers.book(restored).digest, digest, "recompiled from the saved items")
	assert_eq(restored.state_hash(), w.state_hash())
	var b1 := FightBot.new(9)
	var b2 := FightBot.new(9)
	for i in 400:
		w.step(SaveLab.frame(w, b1))
		restored.step(SaveLab.frame(restored, b2))
	assert_eq(restored.state_hash(), w.state_hash(), "equal 400 ticks later")
