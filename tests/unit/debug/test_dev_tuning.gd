extends GutTest
## The dev panel's tuning store (docs/tools/DEV_PANEL.md Step 1): an override reaches the loaded definitions and the
## compiled tables (fields, nested attacks, dictionaries, packed arrays), Reset puts the shipped values back, the store
## survives a save and load with its types, lighting doesn't count as a balance tweak, and Copy lists the changes.

const ENEMY := "res://data/enemies/arc_caster.tres"
const SPAWN := "res://data/spawning/floor_1.tres"
const BIOME := "res://data/biomes/ruins.tres"
const SAVE := "user://test_dev_tuning.json"

var _t: DevTuning


func before_each() -> void:
	_t = DevTuning.new()
	_t.save_path = SAVE


func after_each() -> void:
	_t.reset_all()
	_t.apply()  # one instance per .tres: put the shipped game back for the next test
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))


func _arc_caster() -> EnemyTable:
	var repo := ContentRepository.load_all()
	return ContentCompiler.compile_enemy(repo.get_def(&"enemies", &"arc_caster"))


func test_an_override_reaches_the_compiled_table_and_reset_restores_it() -> void:
	var shipped := _arc_caster().hp
	_t.set_value(ENEMY, "hp", 95)
	_t.apply()
	assert_eq(_arc_caster().hp, 95, "the next compile sees it")
	assert_eq(_t.shipped_value(DevTuning.key_of(ENEMY, "hp")), shipped)
	_t.reset_all()
	_t.apply()
	assert_eq(_arc_caster().hp, shipped, "shipped value back")
	assert_false(_t.balance_tweaked())


func test_nested_fields_dictionaries_and_packed_arrays() -> void:
	_t.set_value(ENEMY, "attacks/0/damage", 33)
	_t.set_value(ENEMY, "behaviour_params/cooldown_seconds", 0.9)
	_t.set_value(SPAWN, "cap_by_floor/1", 44)
	_t.apply()
	var e: EnemyDefinition = load(ENEMY)
	assert_eq((e.attacks[0] as AttackDefinition).damage, 33)
	assert_almost_eq(float(e.behaviour_params["cooldown_seconds"]), 0.9, 0.0001)
	var s: SpawnDirectorDefinition = load(SPAWN)
	assert_eq(s.cap_by_floor[1], 44)
	assert_eq(s.cap_by_floor[0], 14, "the rest of the array untouched")


func test_a_value_equal_to_the_shipped_one_is_no_override() -> void:
	var shipped: int = (load(ENEMY) as EnemyDefinition).hp
	_t.set_value(ENEMY, "hp", shipped + 5)
	_t.set_value(ENEMY, "hp", shipped)
	assert_eq(_t.overrides.size(), 0)


func test_save_and_load_keep_the_overrides_and_their_types() -> void:
	_t.set_value(ENEMY, "hp", 77)
	_t.set_value(BIOME, "mood/ambient_energy", 0.12)
	_t.save()
	var back := DevTuning.load_saved(SAVE)
	back.apply()
	assert_eq(typeof((load(ENEMY) as EnemyDefinition).hp), TYPE_INT, "an int field stays an int")
	assert_eq((load(ENEMY) as EnemyDefinition).hp, 77)
	assert_almost_eq((load(BIOME) as BiomeDefinition).mood.ambient_energy, 0.12, 0.0001)
	back.reset_all()
	back.apply()


func test_lighting_is_not_a_balance_tweak() -> void:
	_t.set_value(BIOME, "mood/glow_intensity", 1.6)
	assert_false(_t.balance_tweaked(), "a mood change keeps the run counting")
	_t.set_value(ENEMY, "move_speed_mps", 4.0)
	assert_true(_t.balance_tweaked())


func test_copy_lists_each_change_with_its_shipped_value() -> void:
	var shipped: int = (load(ENEMY) as EnemyDefinition).hp
	_t.set_value(ENEMY, "hp", shipped + 10)
	assert_eq(
		_t.copy_text(), "data/enemies/arc_caster.tres  hp: %d -> %d" % [shipped, shipped + 10]
	)


func test_no_overrides_change_nothing() -> void:
	var before := ContentRepository.load_all().manifest_hash()
	_t.apply()
	assert_eq(ContentRepository.load_all().manifest_hash(), before)


## v0.7.0 audit A-14: an edit that breaks the content is logged (one error per issue) on the next load, instead of
## reaching the compiler silently; the shipped content loads with no errors.
func test_a_broken_edit_is_logged_on_the_next_load() -> void:
	_t.set_value(ENEMY, "hp", 0)
	_t.apply()
	var repo := ContentRepository.load_all()
	assert_eq(repo.errors().size(), 1, "hp 0 is one content error")
	assert_push_error("arc_caster.tres not_positive: hp must be > 0")
	_t.reset_all()
	_t.apply()
	assert_eq(ContentRepository.load_all().errors(), [], "shipped content: no errors")
