class_name CreditsView
extends Control
## Credits: the owner's line, "Made with Godot Engine", the Godot licence, third-party notices and the font's
## licence. GUT is not shipped (the export smoke and zip audit check that).
## v0.5.5 A5: in the Cold glass look (MenuStyle) over the dark gradient backdrop.
## v0.7.5 SM (N8): the app icon beside the title, and the generated licence list (LicenceListDefinition, built from
## the repo's manifests, fonts and addons by scripts/content/build_credits.gd) before the engine's notices.

signal back_pressed

var text := RichTextLabel.new()


func _init(credits: CreditsDefinition, licences: LicenceListDefinition = null) -> void:
	name = "CreditsView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	MenuStyle.apply(self)
	add_child(MenuBackdrop.new())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 80)
	margin.add_theme_constant_override("margin_left", int(MenuStyle.LIST_LEFT))
	add_child(margin)
	var col := VBoxContainer.new()
	margin.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	col.add_child(head)
	var icon := TextureRect.new()  # v0.7.5 SM: the app icon (project.godot's config/icon)
	icon.name = "AppIcon"
	icon.texture = load(app_icon_path()) as Texture2D
	icon.custom_minimum_size = Vector2(56, 56)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(icon)
	var title := Label.new()
	title.text = "UI_CREDITS"
	title.add_theme_font_override("font", HudStyle.font(true))
	title.add_theme_font_size_override("font_size", 44)
	head.add_child(title)
	var lines := Label.new()
	lines.text = "%s\n%s" % [tr(credits.owner_key), tr(credits.made_with_key)]
	lines.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lines.add_theme_font_size_override("font_size", 24)
	col.add_child(lines)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.add_theme_font_size_override("normal_font_size", 18)
	text.text = legal_text(credits, licences)
	col.add_child(text)
	var back := Button.new()
	back.name = "Back"
	back.text = "UI_BACK"
	back.custom_minimum_size = Vector2(240, 48)
	back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(back)


func focus_first() -> void:
	(find_child("Back", true, false) as Button).grab_focus()


## The project's icon (the window's and the export's), "" when none is set.
static func app_icon_path() -> String:
	return String(ProjectSettings.get_setting("application/config/icon", ""))


static func legal_text(
	credits: CreditsDefinition, licences: LicenceListDefinition = null
) -> String:
	var out := PackedStringArray()
	if licences != null:
		out.append_array(licence_sections(licences))
	out.append("— Godot Engine —\n" + Engine.get_license_text())
	if licences == null:  # the generated list carries the font's licence itself
		out.append(
			(
				"— %s —\n%s"
				% [credits.font_name, FileAccess.get_file_as_string(credits.font_licence_path)]
			)
		)
	out.append("— Third-party notices (Godot Engine) —")
	var licences: Dictionary = Engine.get_license_info()
	for entry: Dictionary in Engine.get_copyright_info():
		for part: Dictionary in entry["parts"]:
			out.append(
				"%s: %s (%s)" % [entry["name"], ", ".join(part["copyright"]), part["license"]]
			)
	for name: String in licences:
		out.append("— %s —\n%s" % [name, licences[name]])
	return "\n\n".join(out)


## v0.7.5 SM: the generated list in words: the assets' provenance lines under one heading, then each font and each
## addon with its licence's full text (a tool the export leaves out says so).
static func licence_sections(l: LicenceListDefinition) -> PackedStringArray:
	var out := PackedStringArray()
	var assets := PackedStringArray()
	for k in l.count():
		if l.kinds[k] == LicenceListDefinition.KIND_ASSETS:
			assets.append("%s: %s" % [l.titles[k], l.bodies[k]])
	if not assets.is_empty():
		out.append(
			"— %s —\n%s" % [TranslationServer.translate("UI_CREDITS_ASSETS"), "\n".join(assets)]
		)
	for k in l.count():
		match l.kinds[k]:
			LicenceListDefinition.KIND_FONT:
				out.append(
					(
						"— %s: %s —\n%s"
						% [TranslationServer.translate("UI_CREDITS_FONT"), l.titles[k], l.bodies[k]]
					)
				)
			LicenceListDefinition.KIND_ADDON:
				var note := (
					""
					if l.shipped[k] == 1
					else TranslationServer.translate("UI_CREDITS_NOT_SHIPPED")
				)
				out.append(
					(
						"— %s: %s %s —\n%s"
						% [
							TranslationServer.translate("UI_CREDITS_ADDON"),
							l.titles[k],
							note,
							l.bodies[k]
						]
					)
				)
	return out
