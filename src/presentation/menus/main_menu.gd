class_name MainMenu
extends MenuPanel
## v0.9.0 HB (owner Q27: "You will have a small menu, with options, continue and play, and the rest of the thing go
## into the hub"): Continue, Play, Options, Quit and the version label. Continue resumes the saved run (focused first
## while a run save exists; greyed out and skipped by the focus when there is none: HUB_MOCKUPS "Shared"); Play goes
## to the hub. The Codex, the Credits and the achievements live in the hub now (the Rune Archive, the Credits stone,
## the Trophy Area); the galleries moved to the master dev panel (F10). v0.8.0 MU: in the Ember stone look
## (MenuStyle), the list on a stone slab on the left over the menu's own backdrop (MenuBackdrop).

signal continue_pressed
signal play_pressed
signal options_pressed
signal quit_pressed

var version_label := Label.new()


func _init(version: String, show_continue: bool = false) -> void:
	super()
	name = "MainMenu"
	add_title("UI_TITLE")
	var cont := add_button("UI_CONTINUE", func() -> void: continue_pressed.emit())
	cont.name = "Continue"
	cont.disabled = not show_continue
	if cont.disabled:
		cont.focus_mode = Control.FOCUS_NONE
		cont.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_button("UI_PLAY", func() -> void: play_pressed.emit()).name = "Play"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"
	add_button("UI_QUIT", func() -> void: quit_pressed.emit()).name = "Quit"
	add_backdrop().own_scene = true  # v0.8.0 MU: nothing is behind the main menu: its own ember scene
	add_hint("UI_MENU_HINT")
	version_label.text = version
	version_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	version_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version_label.position = Vector2(-140, -44)
	version_label.add_theme_font_size_override("font_size", MenuStyle.HINT_SIZE)
	version_label.add_theme_color_override("font_color", MenuStyle.HINT)
	add_child(version_label)


## The first row that can take focus (Continue only while a save exists).
func focus_first() -> void:
	for c in box.get_children():
		if c is Button and not (c as Button).disabled:
			(c as Button).grab_focus()
			return
