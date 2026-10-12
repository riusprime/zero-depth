class_name WandLab
extends RefCounted
## v0.6.5 WN1: helpers for the wand's tests (tests/unit/sim/test_wand*.gd): the shipped cards' modifiers by id, a few
## synthetic cards (Big, Fire, Shock: WN3–WN5 ship the real ones), and fight worlds whose wand holds given cards in a
## given slot order. No randomness beyond the world's own streams.

const OP := ModifierOp.Op
const STAGE := ModifierTable.Stage
const FORM := AttackSpec.Form


static func repo() -> ContentRepository:
	return AttackScenario.repo()


static func tables() -> Array[ItemTable]:
	return ContentCompiler.compile_items(repo())


## The modifier of the shipped card `id` (its first; a trigger card's trigger).
static func card(id: StringName) -> ModifierTable:
	var t := tables()
	return t[AttackScenario.item_index(t, id)].modifiers[0]


static func num(op: int, stage: int, field: StringName, value: float) -> ModifierOp:
	var o := ModifierOp.new()
	o.op = op
	o.stage = stage
	o.field = field
	o.value = value
	return o


static func mod(id: StringName, target: Array, ops: Array[ModifierOp]) -> ModifierTable:
	var m := ModifierTable.new()
	m.id = id
	m.target = PackedStringArray(target)
	m.ops = ops
	return m


## A synthetic Big Shot (WAND.md G1): × 2 size, × 1.6 damage on every attack.
static func big() -> ModifierTable:
	return mod(
		&"big",
		[],
		[
			num(OP.MUL_PERMILLE, STAGE.SCALE, &"radius_m", 2000),
			num(OP.MUL_PERMILLE, STAGE.SCALE, &"reach_m", 2000),
			num(OP.MUL_PERMILLE, STAGE.PAYLOAD, &"damage", 1600),
		]
	)


## A synthetic Fire (WAND.md S1): burns 1 stack, ember element.
static func fire() -> ModifierTable:
	var st := ModifierOp.new()
	st.op = OP.STATUS
	st.stage = STAGE.PAYLOAD
	st.status = &"burn"
	st.stacks = 1
	var el := ModifierOp.new()
	el.op = OP.ELEMENT
	el.stage = STAGE.PAYLOAD
	el.element = &"ember"
	return mod(&"fire", [], [st, el])


## A synthetic Shock (WAND.md S2's look): the storm element, 1 shock stack.
static func shock() -> ModifierTable:
	var st := ModifierOp.new()
	st.op = OP.STATUS
	st.stage = STAGE.PAYLOAD
	st.status = &"shock"
	st.stacks = 1
	var el := ModifierOp.new()
	el.op = OP.ELEMENT
	el.stage = STAGE.PAYLOAD
	el.element = &"storm"
	return mod(&"shock", [], [st, el])


## A plain world of `weapon` (&"gun", &"blade") for compiling (crit off, the wand table from data).
static func world(weapon: StringName) -> World:
	var r := repo()
	var t := ContentCompiler.compile_player(r.get_def(&"player", &"runner"))
	ContentCompiler.apply_build(t, r.get_def(&"build", weapon))
	t.crit_chance_permille = 0
	var w := World.new(3, t)
	w.set_item_tables(tables())
	w.wand_table = WandCompiler.from_repo(r)
	w.blade_table = BladeCompiler.from_repo(r)  # v0.6.5 WN4
	return w


## The AttackScenario fight on `weapon` holding the cards `ids` (items or ability ids), the wand in exactly that
## order (anything else the build holds, an ability merge's parent, after them).
static func fight(weapon: StringName, ids: Array, heat: bool = true) -> World:
	var base := AttackScenario.world(weapon, [], heat, [])
	var items: Array = []
	var abilities: Array = []
	for id: StringName in ids:
		var k := AttackScenario.item_index(base.item_tables, id)
		if k >= 0:
			items.append(id)
			var t := base.item_tables[k]
			if t.requires_ability >= 0:
				var kind := StringName(
					String(AbilityTable.Kind.keys()[t.requires_ability]).to_lower()
				)
				if not abilities.has(kind) and not ids.has(kind):
					abilities.append(kind)
		else:
			abilities.append(id)
	# The abilities first (a grant stops at a full build; add_item never does), then the items.
	var w := AttackScenario.world(weapon, [], heat, abilities)
	for id: StringName in items:
		w.add_item(AttackScenario.item_index(w.item_tables, id))
	w.wand_table = WandCompiler.from_repo(repo())
	w.blade_table = BladeCompiler.from_repo(repo())  # v0.6.5 WN4
	set_order(w, ids)
	return w


## Puts the cards `ids` first in the wand, in that order (the others keep theirs after them), as a reorder would.
static func set_order(w: World, ids: Array) -> void:
	var out := PackedInt32Array()
	for id: StringName in ids:
		var c := code(w, id)
		if c >= 0 and w.mod_slots.has(c):
			out.append(c)
	for c in w.mod_slots:
		if not out.has(c):
			out.append(c)
	w.mod_slots = out
	Modifiers.invalidate(w)


## The Offers code of card `id` (an item, else an ability), -1 if none.
static func code(w: World, id: StringName) -> int:
	var k := AttackScenario.item_index(w.item_tables, id)
	if k >= 0:
		return k
	for a in w.ability_tables.size():
		if w.ability_tables[a].id == id:
			return Offers.ability_code(a)
	return -1


## Every event of the run's script digested (kind, target, applied amount, effect), and the state hash after.
static func run(w: World, ticks: int) -> Dictionary:
	var h := StateHasher.new()
	var seen := 0
	var effects := {}
	for t in ticks:
		w.step(AttackScenario.frame(t))
		for e in w.events_since(seen):
			seen = e.seq
			h.add_int(e.kind)
			h.add_int(e.target_id)
			h.add_int(e.amount_applied)
			h.add_string(String(e.effect_id))
			if e.kind == SimEvent.Kind.HIT:
				effects[e.effect_id] = int(effects.get(e.effect_id, 0)) + 1
	return {"digest": h.finish_hex(), "hash": w.state_hash(), "hits_by_effect": effects}
