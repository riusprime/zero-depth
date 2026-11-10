class_name WardrobePanel
extends MenuPanel
## The hub Wardrobe's panel. Two
## choices, picked apart: the robe's colour and the rune affinity, each a cycler (left / right, or press to step;
## keyboard, mouse and pad through the focus, as every menu), a line on the affinity's gain and its trade-off, and Back.
## The hero in the hub wears the choice at once (HubSession). A robe not yet bought (Rune Fragments, MP) is shown with
## "locked" and isn't worn: the hero keeps the last robe that is. MP2: the epic robes are picked like the others once
## owned; a hidden one not bought yet is listed as "???" (Wardrobe.HIDDEN_NAME), locked. The affinity is free and
## changes any time here; the run locks it when it starts.
## v0.11.1 Step 13 (owner: Astral the only style): in Astral (MenuPanel), each choice an Options-style field row.

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
	for i in robes.size():
		var r: RobeDefinition = robes[i]
		ids.append(String(r.id))
		var masked: bool = r.hidden and not (i < unlocked.size() and unlocked[i])
		keys.append(String(Wardrobe.HIDDEN_NAME if masked else r.name_key))
	robe_cycler = LockCycler.new(ids, keys, String(current_robe), unlocked)
	robe_cycler.name = "Robe"
	robe_cycler.astral = true  # Astral's chevrons and hairline (OptionCycler)
	robe_cycler.custom_minimum_size = Vector2(300, 40)
	robe_cycler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	robe_cycler.changed.connect(_on_robe)
	_row("WARDROBE_ROBE", robe_cycler)
	lock_note = Label.new()
	lock_note.name = "LockNote"
	lock_note.text = "WARDROBE_LOCKED_NOTE"
	AstralMenu.body(lock_note, AstralMenu.NOTE_SIZE, AstralCardArt.DIM)
	lock_note.visible = false
	box.add_child(lock_note)
	var aids: Array = []
	var akeys: Array = []
	for a: AffinityDefinition in affinities:
		aids.append(String(a.id))
		akeys.append(String(a.name_key))
	affinity_cycler = OptionCycler.new(aids, akeys, String(current_aff))
	affinity_cycler.name = "Affinity"
	affinity_cycler.astral = true  # Astral's chevrons and hairline (OptionCycler), as in Options
	affinity_cycler.custom_minimum_size = Vector2(300, 40)
	affinity_cycler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	affinity_cycler.changed.connect(_on_affinity)
	_row("WARDROBE_AFFINITY", affinity_cycler)
	desc = Label.new()
	desc.name = "Desc"
	desc.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(AstralMenu.LIST_W + 120, 96)
	AstralMenu.body(desc, AstralMenu.BODY_SIZE, AstralCardArt.TEXT)
	box.add_child(desc)
	add_button("UI_BACK", func() -> void: back_pressed.emit()).name = "Back"
	add_hint("UI_MENU_HINT")
	_show_desc()


func _row(label_key: String, c: Control) -> void:
	var row := AstralMenu.field_row(box, label_key, 170.0)
	row.add_child(c)
	AstralMenu.light(row, c)


func focus_first() -> void:
	robe_cycler.grab_focus()


func _on_robe(id: String) -> void:
	var open := robe_cycler.is_unlocked()
	lock_note.visible = not open
	lock_note.text = _note_for(id)
	if open:
		worn_robe = StringName(id)
		picked.emit(worn_robe, affinity)


## The note under a locked robe: its own hint (the Runic robe is earned, not bought) or the shop's.
func _note_for(id: String) -> String:
	for r: RobeDefinition in _robes:
		if String(r.id) == id and not String(r.unlock_hint_key).is_empty():
			return String(r.unlock_hint_key)
	return "WARDROBE_LOCKED_NOTE"


func _on_affinity(id: String) -> void:
	affinity = StringName(id)
	_show_desc()
	picked.emit(worn_robe, affinity)


func _show_desc() -> void:
	for a: AffinityDefinition in _affinities:
		if a.id == affinity:
			desc.text = "%s\n%s" % [tr(a.desc_key), tr(a.cost_key)]
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

	func shown_word() -> String:
		var t := tr(label_keys[index])
		if not is_unlocked():
			t = "%s  ·  %s" % [t, tr("WARDROBE_LOCKED")]
		return t

	func _show() -> void:
		text = "‹  %s  ›" % shown_word()
		queue_redraw()
