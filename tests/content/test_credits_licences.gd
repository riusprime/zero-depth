extends GutTest
## v0.7.5 SM (owner N8; ROADMAP v0.9.x "Final credits and licenses"): the credits' licence list is generated from the
## repo (scripts/content/build_credits.gd) and the committed copy matches a fresh build; every asset manifest says
## whose its files are; every font licence and addon licence in the repo is listed; an addon the export leaves out is
## marked not shipped; the app icon is present. The credits screen shows all of it.

const BUILDER := "res://scripts/content/build_credits.gd"
const SHIPPED := "res://data/credits/licences.tres"


func test_the_committed_list_matches_a_fresh_build() -> void:
	var built: LicenceListDefinition = load(BUILDER).build()
	var shipped := load(SHIPPED) as LicenceListDefinition
	assert_not_null(shipped, SHIPPED)
	if shipped == null:
		return
	var hint := "rebuild with: godot --headless --path . -s scripts/content/build_credits.gd"
	assert_eq(Array(shipped.titles), Array(built.titles), hint)
	assert_eq(Array(shipped.sources), Array(built.sources), hint)
	assert_eq(Array(shipped.bodies), Array(built.bodies), hint)
	assert_eq(Array(shipped.kinds), Array(built.kinds), hint)
	assert_eq(Array(shipped.shipped), Array(built.shipped), hint)
	assert_eq(shipped.validate().size(), 0, "valid")


func test_every_manifest_font_and_addon_is_listed() -> void:
	var l := load(SHIPPED) as LicenceListDefinition
	var manifests: PackedStringArray = load(BUILDER).manifests("res://assets")
	assert_gte(
		manifests.size(),
		2,
		"the scan finds the manifests (audio, models; v0.8.0 MU retired the crystal UI art)"
	)
	for m in manifests:
		var k := Array(l.sources).find(m.trim_prefix("res://"))
		assert_gte(k, 0, "%s is in the credits" % m)
		if k >= 0:
			var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(m))
			assert_false(
				String(data.get("licence", "")).is_empty(), "%s says whose its files are" % m
			)
			assert_string_contains(l.bodies[k], String(data["licence"]))
	assert_has(Array(l.sources), "assets/fonts/OFL.txt")
	assert_has(Array(l.titles), "Atkinson Hyperlegible", "the font named from its files")
	for dir in DirAccess.get_directories_at("res://addons"):
		var found := false
		for k in l.count():
			if (
				l.kinds[k] == LicenceListDefinition.KIND_ADDON
				and l.sources[k].begins_with("addons/" + dir)
			):
				found = true
				assert_string_contains(
					l.bodies[k], "Permission is hereby granted", "%s's licence text" % dir
				)
		assert_true(found, "addon %s is credited" % dir)
	var gut := -1
	for k in l.count():
		if l.sources[k].begins_with("addons/gut"):
			gut = k
	assert_gte(gut, 0)
	assert_eq(l.shipped[gut], 0, "GUT is a test tool the export leaves out")


func test_the_app_icon_is_present() -> void:
	var path := CreditsView.app_icon_path()
	assert_eq(path, "res://icon.svg")
	assert_true(FileAccess.file_exists(path), "the icon file is in the repo")
	assert_not_null(load(path) as Texture2D, "and loads as a texture")


func test_the_credits_text_carries_the_generated_list() -> void:
	var repo := ContentRepository.load_all()
	var text := CreditsView.legal_text(
		repo.get_def(&"credits", &"main"), repo.get_def(&"licences", &"generated")
	)
	assert_string_contains(text, "Supplied by the owner")
	assert_string_contains(text, "scripts/audio/generate_sfx.py")
	assert_string_contains(text, "SIL OPEN FONT LICENSE")
	assert_string_contains(text, "Gut 9.7.1")
	assert_string_contains(text, String(TranslationServer.translate("UI_CREDITS_NOT_SHIPPED")))
	assert_string_contains(text, "Permission is hereby granted")  # Godot's MIT licence
	assert_eq(
		text.count("SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007"),
		1,
		"the font's licence once"
	)
