class_name MetaHooks
extends RefCounted
## Where Main's run meets the profile's Rune Fragments and unlocks (MetaProgress), kept out of main.gd:
## - a floor's portal taken (finish_floor): when it was the Purple Portal, the profile records it once and the Void
##   joins the offers from the next floor on (RunState.locked_cards emptied), with a toast;
## - the run's end (bank): the run's fragments go into the profile, shown on the run summary;
## - v0.10.5 O5a (O5_LOOPS.md D1-D3, R1): the Loop device taken (record_loop): the deepest loop per weapon and the loop
##   robes; the run's end: the fastest true ending per weapon, and the recap's "new record" lines and loop bonus.
## A tweaked run (the dev panel's balance edits) banks and unlocks nothing, as the Codex and the achievements.

const UNLOCK_VOID := {
	"id": &"unlock_void",
	"glyph": &"gate",
	"header_key": &"UI_UNLOCK_TOAST",
	"name_key": &"UNLOCK_VOID_NAME",
	"desc_key": &"UNLOCK_VOID_DESC",
}


## Main's _next_floor: closes the floor (RunState.finish_floor), then the Purple Portal's unlock when it was taken.
static func finish_floor(main: Main) -> void:
	var w := main.driver.world
	var purple := w.boss_flow != null and w.boss_flow.route_taken == Routes.Route.DEEP
	main.run.finish_floor(w)
	if purple:
		travelled_portal(main)


## The run travelled through a Purple Portal: the profile's flag (the first time: the toast) and this run's locks go.
static func travelled_portal(main: Main) -> void:
	if _tweaked(main):
		return
	main.run.locked_cards.clear()
	if MetaProgress.travel_portal(main.profile):
		main.toast.push(UNLOCK_VOID.duplicate())
		main.profile.save_file()


## Main's end panel: the run's recap (Main.run_recap) with its fragments banked (bank).
static func recap(main: Main) -> Dictionary:
	return bank(main, main.run_recap())


## Banks the run's fragments (recap["fragments"]) into the profile and adds the balance after it
## (recap["fragments_total"]). Returns the recap.
static func bank(main: Main, recap: Dictionary) -> Dictionary:
	_records(main, recap)
	if not recap.has("fragments"):
		return recap
	if not _tweaked(main):
		MetaProgress.bank(main.profile, int(recap["fragments"]))
		main.profile.save_file()
	else:
		recap["fragments"] = 0
	recap["fragments_total"] = MetaProgress.fragments(main.profile)
	return recap


## The Loop device took the run to loop `loop` (Main._record_ascension): the Ascension achievements'
## counters, the weapon's deepest loop, and the loop robes it earned (a toast each). A tweaked run records nothing.
static func record_loop(main: Main, loop: int) -> void:
	if main.achievement_tracker != null:  # The Ascension achievements count each loop taken
		main.achievement_tracker.report(&"runs:ascended")
		main.achievement_tracker.raise(RunRecords.LOOP_STAT, loop)  # loop_3, loop_5
	if _tweaked(main) or main.run == null or main.profile == null:
		return
	RunRecords.note_loop(main.profile, main.run.build_id, loop, main.run.run_seed)
	var earned := RunRecords.unlock_loop_robes(main.profile, loop)
	var repo := ContentRepository.load_all() if not earned.is_empty() else null
	for id in earned:
		var def: RobeDefinition = repo.get_def(&"robe", id)
		(
			main
			. toast
			. push(
				{
					"id": StringName("robe_%s" % id),
					"glyph": &"ascend",
					"header_key": &"UI_ROBE_TOAST",
					"name_key": def.name_key if def != null else &"ROBE_HIDDEN",
					"desc_key": def.unlock_hint_key if def != null else &"",
				}
			)
		)
	main.profile.save_file()


## The recap's records (the fastest true ending noted now; the deepest loop noted when it was reached)
## and the loop's fragment multiplier.
static func _records(main: Main, recap: Dictionary) -> void:
	if main.run == null or main.profile == null or recap.is_empty():
		return
	var run := main.run
	recap["loop_bonus_permille"] = RuneFragments.loop_permille(run.fragment_table, run.loop)
	if _tweaked(main):
		return
	recap["record_loop"] = RunRecords.holds_loop(main.profile, run.build_id, run.loop, run.run_seed)
	if bool(recap.get("true_ending", false)):
		var ticks := run.total_ticks(main.driver.world) if main.driver != null else 0
		recap["record_time"] = RunRecords.note_win(main.profile, run.build_id, ticks, run.run_seed)


## Main's _on_tick: the achievements read the tick (AchievementTracker.observe), then the collectibles (bank_finds),
## then the boss hints (boss_hints, v0.11.0 O2).
static func observe(main: Main) -> void:
	main.achievement_tracker.observe(main.driver.reader)
	bank_finds(main)
	boss_hints(main)


## The boss hints. Each tick counts the run for every reason the world points at
## (MechanicHints, in the Codex's profile section), and the floor's HUD gets its gate once: a reason's hint shows in
## its first MechanicHints.MEETINGS runs, while Options "Boss hints" is on. Counted in a tweaked run too (a hint is
## about learning the fight, not a record).
static func boss_hints(main: Main) -> void:
	if main.run == null or main._hud == null:
		return
	var hints := MechanicHints.new(main.codex)
	var run_seed := main.run.run_seed
	var view := main._hud.objective_hints
	if not view.gate.is_valid():  # the lambda keeps its MechanicHints (a bound method wouldn't)
		view.gate = func(reason: StringName) -> bool: return hints.shows(reason, run_seed)
	hints.observe(main.driver.reader, run_seed)


## COLLECTIBLES.md; P3 "Added to the Rune Archive" the first time: each collectible the hero took on
## this floor that the profile hasn't found is written to the profile at once (a death never loses it), joins the
## run's collected ones (no later floor arms it), earns its fragment (RuneFragments.add_collectibles) and shows a toast.
## One the profile already holds (a Continue from before its pickup) gives nothing more. A tweaked run records none.
static func bank_finds(main: Main) -> void:
	var taken := main.driver.reader.collectibles_taken()
	if taken.is_empty() or _tweaked(main):
		return
	for s in taken:
		var id := StringName(s)
		if main.run.collected_run.has(id):
			continue
		main.run.collected_run.append(id)
		if not main.run.collected.has(id):
			main.run.collected.append(id)
		if not CollectibleBook.record(main.profile, id, main.run.run_seed):
			continue
		RuneFragments.add_collectibles(main.run)
		main.profile.save_file()
		var def := main.codex_catalog().collectible(id)
		if def != null:
			main.toast.push(CollectibleBook.toast_of(def))


static func _tweaked(main: Main) -> bool:
	return main.tuning != null and main.tuning.balance_tweaked()
