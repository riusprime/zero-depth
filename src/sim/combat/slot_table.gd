class_name SlotTable
extends RefCounted
## v0.9.0 AS (owner Q2–Q5, Q13; AttackSlotsDefinition, data/wand/attack_slots.tres): the wand's slot limits, the
## per-attack projectile caps and the form × card compatibility table in sim units (item indices). Loadout: compiled at
## setup (WandCompiler.slots), never written in play (World.slot_table; null = a lab world: no limits, no table, no
## caps, as before AS).

## A compatibility cell: off, on, on with the form's own rule.
const CELL_OFF := 0
const CELL_ON := 1
const CELL_RULED := 2

## Per AttackSlots category (FORM, PATTERN, SECONDARY, ELEMENT: index − 1 here) the most cards of it a Gun / Blade
## wand holds (-1: no limit).
var gun_limits := PackedInt32Array([1, 1, 2, 2])
var blade_limits := PackedInt32Array([-1, 1, -1, -1])
var shots_per_attack_max := 12
var shots_per_second_max := 40
var merge_radius_max_permille := 2000
## The forms in data order: each one's id, the item index of the card that sets it (-1: the default form, Orbs) and
## its cells (item index -> CELL_ON or CELL_RULED; a card not listed is off).
var form_ids: Array[StringName] = []
var form_cards := PackedInt32Array()
var form_cells: Array[Dictionary] = []
## The default form's row (the one without a card), or -1.
var default_form := -1


## The cell of form row `row` for item `idx` (CELL_*; off past the table).
func cell(row: int, idx: int) -> int:
	if row < 0 or row >= form_cells.size():
		return CELL_OFF
	return int(form_cells[row].get(idx, CELL_OFF))


## The row of the form card `idx` sets, or -1.
func row_of_card(idx: int) -> int:
	return form_cards.find(idx) if idx >= 0 else -1
