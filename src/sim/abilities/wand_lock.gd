class_name WandLock
extends RefCounted
## A wand card switched off for a while without leaving the wand: The Fallen holds it (FallenTheft,
## BossFightStore.fl_tk_code). Its slot, its level and the wand's order are untouched; only what the card does stops.
## The places that read what the held cards do skip it: the compile of the held wand (Modifiers.build_modifiers), the
## items' folded numbers (World._build_mods), and the element, Stress Mark and form reads that look a held card up
## (ElementLevels, ElementLevelsFsf, ElementStack, StressMarks, Modifiers._engine_outside_wand, AttackSlots.form_row).
## Taking and giving back a card rebuilds the build (World.refresh_build). Pure.


## Card `code` is held by The Fallen now: it stays in its slot but does nothing.
static func off(w: World, code: int) -> bool:
	return not w.boss_fight.fl_tk_code.is_empty() and w.boss_fight.fl_tk_code.has(code)


## `codes` without the cards switched off (the same array when none is).
static func lit(w: World, codes: PackedInt32Array) -> PackedInt32Array:
	var held := w.boss_fight.fl_tk_code
	if held.is_empty():
		return codes
	var out := PackedInt32Array()
	for c in codes:
		if not held.has(c):
			out.append(c)
	return out
