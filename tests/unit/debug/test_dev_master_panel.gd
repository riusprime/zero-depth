extends GutTest
## The master dev panel (docs/tools/DEV_PANEL.md Step 2): it covers every balance folder under data/ (a new
## one fails here),
## reflects every tunable field of a file (nested attacks, dictionaries, arrays), and its edits go into the tuning
## store, are saved and announced; Reset all and Copy changes work.

## Folders that hold no balance: sounds, text, and two legacy folders the run never reads (the knob inventory).
const NOT_BALANCE := ["audio", "credits", "patch_notes", "utilities", "encounters", "achievements"]
const ENEMY := "res://data/enemies/arc_caster.tres"
const SAVE := "user://test_dev_master_panel.json"

var _t: DevTuning
var _panel: DevMasterPanel


func before_each() -> void:
	_t = DevTuning.new()
	_t.save_path = SAVE
	_panel = add_child_autofree(DevMasterPanel.new(_t))


func after_each() -> void:
	_t.reset_all()
	_t.apply()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func test_every_balance_folder_is_in_the_panel() -> void:
	var covered := {}
	for g: Array in DevFields.GROUPS:
		assert_gt(DevFields.sources(g).size(), 0, "%s has content" % g[0])
		for dir: String in g[2]:
			covered[dir.trim_prefix("res://data/")] = true
	for dir in DirAccess.get_directories_at("res://data"):
		if dir in NOT_BALANCE:
			continue
		assert_true(covered.has(dir), "data/%s is in the panel" % dir)


func test_a_file_shows_every_tunable_field() -> void:
	var paths := DevFields.rows(load(ENEMY)).map(func(r: Dictionary) -> String: return r["path"])
	for p: String in [
		"hp", "move_speed_mps", "attacks/0/damage", "behaviour_params/cooldown_seconds"
	]:
		assert_has(paths, p)
	assert_does_not_have(paths, "id")
	var mood := DevFields.rows(load("res://data/biomes/ruins.tres"), "mood")
	assert_gt(mood.size(), 20)
	for r: Dictionary in mood:
		assert_true(String(r["path"]).begins_with("mood/"), "the lighting page shows only the mood")


func test_an_edit_reaches_the_store_is_saved_and_announced() -> void:
	watch_signals(_panel)
	_panel.show_source(ENEMY)
	assert_gt(_panel.row_count(), 10)
	var key := DevTuning.key_of(ENEMY, "hp")
	_panel.set_value(key, 123)
	assert_eq((load(ENEMY) as EnemyDefinition).hp, 123, "written into the content")
	assert_signal_emitted_with_parameters(_panel, "changed", [key])
	assert_true(FileAccess.file_exists(SAVE), "saved at once")
	assert_eq(DevTuning.load_saved(SAVE).overrides.get(key), 123)
	assert_string_contains(_panel.copy_changes(), "arc_caster.tres  hp:")
	_panel.reset_all()
	assert_eq(_t.overrides.size(), 0)
	assert_ne((load(ENEMY) as EnemyDefinition).hp, 123, "shipped value back")
