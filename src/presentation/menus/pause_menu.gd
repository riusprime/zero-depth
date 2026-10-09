class_name PauseMenu
extends MenuPanel
## Resume, restart the run, Options (v0.3.0 O), or return to the main menu (v0.3.0 B). Shown over the stage; the
## sim is paused (no ticks) while it's open. Keyboard, mouse and pad all work through the focus (MenuPanel).
## v0.5.5 A5 (Cold glass): the game blurred behind, the list on the left, the run's line and the key hint under it;
## no build cards beside it (owner: not needed).

signal resume_pressed
signal options_pressed
signal restart_pressed
signal main_menu_pressed

var run_line: Label


func _init() -> void:
	super()
	name = "PauseMenu"
	add_backdrop()
	add_title("UI_PAUSED")
	add_button("UI_RESUME", func() -> void: resume_pressed.emit()).name = "Resume"
	add_button("UI_RESTART_RUN", func() -> void: restart_pressed.emit()).name = "Restart"
	add_button("UI_OPTIONS", func() -> void: options_pressed.emit()).name = "Options"  # v0.3.0 O
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
	run_line = add_note("")
	run_line.name = "RunLine"
	run_line.visible = false
	add_hint("UI_PAUSE_HINT")


## The run so far under the list: "Floor 1 · 03:42 · 87 kills · 146 shards" (Main passes the recap's numbers).
func show_run(floor_index: int, seconds: float, kills: int, shards: int) -> void:
	var secs := int(seconds)
	run_line.text = tr("UI_PAUSE_RUN") % [floor_index, secs / 60, secs % 60, kills, shards]
	run_line.visible = true
