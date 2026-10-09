extends GutTest
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md §7, "Tests without bots"): the start of the combinatorial smoke test.
## Every shipped modifier, alone and with every other one, compiled onto the weapon attacks of a Blade run and a Gun
## run (heat on, both Skills in play), runs the AttackScenario script: no watchdog LIMIT, the launches per tick under
## the cap, a bounded number of live projectiles, and (alone, and all together) the same digest and state hash when
## replayed. Mechanics only: no bot, no balance (owner P1: "From now on not run bot tests").

const SOLO_TICKS := 300
const PAIR_TICKS := 120
const MAX_LIVE_PROJECTILES := 400

var _mods: Array[ModifierTable] = []


func before_all() -> void:
	_mods = ModifierCompiler.compile_modifiers(AttackScenario.repo())


## Runs the script for `ticks` on a `weapon` run with `mods` compiled onto its attacks. Returns {digest, hash,
## limits, max_launches, max_projectiles}.
func _run(weapon: StringName, mods: Array[ModifierTable], ticks: int) -> Dictionary:
	var w := AttackScenario.world(weapon, [], true, [])
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
	assert_eq(_mods.size(), 14, "the 14 migrated attack items (MX1)")


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
