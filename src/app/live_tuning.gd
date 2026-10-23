class_name LiveTuning
extends RefCounted
## The dev panel's balance edits on the running floor (docs/tools/DEV_PANEL.md Step 4; owner pick "Live + restart
## button"). Every table the sim reads is compiled again from the tweaked content and put into the World in place
## of the old one, with the floor's scaling applied as at floor start; then the build is refreshed (modifiers,
## combos, attack specs), the player's max HP follows the new numbers, and the hidden catch-up is read again.
## Called between ticks only (the panel pauses the run; Main applies it when the panel closes). What is fixed when
## something spawns (an enemy's or boss's HP, the shards it carries) changes for the next ones; what is laid out
## when the floor is built (chests, altars, rooms, the event rooms and curses) takes Restart floor; the run's
## per-floor numbers take effect on the next floor or on Restart floor.


static func apply(w: World, run: RunState, repo: ContentRepository) -> void:
	var player := ContentCompiler.compile_player(repo.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(player, repo.get_def(&"build", run.build_id))
	var aff := FloorPlan.affinity_def(repo, run)  # v0.9.0 RB: as FloorPlan (A2 Storm's dash; the offer bias)
	if aff != null and not aff.is_none():
		player.dash_cooldown_ticks += SimTick.seconds_to_ticks(aff.dash_cooldown_add_seconds)
	w.player = player
	var enemies := ContentCompiler.compile_enemies(repo)
	run.scale_enemies(enemies)
	w.set_enemy_tables(enemies)
	var bosses := ContentCompiler.compile_bosses(repo)
	run.scale_bosses(bosses)
	w.set_boss_tables(bosses)
	w.spawner = ContentCompiler.compile_floor_spawning(repo, run.floor_index)
	w.set_item_tables(ContentCompiler.compile_items(repo))
	w.set_combo_tables(ContentCompiler.compile_combos(repo))
	w.reward_table = ContentCompiler.compile_rewards(repo.get_def(&"rewards", &"floor"))
	if w.shop_table != null:
		w.shop_table = ContentCompiler.compile_shop(repo.get_def(&"shop", &"terminal"))
	w.gamble_table = ContentCompiler.compile_gamble(repo.get_def(&"gamble", &"shrine"))
	w.ability_tables = ContentCompiler.compile_abilities(repo)
	w.stat_tables = ContentCompiler.compile_stat_cards(repo)
	w.overrun_table = ContentCompiler.compile_overrun(repo.get_def(&"overrun", &"overrun"))
	if w.arena_table != null:
		w.arena_table = RunContentCompiler.compile_arena(repo.get_def(&"arena", &"arena"))
	w.legendary_table = RunContentCompiler.compile_legendary(
		repo.get_def(&"legendary", &"boss"), w.stat_tables, w.item_tables
	)
	# v0.8.0 FL: floor-paced loot (LootPacing)
	w.loot_pacing = RunContentCompiler.compile_loot_pacing(repo.get_def(&"loot_pacing", &"pacing"))
	if w.heat != null:
		w.heat.table = ContentCompiler.compile_heat(repo.get_def(&"heat", &"overclock"))
	if w.affinity != null:  # v0.9.0 RB: the affinity's numbers (its ward and counts stay)
		var t := RunContentCompiler.compile_affinity(aff, w.item_tables)
		if t != null:
			w.affinity.table = t
	w.refresh_build(false)
	var max_hp := maxi(1, Stats.max_hp(w))
	w.actors.max_hp[0] = max_hp
	w.actors.hp[0] = mini(w.actors.hp[0], max_hp)
	w.catch_up_table = ContentCompiler.compile_catch_up(repo.get_def(&"scaling", &"catch_up"))
	CatchUp.start_floor(w)
	w.tuning = RunContentCompiler.compile_sim_tuning(repo.get_def(&"tuning", &"sim"))
	run.table = ContentCompiler.compile_run(repo.get_def(&"run", Main.RUN_ID))
