extends GutTest
## The dev panel's balance edits on the running floor (docs/tools/DEV_PANEL.md Step 4): with no edits, recompiling
## every table into the running World changes nothing (same state hash); an edit made with F10 open goes into the
## World when F10 closes it, without a Restart floor (the player's speed, an enemy's attack damage, the spawn cap).

const PLAYER := "res://data/player/runner.tres"
const ENEMY := "res://data/enemies/arc_caster.tres"
const SPAWN := "res://data/spawning/floor_1.tres"
const SAVE := "user://e2e_dev_live_balance.json"

var _e: E2e


func after_each() -> void:
	if _e != null and _e.main != null:
		_e.main.tuning.reset_all()
		_e.main.tuning.apply()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _arc_caster(w: World) -> EnemyTable:
	for t: EnemyTable in w.enemy_tables.values():
		if t.name_key == &"ENEMY_ARC_CASTER":
			return t
	return null


func test_no_edits_change_nothing() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	main.tuning.save_path = SAVE
	await _e.start_from_menu()
	await _e.frames(30)
	var before := _e.world().state_hash()
	LiveTuning.apply(_e.world(), main.run, main._content())
	assert_eq(_e.world().state_hash(), before, "the same tables, the same world")


func test_an_edit_goes_live_when_the_panel_closes() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	main.tuning.save_path = SAVE
	await _e.start_from_menu()
	var speed := _e.world().player.move_speed
	var dmg := _arc_caster(_e.world()).damage
	await _e.tap(KEY_F10)
	var panel := main.get_node("UI/DevMasterPanel") as DevMasterPanel
	panel.set_value(DevTuning.key_of(PLAYER, "move_speed_mps"), 9.0)
	panel.set_value(DevTuning.key_of(ENEMY, "attacks/0/damage"), 31)
	panel.set_value(DevTuning.key_of(SPAWN, "cap_by_floor/0"), 3)
	assert_eq(_e.world().player.move_speed, speed, "nothing changes while the panel is open")
	await _e.tap(KEY_F10)
	assert_almost_eq(_e.world().player.move_speed, 9.0 / SimTick.TICKS_PER_SECOND, 0.0001, "live")
	assert_ne(_arc_caster(_e.world()).damage, dmg)
	assert_eq(_e.world().spawner.cap_by_floor[0], 3)
	assert_false(main.driver.paused, "the run goes on")


## Step 5 (owner: tweaked runs don't count): a balance edit drops the run's save and shows the DEV mark; a lighting
## edit alone doesn't.
func test_a_tweaked_run_is_not_saved_and_shows_dev() -> void:
	_e = E2e.new(self)
	var main := await _e.boot()
	main.tuning.save_path = SAVE
	await _e.start_from_menu()
	assert_true(main.saves.store.has_save(), "a normal run saves its start hall")
	var mark := main.get_node("UI/DevMark") as Label
	assert_false(mark.visible)
	await _e.tap(KEY_F10)
	var panel := main.get_node("UI/DevMasterPanel") as DevMasterPanel
	panel.set_value(DevTuning.key_of(main._biome_path, "mood/glow_intensity"), 1.7)
	await _e.tap(KEY_F10)
	assert_false(mark.visible, "lighting alone keeps the run counting")
	assert_true(main.saves.store.has_save())
	await _e.tap(KEY_F10)
	panel = main.get_node("UI/DevMasterPanel") as DevMasterPanel
	panel.set_value(DevTuning.key_of(ENEMY, "hp"), 200)
	await _e.tap(KEY_F10)
	assert_true(mark.visible, "DEV")
	assert_false(main.saves.store.has_save(), "no save to continue a tweaked run")
