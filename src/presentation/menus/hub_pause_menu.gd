class_name HubPauseMenu
extends MenuPanel
## v0.9.0 HB: the hub's pause (Esc / Start in the hub): Resume, Options, Main menu. Ember stone over the blurred hub
## (MenuPanel). Esc, pad B or Start again resumes.

signal resume_pressed
signal options_pressed
signal main_menu_pressed


func _init() -> void:
	super()
	name = "HubPauseMenu"
	add_backdrop()
	add_title("HUB_TITLE")
	add_button("UI_RESUME", func() -> void: resume_pressed.emit()).name = "Resume"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
	add_hint("UI_PAUSE_HINT")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
