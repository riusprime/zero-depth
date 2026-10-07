class_name PickSlot
extends PanelContainer
## One card of the 3-card pick (v0.3.0 E; restyled in v0.3.5 F16): the compact item card (ItemCard) in a flat,
## square CardStyle panel, with its number key and its rarity above it: a small faceted mark (CardMark) in the
## rarity's colour and the rarity's name. The focused slot has a brighter outline and fill. A mouse click or hover
## reports itself; the panel decides what happens.

signal clicked(slot: int)
signal hovered(slot: int)

const COMMON := Color("#9AA4B2")
const RARE := Color("#F0B840")
## v0.4.0 BS: an epic stat card, and an ability card (the hero's cyan).
const EPIC := Color("#C77DFF")
const ABILITY := Color("#2BC4E2")
## The mark's colour by tier: common, rare, epic, ability.
const TIERS: Array[Color] = [COMMON, RARE, EPIC, ABILITY]

var index := 0
var card := ItemCard.new()
var focused := false
var rare := false
## v0.4.0 BS: 0 common, 1 rare, 2 epic, 3 an ability card (TIERS).
var tier := 0
var _box := CardStyle.box(Vector4(10, 8, 10, 10))
var _key := Label.new()
var _mark := CardMark.new(11.0)
var _rarity := Label.new()


func _init(p_index: int) -> void:
	index = p_index
	name = "PickSlot%d" % (p_index + 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _box)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 6)
	col.add_child(head)
	_key.text = str(p_index + 1)
	_key.add_theme_font_size_override("font_size", 15)
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_key)
	_rarity.add_theme_font_size_override("font_size", 13)
	head.add_child(_mark)
	head.add_child(_rarity)
	for l: Label in [_key, _rarity]:
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.slide = false
	card.bare = true
	col.add_child(card)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit(index))
	_apply()


## Shows item `id` (already-translated title and sentence) with its rarity.
func show_item(
	id: StringName, title: String, sentence: String, c: Color, p_rare: bool, rarity_text: String
) -> void:
	rare = p_rare
	tier = 1 if p_rare else 0
	card.show_item(id, title, sentence, c)
	_rarity.text = rarity_text
	_apply()


## v0.4.0 BS: shows any card's face (PickPanel.card_face: id, title, sentence, color, tier, tier_text).
func show_card(face: Dictionary) -> void:
	tier = int(face["tier"])
	rare = tier == 1
	card.show_item(face["id"], face["title"], face["sentence"], face["color"])
	_rarity.text = face["tier_text"]
	_apply()


func set_focused(on: bool) -> void:
	focused = on
	_apply()


## The rarity's colour: the mark's colour (the card's outline stays neutral).
func rarity_color() -> Color:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


## The card's panel (tests check it is square, unshadowed and has no side bar).
func panel_box() -> StyleBoxFlat:
	return _box


func _apply() -> void:
	var c := rarity_color()
	CardStyle.apply(_box, c, focused)
	_mark.color = c
	_rarity.add_theme_color_override("font_color", Color(c, 0.95 if focused else 0.75))
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.95 if focused else 0.5))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)
