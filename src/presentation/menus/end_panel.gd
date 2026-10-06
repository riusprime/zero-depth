class_name EndPanel
extends MenuPanel
## Shown when the fight ends (PLAN v0.1.0 Step 5): "You died" with what killed you, or "Arena cleared".
## Restart has focus.

signal restart_pressed
signal main_menu_pressed

const CAUSES := {
	WorldReader.KIND_CHARGER: "CAUSE_CHARGER",
	WorldReader.KIND_WARDEN: "CAUSE_WARDEN",
	WorldReader.KIND_NEEDLE: "CAUSE_NEEDLE",
}


func _init(won: bool, killer_kind: int) -> void:
	super()
	name = "EndPanel"
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	add_title("UI_ARENA_CLEARED" if won else "UI_YOU_DIED").name = "Title"
	if not won:
		var cause := Label.new()
		cause.name = "Cause"
		cause.text = CAUSES.get(killer_kind, "CAUSE_UNKNOWN")
		cause.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cause.add_theme_font_size_override("font_size", 26)
		box.add_child(cause)
	add_button("UI_RESTART", func() -> void: restart_pressed.emit()).name = "Restart"
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"
