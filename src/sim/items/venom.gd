class_name Venom
extends RefCounted
## v0.6.0 MX4 (M4 Venom Core: "Hits stack poison that spreads on death"): the poison engine, beside the v0.3.0 ones
## (Engines). A hit whose spec feeds &"poison" adds stacks (capped at poison_max_stacks, each new stack refreshing
## poison_ticks); every poison_period_ticks a poisoned enemy takes poison_damage × stacks as DoT (its own root, proc 0,
## never a HIT: it can't set off on-hit effects); when a poisoned enemy dies, its stacks spread to every enemy within
## poison_spread_m (once per enemy per dying root). The numbers are the strongest owned (ItemMods, Venom Core's
## card). No randomness. The actor columns are hashed with the modifier engine's state (ModifierRuntime.hash_into).

const EFFECT_POISON := &"venom"
const EFFECT_SPREAD := &"venom_spread"
## ProcLedger code of a spread (after the hook feeds' codes; appended, never renumbered).
const CODE_SPREAD := 70


## Adds `n` poison stacks to enemy `i` (capped, refreshed), from root `root`.
static func add(w: World, i: int, n: int, root: int) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.poison_max_stacks <= 0 or a.dead[i] == 1 or n <= 0 or i == 0:
		return
	if a.poison_stacks[i] == 0:
		a.poison_cd[i] = m.poison_period_ticks
	a.poison_stacks[i] = mini(a.poison_stacks[i] + n, m.poison_max_stacks)
	a.poison_t[i] = m.poison_ticks
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, a.ids[0], a.ids[0], a.ids[i], a.pos(i))
	e.root_id = root
	e.amount = a.poison_stacks[i]
	e.effect_id = EFFECT_POISON


## Tick phase 8: each poisoned enemy's DoT, then its stacks run out.
static func tick(w: World) -> void:
	var a := w.actors
	var m := w.item_mods
	if m.poison_max_stacks <= 0:
		return
	for i in range(1, a.size()):
		if a.poison_stacks[i] == 0:
			continue
		a.poison_t[i] -= 1
		a.poison_cd[i] -= 1
		if a.poison_cd[i] <= 0:
			a.poison_cd[i] = m.poison_period_ticks
			Damage.tick_dot(
				w, i, m.poison_damage * a.poison_stacks[i], a.ids[0], a.ids[0], EFFECT_POISON
			)
		if a.poison_t[i] <= 0:
			a.poison_stacks[i] = 0
			a.poison_cd[i] = 0


## Enemy `i` died (Damage._apply, a kill the player owns) under root `root`: its poison spreads.
static func on_kill(w: World, i: int, root: int) -> void:
	var a := w.actors
	var m := w.item_mods
	var n := a.poison_stacks[i] if i < a.poison_stacks.size() else 0
	if n <= 0 or m.poison_spread_m <= 0.0:
		return
	var at := a.pos(i)
	for j in w.enemies_near(at, m.poison_spread_m):
		if j == i or not w.proc_ledger.try_mark(root, CODE_SPREAD, a.ids[j], w.tick):
			continue
		add(w, j, n, root)


## The poison columns (ModifierRuntime.hash_into), once the engine runs.
static func hash_into(w: World, h: StateHasher) -> void:
	if w.item_mods.poison_max_stacks > 0:
		w.actors.hash_venom(h)
