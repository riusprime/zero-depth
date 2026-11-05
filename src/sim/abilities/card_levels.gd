class_name CardLevels
extends RefCounted
## v0.6.5 WN3 (docs/design/WAND.md rule 6: "A duplicate levels up. Taking a card you already hold makes it stronger
## (levels 1–5) and uses no new slot"): the levels of the wand's cards (World.card_levels, by item index). A wand card
## is an item tagged `wand` (ItemTable.tags): the Gun pool G1–G16 (WN3), and the other pools as they ship. While you
## hold one below MAX_LEVEL it stays in the offers (altars, chests, the shop, events, cores; v0.8.0 FL: below the
## floor's level ceiling, LootPacing), and taking it again raises its level instead of taking a slot. Its modifiers
## compile at that level (ModifierTable.at: each op's per_level, Modifiers.build_modifiers). Deterministic; no
## randomness.

const MAX_LEVEL := 5
const TAG := "wand"


## Item `idx` is a wand card (it levels up).
static func is_card(w: World, idx: int) -> bool:
	return idx >= 0 and idx < w.item_tables.size() and w.item_tables[idx].tags.has(TAG)


## v0.9.5 CLV (CARD_LEVELS.md): the most levels item `idx` has: its `level_max` (ItemTable; 0 = MAX_LEVEL). A card of 1
## is offered once and never again while held. 1 for an index that is no item.
static func max_level(w: World, idx: int) -> int:
	if idx < 0 or idx >= w.item_tables.size():
		return 1
	var m := w.item_tables[idx].level_max
	return MAX_LEVEL if m <= 0 else mini(m, MAX_LEVEL)


## v0.10.5 W3-P3 (the progression audit's P3, owner 2026-11-04: "a way of scale the player build further in strength
## so loops feel more difficult but possible to overcome"): overlevels. From loop 2 every wand card's cap rises by
## LootPacingTable.overlevels_per_loop a loop past its own max_level (a Gun form or a one-level card Lv 2 at loop 2,
## Lv 3 at loop 3; an element Lv 4, 5; a Blade card of 5 levels Lv 6, 7). A level past max_level is an overlevel:
## the card's ops stay at max_level and its main number grows by its category's overlevel_permille per overlevel
## (overlevel_permille; ModifierTable.overlevelled, ElementStack.level_permille). No overlevels without a pacing table
## (the labs) nor in loop 1. Old saves load unchanged (their levels are at most max_level).
static func overlevel_room(w: World) -> int:
	var t := w.loot_pacing
	if t == null or w.loop <= 1:
		return 0
	return maxi(0, t.overlevels_per_loop) * (w.loop - 1)


## W3-P3: the highest level item `idx` can reach now: max_level plus this loop's overlevel room (a wand card only).
static func cap(w: World, idx: int) -> int:
	return max_level(w, idx) + (overlevel_room(w) if is_card(w, idx) else 0)


## The level of item `idx` (1 for an item that never levelled, and for one not held). W3-P3: overlevels included (the
## badge, the offers' check); a card's effect reads base_level and overlevels.
static func level(w: World, idx: int) -> int:
	if idx < 0 or idx >= w.card_levels.size() or not w.items_owned.has(idx):
		return 1
	return clampi(w.card_levels[idx], 1, cap(w, idx))  # v0.9.5 CLV: an old save above the cap reads capped


## W3-P3: the level item `idx`'s ops compile at (at most its max_level: Modifiers, the element rows, the catch-up's P).
static func base_level(w: World, idx: int) -> int:
	return mini(level(w, idx), max_level(w, idx))


## W3-P3: item `idx`'s overlevels now (its level past max_level; 0 in loop 1).
static func overlevels(w: World, idx: int) -> int:
	return level(w, idx) - base_level(w, idx)


## W3-P3: what `n` overlevels make item `idx`'s main number, per mille: 1000 + its category's overlevel_permille × n
## (linear, not compounding); 1000 for n <= 0, without a pacing table, or for a category without an entry.
## v0.10.5 W3-P10c: C2 Twin Star makes each step Constellations.TWIN_STAR_OVERLEVEL_MULT times as big.
static func overlevel_permille(w: World, idx: int, n: int) -> int:
	var t := w.loot_pacing
	if n <= 0 or t == null:
		return 1000
	var cat := LootPacing.category(w, idx)
	if cat <= 0 or cat > t.overlevel_permille.size():
		return 1000
	var step := maxi(0, t.overlevel_permille[cat - 1])
	if Constellations.has(w, Constellations.TWIN_STAR):
		step *= Constellations.TWIN_STAR_OVERLEVEL_MULT
	return 1000 + step * n


## W3-P3: item `idx`'s overlevel multiplier now, per mille (the compile's and the forecast's one function).
static func overlevel_now(w: World, idx: int) -> int:
	return overlevel_permille(w, idx, overlevels(w, idx))


## W3-P3: the weapon's damage factor from overlevels, per mille: the product of overlevel_now over the wand's cards
## whose main number is the damage of the attacks they shape (a form's damage, Pierce, Homing, Wide Arc …: no share
## of the hit, ModifierTable.has_share; never an element). PlayerBuild.bolt_permille / melee_permille apply it with
## their carried remainder, so a +15 % step lands exactly on a 5-point shot and on every hit made from it. 1000 in
## loop 1.
static func weapon_overlevel_permille(w: World) -> int:
	if overlevel_room(w) <= 0:
		return 1000
	var pm := 1000
	for code in w.mod_slots:
		if Offers.type_of(code) != Offers.MOD or not is_card(w, code) or overlevels(w, code) <= 0:
			continue
		if (
			LootPacing.category(w, code) == LootPacing.Category.ELEMENT
			or not AttackSlots.compiles(w, code)
		):
			continue
		var share := false
		for m in w.item_tables[code].modifiers:
			share = share or m.has_share()
		if not share:
			pm = pm * overlevel_now(w, code) / 1000
	return pm


## Item `idx` may be offered now: it isn't held, or it is a wand card below the floor's level ceiling (v0.8.0 FL:
## LootPacing.ceiling, MAX_LEVEL without a pacing table), or below `ceiling` when given (at most MAX_LEVEL; the
## boss's upgrade and a jackpot pass a higher one, the dev panel's grants MAX_LEVEL). Every card source's check:
## ItemPool.available, Shop.can_apply (the shop, an event's cards, a core's drop).
## v0.10.5 W3-P2: an element card also stays below its own ceiling (LootPacing.element_ceiling: this floor's, or
## `element_ceiling` when given: the next floor's for the boss's upgrade, one past for a jackpot; a `ceiling` given
## alone holds for elements too: the dev panel's MAX_LEVEL grant).
static func can_take(w: World, idx: int, ceiling: int = -1, element_ceiling: int = -1) -> bool:
	if not w.items_owned.has(idx):
		return true
	return is_card(w, idx) and level(w, idx) < offer_cap(w, idx, ceiling, element_ceiling)


## The level held item `idx` is offered up to (can_take's arguments): the stage's ceiling (or `ceiling`) and an
## element's own, under its max_level; W3-P3: once that reaches max_level, its cap with this loop's overlevels (cap).
static func offer_cap(w: World, idx: int, ceiling: int = -1, element_ceiling: int = -1) -> int:
	var top := mini(ceiling if ceiling > 0 else LootPacing.ceiling(w), max_level(w, idx))
	if LootPacing.category(w, idx) == LootPacing.Category.ELEMENT:
		var el := element_ceiling
		if el <= 0:
			el = ceiling if ceiling > 0 else LootPacing.element_ceiling(w)
		top = mini(top, el)
	return cap(w, idx) if top >= max_level(w, idx) else top


## A held wand card taken again: one level up (at most MAX_LEVEL); the build compiles again. False if `idx` isn't a
## held wand card below MAX_LEVEL.
static func level_up(w: World, idx: int) -> bool:
	if not w.items_owned.has(idx) or not is_card(w, idx) or level(w, idx) >= cap(w, idx):
		return false
	_store(w, idx, level_after(w, idx))
	Modifiers.invalidate(w)
	return true


## v0.8.0 N8: the level item `idx` has after it is taken once more: 1 when not held, one up for a held wand card
## below MAX_LEVEL, else its level (level_up's step, and the pick card's forecast: CardForecast). Pure.
static func level_after(w: World, idx: int) -> int:
	if not w.items_owned.has(idx):
		return 1
	return mini(level(w, idx) + 1, cap(w, idx)) if is_card(w, idx) else level(w, idx)  # W3-P3: to its cap


## Sets held wand card `idx` to `lvl` (1..cap: W3-P3, overlevels included; the dev panel's TEST HELPER and the labs).
## False if `idx` isn't a held wand card.
static func set_level(w: World, idx: int, lvl: int) -> bool:
	if not w.items_owned.has(idx) or not is_card(w, idx):
		return false
	_store(w, idx, clampi(lvl, 1, cap(w, idx)))
	Modifiers.invalidate(w)
	return true


## Item `idx` enters the build fresh (or leaves it): back to level 1.
static func reset(w: World, idx: int) -> void:
	if idx >= 0 and idx < w.card_levels.size() and w.card_levels[idx] > 1:
		w.card_levels[idx] = 0
		Modifiers.invalidate(w)


static func _store(w: World, idx: int, v: int) -> void:
	if w.card_levels.size() <= idx:
		w.card_levels.resize(maxi(idx + 1, w.item_tables.size()))  # a packed resize fills with 0
	w.card_levels[idx] = v


## Hashed once a card levelled (BuildSlots.hash_into).
static func hash_into(w: World, h: StateHasher) -> void:
	if not w.card_levels.is_empty():
		h.add_ints(w.card_levels)
