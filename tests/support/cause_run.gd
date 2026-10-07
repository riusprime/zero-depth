class_name CauseRun
extends RefCounted
## One readable-cause run (v0.3.0 O): a real floor of a run (FightLab), the fighting bot (FightBot), `floor_ticks`
## on the floor with its spawning, then into the boss room for `boss_ticks` against the floor's boss. The player's
## HP is topped up after every tick so the run keeps collecting hits (a test-side write, never gameplay); at the end
## the top-up stops at 1 HP and the run plays on until a hit kills, so the death recap's cause line is checked too.
## Returns {damage, violations, by_cause, death_cause, death_expected, boss_seen}.

const DEATH_LIMIT := 1800


static func run(
	run_seed: int,
	floor_index: int,
	floor_ticks: int,
	boss_ticks: int,
	utility: StringName = &"guard"
) -> Dictionary:
	var w := FightLab.floor_world(run_seed, floor_index, utility)
	var bot := FightBot.new(run_seed * 31 + floor_index)
	var check := ReadableCause.new(w)
	check.context = {"seed": run_seed, "floor": floor_index, "phase": "floor"}
	for t in floor_ticks:
		w.step(bot.frame(w))
		check.observe(w)
		_top_up(w)
	FightLab.enter_boss_room(w)
	check.context["phase"] = "boss"
	var boss_seen := false
	for t in boss_ticks:
		w.step(bot.frame(w))
		check.observe(w)
		boss_seen = boss_seen or w.boss_id >= 0
		_top_up(w)
		if boss_seen and not w.boss_alive():
			break
	check.context["phase"] = "death"
	w.actors.hp[0] = 1
	for t in DEATH_LIMIT:
		if w.player_dead():
			break
		w.step(bot.frame(w))
		check.observe(w)
	var death_cause := ""
	var expected := ""
	if w.player_dead():
		var reader := WorldReader.new(w)
		death_cause = String(reader.killer_cause_key())
		if death_cause.is_empty():
			death_cause = String(EndPanel.CAUSES.get(reader.killer_kind(), "CAUSE_UNKNOWN"))
		expected = check.last_cause
	return {
		"seed": run_seed,
		"floor": floor_index,
		"ticks": w.tick,
		"damage": check.damage_count,
		"violations": check.violations,
		"by_cause": check.by_cause,
		"boss_seen": boss_seen,
		"death_cause": death_cause,
		"death_expected": expected,
	}


static func _top_up(w: World) -> void:
	if not w.player_dead():
		w.actors.hp[0] = w.actors.max_hp[0]
