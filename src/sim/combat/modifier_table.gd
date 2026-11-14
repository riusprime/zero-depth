class_name ModifierTable
extends RefCounted
## One compiled ModifierDefinition (ContentCompiler.compile_modifier), in sim units. Loadout: compiled
## at setup, never written in play (Modifiers.compile reads it into fresh specs).

## ModifierDefinition.Stage, same numbers. the order of one card's own ops (across cards the slot order
## decides: WandCompile).
enum Stage { FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE }
## ModifierDefinition.OrderKind, same numbers.
enum OrderKind { FREE, SHAPE, COUNT, MOTION }
const STAGE_COUNT := 6

var id := &""
var family := &""
var rarity := 0
## Every tag a spec must carry to be rewritten (empty: all).
var target := PackedStringArray()
var stage: int = Stage.PAYLOAD
var ops: Array[ModifierOp] = []
var overlay := &""
## ModifierDefinition.OrderKind, same numbers (WandCompile: a SHAPE card takes in what is left of it).
var order_kind := 0
## The card's other reading. On a spec matching alt_target (and not
## target) that has no hook child matching target yet, the card's `alt` ops run instead (WandCompile.run): Split Wave
## splits a flying slash, and on a slash with no flying slash its hits throw small crescents. Empty: none.
var alt_target := PackedStringArray()


## The wand trigger's op (a trigger card's one op), or null for a modifier of rewrites.
func trigger_op() -> ModifierOp:
	for o in ops:
		if o.op == ModifierOp.Op.TRIGGER:
			return o
	return null


func is_trigger() -> bool:
	return trigger_op() != null


## WAND.md rule 6, a duplicate levels the card up: this card at `level` (1..5): itself when no op grows
## with the level (or at level 1), else a copy whose ops are at that level (ModifierOp.at_level). Compile-time only.
func at(level: int) -> ModifierTable:
	if level <= 1:
		return self
	var grows := false
	for o in ops:
		grows = grows or o.levels()
	if not grows:
		return self
	var t := ModifierTable.new()
	t.id = id
	t.family = family
	t.rarity = rarity
	t.target = target.duplicate()
	t.stage = stage
	t.overlay = overlay
	t.order_kind = order_kind
	t.alt_target = alt_target.duplicate()  # v0.8.0 MR
	for o in ops:
		t.ops.append(o.at_level(level))
	return t


## The card's main number is a share of the hit (a hook's child, Twin's or Halo's share:
## ModifierOp.is_share), which its overlevels grow here; a card without one grows the weapon's damage factor instead
## (CardLevels.weapon_overlevel_permille).
func has_share() -> bool:
	for o in ops:
		if o.is_share():
			return true
	return false


## Overlevels; CardLevels.overlevel_permille: this card with each share × `permille` / 1000
## (ModifierOp.overlevelled); itself at 1000 or below, or without a share. Compile-time only
## (Modifiers.build_modifiers_of).
func overlevelled(permille: int) -> ModifierTable:
	if permille <= 1000 or not has_share():
		return self
	var t := ModifierTable.new()
	t.id = id
	t.family = family
	t.rarity = rarity
	t.target = target.duplicate()
	t.stage = stage
	t.overlay = overlay
	t.order_kind = order_kind
	t.alt_target = alt_target.duplicate()
	for o in ops:
		var g := o.overlevelled(permille)
		t.ops.append(g if g != null else o)
	return t
