extends GutTest
## The 1,000-line file cap (gdlintrc max-file-lines) can't be switched off quietly: every file that carries
## `gdlint: disable=max-file-lines` is listed here with the reason it is one thing that should not be split. A file is
## never split only to fit the cap (split by responsibility), and never exempted without a line here.

const CAP := 1000
## path -> why it is exempt. Remove a row when its file drops under the cap.
const EXEMPT := {
	"res://src/sim/world/world_reader.gd":
	"the one read-only facade presentation may use (ARCHITECTURE); it shrinks as unused queries go",
	"res://src/sim/world/world.gd":
	"the sim's state and its tick; grouped into state objects in v0.11.1 step 37",
	"res://src/sim/core/world_snapshot.gd":
	"carries the old-save field list; under the cap once v0.11.1 step 35 removes it",
	"res://src/application/content_compiler.gd":
	"one compiler per content family, by rule in v0.11.1 step 43",
	"res://src/sim/combat/attacks.gd": "the attack forms' launch code; split with v0.11.1 step 25",
	"res://src/sim/ai/enemy_ai.gd":
	"the enemy behaviours; its view telegraphs move out when next touched",
	"res://src/presentation/world_view/fireball_views.gd":
	"shrinks with v0.11.1 step 42 (the shared pool helper)",
	"res://src/presentation/world_view/horde_avatar.gd":
	"shrinks with v0.11.1 step 42 (the avatar base)",
	"res://scripts/balance/progression_audit.gd": "a one-file balance tool, not game code",
}


func _exempt_files() -> PackedStringArray:
	var found := PackedStringArray()
	for dir: String in ["res://src", "res://scripts", "res://tests"]:
		for path in GdSource.files_under(dir):
			for line in GdSource.read(path).left(600).split("\n"):
				if line.begins_with("# gdlint:") and line.contains("max-file-lines"):
					found.append(path)
					break
	found.sort()
	return found


func test_only_the_listed_files_switch_the_line_cap_off() -> void:
	var listed := PackedStringArray(EXEMPT.keys())
	listed.sort()
	assert_eq(
		_exempt_files(),
		listed,
		"a new exemption needs a row in EXEMPT with its reason; a removed one loses its row"
	)


func test_every_exempt_file_is_really_over_the_cap() -> void:
	for path: String in EXEMPT:
		var lines := GdSource.read(path).split("\n").size()
		assert_gt(lines, CAP, "%s is %d lines: drop its exemption and its row" % [path, lines])


func test_every_exemption_says_why() -> void:
	for path: String in EXEMPT:
		assert_gt(String(EXEMPT[path]).length(), 20, path)
