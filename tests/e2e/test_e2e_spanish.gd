extends GutTest
## Switching the language to Spanish (a profile setting) shows the menu in Spanish.


func after_each() -> void:
	TranslationServer.set_locale("en")


func test_menu_in_spanish() -> void:
	var profile := ProfileStore.new("")
	profile.section("settings")["language"] = "es"
	var e := E2e.new(self)
	var main: Main = await e.boot(profile)
	var play: Button = main.get_node("UI/MainMenu").find_child("Play", true, false)
	assert_eq(play.text, "UI_PLAY", "the button holds a key")
	assert_eq(tr(play.text), "Jugar", "and shows its Spanish text")
	assert_eq(TranslationServer.get_locale(), "es")


func test_spanish_text_renders_in_the_shipped_font() -> void:
	var t: Theme = load(ThemePalette.UI_THEME)
	for ch in "áéíóúüñ¿¡":
		assert_true(t.default_font.has_char(ch.unicode_at(0)), "glyph %s" % ch)
