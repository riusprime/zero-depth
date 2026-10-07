class_name PauseMenu
extends MenuPanel
## Resume, restart the run, Options (v0.3.0 O), or return to the main menu (v0.3.0 B). Shown over the stage; the
## sim is paused (no ticks) while it's open. Keyboard, mouse and pad all work through the focus (MenuPanel).

signal resume_pressed
signal options_pressed
signal restart_pressed
signal main_menu_pressed


func _init() -> void:
	super()
	name = "PauseMenu"
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	add_title("UI_PAUSED")
	add_button("UI_RESUME", func() -> void: resume_pressed.emit()).name = "Resume"
	add_button("UI_RESTART_RUN", func() -> void: restart_pressed.emit()).name = "Restart"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"  # v0.3.0 O
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
