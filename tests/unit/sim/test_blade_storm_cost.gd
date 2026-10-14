extends GutTest
## v0.8.0 PF2 (owner O9: "find a way … so the game doesn't have lag"; docs/roadmap/v0.8.0/evidence/PERF.md PF2): the
## Blade Storm build's cost.
## - A cast-free line (WandTable.cast_free_lines: Blade Storm): a Blade Storm blade's hits cast no trigger's spell (a
##   returning blade passes each enemy twice a throw, and each hit cast On Hit's slash); the slash and Wave's crescents
##   still cast.
## - A cap of its own (AttackSpec.alive_max, data/modifiers/blade_storm.tres: 36, one Double Slash swing's blades at
##   level 5): past it a throw is cut short with one LIMIT event; Blade Storm alone never reaches it.
## Mechanics only: no bot, no balance (P1).

const FAR_HP := 100000


func _hook(s: AttackSpec, id: StringName) -> AttackHook:
	for k in s.hooks:
		if k.id == id:
			return k
	return null


func _at(w: World, id: StringName, lvl: int) -> void:
	assert_true(CardLevels.set_level(w, WandLab.code(w, id), lvl), "%s to level %d" % [id, lvl])


## A Blade world holding `ids` (in that wand order; the leveled cards at `lvl`) with six far-HP dummies in reach.
func _storm(ids: Array, lvl: int) -> World:
	var w := WandLab.world(&"blade")
	Abilities.grant_start(w)
	Abilities.start_floor(w)
	for id: StringName in ids:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	WandLab.set_order(w, ids)
	for id: StringName in ids:
		if lvl > 1:
			_at(w, id, lvl)
	for k in 6:
		w.add_dummy(Vector2(1.4 + 0.9 * (k / 3), -1.0 + 1.0 * (k % 3)), 0.35, FAR_HP)
	return w


## Primary pressed every tick for `ticks` ticks (aim +x): the most Blade Storm blades alive at once, the LIMIT events
## of the cap, and the player's HITs by effect id.
func _press(w: World, ticks: int) -> Dictionary:
	var seen := w.last_event_seq()
	var pid := w.actors.ids[0]
	var most := 0
	var limits: Array[SimEvent] = []
	var hits := {}
	for t in ticks:
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY))
		most = maxi(most, w.player_projectiles_of(&"blade_storm"))
		for e in w.events_since(seen):
			seen = e.seq
			if e.kind == SimEvent.Kind.LIMIT and e.effect_id == Attacks.EFFECT_ALIVE_CAP:
				limits.append(e)
			elif e.kind == SimEvent.Kind.HIT and e.owner_id == pid and e.target_id != pid:
				hits[e.effect_id] = int(hits.get(e.effect_id, 0)) + 1
	return {"most": most, "limits": limits, "hits": hits}


# --- The cast-free line ------------------------------------------------------------------------------------------
func test_the_shipped_cast_free_line_is_blade_storm() -> void:
	assert_eq(WandTable.new().cast_free_lines, [&"blade_storm"] as Array[StringName])
	var t := WandCompiler.from_repo(WandLab.repo())
	assert_eq(t.cast_free_lines, [&"blade_storm"] as Array[StringName], "data/wand/wand.tres")


func test_storm_blades_cast_no_trigger_but_the_slash_does() -> void:
	var w := WandLab.fight(&"blade", [&"blade_storm", &"trigger_on_hit", &"shared_explosive"])
	var step := Modifiers.step(w, 0)
	assert_not_null(_hook(step, &"trigger_on_hit"), "the slash's hit still casts")
	var blades := _hook(step, &"blade_storm").child
	assert_null(_hook(blades, &"trigger_on_hit"), "a Blade Storm blade's hit casts nothing")
	assert_null(
		_hook(blades, &"shared_explosive"), "and the cards right of the trigger don't reach it"
	)


func test_waves_still_cast() -> void:
	var w := WandLab.fight(&"blade", [&"echo_slash", &"trigger_on_hit"])
	var wave := _hook(Modifiers.step(w, 0), &"echo_slash").child
	assert_not_null(_hook(wave, &"trigger_on_hit"), "only the cast-free line loses its casts")


func test_a_storm_blade_hit_casts_nothing_in_play() -> void:
	var w := _storm([&"blade_storm", &"trigger_on_hit"], 1)
	var hits: Dictionary = _press(w, 60)["hits"]
	assert_gt(int(hits.get(&"blade_storm", 0)), 0, "the blades hit")
	var w2 := _storm([&"trigger_on_hit"], 1)
	var plain: Dictionary = _press(w2, 60)["hits"]
	assert_eq(
		int(hits.get(&"trigger_on_hit", 0)),
		int(plain.get(&"trigger_on_hit", 0)),
		"the casts are the slashes' alone"
	)


# --- The cap of its own ------------------------------------------------------------------------------------------
func test_blade_storm_caps_its_blades_at_36_every_level() -> void:
	var w := WandLab.fight(&"blade", [&"blade_storm"])
	for lvl in range(1, 6):
		_at(w, &"blade_storm", lvl)
		var k := _hook(Modifiers.step(w, 0), &"blade_storm")
		assert_eq(k.child.alive_max, 36, "level %d" % lvl)
		assert_eq(int(k.child.read()["alive_max"]), 36, "the views' read")
	var plain := WandLab.fight(&"blade", [&"echo_slash"])
	assert_eq(_hook(Modifiers.step(plain, 0), &"echo_slash").child.alive_max, 0, "no cap elsewhere")


func test_alone_blade_storm_never_reaches_its_cap() -> void:
	var got := _press(_storm([&"blade_storm"], 5), 300)
	assert_gt(int(got["most"]), 6, "several throws in flight")
	assert_lt(int(got["most"]), 36)
	assert_eq((got["limits"] as Array).size(), 0, "no LIMIT")


func test_with_double_slash_the_cap_holds_with_a_limit_event() -> void:
	var got := _press(_storm([&"double_slash", &"blade_storm"], 5), 300)
	assert_eq(int(got["most"]), 36, "at most 36 in flight")
	var limits: Array = got["limits"]
	assert_gt(limits.size(), 0, "a throw cut short leaves a LIMIT")
	assert_eq((limits[0] as SimEvent).amount, 36)


func test_the_count_holds_the_queued_blades_too() -> void:
	var w := _storm([&"blade_storm"], 5)
	var thrown := 0
	for t in 30:  # the first slash: its throw counts as soon as it is queued (before phase 9 spawns it)
		w.step(InputFrame.make(Vector2i.ZERO, 0, 300, 0, InputFrame.PRIMARY if t == 0 else 0))
		thrown = w.player_projectiles_of(&"blade_storm")
		if thrown > 0:
			break
	assert_eq(thrown, 6, "level 5: six blades, alive or queued")
	assert_eq(w.player_projectiles_of(&"echo_slash"), 0, "another attack's count")


func test_a_spec_without_a_cap_hashes_as_before() -> void:
	var s := AttackSpec.new()
	s.form = AttackSpec.Form.BOLT
	var a := StateHasher.new()
	s.hash_into(a)
	var plain := a.finish_hex()
	s.alive_max = 36
	var b := StateHasher.new()
	s.hash_into(b)
	assert_ne(b.finish_hex(), plain, "a capped spec hashes its cap")
	s.alive_max = 0
	var c := StateHasher.new()
	s.hash_into(c)
	assert_eq(c.finish_hex(), plain, "0 adds nothing (LATE_INT_FIELDS)")
