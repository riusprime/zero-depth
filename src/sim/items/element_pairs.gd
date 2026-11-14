class_name ElementPairs
extends RefCounted
## v0.9.5 EE3 (ELEMENTS.md X1-X10; the owner: "maybe we could add some special combinations so something else happens
## when you have 2 level 3 elements they do something special"): two elements held together turn on one named pair
## rule (from Lv 1; the pair's level is the lower of the two elements' levels, and its strength scales by
## table.level_permille: 40 / 70 / 100 % of the Lv 3 bonus; a chain pair acts on its first `level` jumps below Lv 3).
## The elements are Fire (ember_core), Lightning (storm_core), Frost (frost_core), Venom (venom_core) and
## Bleed (shared_bleed); the Gun has two element slots, so on a Gun run one pair is on at most (the mask allows more for
## a Blade run). The mask is worked out when the wand compiles (Modifiers.compile) and a pair turning on emits PAIR_ON
## (the view's banner). The numbers are the table's (data/combos/element_pairs.tres, World.pair_table: none, no pairs).
## X1 Thermal Shock (Fire+Frost): a hero hit on a burning and frozen enemy ends both and bursts. X2 Toxic Fumes
## (Fire+Venom): a poisoned enemy catching fire leaves a poison cloud. X3 Ignition Arc (Fire+Lightning), X8 Neurotoxin
## (Lightning+Venom), X9 Arterial Arc (Lightning+Bleed): a chain jump burns, poisons or bleeds. X4 Boiling Blood
## (Fire+Bleed): bleed ticks on a burning enemy are doubled. X5 Cold Circuit (Frost+Lightning): a chain jumps to frozen
## enemies first and hits them harder. X6 Black Ice (Frost+Venom): poisoned enemies are slower, and frozen they keep
## their poison. X7 Brittle (Frost+Bleed): a frozen enemy shattered or killed bursts its remaining bleed. X10 Sepsis
## (Venom+Bleed): an enemy deep in both takes more from the hero.
## Budget: the rules that do work (a burst, a cloud, a status on a jump) fire at most triggers_per_second times a second
## each (pair_log, the EE2 pattern); the rules that only change a number (X4, X5's damage, X6, X10) cost nothing to
## repeat and are not counted. No new particle system: the view reuses the effects layer's bursts and a flat quad per
## cloud. Integers and the sim clock only. State (mask, log, clouds, the actors' gas_cd) is saved, and hashed only while
## a pair is on.

const FIRE := ElementLevelsFsf.FIRE
const STORM := ElementLevelsFsf.STORM
const FROST := ElementLevelsFsf.FROST
const VENOM := 3
const BLEED := 4
const WINDOW := 60  # a budget's "second", in ticks
const COUNT := 10
const X1 := 0
const X2 := 1
const X3 := 2
const X4 := 3
const X5 := 4
const X6 := 5
const X7 := 6
const X8 := 7
const X9 := 8
const X10 := 9
## The pairs' ids (their text keys are PAIR_<ID> and PAIR_<ID>_DESC), in X order.
const IDS: Array[StringName] = [
	&"thermal_shock",
	&"toxic_fumes",
	&"ignition_arc",
	&"boiling_blood",
	&"cold_circuit",
	&"black_ice",
	&"brittle",
	&"neurotoxin",
	&"arterial_arc",
	&"sepsis",
]
## The element cards, by element code (the banner's two icons).
const CARDS: Array[StringName] = [
	&"ember_core", &"storm_core", &"frost_core", &"venom_core", &"shared_bleed"
]
## Each pair's two elements, in X order.
const ELEMENTS: Array[Array] = [
	[FIRE, FROST],
	[FIRE, VENOM],
	[FIRE, STORM],
	[FIRE, BLEED],
	[FROST, STORM],
	[FROST, VENOM],
	[FROST, BLEED],
	[STORM, VENOM],
	[STORM, BLEED],
	[VENOM, BLEED],
]
const CLOUD_CAP := 16  # live clouds (the budget keeps it near 12)
const CLOUD_PULSE := 5  # a cloud looks for enemies every this many ticks


# --- Which pairs are on ----------------------------------------------------------------------------------------
## The held element's level, 1 without one.
static func element_level(w: World, e: int) -> int:
	match e:
		VENOM:
			return ElementLevels.level(w, true)
		BLEED:
			return ElementLevels.level(w, false)
	return ElementLevelsFsf.level(w, e)


## Element `e` is held (a card of it is in the build).
static func held_element(w: World, e: int) -> bool:
	match e:
		VENOM:
			return ElementLevels.held(w, true)
		BLEED:
			return ElementLevels.held(w, false)
	return ElementLevelsFsf.held(w, e)


## The pairs whose two elements are both held now, at any level (bit X each); 0 without the table.
static func mask(w: World) -> int:
	if w.pair_table == null:
		return 0
	var held := PackedInt32Array()
	for e in 5:
		held.append(1 if held_element(w, e) else 0)
	var m := 0
	for x in COUNT:
		if held[ELEMENTS[x][0]] == 1 and held[ELEMENTS[x][1]] == 1:
			m |= 1 << x
	return m


## Each on pair's level (the lower of its elements' levels, 1-3) in 2 bits at 2*X; 0 without the table.
static func levels(w: World) -> int:
	if w.pair_table == null:
		return 0
	var m := mask(w)
	var out := 0
	for x in COUNT:
		if (m >> x) & 1 == 1:
			var lv := mini(element_level(w, ELEMENTS[x][0]), element_level(w, ELEMENTS[x][1]))
			out |= clampi(lv, 1, 3) << (2 * x)
	return out


## Pair `x` is on (worked out at the last compile; a world whose wand has not compiled yet compiles it first).
static func on(w: World, x: int) -> bool:
	if w.pair_table == null:
		return false
	if w.attack_book == null:
		Modifiers.book(w)
	return (w.pair_mask >> x) & 1 == 1


## Pair `x`'s level 1-3 now: 0 while off; an older save's pair (no saved level) reads as Lv 3.
static func level(w: World, x: int) -> int:
	if not on(w, x):
		return 0
	var lv := (w.pair_levels >> (2 * x)) & 3
	return 3 if lv == 0 else lv


## Pair `x`'s strength, per mille of its Lv 3 bonus (1000 while off).
static func scale(w: World, x: int) -> int:
	var lv := level(w, x)
	return w.pair_table.level_permille[lv - 1] if lv > 0 else 1000


## A multiplier `m` per mille (1000 = none) grown by pair `x`'s level: Lv 3 is `m`, lower levels a share of its extra.
static func bonus(w: World, x: int, m: int) -> int:
	return 1000 + (m - 1000) * scale(w, x) / 1000


## The pairs that taking item `idx` would turn on or raise, flat [x, new_level,...] (the offer card's
## line). Empty for a card that is not an element card or that changes no pair. Slot limits and swaps are ignored.
static func preview(w: World, idx: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if w.pair_table == null or idx < 0 or idx >= w.item_tables.size():
		return out
	var own := CARDS.find(w.item_tables[idx].id)
	if own < 0:
		return out
	var lv := PackedInt32Array()
	for e in 5:
		lv.append(element_level(w, e) if held_element(w, e) else 0)
	lv[own] = mini(lv[own] + 1, 3) if lv[own] > 0 else 1
	for x in COUNT:
		var a: int = ELEMENTS[x][0]
		var b: int = ELEMENTS[x][1]
		if a != own and b != own:
			continue
		if lv[a] <= 0 or lv[b] <= 0:
			continue
		var nl := clampi(mini(lv[a], lv[b]), 1, 3)
		if nl > level(w, x):
			out.append(x)
			out.append(nl)
	return out


## The wand compiled (Modifiers.compile): the mask and levels follow the cards, a pair that just turned on or grew a
## level is announced (amount_applied: its level), and a pair that turned off takes its clouds with it.
static func refresh(w: World) -> void:
	var now := mask(w)
	var lv := levels(w)
	var old_mask := w.pair_mask
	var old_levels := w.pair_levels
	w.pair_mask = now
	w.pair_levels = lv
	if (now >> X2) & 1 == 0:
		w.pair_clouds = PackedInt32Array()
	if now == 0 or w.actors.size() == 0:
		return
	var pid := w.actors.ids[0]
	for x in COUNT:
		if (now >> x) & 1 == 0:
			continue
		var was := (old_levels >> (2 * x)) & 3
		if was == 0:
			was = 3 if (old_mask >> x) & 1 == 1 else 0
		var nl := (lv >> (2 * x)) & 3
		if nl > was:
			var e := w.emit_event(SimEvent.Kind.PAIR_ON, pid, pid, pid, w.player_pos())
			e.amount = x
			e.effect_id = IDS[x]
			e.amount_applied = nl


# --- The budget ------------------------------------------------------------------------------------------------
## One more firing of pair `x` fits in the last second: the log forgets older ones; true (and counted) if fewer than
## triggers_per_second fired.
static func _room(w: World, x: int) -> bool:
	var keep := PackedInt32Array()
	var n := 0
	for k in range(0, w.pair_log.size(), 2):
		if w.pair_log[k + 1] > w.tick - WINDOW:
			keep.append(w.pair_log[k])
			keep.append(w.pair_log[k + 1])
			if w.pair_log[k] == x:
				n += 1
	var ok := n < w.pair_table.triggers_per_second
	if ok:
		keep.append(x)
		keep.append(w.tick)
	w.pair_log = keep
	return ok


# --- X1 Thermal Shock, X7 Brittle: bursts ----------------------------------------------------------------------
## Damage.hit, after a landed hero hit of `dmg` on `target` that found it burning and frozen (read before the hit's own
## statuses landed): Thermal Shock.
static func thermal_shock(
	w: World, target: int, dmg: int, tags: int, effect_id: StringName
) -> void:
	var a := w.actors
	if not on(w, X1):
		return
	if (
		tags & (SimEvent.TAG_DOT | SimEvent.TAG_SHRAPNEL)
		or effect_id == SimEvent.EFFECT_PAIR_BURST
		or effect_id == SimEvent.EFFECT_FROST_SHARD
		or not _room(w, X1)
	):
		return
	var t := w.pair_table
	a.burn_stacks[target] = 0
	a.burn_t[target] = 0
	a.burn_cd[target] = 0
	a.frost_stacks[target] = 0
	a.frost_t[target] = 0
	a.frozen_t[target] = 0
	var at := a.pos(target)
	var pid := a.ids[0]
	var root := w.take_root()
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, a.ids[target], at)
	e.root_id = root
	e.amount = roundi(t.burst_radius_m * 1000.0)
	e.effect_id = SimEvent.EFFECT_PAIR_BURST
	var burst := maxi(1, dmg * bonus(w, X1, t.burst_permille) / 1000)
	for j in w.enemies_near(at, t.burst_radius_m):
		Damage.hit(
			w,
			j,
			burst,
			pid,
			pid,
			root,
			SimEvent.TAG_AREA,
			at,
			a.pos(j),
			SimEvent.EFFECT_PAIR_BURST,
			50
		)


## Brittle: frozen enemy `i` is shattered or has died (Damage._apply, ElementLevelsFsf.shatter): the bleed it still had
## to take bursts on the enemies within brittle_radius_m, split evenly, and its bleed ends.
static func on_frozen_end(w: World, i: int) -> void:
	var a := w.actors
	if a.bleed_stacks[i] <= 0 or not on(w, X7) or not _room(w, X7):
		return
	var m := w.item_mods
	var period := Engines.bleed_period(w)
	var ticks := 0
	if a.bleed_t[i] >= a.bleed_cd[i]:
		ticks = 1 + (a.bleed_t[i] - a.bleed_cd[i]) / period
	var total := m.bleed_damage * a.bleed_stacks[i] * ticks
	total = total * scale(w, X7) / 1000
	a.bleed_stacks[i] = 0
	a.bleed_t[i] = 0
	a.bleed_cd[i] = 0
	var at := a.pos(i)
	var near := PackedInt32Array()
	for j in w.enemies_near(at, w.pair_table.brittle_radius_m):
		if j != i:
			near.append(j)
	if total <= 0 or near.is_empty():
		return
	var pid := a.ids[0]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, a.ids[i], at)
	e.amount = roundi(w.pair_table.brittle_radius_m * 1000.0)
	e.effect_id = SimEvent.EFFECT_PAIR_BURST
	var share := maxi(1, total / near.size())
	for j in near:
		Damage.tick_dot(w, j, share, pid, pid, SimEvent.EFFECT_PAIR_BURST)


# --- X2 Toxic Fumes --------------------------------------------------------------------------------------------
## Enemy `i` has just caught fire (Engines.add_burn, ItemEffects.on_melee_hit: its burn was 0 before): a poisoned one
## leaves a gas cloud where it stands.
static func on_burn_start(w: World, i: int) -> void:
	if w.pair_table == null or w.actors.poison_stacks[i] <= 0 or not on(w, X2) or not _room(w, X2):
		return
	var a := w.actors
	var t := w.pair_table
	var clouds := w.pair_clouds
	if clouds.size() >= CLOUD_CAP * 3:  # the oldest goes
		clouds = clouds.slice(3)
	clouds.append(roundi(a.pos_x[i] * 1000.0))
	clouds.append(roundi(a.pos_y[i] * 1000.0))
	clouds.append(maxi(1, t.cloud_ticks * scale(w, X2) / 1000))
	w.pair_clouds = clouds
	var pid := a.ids[0]
	var e := w.emit_event(SimEvent.Kind.STATUS_APPLY, pid, pid, a.ids[i], a.pos(i))
	e.amount = roundi(t.cloud_radius_m * 1000.0)
	e.effect_id = SimEvent.EFFECT_PAIR_CLOUD


## Tick phase 8 (Venom.tick): the clouds age, and every CLOUD_PULSE ticks each poisons the enemies in it whose gas clock
## is spent (cloud_stacks stacks, then a cloud_gap_ticks wait for that enemy).
static func tick(w: World) -> void:
	if w.pair_table == null or w.pair_mask == 0:
		return
	var a := w.actors
	for i in range(1, a.size()):
		if a.gas_cd[i] > 0:
			a.gas_cd[i] -= 1
	if w.pair_clouds.is_empty():
		return
	var t := w.pair_table
	var pulse := w.tick % CLOUD_PULSE == 0
	var left := PackedInt32Array()
	for k in range(0, w.pair_clouds.size(), 3):
		var ticks := w.pair_clouds[k + 2] - 1
		if ticks <= 0:
			continue
		left.append(w.pair_clouds[k])
		left.append(w.pair_clouds[k + 1])
		left.append(ticks)
		if not pulse:
			continue
		var centre := Vector2(w.pair_clouds[k] / 1000.0, w.pair_clouds[k + 1] / 1000.0)
		for j in w.enemies_near(centre, t.cloud_radius_m):
			if a.gas_cd[j] > 0:
				continue
			a.gas_cd[j] = t.cloud_gap_ticks
			Venom.add(w, j, t.cloud_stacks, w.take_root())
	w.pair_clouds = left


# --- X3, X5, X8, X9: the chain ---------------------------------------------------------------------------------
## Cold Circuit (Attacks._chain): the next jump from `from` goes to the nearest frozen enemy within `reach` that `hit`
## doesn't hold yet, or -1 (the plain nearest jump then runs).
static func frozen_target(w: World, from: Vector2, reach: float, hit: PackedInt32Array) -> int:
	if not on(w, X5):
		return -1
	var a := w.actors
	var best := -1
	var best_d := reach
	for j in w.enemies_near(from, reach):
		if hit.has(j) or a.frozen_t[j] <= 0:
			continue
		var d := Kin.length(a.pos(j) - from)
		if d <= best_d and (best < 0 or d < best_d):
			best = j
			best_d = d
	return best


## Cold Circuit: the damage of a jump onto enemy `j`, `damage` plain.
static func jump_damage(w: World, j: int, damage: int) -> int:
	if w.actors.frozen_t[j] > 0 and on(w, X5):
		return damage * bonus(w, X5, w.pair_table.circuit_permille) / 1000
	return damage


## A chain jump landed on enemy `j` (Attacks._chain, root `root`): Ignition Arc burns, Neurotoxin poisons, Arterial Arc
## bleeds it; each rule within its own budget. `n` is the jump's 0-based index in its chain: a pair below Lv 3 acts on
## its first `level` jumps only.
static func on_jump(w: World, j: int, root: int, n: int) -> void:
	if w.pair_table == null or w.pair_mask == 0 or w.actors.dead[j] == 1:
		return
	var t := w.pair_table
	if on(w, X3) and _jumps(w, X3, n) and _room(w, X3):
		Engines.add_burn(w, j, t.arc_burn_stacks, root, &"ignition_arc")
	if on(w, X8) and _jumps(w, X8, n) and _room(w, X8):
		Venom.add(w, j, t.arc_poison_stacks, root)
	if on(w, X9) and _jumps(w, X9, n) and _room(w, X9):
		Engines.add_bleed(w, j, t.arc_bleed_stacks, root)


## Pair `x` acts on chain jump `n` (0-based): every jump at Lv 3, else the first `level` jumps.
static func _jumps(w: World, x: int, n: int) -> bool:
	var lv := level(w, x)
	return lv >= 3 or n < lv


# --- Numbers: X4, X6, X10 --------------------------------------------------------------------------------------
## Boiling Blood: a bleed tick `base` on enemy `i`.
static func bleed_tick(w: World, i: int, base: int) -> int:
	if w.actors.burn_stacks[i] > 0 and on(w, X4):
		return base * bonus(w, X4, w.pair_table.boil_permille) / 1000
	return base


## Black Ice: enemy `i`'s speed factor (1000 = unchanged).
static func slow_permille(w: World, i: int) -> int:
	if w.actors.poison_stacks[i] > 0 and on(w, X6):
		return 1000 - w.pair_table.ice_slow_permille * scale(w, X6) / 1000
	return 1000


## Black Ice: a frozen poisoned enemy's poison doesn't run down.
static func poison_holds(w: World, i: int) -> bool:
	return w.actors.frozen_t[i] > 0 and w.actors.poison_stacks[i] > 0 and on(w, X6)


## Sepsis: the hero's hit (or tick) on enemy `target`, per mille.
static func attacker_mult(w: World, target: int, owner_id: int) -> int:
	var a := w.actors
	if target == 0 or w.pair_mask == 0 or owner_id != a.ids[0]:
		return 1000
	var t := w.pair_table
	if (
		a.poison_stacks[target] >= t.sepsis_stacks
		and a.bleed_stacks[target] >= t.sepsis_stacks
		and on(w, X10)
	):
		return bonus(w, X10, t.sepsis_permille)
	return 1000


## The state (ModifierRuntime.hash_into): hashed only while a pair is on.
static func hash_into(w: World, h: StateHasher) -> void:
	if w.pair_mask == 0:
		return
	h.add_int(w.pair_mask)
	h.add_int(w.pair_levels)
	h.add_ints(w.pair_log)
	h.add_ints(w.pair_clouds)
	w.actors.hash_pair(h)


# --- Text and cards (the view reads these through WorldReader) --------------------------------------------------
## Pair `x`'s name and one-line text keys.
static func name_key(x: int) -> StringName:
	return StringName("PAIR_" + String(IDS[x]).to_upper())


static func desc_key(x: int) -> StringName:
	return StringName("PAIR_" + String(IDS[x]).to_upper() + "_DESC")


## The two element cards of pair `x` (the banner's two icons).
static func card_ids(x: int) -> Array[StringName]:
	return [CARDS[ELEMENTS[x][0]], CARDS[ELEMENTS[x][1]]]
