class_name PickSlot
extends VBoxContainer
## One card of the 3-card pick and of the shop's stock (v0.3.0 E; v0.5.5 A4: the owner's crystal frames). The card
## (CrystalCard) wears the frame of its family (CardFrames; a cursed offer wears the curse frame, an epic card the
## epic frame) with the title, the sentence, the rarity and two icons inside; under it the card's number key and,
## on a cursed offer, the curse's line. The rarity reads as the rarity line, the gem icon's colour and the glow
## behind the frame. The focused card lifts, its frame brightens and its glow grows. A mouse click or hover reports
## itself; the panel decides what happens.

signal clicked(slot: int)
signal hovered(slot: int)

const COMMON := Color("#9AA4B2")
const RARE := Color("#F0B840")
## v0.4.0 BS: an epic stat card, and an ability card (the hero's cyan).
const EPIC := Color("#C77DFF")
const ABILITY := Color("#2BC4E2")
## The mark's colour by tier: common, rare, epic, ability.
const TIERS: Array[Color] = [COMMON, RARE, EPIC, ABILITY]
## Frame pixels → screen pixels in the 3-card pick (1080p layout); the shop passes its own.
const PICK_SCALE := 1.2

var index := 0
var card: CrystalCard
var focused := false
var rare := false
## v0.4.0 BS: 0 common, 1 rare, 2 epic, 3 an ability card (TIERS).
var tier := 0
var _key := Label.new()
## v0.5.0 EV: a cursed card's mark and line, under the card (hidden on a clean card).
var _curse := HBoxContainer.new()
var _curse_text := Label.new()
var _face := {}


func _init(p_index: int, p_scale: float = PICK_SCALE) -> void:
	index = p_index
	name = "PickSlot%d" % (p_index + 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 2)
	card = CrystalCard.new(p_scale)
	add_child(card)
	_key.text = str(p_index + 1)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.add_theme_font_size_override("font_size", 15)
	_key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	_build_curse(p_scale)
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(func() -> void: hovered.emit(index))
	_apply()


## Shows item `id` (already-translated title and sentence) with its rarity (a mod card; shot scripts).
func show_item(
	id: StringName, title: String, sentence: String, c: Color, p_rare: bool, rarity_text: String
) -> void:
	show_card(
		{
			"id": id,
			"title": title,
			"sentence": sentence,
			"color": c,
			"tier": 1 if p_rare else 0,
			"tier_text": rarity_text,
		}
	)


## v0.4.0 BS: shows any card's face (PickPanel.card_face: id, title, sentence, color, tier, tier_text, and since
## v0.5.5 type).
func show_card(face: Dictionary) -> void:
	_face = face
	tier = int(face["tier"])
	rare = tier == 1
	_render()


## v0.5.0 EV: marks the card cursed with `line` (CurseLook.line), or clean with "". A cursed card wears the curse
## frame (v0.5.5 A4).
func show_curse(line: String) -> void:
	_curse_text.text = line
	_curse.visible = not line.is_empty()
	if not _face.is_empty():
		_render()


func curse_text() -> String:
	return _curse_text.text if _curse.visible else ""


## The card's family (CardFrames.family) and frame colour id.
func family() -> StringName:
	return card.family


func frame_id() -> StringName:
	return card.frame_id


func set_focused(on: bool) -> void:
	focused = on
	_apply()


## The rarity's colour: the gem's colour and the glow's.
func rarity_color() -> Color:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


## The text panel inside the frame (FACET corners, no shadow, no side bar).
func panel_box() -> StyleBoxFlat:
	return card.panel_box()


func _render() -> void:
	var id: StringName = _face.get("id", &"")
	var fam := CardFrames.family(id, int(_face.get("type", -1)), tier, _curse.visible)
	card.show_face(
		id,
		_face.get("title", ""),
		_face.get("sentence", ""),
		fam,
		tier,
		rarity_color(),
		_face.get("tier_text", "")
	)
	_apply()


func _build_curse(s: float) -> void:
	_curse.name = "Curse"
	_curse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curse.alignment = BoxContainer.ALIGNMENT_CENTER
	_curse.add_theme_constant_override("separation", 6)
	var mark := CardMark.new(12.0)
	mark.color = CurseLook.COLOR
	_curse.add_child(mark)
	_curse_text.add_theme_font_size_override("font_size", 14)
	_curse_text.add_theme_color_override("font_color", CurseLook.COLOR.lerp(Color.WHITE, 0.3))
	_curse_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_curse_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curse_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_curse_text.custom_minimum_size = Vector2(CardFrames.SIZE.x * s - 30.0, 0)
	_curse.add_child(_curse_text)
	_curse.visible = false
	add_child(_curse)


func _apply() -> void:
	card.set_focused(focused)
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.95 if focused else 0.5))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)
