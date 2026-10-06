# Ported from riusprime/deathventory@1d697803:tests/v2/v2_01/test_game_version.gd.
# Changes: kept the version and preset checks; dropped the patch-note checks until patch notes exist (v0.0.1 Step 13).
extends GutTest
## One game version (ROADMAP §2): project.godot holds it, the export presets carry the same numbers.

const PRESETS := "res://export_presets.cfg"


func test_project_declares_a_version() -> void:
	assert_ne(GameVersion.string(), GameVersion.FALLBACK)
	assert_ne(GameVersion.parts(), [0, 0, 0] as Array[int])


func test_export_presets_carry_the_same_numbers() -> void:
	var cfg := ConfigFile.new()
	assert_eq(cfg.load(ProjectSettings.globalize_path(PRESETS)), OK)
	var expected := GameVersion.numeric() + ".0"
	var checked := 0
	for section in cfg.get_sections():
		if not section.ends_with(".options"):
			continue
		checked += 1
		assert_eq(str(cfg.get_value(section, "application/file_version", "")), expected, section)
		assert_eq(str(cfg.get_value(section, "application/product_version", "")), expected, section)
	assert_gt(checked, 0, "at least one export preset")


func test_label_and_parts() -> void:
	assert_eq(GameVersion.label(), "v" + GameVersion.string())
	assert_eq(GameVersion.parts("1.2.3-dev"), [1, 2, 3] as Array[int])
	assert_eq(GameVersion.parts("0.5"), [0, 5, 0] as Array[int])
	assert_true(GameVersion.compare("0.2.5", "0.2.0") > 0)
	assert_true(GameVersion.compare("0.10.0", "0.9.9") > 0)
	assert_eq(GameVersion.compare("0.2.0-dev", "0.2.0"), 0)
