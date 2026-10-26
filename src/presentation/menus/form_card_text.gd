class_name FormCardText
extends RefCounted
## v0.9.5 TX: what a Pattern or Secondary Gun card does on the form you hold. FC1-FC9 made each of those cards behave
## differently per Gun form (docs/roadmap/v0.9.5/FORM_COMBOS.md), so the card's generic sentence is not the whole
## story: line_for() gives the one short line for the (form, card) cell, "FORMCARD_<FORM>_<CARD>" in locale/strings.csv
## (en, es). A card the form does not allow reads "Does nothing on this form" (FORMCARD_OFF; the allowed list is
## data/wand/attack_slots.tres, the table the sim reads). The Orbs have no lines (the generic sentence describes the
## orbs); the form cards, the element cores and the Blade have none either. Presentation only (EI-07): it reads
## content and decides nothing.

const SLOTS_PATH := "res://data/wand/attack_slots.tres"

## The Pattern and Secondary cards that have a line, by card id, and the short name their key ends with.
const CARDS := {
	&"gun_twin": "twin",
	&"halo_shot": "halo",
	&"gun_ring": "ring",
	&"gun_backfire": "backfire",
	&"gun_pierce": "pierce",
	&"gun_ricochet": "ricochet",
	&"gun_homing": "homing",
	&"gun_echo": "echo",
	&"gun_big_shot": "big_shot",
	&"gun_rapid_fire": "rapid_fire",
	&"split_shot": "split",
	&"gun_mine": "mine",
	&"orbit_rounds": "orbit",
	&"gun_threadline": "threadline",
	&"gun_spiral": "spiral",
	&"gun_swirl": "swirl",
}
const OFF_KEY := "FORMCARD_OFF"
## The form line's colour when a form has none of its own (the card text's secondary tone).
const FALLBACK := Color("#E2B07A")

static var _def: AttackSlotsDefinition


## The attack-slots table (data/wand/attack_slots.tres), loaded once.
static func slots() -> AttackSlotsDefinition:
	if _def == null:
		_def = load(SLOTS_PATH) as AttackSlotsDefinition
	return _def


## The row of form `form_id` (&"orbs", &"laser" ...), or null.
static func row_of(form_id: StringName) -> AttackFormRow:
	var def := slots()
	if def == null:
		return null
	for r in def.forms:
		if r.id == form_id:
			return r
	return null


## The translation key of the (form, card) cell: "FORMCARD_LASER_RING" ("" for a card with no line).
static func key_for(form_id: StringName, card_id: StringName) -> String:
	if not CARDS.has(card_id) or String(form_id).is_empty():
		return ""
	return "FORMCARD_%s_%s" % [String(form_id).to_upper(), String(CARDS[card_id]).to_upper()]


## The translated line for card `card_id` on form `form_id`: the cell's line, FORMCARD_OFF for a card the form does not
## allow, "" for a cell with no line (every Orbs cell, and any card that is not a Pattern or Secondary card).
static func line_for(form_id: StringName, card_id: StringName) -> String:
	var row := row_of(form_id)
	if row == null or not CARDS.has(card_id):
		return ""
	if not row.allowed.has(card_id):
		return TranslationServer.translate(OFF_KEY)
	var key := key_for(form_id, card_id)
	var text := TranslationServer.translate(key)
	return "" if text == key else text


## The colour of form `form_id`'s line: its Form card's colour (ItemLooks), else FALLBACK.
static func accent_for(form_id: StringName) -> Color:
	var row := row_of(form_id)
	if row == null or row.card == &"":
		return FALLBACK
	var c := ItemLooks.color_of_id(row.card)
	return FALLBACK if c == ItemLooks.color_of_id(&"") else c
