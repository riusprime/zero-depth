class_name ConstellationPanel
extends PickPanel
## v0.10.5 W3-P10c (owner W7, docs/roadmap/v0.10.5/W3_W7_LOOP_POWER_G1.md §C): a new loop's free Constellation pick.
## The 3-card pick's look and feel (PickPanel: the Astral heading and hint, the deal, the tilt, the glare and the
## noise dissolve of the cards not taken) on the owner's violet Constellation cards (AstralCardArt.CONSTELLATION:
## frame_constellation.png, back_constellation.png; icon_const_<name>.png, else icon_unknown). It opens while the
## sim's offer is open (WorldReader.constellation_open) and sends the pick as input (`picked` -> InputLatch ->
## InputFrame.pick). Mouse, keyboard (1/2/3, arrows, Enter) and pad as the pick; there is no way to leave it (owner
## Q3: permanent, never rerolled), so a cancel (Esc, pad B) passes on to the pause menu. It decides nothing (EI-07).

## The card tier its cards wear (PickSlot.TIERS: epic, the violet one).
const TIER := 2


func _init() -> void:
	super()
	name = "ConstellationPanel"


func sync(reader: WorldReader) -> void:
	_reader = reader
	if _closed(reader.constellation_open() and not reader.arriving()):
		return
	if _open:
		return
	_open = true
	_sent = false
	visible = true
	_end_outro()
	var offer := reader.constellation_offer()
	_codes = offer
	_boss = false
	_count = offer.size()
	for k in SLOTS:
		var s := _slots[k]
		s.visible = k < _count
		if k < _count:
			s.show_card(face(self, offer[k]))
			s.show_curse("")
	_price_icon.visible = false
	_title.set_text(tr("CONST_PICK_TITLE"))
	_hint.label.text = tr("CONST_PICK_HINT")
	_dealt = false
	_answer = InputFrame.PICK_NONE
	_set_focus(0)
	_start_deal()


## Constellation `id`'s card face (PickSlot.show_card), translated through `ci`.
static func face(ci: Object, id: int) -> Dictionary:
	return {
		"id": WorldReader.constellation_card_id(id),
		"title": ci.tr(WorldReader.constellation_name_key(id)),
		"sentence": ci.tr(WorldReader.constellation_desc_key(id)),
		"color": Color(0, 0, 0, 0),
		"tier": TIER,
		"tier_text": ci.tr("CONSTELLATION_KIND"),
	}


## The offered Constellation ids (tests).
func offer() -> PackedInt32Array:
	return _codes


func _input(event: InputEvent) -> void:
	if PanelInput.decode(event, 3, ECHO).kind == PanelInput.Kind.CANCEL:
		return  # no skip: the pause menu takes it
	if get_viewport().gui_get_focus_owner() != null:
		return  # a menu over the pick (the pause menu) has the keys and the pad
	super(event)


## A pick only: the panel never sends a cancel.
func _send(value: int) -> void:
	if value <= 0:
		return
	super(value)


## The pick went in: the picked card fades, the others burn (no icon flies: a Constellation has no HUD slot).
func _on_closed() -> void:
	var k := _answer - 1
	if k < 0 or k >= _count:
		return
	visible = true
	_outro = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for s in _slots:
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picked = k
