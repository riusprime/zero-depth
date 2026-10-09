class_name MainMenu
extends MenuPanel
## Continue (v0.4.0 SV: only while a run save exists, focused first), Play, Options, Credits, Quit, the version
## label and, in debug builds only, the galleries. v0.5.5 A5: in the Cold glass look (MenuStyle), list on the left.

signal continue_pressed
signal play_pressed
signal options_pressed
signal credits_pressed
signal galleries_pressed
signal quit_pressed

var version_label := Label.new()


func _init(version: String, show_galleries: bool, show_continue: bool = false) -> void:
	super()
	name = "MainMenu"
	add_title("UI_TITLE")
	if show_continue:
		add_button("UI_CONTINUE", func() -> void: continue_pressed.emit()).name = "Continue"
	add_button("UI_PLAY", func() -> void: play_pressed.emit()).name = "Play"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"
	add_button("UI_CREDITS", func() -> void: credits_pressed.emit()).name = "Credits"
	if show_galleries:
		add_button("UI_GALLERIES", func() -> void: galleries_pressed.emit()).name = "Galleries"
	add_button("UI_QUIT", func() -> void: quit_pressed.emit()).name = "Quit"
	add_backdrop()
	add_hint("UI_MENU_HINT")
	version_label.text = version
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.position = Vector2(-140, -44)
	version_label.add_theme_font_size_override("font_size", MenuStyle.HINT_SIZE)
	version_label.add_theme_color_override("font_color", MenuStyle.HINT)
	add_child(version_label)
