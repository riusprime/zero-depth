class_name CreditsView
extends Control
## Credits: the owner's line, "Made with Godot Engine", the Godot licence, third-party notices and the font's
## licence. GUT is not shipped (the export smoke and zip audit check that).
## v0.5.5 A5: in the Cold glass look (MenuStyle) over the dark gradient backdrop.

signal back_pressed

var text := RichTextLabel.new()


func _init(credits: CreditsDefinition) -> void:
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
	var title := Label.new()
	title.text = "UI_CREDITS"
	title.add_theme_font_override("font", HudStyle.font(true))
	title.add_theme_font_size_override("font_size", 44)
	col.add_child(title)
	var lines := Label.new()
	lines.text = "%s\n%s" % [tr(credits.owner_key), tr(credits.made_with_key)]
	lines.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lines.add_theme_font_size_override("font_size", 24)
	col.add_child(lines)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	text.add_theme_font_size_override("normal_font_size", 18)
	text.text = legal_text(credits)
	col.add_child(text)
	var back := Button.new()
	back.name = "Back"
	back.text = "UI_BACK"
	back.custom_minimum_size = Vector2(240, 48)
	back.pressed.connect(func() -> void: back_pressed.emit())
	col.add_child(back)


func focus_first() -> void:
	(find_child("Back", true, false) as Button).grab_focus()


static func legal_text(credits: CreditsDefinition) -> String:
	var out := PackedStringArray()
	out.append("— Godot Engine —\n" + Engine.get_license_text())
	out.append(
		"— %s —\n%s" % [credits.font_name, FileAccess.get_file_as_string(credits.font_licence_path)]
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
