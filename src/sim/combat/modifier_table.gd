class_name ModifierTable
extends RefCounted
## v0.6.0 MX1: one compiled ModifierDefinition (ContentCompiler.compile_modifier), in sim units. Loadout: compiled
## at setup, never written in play (Modifiers.compile reads it into fresh specs).

## ModifierDefinition.Stage, same numbers. v0.6.5 WN1: the order of one card's own ops (across cards the slot order
## decides: WandCompile).
enum Stage { FORM, PATTERN, BEHAVIOUR, PAYLOAD, HOOK, SCALE }
const STAGE_COUNT := 6

var id := &""
var family := &""
var rarity := 0
## Every tag a spec must carry to be rewritten (empty: all).
var target := PackedStringArray()
var stage: int = Stage.PAYLOAD
var ops: Array[ModifierOp] = []
var overlay := &""
## v0.6.5 WN4 (WAND.md rule 6): the card at levels 2..5 (ModifierCompiler; empty when no op grows with the level).
var levels: Array[ModifierTable] = []


## v0.6.5 WN1: the wand trigger's op (a trigger card's one op), or null for a modifier of rewrites.
func trigger_op() -> ModifierOp:
	for o in ops:
		if o.op == ModifierOp.Op.TRIGGER:
			return o
	return null


func is_trigger() -> bool:
	return trigger_op() != null


## v0.6.5 WN4: this card at `level` (1 = itself; past its last compiled level, the last).
func at_level(level: int) -> ModifierTable:
	if level <= 1 or levels.is_empty():
		return self
	return levels[mini(level - 2, levels.size() - 1)]
