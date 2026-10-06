extends GutTest
## Every font ships with its licence (LESSONS L15/L21: sources and licences recorded on delivery).


func test_fonts_have_licences() -> void:
	var dir := "res://assets/fonts"
	var files := DirAccess.get_files_at(dir)
	var fonts := Array(files).filter(
		func(f: String) -> bool: return f.ends_with(".ttf") or f.ends_with(".otf")
	)
	assert_gt(fonts.size(), 0)
	assert_true(
		"OFL.txt" in files or "LICENSE" in files or "LICENSE.txt" in files,
		"a licence file sits next to the fonts"
	)


func test_theme_uses_the_shipped_font_at_readable_size() -> void:
	var t: Theme = load(ThemePalette.UI_THEME)
	assert_not_null(t.default_font)
	assert_true(t.default_font.resource_path.begins_with("res://assets/fonts/"))
	assert_gte(t.default_font_size, 18, "body text is at least 18 px at 1080p")
