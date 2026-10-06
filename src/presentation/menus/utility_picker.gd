class_name UtilityPicker
extends MenuPanel
## Choose the run's utility before play (PD-01): one button per UtilityDefinition, with its one-line description.
## The last pick has focus, so Enter repeats it.

signal picked(id: StringName)
signal back_pressed

var _focus: Button


func _init(utilities: Array, last_id: StringName) -> void:
	super()
	name = "UtilityPicker"
	add_title("UI_CHOOSE_UTILITY")
	var focus: Button = null
	for def: UtilityDefinition in utilities:
		var id := def.id
		var b := add_button(String(def.name_key), func() -> void: picked.emit(id))
		b.name = String(id).capitalize()
		var desc := Label.new()
		desc.text = String(def.desc_key)
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(desc)
		if id == last_id:
			focus = b
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	_focus = focus


func focus_first() -> void:
	if _focus != null:
		_focus.grab_focus()
	else:
		super()
