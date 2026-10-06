# Ported from riusprime/deathventory@1d697803:tests/support/test_harness_self_test.gd. Changes: header only.
extends GutTest


func test_gut_version_is_9_7_1() -> void:
	var gut_plugin_cfg := ConfigFile.new()
	var err := gut_plugin_cfg.load("res://addons/gut/plugin.cfg")
	assert_eq(err, OK, "plugin.cfg should load successfully")
	var version: String = gut_plugin_cfg.get_value("plugin", "version", "")
	assert_eq(version, "9.7.1", "GUT version must be exactly 9.7.1")


func test_support_fixture_passes() -> void:
	assert_true(true, "Support test harness self test passes")
