class_name MetaHooks
extends RefCounted
## v0.9.0 MP: where Main's run meets the profile's Rune Fragments and unlocks (MetaProgress), kept out of main.gd:
## - a floor's portal taken (finish_floor): when it was the Purple Portal, the profile records it once and the Void
##   joins the offers from the next floor on (RunState.locked_cards emptied), with a toast;
## - the run's end (bank): the run's fragments go into the profile, shown on the run summary.
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
	if not recap.has("fragments"):
		return recap
	if not _tweaked(main):
		MetaProgress.bank(main.profile, int(recap["fragments"]))
		main.profile.save_file()
	else:
		recap["fragments"] = 0
	recap["fragments_total"] = MetaProgress.fragments(main.profile)
	return recap


## Main's _on_tick: the achievements read the tick (AchievementTracker.observe), then the collectibles (bank_finds).
static func observe(main: Main) -> void:
	main.achievement_tracker.observe(main.driver.reader)
	bank_finds(main)


## v0.9.0 CL (COLLECTIBLES.md; P3 "Added to the Rune Archive" the first time): each collectible the hero took on
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
