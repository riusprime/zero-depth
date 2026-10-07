class_name EndPanel
extends MenuPanel
## Shown when the fight ends (PLAN v0.1.0 Step 5): "You died" with what killed you, or "Arena cleared". Restart has
## focus. On a run (v0.3.0 B) it is the run recap: "Run complete" or "You died", the floor reached, the run's time,
## kills, shards (only when the run counts them), the items you held and the killing cause.

signal restart_pressed
signal main_menu_pressed

const CAUSES := {
	WorldReader.KIND_CHARGER: "CAUSE_CHARGER",
	WorldReader.KIND_WARDEN: "CAUSE_WARDEN",
	WorldReader.KIND_NEEDLE: "CAUSE_NEEDLE",
}

## Recap keys (all optional): "floor" and "floors" (ints), "seconds" (float), "kills" (int), "shards" (int; omitted
## when the run has no shards), "items" (Array of item name keys).
var recap := {}


func _init(won: bool, killer_kind: int, p_recap: Dictionary = {}) -> void:
	super()
	name = "EndPanel"
	recap = p_recap
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	move_child(dim, 0)
	var title := "UI_YOU_DIED"
	if won:
		title = "UI_RUN_COMPLETE" if not recap.is_empty() else "UI_ARENA_CLEARED"
	add_title(title).name = "Title"
	if not won:
		var cause := _line("Cause", CAUSES.get(killer_kind, "CAUSE_UNKNOWN"), 26)
		cause.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_INHERIT
	if not recap.is_empty():
		_add_recap()
	add_button("UI_RESTART", func() -> void: restart_pressed.emit()).name = "Restart"
	add_button("UI_MAIN_MENU", func() -> void: main_menu_pressed.emit()).name = "MainMenu"


## The recap's text lines, by node name (tests and the shot script read them).
func recap_line(line_name: String) -> String:
	var l := box.find_child(line_name, false, false) as Label
	return l.text if l != null else ""


func _add_recap() -> void:
	if recap.has("floor"):
		_line("Floor", tr("UI_RECAP_FLOOR") % [recap["floor"], recap.get("floors", recap["floor"])])
	if recap.has("seconds"):
		var secs := int(recap["seconds"])
		_line("Time", tr("UI_RECAP_TIME") % [secs / 60, secs % 60])
	if recap.has("kills"):
		_line("Kills", tr("UI_RECAP_KILLS") % recap["kills"])
	if recap.has("shards"):
		_line("Shards", tr("UI_RECAP_SHARDS") % recap["shards"])
	if recap.has("items"):
		var names := PackedStringArray()
		for k in recap["items"]:
			names.append(tr(k))
		var text := (
			tr("UI_RECAP_ITEMS") % ", ".join(names)
			if not names.is_empty()
			else tr("UI_RECAP_NO_ITEMS")
		)
		var l := _line("Items", text, 20)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(560, 0)


func _line(line_name: String, text: String, font_size: int = 24) -> Label:
	var l := Label.new()
	l.name = line_name
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	box.add_child(l)
	return l
