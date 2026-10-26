class_name ElementLevels
extends RefCounted
## v0.9.5 EE1 (ELEMENTS.md E1, E2; the owner: "each element should have its own reward system for levelling"): what the
## Venom card (Gun) and the Bleed card (both weapons) do at their levels. Lv 1 is the engine as it was. Venom Lv 2,
## Contagion: every el_jump_ticks a poisoned enemy passes its poison to the nearest unpoisoned enemy in range, the whole
## room at most one jump per el_jump_gap_ticks (4 a second: a tick that is a multiple of the gap, so no counter to
## save); Lv 3, Virulence: stacks cap at el_stack_cap, each adds el_stack_bonus_permille to a tick, a jump passes one.
## Bleed Lv 2, Open wounds: a tick on an enemy that moved over el_wound_move_mm since its last tick deals
## el_wound_bonus_permille more; Lv 3, Exsanguinate: stacks cap at el_stack_cap, and the el_burst_stacks-th stack
## deals at once every tick its stacks would still deal and ends the bleed. Integers and the sim clock only. The
## numbers are the card's (ItemDefinition el_*). The columns (ActorStore.ELEMENT_FIELDS) are hashed and saved only while
## a card runs at Lv 2 or more.

const LV_SPREAD := 2  # Contagion, Open wounds
const LV_STACK := 3  # Virulence, Exsanguinate
const EFFECT_JUMP := SimEvent.EFFECT_VENOM_JUMP
const EFFECT_EXSANGUINATE := SimEvent.EFFECT_EXSANGUINATE
const MM := 1000


## The owned wand card whose table `poison` (Venom) or bleed (else) engine runs, or null.
static func card(w: World, venom: bool) -> ItemTable:
	for idx in w.items_owned:
		var t := w.item_tables[idx]
		if (
			(t.poison_max_stacks if venom else t.bleed_max_stacks) > 0
			and CardLevels.is_card(w, idx)
		):
			return t
	return null


## The held Venom (or Bleed) card's level, 1 without one.
static func level(w: World, venom: bool) -> int:
	for idx in w.items_owned:
		var t := w.item_tables[idx]
		if (
			(t.poison_max_stacks if venom else t.bleed_max_stacks) > 0
			and CardLevels.is_card(w, idx)
		):
			return CardLevels.level(w, idx)
	return 1


## Some element card runs at Lv 2 or more (its columns are in the hash).
static func active(w: World) -> bool:
	return level(w, true) >= LV_SPREAD or level(w, false) >= LV_SPREAD


## The poison stack cap now: the engine's, or Virulence's.
static func poison_cap(w: World) -> int:
	var cap := w.item_mods.poison_max_stacks
	if level(w, true) >= LV_STACK:
		cap = mini(cap, card(w, true).el_stack_cap)
	return cap


## The bleed stack cap now: the engine's, or Exsanguinate's.
static func bleed_cap(w: World) -> int:
	var cap := w.item_mods.bleed_max_stacks
	if level(w, false) >= LV_STACK:
		cap = mini(cap, card(w, false).el_stack_cap)
	return cap


## A poison tick's damage: `base` (damage × stacks) with Virulence's +bonus per stack past the first.
static func poison_tick(w: World, base: int, stacks: int) -> int:
	if level(w, true) < LV_STACK:
		return base
	var t := card(w, true)
	return (base * (1000 + t.el_stack_bonus_permille * (stacks - 1)) + 500) / 1000


## The columns that follow an enemy whose poison starts: its next jump.
static func on_poison_start(w: World, i: int) -> void:
	var t := card(w, true)
	w.actors.poison_jump_cd[i] = t.el_jump_ticks if t != null else 0


## The columns that follow an enemy whose bleed starts: where it stands.
static func on_bleed_start(w: World, i: int) -> void:
	var a := w.actors
	a.bleed_x[i] = roundi(a.pos_x[i] * MM)
	a.bleed_y[i] = roundi(a.pos_y[i] * MM)


## Open wounds: a bleed tick's damage `base` for enemy `i`; its place is kept for the next tick.
static func bleed_tick(w: World, i: int, base: int) -> int:
	var lvl := level(w, false)
	if lvl < LV_SPREAD:
		return base
	var a := w.actors
	var t := card(w, false)
	var x := roundi(a.pos_x[i] * MM)
	var y := roundi(a.pos_y[i] * MM)
	var dx := x - a.bleed_x[i]
	var dy := y - a.bleed_y[i]
	a.bleed_x[i] = x
	a.bleed_y[i] = y
	if dx * dx + dy * dy <= t.el_wound_move_mm * t.el_wound_move_mm:
		return base
	return (base * (1000 + t.el_wound_bonus_permille) + 500) / 1000


## Contagion (tick phase 8, after the poison ticks): the giver timers run; on a gap tick the lowest-id ready giver
## passes its poison to the nearest unpoisoned enemy in range (ties: the lower id).
static func tick_contagion(w: World) -> void:
	if level(w, true) < LV_SPREAD:
		return
	var a := w.actors
	var t := card(w, true)
	var gap := t.el_jump_gap_ticks
	var giver := -1
	for i in range(1, a.size()):
		if a.poison_stacks[i] == 0 or a.dead[i] == 1:
			continue
		a.poison_jump_cd[i] = maxi(0, a.poison_jump_cd[i] - 1)
		if giver < 0 and a.poison_jump_cd[i] == 0 and gap > 0 and w.tick % gap == 0:
			giver = i
	if giver < 0:
		return
	var at := a.pos(giver)
	var best := -1
	var best_d := INF
	for j in w.enemies_near(at, t.el_jump_range_m):
		if j == giver or a.poison_stacks[j] > 0 or a.dead[j] == 1:
			continue
		var d := Kin.length(a.pos(j) - at)
		if d < best_d or (d == best_d and j < best):
			best = j
			best_d = d
	a.poison_jump_cd[giver] = t.el_jump_ticks  # it tried: the next try is a period away
	if best < 0:
		return
	var n := 1 if level(w, true) >= LV_STACK else a.poison_stacks[giver]
	var root := w.take_root()
	Venom.add(w, best, n, root)
	var e := w.emit_event(
		SimEvent.Kind.STATUS_APPLY, a.ids[giver], a.ids[0], a.ids[best], a.pos(best)
	)
	e.root_id = root
	e.amount = a.poison_stacks[best]
	e.effect_id = EFFECT_JUMP


## Exsanguinate: bleed stack just landed on `i` (already counted). At the burst count the enemy takes every tick its
## stacks would still deal, now, and the bleed ends. `period` is the bleed's period; `damage` its tick damage per stack.
static func exsanguinate(w: World, i: int, period: int) -> void:
	if level(w, false) < LV_STACK:
		return
	var a := w.actors
	var t := card(w, false)
	if a.bleed_stacks[i] < t.el_burst_stacks or a.dead[i] == 1:
		return
	var ticks := 0
	if a.bleed_t[i] >= a.bleed_cd[i]:
		ticks = 1 + (a.bleed_t[i] - a.bleed_cd[i]) / period
	var dmg := w.item_mods.bleed_damage * a.bleed_stacks[i] * ticks
	a.bleed_stacks[i] = 0
	a.bleed_t[i] = 0
	a.bleed_cd[i] = 0
	if dmg > 0:
		Damage.tick_dot(w, i, dmg, a.ids[0], a.ids[0], EFFECT_EXSANGUINATE)


## The element columns (Venom.hash_into): hashed only while a card runs at Lv 2 or more.
static func hash_into(w: World, h: StateHasher) -> void:
	if active(w):
		w.actors.hash_element(h)
