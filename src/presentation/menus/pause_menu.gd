class_name PauseMenu
extends MenuPanel
## Resume or return to the main menu. Shown over the stage; the sim is paused while it's open.

signal resume_pressed
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
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
