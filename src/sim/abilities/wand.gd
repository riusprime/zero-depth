class_name Wand
extends RefCounted
## v0.6.5 WN1 (docs/design/WAND.md; owner W3, W6; SIM_CONTRACTS §8e): the wand is the build's modifier slots in their
## order (World.mod_slots), read left to right by the compile (WandCompile). This holds what the slots mean as a wand:
## - how many slots it has now: 4 on floor 1, 6 after the first boss, 8 after the second (WandTable, data; a world
##   without the table, a lab, keeps v0.6.0's six). With every slot full a new card opens the Swap (BuildSlots).
## - the reorder: a player action that arrives as input (InputFrame.pick = PICK_WAND_MOVE_BASE + from × 16 + to) and
##   moves a card at the tick it arrives, in any state; the cards between shift by one. Free and immediate (rule 4).
## - the read the views get (WorldReader.wand: the cards in order, their levels and the trigger cuts) and the plain-
##   words read-back (describe: translation keys and their arguments, which the Build page renders, WN2).
## Pure: no randomness, no engine calls (render takes the translation as a Callable).

const MAX_SLOTS := WandDefinition.MAX_SLOTS
## WAND.md T1–T4's read-back keys by trigger (AttackSpec.Trigger).
const TRIGGER_KEYS := {
	AttackSpec.Trigger.ON_HIT: &"WAND_READ_ON_HIT",
	AttackSpec.Trigger.ON_KILL: &"WAND_READ_ON_KILL",
	AttackSpec.Trigger.ON_END: &"WAND_READ_ON_END",
	AttackSpec.Trigger.ON_FINISHER: &"WAND_READ_ON_FINISHER",
	AttackSpec.Trigger.ON_CRIT: &"WAND_READ_ON_CRIT",
}


## The wand's slot count now (the floor's, WandTable.slots_at; six without a table).
static func slots(w: World) -> int:
	if w.wand_table == null:
		return BuildSlots.SLOTS
	return mini(MAX_SLOTS, w.wand_table.slots_at(w.floor_index))


## The cards held, in slot order (Offers codes).
static func cards(w: World) -> PackedInt32Array:
	return w.mod_slots


static func size(w: World) -> int:
	return w.mod_slots.size()


# --- The reorder (input) ------------------------------------------------------------------------------------
## `v` is a wand move pick value.
static func is_move(v: int) -> bool:
	var n := v - InputFrame.PICK_WAND_MOVE_BASE
	return n >= 0 and n < InputFrame.WAND_MOVE_STRIDE * InputFrame.WAND_MOVE_STRIDE


## World.step's first phase: a move in `frame` is applied, and the frame the rest of the tick reads has no pick (a
## copy; the caller's frame is not written). Any other frame comes back as it is.
static func take_move(w: World, frame: InputFrame) -> InputFrame:
	if not is_move(frame.pick):
		return frame
	var n := frame.pick - InputFrame.PICK_WAND_MOVE_BASE
	move(w, n / InputFrame.WAND_MOVE_STRIDE, n % InputFrame.WAND_MOVE_STRIDE)
	var f := InputFrame.make(
		frame.move, frame.aim_angle, frame.aim_dist_cm, frame.held, frame.pressed
	)
	return f


## Moves the card in slot `from` to slot `to` (the cards between shift one slot toward `from`); the build compiles
## again on the next read. False (nothing changes) when either slot is empty or they are the same.
static func move(w: World, from: int, to: int) -> bool:
	var n := w.mod_slots.size()
	if from < 0 or to < 0 or from >= n or to >= n or from == to:
		return false
	var code := w.mod_slots[from]
	w.mod_slots.remove_at(from)
	w.mod_slots.insert(to, code)
	Modifiers.invalidate(w)
	return true


# --- Reads ------------------------------------------------------------------------------------------------------
## The trigger card `code` cuts on for this run (AttackSpec.Trigger, the Gun's when it has its own), or -1 for a
## card of rewrites.
static func trigger_of(w: World, code: int) -> int:
	var mods: Array[ModifierTable] = []
	if Offers.type_of(code) == Offers.ABILITY:
		var idx := Offers.ability_of(code)
		if idx < w.ability_tables.size():
			mods = w.ability_tables[idx].modifiers
	elif code >= 0 and code < w.item_tables.size():
		mods = w.item_tables[code].modifiers
	for m in mods:
		var op := m.trigger_op()
		if op != null:
			var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
			return op.trigger_gun if gun and op.trigger_gun >= 0 else op.trigger
	return -1


## The wand as the views read it (WorldReader.wand): the weapon (&"gun" or &"blade": what the spell is), the slot
## count, every card in slot order (code, id, name_key, type, level, trigger: -1 or the AttackSpec.Trigger it cuts
## on) and the cuts (the slots holding a trigger, in order).
static func read(w: World) -> Dictionary:
	var out: Array[Dictionary] = []
	var cuts := PackedInt32Array()
	for s in w.mod_slots.size():
		var code := w.mod_slots[s]
		var info := Offers.info(w, code)
		var trig := trigger_of(w, code)
		if trig >= 0:
			cuts.append(s)
		(
			out
			. append(
				{
					"code": code,
					"id": info["id"],
					"name_key": info["name_key"],
					"type": info["type"],
					"level": BuildSlots.level_at(w, s),
					"trigger": trig,
				}
			)
		)
	var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	return {"weapon": &"gun" if gun else &"blade", "slots": slots(w), "cards": out, "cuts": cuts}


## The plain-words read-back of a wand read (read()): an Array of lines, each {"key": a translation key, "args": its
## arguments}, where an argument is a line of the same shape, an Array of them (a list, joined) or a plain value.
## The first line is the spell you fire (the weapon's attack, and the cards that shape it); each trigger adds a line
## for the child spell it casts (a small copy, shaped by the cards to its right); cards past a third trigger (deeper
## than the compile casts) are listed as unused.
static func describe(wand: Dictionary) -> Array[Dictionary]:
	var gun: bool = wand.get("weapon", &"blade") == &"gun"
	var segments: Array = [[]]
	var triggers: Array[int] = []
	for c: Dictionary in wand.get("cards", []):
		if int(c["trigger"]) >= 0:
			triggers.append(int(c["trigger"]))
			segments.append([])
		else:
			(segments[segments.size() - 1] as Array).append({"key": c["name_key"], "args": []})
	var lines: Array[Dictionary] = []
	var base := &"WAND_READ_BOLT" if gun else &"WAND_READ_SLASH"
	lines.append({"key": &"WAND_READ_FIRE", "args": [_spell(base, segments[0])]})
	var small := &"WAND_READ_SMALL_BOLT" if gun else &"WAND_READ_SMALL_SLASH"
	for k in triggers.size():
		var names: Array = segments[k + 1]
		if k >= WandCompile.MAX_DEPTH:
			if not names.is_empty():
				lines.append({"key": &"WAND_READ_UNUSED", "args": [names]})
			continue
		var key: StringName = TRIGGER_KEYS.get(triggers[k], &"WAND_READ_ON_HIT")
		lines.append({"key": key, "args": [_spell(small, names)]})
	return lines


static func _spell(base: StringName, names: Array) -> Dictionary:
	var b := {"key": base, "args": []}
	if names.is_empty():
		return b
	return {"key": &"WAND_READ_SHAPED", "args": [b, names]}


## describe()'s lines in words: each line's key through `translate` (a Callable: key -> String; the views pass tr),
## formatted with its arguments; lists joined with ", "; lines joined with a space.
static func render(lines: Array[Dictionary], translate: Callable) -> String:
	var out := PackedStringArray()
	for l in lines:
		out.append(_words(l, translate))
	return " ".join(out)


static func _words(v: Variant, translate: Callable) -> String:
	if v is Dictionary:
		var d: Dictionary = v
		var args := []
		for a: Variant in d.get("args", []):
			args.append(_words(a, translate))
		var text: String = translate.call(d["key"])
		return text % args if not args.is_empty() else text
	if v is Array:
		var parts := PackedStringArray()
		for a: Variant in v:
			parts.append(_words(a, translate))
		return ", ".join(parts)
	return str(v)
