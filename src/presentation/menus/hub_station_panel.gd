class_name HubStationPanel
extends MenuPanel
## v0.9.0 HB: a hub station's stand-in panel (the Wardrobe until RB's robes and affinities, the Progression Station
## until MP's Rune Fragments): its name, one line on what will be there, and Back. In Astral over the blurred hub
## (MenuPanel; v0.11.1 Step 13). Esc, pad B or Back closes it.

signal back_pressed


func _init(id: StringName, title_key: String, line_key: String) -> void:
	super()
	name = "HubPanel_%s" % id
	add_backdrop()
	add_title(title_key).name = "Title"
	var l := Label.new()
	l.name = "Line"
	l.text = line_key
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(520, 0)
	AstralMenu.body(l, AstralMenu.BODY_SIZE + 2, AstralCardArt.DIM)
	box.add_child(l)
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	add_hint("UI_MENU_HINT")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()
