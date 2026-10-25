class_name AttackSlots
extends RefCounted
## v0.9.0 AS (owner Q2–Q7, Q13, Q14; PLAN C37–C45, C60–C67, C87; docs/roadmap/v0.9.0/ATTACK_FORMS.md): the wand's slot
## categories inside its slots (SIM_CONTRACTS §8e). The wand stays (its slots, read left to right, triggers cast child
## spells); every card has a slot category (ItemTable.slot_category, data) and some categories hold a limited number
## of cards (World.slot_table, data/wand/attack_slots.tres: on a Gun run Form 1, Pattern 1, Secondary 2, Element 2; on a
## Blade run only Pattern 1, Q6). Free cards (triggers, mutations, the rest) never have a limit.
## - Replace (Q5 "Marked, old one burns"): taking a Form or Pattern card while that category is at its limit replaces
##   the held card of that category (replaces()): the old card leaves the build (its level with it) and the new one
##   takes its place in the wand order. The card says so before it is taken (Offers.info "replaces", the pick card's
##   "Replaces <card>"), and the wand being full doesn't ask for the Swap then (BuildSlots.needs_swap).
## - Choose (v0.9.0 AS2, owner "Let me choose"): taking a Secondary or Element card while that category is full asks
##   the player which card of it goes (choices(): the Swap panel, limited to those slots; BuildSlots.needs_swap and
##   swap_answer); the chosen one leaves and the new one takes its slot. Skipping leaves the card un-taken.
##   Taking a card you hold levels it up as before.
## - The form × card table (C60–C66): the run's form is the held Form card's row, else the default row (Orbs, the Gun's
##   own shot). A Pattern, Secondary or Element card whose cell is off for that form is never offered (usable(), read by
##   ItemPool.usable) and, if held, never compiled (compiles(), read by Modifiers.build_modifiers). The table is the
##   Gun's: a Blade run has no form, and every card reads as on there.
## - An old save (trim(), on load after WandMigration): a wand saved before AS may hold more cards of a category than
##   its limit; the leftmost ones up to the limit stay and the rest leave the build, refunded as shards (the shop's
##   salvage price, WandMigration.refund_of), so the run loads with a legal wand.
## A world without the table (a lab) has no limits and no cells off: every function here reads as before AS.
## Pure: no randomness, no engine calls.

const FREE := 0
const FORM := 1
const PATTERN := 2
const SECONDARY := 3
const ELEMENT := 4
## The tag keys by category (the cards' slot tag, en + es; FREE has none).
const TAG_KEYS: Array[StringName] = [
	&"", &"UI_SLOT_FORM", &"UI_SLOT_PATTERN", &"UI_SLOT_SECONDARY", &"UI_SLOT_ELEMENT"
]


## Card `code`'s slot category (an Offers code; an ability or a non-item card is FREE).
static func category(w: World, code: int) -> int:
	if Offers.type_of(code) != Offers.MOD or code < 0 or code >= w.item_tables.size():
		return FREE
	return w.item_tables[code].slot_category


## The most cards of category `cat` this run's wand holds (-1: no limit; always -1 without the table or for FREE).
static func limit(w: World, cat: int) -> int:
	var t := w.slot_table
	if t == null or cat <= FREE or cat > ELEMENT:
		return -1
	var lim := t.gun_limits if gun(w) else t.blade_limits
	return lim[cat - 1] if cat - 1 < lim.size() else -1


## The run is a Gun run (the Gun without the Blade): the forms and the table are the Gun's.
static func gun(w: World) -> bool:
	return PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)


## Card `code`'s slot tag on this run: its category when that category has a limit here, else FREE (no tag).
static func tag(w: World, code: int) -> int:
	var cat := category(w, code)
	return cat if limit(w, cat) >= 0 else FREE


## The wand slots (indices into World.mod_slots, left to right) holding cards of category `cat`.
static func held_of(w: World, cat: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for s in w.mod_slots.size():
		if category(w, w.mod_slots[s]) == cat:
			out.append(s)
	return out


## The category of `code` when taking it meets a full slot category: a modifier card not held, of a category already
## holding its limit (FREE otherwise). A limit of 0 is never full (usable() keeps such a card out of the offers).
static func full_category(w: World, code: int) -> int:
	var cat := category(w, code)
	var lim := limit(w, cat)
	if lim <= 0 or not BuildSlots.is_modifier(w, code) or BuildSlots.held(w, code):
		return FREE
	return cat if held_of(w, cat).size() >= lim else FREE


## The player chooses which card of category `cat` goes when it is full (AS2: Secondary and Element); Form and
## Pattern replace their card.
static func chosen(cat: int) -> bool:
	return cat == SECONDARY or cat == ELEMENT


## The wand slot whose card taking `code` would replace (class doc), or -1: `code` meets its full Form or Pattern
## category (the leftmost held card of it). A full Secondary or Element category asks instead (choices()).
static func replaces(w: World, code: int) -> int:
	var cat := full_category(w, code)
	if cat == FREE or chosen(cat):
		return -1
	return held_of(w, cat)[0]


## v0.9.0 AS2: the wand slots the player chooses from when taking `code` meets its full Secondary or Element
## category (its held cards of that category, left to right); empty when no such choice applies.
static func choices(w: World, code: int) -> PackedInt32Array:
	var cat := full_category(w, code)
	return held_of(w, cat) if chosen(cat) else PackedInt32Array()


## v0.9.0 AS2: the category a choice for `code` is limited to (SECONDARY or ELEMENT), or FREE (any slot).
static func choice_category(w: World, code: int) -> int:
	var cat := full_category(w, code)
	return cat if chosen(cat) else FREE


## The card code `replaces(w, code)` would remove, or -1.
static func replaced_code(w: World, code: int) -> int:
	var s := replaces(w, code)
	return w.mod_slots[s] if s >= 0 else -1


## The form row the run fires now (SlotTable): the held Form card's row, else the default one; -1 without the table or
## on a Blade run.
static func form_row(w: World) -> int:
	var t := w.slot_table
	if t == null or not gun(w):
		return -1
	for s in held_of(w, FORM):
		var r := t.row_of_card(w.mod_slots[s])
		if r >= 0:
			return r
	return t.default_form


## The form the run fires now (its row's id; &"" without the table or on a Blade run).
static func form_id(w: World) -> StringName:
	var r := form_row(w)
	return w.slot_table.form_ids[r] if r >= 0 else &""


## Item `idx` works with the run's form (C60): a Pattern, Secondary or Element card whose cell is on (or on with a
## rule) for the form fired now; a Form card that has a row; any other card. True without the table, on a Blade run.
static func compatible(w: World, idx: int) -> bool:
	var r := form_row(w)
	if r < 0:
		return true
	var cat := category(w, idx)
	if cat == FORM:
		return w.slot_table.row_of_card(idx) >= 0
	if cat == FREE:
		return true
	return w.slot_table.cell(r, idx) != SlotTable.CELL_OFF


## Item `idx` may be offered (ItemPool.usable, C66): it works with the form, and its category's limit isn't 0.
static func usable(w: World, idx: int) -> bool:
	return compatible(w, idx) and limit(w, category(w, idx)) != 0


## Held card `code` is compiled (Modifiers.build_modifiers): every card but an item the form can't use.
static func compiles(w: World, code: int) -> bool:
	return Offers.type_of(code) != Offers.MOD or compatible(w, code)


## v0.9.0 AS: an old save's wand trimmed to the limits (class doc). Returns the shards refunded (0 when it was legal).
## Deterministic, idempotent.
static func trim(w: World) -> int:
	if w.slot_table == null:
		return 0
	var counts := {}
	var over := PackedInt32Array()
	for s in w.mod_slots.size():
		var code := w.mod_slots[s]
		var cat := category(w, code)
		var lim := limit(w, cat)
		if lim < 0:
			continue
		counts[cat] = int(counts.get(cat, 0)) + 1
		if int(counts[cat]) > lim:
			over.append(code)
	var refund := 0
	for code in over:
		refund += WandMigration.refund_of(w, code)
		var s := w.mod_slots.find(code)
		if s >= 0:
			BuildSlots.drop(w, s)
	w.shards += refund
	return refund


## The slot counts the Build page shows (WorldReader.wand): per limited category in order, [category, held, limit].
static func counts(w: World) -> Array:
	var out := []
	for cat in [FORM, PATTERN, SECONDARY, ELEMENT]:
		var lim := limit(w, cat)
		if lim > 0:
			out.append([cat, held_of(w, cat).size(), lim])
	return out
