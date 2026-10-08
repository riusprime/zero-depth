class_name ModifierTable
extends RefCounted
## v0.6.0 MX1: one compiled ModifierDefinition (ContentCompiler.compile_modifier), in sim units. Loadout: compiled
## at setup, never written in play (Modifiers.compile reads it into fresh specs).

## ModifierDefinition.Stage, same numbers: the fixed compile order.
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
