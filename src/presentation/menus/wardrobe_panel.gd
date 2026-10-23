class_name WardrobePanel
extends MenuPanel
## v0.9.0 RB (owner, PLAN "Owner decisions" RB; docs/roadmap/v0.9.0/AFFINITIES.md): the hub Wardrobe's panel. Two
## choices, picked apart (W53): the robe's colour and the rune affinity, each a cycler (left / right, or press to step;
## keyboard, mouse and pad through the focus, as every menu), a line on the affinity's gain and its trade-off, and Back.
## The hero in the hub wears the choice at once (HubSession). A robe not yet bought (Rune Fragments, MP) is shown with
## "locked" and isn't worn: the hero keeps the last robe that is. The affinity is free and changes any time here; the
## run locks it when it starts.

signal picked(robe: StringName, affinity: StringName)
signal back_pressed

var robe_cycler: LockCycler
var affinity_cycler: OptionCycler
var desc: Label
var lock_note: Label
## The robe worn (an unlocked one) and the affinity picked.
var worn_robe := &""
var affinity := &""
var _robes: Array = []
var _affinities: Array = []


func _init(
	robes: Array,
	unlocked: Array[bool],
	current_robe: StringName,
	affinities: Array,
	current_aff: StringName
) -> void:
	super()
	name = "WardrobePanel"
	_robes = robes
	_affinities = affinities
	worn_robe = current_robe
	affinity = current_aff
	add_backdrop()
	add_title("HUB_WARDROBE").name = "Title"
	var ids: Array = []
	var keys: Array = []
	for r: RobeDefinition in robes:
		ids.append(String(r.id))
		keys.append(String(r.name_key))
	robe_cycler = LockCycler.new(ids, keys, String(current_robe), unlocked)
	robe_cycler.name = "Robe"
	robe_cycler.changed.connect(_on_robe)
	_row("WARDROBE_ROBE").add_child(robe_cycler)
	lock_note = Label.new()
	lock_note.name = "LockNote"
	lock_note.text = "WARDROBE_LOCKED_NOTE"
	lock_note.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE)
	lock_note.add_theme_color_override("font_color", MenuStyle.DIM)
	lock_note.visible = false
	box.add_child(lock_note)
	var aids: Array = []
	var akeys: Array = []
	for a: AffinityDefinition in affinities:
		aids.append(String(a.id))
		akeys.append(String(a.name_key))
	affinity_cycler = OptionCycler.new(aids, akeys, String(current_aff))
	affinity_cycler.name = "Affinity"
	affinity_cycler.changed.connect(_on_affinity)
	_row("WARDROBE_AFFINITY").add_child(affinity_cycler)
	desc = Label.new()
	desc.name = "Desc"
	desc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(MenuStyle.LIST_W + 120, 96)
	desc.add_theme_font_size_override("font_size", MenuStyle.NOTE_SIZE + 2)
	desc.add_theme_color_override("font_color", MenuStyle.TEXT)
	box.add_child(desc)
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	add_hint("UI_MENU_HINT")
	_show_desc()


func _row(label_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var l := Label.new()
	l.text = label_key
	l.custom_minimum_size = Vector2(170, 0)
	l.add_theme_font_size_override("font_size", 22)
	row.add_child(l)
	box.add_child(row)
	return row


func focus_first() -> void:
	robe_cycler.grab_focus()


func _on_robe(id: String) -> void:
	var open := robe_cycler.is_unlocked()
	lock_note.visible = not open
	if open:
		worn_robe = StringName(id)
		picked.emit(worn_robe, affinity)


func _on_affinity(id: String) -> void:
	affinity = StringName(id)
	_show_desc()
	picked.emit(worn_robe, affinity)


func _show_desc() -> void:
	for a: AffinityDefinition in _affinities:
		if a.id == affinity:
			desc.text = "%s\n%s" % [tr(a.desc_key), tr(a.cost_key)]
			desc.add_theme_color_override("font_color", MenuStyle.TEXT)
			return
	desc.text = ""


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and desc != null:
		_show_desc()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


## The robe cycler: an OptionCycler that marks the robes not bought yet.
class LockCycler:
	extends OptionCycler
	var unlocked: Array[bool] = []

	func _init(p_values: Array, p_keys: Array, current: String, p_unlocked: Array[bool]) -> void:
		unlocked = p_unlocked
		super(p_values, p_keys, current)

	func is_unlocked() -> bool:
		return index >= unlocked.size() or unlocked[index]

	func _show() -> void:
		var t := tr(label_keys[index])
		if not is_unlocked():
			t = "%s  ·  %s" % [t, tr("WARDROBE_LOCKED")]
		text = "‹  %s  ›" % t
