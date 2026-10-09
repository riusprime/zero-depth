extends GutTest
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §7, "Tests without bots"): the start of the combinatorial smoke test.
## Every shipped modifier, alone and with every other one, compiled onto the weapon attacks of a Blade run and a Gun
## run (heat on, both Skills in play), runs the AttackScenario script: no watchdog LIMIT, the launches per tick under
## the cap, a bounded number of live projectiles, and (alone, and all together) the same digest and state hash when
## replayed. Mechanics only: no bot, no balance (owner P1: "From now on not run bot tests").
## v0.6.0 MX2: every shipped modifier with the six ability modifiers held (their bombs, drone copies, orbiters,
## fields, rings and fire carry it), and every form as a hook's child and as a layer (LOB, ZONE, RING, ORBITER and
## the MX1 forms) on every attack, the abilities' included: no crash, bounded, the same replay.

const SOLO_TICKS := 300
const PAIR_TICKS := 120
const MAX_LIVE_PROJECTILES := 400
## v0.6.0 MX2: the six ability modifiers (each a slot), held at level 3 in the runs that use them.
const ABILITY_MODS: Array = [
	&"bomb_lobber", &"drone_buddy", &"orbit_blades", &"arc_field", &"frost_nova", &"flame_trail"
]
const FORM := AttackSpec.Form
const OP := ModifierOp.Op
const STAGE := ModifierTable.Stage

var _mods: Array[ModifierTable] = []


func before_all() -> void:
	_mods = ModifierCompiler.compile_modifiers(AttackScenario.repo())


## Runs the script for `ticks` on a `weapon` run with `mods` compiled onto its attacks. Returns {digest, hash,
## limits, max_launches, max_projectiles}.
func _run(
	weapon: StringName, mods: Array[ModifierTable], ticks: int, abilities: Array = []
) -> Dictionary:
	var w := AttackScenario.world(weapon, [], true, abilities)
	for k in w.ability_owned.size():  # v0.6.0 MX2: the ability modifiers at level 3
		if w.ability_tables[w.ability_owned[k]].is_modifier():
			w.ability_levels[k] = 3
	w.refresh_build(false)
	w.attack_book = Modifiers.compile_for(w, mods)
	var h := StateHasher.new()
	var seen := 0
	var limits := 0
	var max_launches := 0
	var max_projectiles := 0
	for t in ticks:
		w.step(AttackScenario.frame(t))
		if w.launch_tick == w.tick - 1:
			max_launches = maxi(max_launches, w.launch_count)
		max_projectiles = maxi(max_projectiles, w.projectiles.size())
		for e in w.events_since(seen):
			seen = e.seq
			h.add_int(e.kind)
			h.add_int(e.target_id)
			h.add_int(e.amount_applied)
			h.add_string(String(e.effect_id))
			if e.kind == SimEvent.Kind.LIMIT:
				limits += 1
	return {
		"digest": h.finish_hex(),
		"hash": w.state_hash(),
		"limits": limits,
		"max_launches": max_launches,
		"max_projectiles": max_projectiles,
	}


func _check(label: String, r: Dictionary) -> void:
	assert_eq(r["limits"], 0, "%s: no LIMIT" % label)
	assert_lte(r["max_launches"], Attacks.MAX_LAUNCHES_PER_TICK, "%s: launches per tick" % label)
	assert_lte(r["max_projectiles"], MAX_LIVE_PROJECTILES, "%s: live projectiles" % label)


func test_every_modifier_is_shipped_and_compiled() -> void:
	assert_eq(
		_mods.size(),
		16,
		"the 14 migrated attack items (MX1), Frost Nova's frost, Razor Orbit (MX2)"
	)


func test_every_modifier_alone_on_each_weapon_runs_and_replays() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for m in _mods:
			var one: Array[ModifierTable] = [m]
			var label := "%s + %s" % [weapon, m.id]
			var a := _run(weapon, one, SOLO_TICKS)
			_check(label, a)
			var b := _run(weapon, one, SOLO_TICKS)
			assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s: replays" % label)


func test_every_pair_of_modifiers_runs() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for i in _mods.size():
			for j in range(i + 1, _mods.size()):
				var pair: Array[ModifierTable] = [_mods[i], _mods[j]]
				_check(
					"%s + %s + %s" % [weapon, _mods[i].id, _mods[j].id],
					_run(weapon, pair, PAIR_TICKS)
				)


func test_all_modifiers_at_once_run_and_replay() -> void:
	for weapon: StringName in [&"blade", &"gun", &""]:
		var a := _run(weapon, _mods, SOLO_TICKS)
		_check("%s + all" % weapon, a)
		var b := _run(weapon, _mods, SOLO_TICKS)
		assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s + all: replays" % weapon)


# --- v0.6.0 MX2 -----------------------------------------------------------------------------------------------
static func _hook(form: int, trigger: int) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = OP.HOOK
	o.stage = STAGE.HOOK
	o.form = form
	o.trigger = trigger
	o.radius_m = 1.2
	o.reach_m = 2.5
	o.damage_permille = 500
	return o


static func _set_form(form: int) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = OP.SET_FORM
	o.stage = STAGE.FORM
	o.form = form
	return o


static func _synthetic(id: String, ops: Array[ModifierOp]) -> ModifierTable:
	var m := ModifierTable.new()
	m.id = StringName(id)
	m.ops = ops
	return m


func test_the_ability_modifiers_carry_every_modifier_and_replay() -> void:
	for weapon: StringName in [&"blade", &"gun"]:
		for m in _mods:
			var one: Array[ModifierTable] = [m]
			var label := "%s + six ability modifiers + %s" % [weapon, m.id]
			var a := _run(weapon, one, PAIR_TICKS * 2, ABILITY_MODS)
			_check(label, a)
			var b := _run(weapon, one, PAIR_TICKS * 2, ABILITY_MODS)
			assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s: replays" % label)
		var all := _run(weapon, _mods, SOLO_TICKS, ABILITY_MODS)
		_check("%s + six ability modifiers + all" % weapon, all)


func test_every_form_as_a_hook_runs_on_every_attack_and_replays() -> void:
	for form: int in [FORM.LOB, FORM.ZONE, FORM.RING, FORM.ORBITER, FORM.BURST, FORM.BEAM]:
		for trigger: int in [AttackSpec.Trigger.ON_HIT, AttackSpec.Trigger.ON_KILL]:
			var ops: Array[ModifierOp] = [_hook(form, trigger)]
			var one: Array[ModifierTable] = [_synthetic("hook_%d_%d" % [form, trigger], ops)]
			for weapon: StringName in [&"blade", &"gun"]:
				var label := "%s + hook form %d trigger %d" % [weapon, form, trigger]
				var a := _run(weapon, one, PAIR_TICKS * 2, ABILITY_MODS)
				_check(label, a)
				var b := _run(weapon, one, PAIR_TICKS * 2, ABILITY_MODS)
				assert_eq([b["digest"], b["hash"]], [a["digest"], a["hash"]], "%s: replays" % label)


func test_every_form_as_a_layer_runs_on_every_attack() -> void:
	var forms := [
		FORM.ARC, FORM.BOLT, FORM.RING, FORM.BEAM, FORM.ZONE, FORM.ORBITER, FORM.LOB, FORM.BURST
	]
	for a: int in forms:
		for b: int in [FORM.BOLT, FORM.LOB, FORM.RING, FORM.ZONE]:
			var ops: Array[ModifierOp] = [_set_form(a), _set_form(b)]
			var one: Array[ModifierTable] = [_synthetic("layer_%d_%d" % [a, b], ops)]
			for weapon: StringName in [&"blade", &"gun"]:
				_check(
					"%s + form %d then %d" % [weapon, a, b],
					_run(weapon, one, PAIR_TICKS, ABILITY_MODS)
				)


func test_the_ability_specs_are_compiled_and_carry_the_weapon() -> void:
	var five := ABILITY_MODS.slice(0, 5)  # Ember Edge takes the sixth slot
	var w := AttackScenario.world(&"blade", [&"ember_edge"], false, five)
	assert_eq(w.mod_slots.size(), 6)
	for id: StringName in five:
		var s := Modifiers.book(w).spec(id)
		assert_not_null(s, "%s has a spec" % id)
		if s != null:
			assert_true(s.has_tag(&"ability"), "%s is an ability's" % id)
			assert_true(s.elements.has("ember"), "%s carries the Blade's ember" % id)
			assert_ne(s.key, "", "%s is filed by key" % id)
