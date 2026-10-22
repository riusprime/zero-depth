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
## v0.8.0 MR (owner O91: "Clearly flag incompatible placements"): why a card can't act where it sits (flags()): right
## of a trigger a repeat or a hold (WandTable.after_trigger_dead), or past the third trigger (too deep to cast).
const DEAD_AFTER_TRIGGER := &"UI_WAND_DEAD_TRIGGER"
const DEAD_TOO_DEEP := &"UI_WAND_DEAD_DEEP"
## v0.8.0 RM: what a card's remnant does (remnant_of; the read-back's lines).
const REMNANT_NONE := 0
const REMNANT_CASTS := 1
const REMNANT_PULLS := 2
const REMNANT_CONSUMES := 3
## A wand without a table (a lab): WandTable's defaults (they mirror data/wand/wand.tres).
static var _defaults := WandTable.new()


## The wand's slot count now (the floor's, WandTable.slots_at; six without a table). v0.7.5 AP: by the run's floor
## across loops (World.run_floor_index), so a wand never shrinks when a new loop starts.
static func slots(w: World) -> int:
	if w.wand_table == null:
		return BuildSlots.SLOTS
	return mini(MAX_SLOTS, w.wand_table.slots_at(w.run_floor_index()))


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
	if not can_move(w.mod_slots.size(), from, to):
		return false
	w.mod_slots = moved_order(w.mod_slots, from, to)
	Modifiers.invalidate(w)
	return true


## v0.6.5 WN2: whether a move from slot `from` to slot `to` changes a wand of `n` cards (both held, not the same).
static func can_move(n: int, from: int, to: int) -> bool:
	return from >= 0 and to >= 0 and from < n and to < n and from != to


## v0.6.5 WN2: `order` with the card in slot `from` moved to slot `to` (a copy; the cards between shift by one): the
## one rule move() applies, so the Build page's preview and the sim's outcome are the same function (EI-07). A move
## that changes nothing (can_move) gives an unchanged copy.
static func moved_order(order: PackedInt32Array, from: int, to: int) -> PackedInt32Array:
	var out := order.duplicate()
	if not can_move(out.size(), from, to):
		return out
	var code := out[from]
	out.remove_at(from)
	out.insert(to, code)
	return out


## v0.6.5 WN2: a wand read (read()) with the card in slot `from` moved to slot `to` (moved_order's rule), its cuts
## found again: what read() gives after the move, for the Build page's live preview and read-back (describe).
static func moved_read(wand: Dictionary, from: int, to: int) -> Dictionary:
	var cards: Array = wand.get("cards", [])
	var idx := PackedInt32Array()
	for k in cards.size():
		idx.append(k)
	idx = moved_order(idx, from, to)
	var moved: Array[Dictionary] = []
	for k in idx:
		moved.append(cards[k])
	return _with_cards(wand, moved)


## A copy of the wand read `wand` holding `cards` (in slot order), its cuts found again.
static func _with_cards(wand: Dictionary, cards: Array[Dictionary]) -> Dictionary:
	var out := wand.duplicate()
	var cuts := PackedInt32Array()
	for k in cards.size():
		if int(cards[k]["trigger"]) >= 0:
			cuts.append(k)
	out["cards"] = cards
	out["cuts"] = cuts
	return out


## v0.6.5 WN2 (the Swap panel): a wand read (read(), with its "incoming" card) after the swap answer "the card in
## slot `leave` leaves" and then the move of the new card from that slot to `at`: BuildSlots.take's rule (the new card
## takes the slot it replaces) and moved_order's, so the panel's preview is what the sim will hold. `at` = `leave` is a
## plain replace; another `at` inserts the new card there. An unchanged copy without an incoming card or a held `leave`.
static func swapped_read(wand: Dictionary, leave: int, at: int) -> Dictionary:
	var cards: Array = wand.get("cards", [])
	var incoming: Dictionary = wand.get("incoming", {})
	var out := wand.duplicate()
	if incoming.is_empty() or leave < 0 or leave >= cards.size():
		return out
	var replaced: Array[Dictionary] = []
	for c: Dictionary in cards:
		replaced.append(c)
	replaced[leave] = incoming
	out = _with_cards(out, replaced)
	out["incoming"] = {}
	return moved_read(out, leave, clampi(at, 0, cards.size() - 1))


## v0.6.5 WN2: the picks (in order, one per tick) that give swapped_read(leave, at): the answer that replaces slot
## `leave`, then the move of the new card to `at` when it goes elsewhere.
static func swap_picks(leave: int, at: int) -> PackedInt32Array:
	var out := PackedInt32Array([InputFrame.PICK_SWAP_BASE + leave])
	if at != leave:
		out.append(InputFrame.wand_move(leave, at))
	return out


## v0.6.5 WN2: the fewest wand moves (pick values, InputFrame.wand_move) that turn the order `from` into `to` (the
## same cards; each card's code appears once): at most one per slot, applied in turn by move(). Empty when they are
## already equal or hold different cards.
static func plan_moves(from: PackedInt32Array, to: PackedInt32Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	if from.size() != to.size():
		return out
	var cur := from.duplicate()
	for k in to.size():
		var at := cur.find(to[k])
		if at < 0:
			return PackedInt32Array()
		if at != k:
			out.append(InputFrame.wand_move(at, k))
			cur = moved_order(cur, at, k)
	return out


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
## on) and the cuts (the slots holding a trigger, in order). v0.6.5 WN2: while a swap waits, "incoming" is the card
## offered, in the same shape (level 1; empty otherwise), so the Swap panel can preview it in the row.
static func read(w: World) -> Dictionary:
	var out: Array[Dictionary] = []
	var cuts := PackedInt32Array()
	for s in w.mod_slots.size():
		var c := _card(w, w.mod_slots[s], BuildSlots.level_at(w, s))
		if int(c["trigger"]) >= 0:
			cuts.append(s)
		out.append(c)
	var gun := PlayerBuild.has_gun(w) and not PlayerBuild.has_blade(w)
	var incoming := _card(w, w.swap_code, 1) if BuildSlots.swapping(w) else {}
	return {
		"weapon": &"gun" if gun else &"blade",
		"slots": slots(w),
		"cards": out,
		"cuts": cuts,
		"incoming": incoming,
		# v0.9.0 AS: the form fired now (&"" on a Blade run) and per limited slot category [category, held, limit]
		"form": AttackSlots.form_id(w),
		"slot_counts": AttackSlots.counts(w),
		# v0.9.0 AS2: the slot category the waiting swap is limited to (AttackSlots.choice_category; 0: any slot)
		"swap_slot": AttackSlots.choice_category(w, w.swap_code) if BuildSlots.swapping(w) else 0,
	}


static func _card(w: World, code: int, level: int) -> Dictionary:
	var info := Offers.info(w, code)
	return {
		"code": code,
		"id": info["id"],
		"name_key": info["name_key"],
		"type": info["type"],
		"level": level,
		"trigger": trigger_of(w, code),
		"wand": bool(info.get("wand", false)),  # v0.7.5 SM: a wand card (it has a level, 1–5)
		"order": order_of(w, code),  # v0.8.0 AO: what it does to the cards to its left
		"after_trigger_dead": dead_after_trigger(w, info["id"]),  # v0.8.0 MR: it does nothing right of a trigger
		"remnant": remnant_of(w, code),  # v0.8.0 RM: what its remnant does (REMNANT_*)
		"slot": AttackSlots.tag(w, code),  # v0.9.0 AS: its slot tag on this run (AttackSlots; 0 none)
	}


## v0.8.0 RM (owner O91; Remnants): what card `code`'s remnant does, for the read-back: REMNANT_NONE, REMNANT_CASTS
## (its activation casts a spell the cards to its right shape), REMNANT_PULLS (an anchor's pull) or REMNANT_CONSUMES
## (Grand Finale: it releases the remnants to its left).
static func remnant_of(w: World, code: int) -> int:
	if Offers.type_of(code) == Offers.ABILITY or code < 0 or code >= w.item_tables.size():
		return REMNANT_NONE
	for m in w.item_tables[code].modifiers:
		for o in m.ops:
			if o.remnant == null:
				continue
			match o.remnant.activate:
				RemnantRule.Activate.PULL:
					return REMNANT_PULLS
				RemnantRule.Activate.CONSUME:
					return REMNANT_CONSUMES
			return REMNANT_CASTS
	return REMNANT_NONE


## v0.8.0 MR: card `id` does nothing right of a trigger (WandTable.after_trigger_dead).
static func dead_after_trigger(w: World, id: Variant) -> bool:
	var t := w.wand_table if w.wand_table != null else _defaults
	return t.after_trigger_dead.has(StringName(str(id)))


## v0.8.0 MR (owner O91): per card of a wand read (read(), or a preview from WorldReader.wand_moved), in slot order,
## why it can't act where it sits: DEAD_AFTER_TRIGGER (a card that does nothing right of a trigger, there),
## DEAD_TOO_DEEP (past the third trigger: the compile casts nothing that deep), or &"" (it acts). A trigger card is
## never flagged. The wand's tiles dim a flagged card and show the reason; describe() leaves its effect out.
static func flags(wand: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	var cuts := 0
	for c: Dictionary in wand.get("cards", []):
		if int(c["trigger"]) >= 0:
			out.append(&"")
			cuts += 1
		elif cuts > WandCompile.MAX_DEPTH:
			out.append(DEAD_TOO_DEEP)
		elif cuts > 0 and bool(c.get("after_trigger_dead", false)):
			out.append(DEAD_AFTER_TRIGGER)
		else:
			out.append(&"")
	return out


## v0.8.0 AO (owner O37): card `code`'s ModifierTable.OrderKind (its first modifier that has one; FREE otherwise): the
## wand's tiles mark a shape, a count and a motion card (it changes what is left of it).
static func order_of(w: World, code: int) -> int:
	if Offers.type_of(code) == Offers.ABILITY or code < 0 or code >= w.item_tables.size():
		return ModifierTable.OrderKind.FREE
	for m in w.item_tables[code].modifiers:
		if m.order_kind != ModifierTable.OrderKind.FREE:
			return m.order_kind
	return ModifierTable.OrderKind.FREE


## The plain-words read-back of a wand read (read()): an Array of lines, each {"key": a translation key, "args": its
## arguments}, where an argument is a line of the same shape, an Array of them (a list, joined) or a plain value.
## The first line is the spell you fire (the weapon's attack, and the cards that shape it); each trigger adds a line
## for the child spell it casts (a small copy, shaped by the cards to its right); cards past a third trigger (deeper
## than the compile casts) are listed as unused; v0.8.0 MR: a card that does nothing right of a trigger (flags()) is
## left out of its spell and listed last ("Does nothing after a trigger: Echo.").
static func describe(wand: Dictionary) -> Array[Dictionary]:
	var gun: bool = wand.get("weapon", &"blade") == &"gun"
	var segments: Array = [[]]
	var triggers: Array[int] = []
	var dead: Array = []  # v0.8.0 MR: the cards that do nothing right of a trigger (flags())
	var why := flags(wand)
	var cards: Array = wand.get("cards", [])
	for n in cards.size():
		var c: Dictionary = cards[n]
		if int(c["trigger"]) >= 0:
			triggers.append(int(c["trigger"]))
			segments.append([])
		elif why[n] == DEAD_AFTER_TRIGGER:
			dead.append({"key": c["name_key"], "args": []})
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
	lines.append_array(_remnant_lines(cards, why))  # v0.8.0 RM
	if not dead.is_empty():
		lines.append({"key": &"WAND_READ_DEAD", "args": [dead]})
	return lines


## v0.8.0 RM (owner O91): a line per remnant card that acts where it sits: what it leaves and what its remnants release
## (a burst shaped by the cards right of it in its trigger section), or that it pulls, or (Grand Finale) that it
## releases the remnants to its left.
static func _remnant_lines(cards: Array, why: Array[StringName]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cuts := 0
	for n in cards.size():
		var c: Dictionary = cards[n]
		if int(c["trigger"]) >= 0:
			cuts += 1
			continue
		var kind := int(c.get("remnant", REMNANT_NONE))
		if kind == REMNANT_NONE or why[n] != &"" or cuts > WandCompile.MAX_DEPTH:
			continue
		var me := {"key": c["name_key"], "args": []}
		if kind == REMNANT_PULLS:
			out.append({"key": &"WAND_READ_REMNANT_PULL", "args": [me]})
			continue
		var right: Array = []
		for m in range(n + 1, cards.size()):
			var r: Dictionary = cards[m]
			if int(r["trigger"]) >= 0:
				break
			if why[m] == &"":
				right.append({"key": r["name_key"], "args": []})
		var burst := _spell(&"WAND_READ_BURST", right)
		var key := &"WAND_READ_FINALE" if kind == REMNANT_CONSUMES else &"WAND_READ_REMNANT"
		out.append({"key": key, "args": [me, burst]})
	return out


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
