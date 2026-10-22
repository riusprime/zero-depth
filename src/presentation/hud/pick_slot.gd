class_name PickSlot
extends VBoxContainer
## One card of the 3-card pick and of the shop's stock (v0.3.0 E; v0.8.0 MU: a carved stone tablet, StoneCard, in
## place of v0.5.5 A4's crystal frames). The card wears its family's colour (CardFrames; a cursed offer the curse
## violet, an epic card the epic gold) on its title and inlay groove, its element's colour on the icon's inlay ring,
## the rarity on the carved gem and the rarity words; under it the card's number key and, on a cursed offer, the
## curse's line. The rarity also reads as the ember glow under the tablet (and a gold rim on epic and legendary). The
## focused card lifts, its glow grows and its lower edge lights up. A mouse click or hover reports itself; the panel
## decides what happens.
## v0.9.0 AS (owner Q5, Q14; G2 option A): under a Form, Pattern, Secondary or Element card its slot line: the slot's
## mark (SlotGlyph) and tag ("Pattern"), and when that slot is full the card it replaces (its small icon and "Replaces
## Twin", in ember), which burns away when this card is picked (burn_replaced, the pick panel's outro).

signal clicked(slot: int)
signal hovered(slot: int)

const COMMON := Color("#9AA4B2")
## v0.8.0 RR (owner O33, four tiers each with its colour): rare is blue (was the amber #F0B840, too close to the
## legendary gold); the tier's word is always on the card too, so no tier reads by colour alone.
const RARE := Color("#4AA8F0")
## v0.4.0 BS: an epic stat card, and an ability card (the hero's cyan).
const EPIC := Color("#C77DFF")
const ABILITY := Color("#2BC4E2")
## v0.5.5 AR (X1b): a legendary card (the boss's tier): bright gold.
const LEGENDARY := Color("#FFD84A")
## The mark's colour by tier: common, rare, epic, ability, legendary (CardFrames.LEGENDARY_TIER).
const TIERS: Array[Color] = [COMMON, RARE, EPIC, ABILITY, LEGENDARY]
## Frame pixels → screen pixels in the 3-card pick (1080p layout); the shop passes its own.
const PICK_SCALE := 1.2

var index := 0
var card: StoneCard
var focused := false
var rare := false
## v0.4.0 BS: 0 common, 1 rare, 2 epic, 3 an ability card, 4 (v0.5.5 AR) a legendary card (TIERS).
var tier := 0
var _key := Label.new()
## v0.5.0 EV: a cursed card's mark and line, under the card (hidden on a clean card).
var _curse := HBoxContainer.new()
var _curse_text := Label.new()
var _face := {}
## v0.9.0 AS: the slot line (its mark, its tag) and the replaced card's chip (its icon and words; the part that burns).
var _slot := HBoxContainer.new()
var _slot_glyph := SlotGlyph.new(14.0)
var _slot_text := Label.new()
var _old := HBoxContainer.new()
var _old_icon := InlaySocket.new()
var _old_text := Label.new()
var _old_burn: ShaderMaterial


func _init(p_index: int, p_scale: float = PICK_SCALE) -> void:
	index = p_index
	name = "PickSlot%d" % (p_index + 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_constant_override("separation", 2)
	card = StoneCard.new(p_scale)
	add_child(card)
	_key.text = str(p_index + 1)
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.add_theme_font_size_override("font_size", 15)
	_key.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_key)
	_build_slot_line()
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
## colour (v0.5.5 A4).
func show_curse(line: String) -> void:
	_curse_text.text = line
	_curse.visible = not line.is_empty()
	if not _face.is_empty():
		_render()


func curse_text() -> String:
	return _curse_text.text if _curse.visible else ""


## The card's family (CardFrames.family) and its colour id (CardFrames.frame_of).
func family() -> StringName:
	return card.family


func colour_id() -> StringName:
	return card.colour_id


## v0.8.0 RR: the shown card's type (WorldReader.CARD_*; -1 for a face without one).
func face_type() -> int:
	return int(_face.get("type", -1))


func set_focused(on: bool) -> void:
	focused = on
	_apply()


## The rarity's colour: the gem's colour and the rarity words'.
func rarity_color() -> Color:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


## The card's stone tablet (StoneBox).
func panel_box() -> StoneBox:
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
		_face.get("tier_text", ""),
		_face.get("level_text", ""),  # v0.7.5 SM: the level badge
		_face.get("color", Color(0, 0, 0, 0))  # v0.8.0 MU: the element's colour on the inlay ring
	)
	card.show_gain(_face.get("gain", {}))  # v0.8.0 N8: what gets better, old → new
	_show_slot_line()
	_apply()


## v0.9.0 AS: the slot line from the face (PickPanel.slot_face): hidden on a card without a slot tag.
func _show_slot_line() -> void:
	var slot := int(_face.get("slot", WorldReader.SLOT_NONE))
	_slot.visible = slot != WorldReader.SLOT_NONE
	_slot_glyph.slot = slot
	_slot_glyph.color = Color(_face.get("color", MenuStyle.TEXT), 1.0).lerp(Color.WHITE, 0.35)
	_slot_text.text = _face.get("slot_text", "")
	var old: StringName = _face.get("replaces_id", &"")
	_old.visible = old != &""
	_old_text.text = _face.get("replaces_text", "")
	var c: Color = _face.get("replaces_color", MenuStyle.EMBER)
	_old_icon.show_item(old, c, c)
	burn_replaced(0.0)


## v0.9.0 AS: the slot tag shown under the card ("" when none) and the "Replaces <card>" words ("" when the slot has
## room).
func slot_text() -> String:
	return _slot_text.text if _slot.visible else ""


func replaces_text() -> String:
	return _old_text.text if _slot.visible and _old.visible else ""


## v0.9.0 AS (owner Q5): 0..1 of the replaced card's burn (0: whole; 1: gone), N8's dissolve (CardFx).
func burn_replaced(t: float) -> void:
	if t <= 0.0:
		_old.material = null
		_old_burn = null
		_old.modulate.a = 1.0
		return
	if HudStyle.reduced_motion:
		_old.modulate.a = 1.0 - t
		return
	if _old_burn == null:
		_old_burn = CardFx.burn_material()
		_old.material = _old_burn
	_old_burn.set_shader_parameter("burn", t)
	_old_burn.set_shader_parameter("edge_color", Color("#FF8A3D"))
	var r := _old.get_global_rect()
	_old_burn.set_shader_parameter("rect_pos", r.position)
	_old_burn.set_shader_parameter("rect_size", r.size.max(Vector2.ONE))


## The replaced card's chip is burning now (tests).
func replaced_burning() -> bool:
	return _old_burn != null


func _build_slot_line() -> void:
	_slot.name = "SlotLine"
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot.add_theme_constant_override("separation", 6)
	_slot_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slot.add_child(_slot_glyph)
	for l: Label in [_slot_text, _old_text]:
		l.add_theme_font_size_override("font_size", 15)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_text.add_theme_color_override("font_color", Color(MenuStyle.TEXT, 0.9))
	_slot.add_child(_slot_text)
	_old.name = "Replaces"
	_old.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_old.add_theme_constant_override("separation", 4)
	var dot := Label.new()
	dot.text = "·"
	dot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	dot.add_theme_color_override("font_color", Color(MenuStyle.TEXT, 0.6))
	_old.add_child(dot)
	_old_icon.custom_minimum_size = Vector2(22, 22)
	_old_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_old.add_child(_old_icon)
	_old_text.add_theme_color_override("font_color", MenuStyle.EMBER)
	_old.add_child(_old_text)
	for c in _old.find_children("*", "CanvasItem", true, false):
		(c as CanvasItem).use_parent_material = true  # every part burns along one front
	_slot.add_child(_old)
	_slot.visible = false
	add_child(_slot)


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
	_curse_text.custom_minimum_size = Vector2(StoneCard.SIZE.x * s - 30.0, 0)
	_curse.add_child(_curse_text)
	_curse.visible = false
	add_child(_curse)


## Shows or hides the number key under the card (v0.6.0 UP: the Swap panel's single card has none).
func set_key_visible(v: bool) -> void:
	_key.visible = v


func _apply() -> void:
	card.set_focused(focused)
	_key.add_theme_color_override("font_color", Color(1, 1, 1, 0.95 if focused else 0.5))


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit(index)
