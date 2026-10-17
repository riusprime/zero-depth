class_name BossReward
extends RefCounted
## The boss's reward (v0.5.5 AR; owner X1: "we are also missing a big reward from killing the boss", X1b: "Pick a
## legendary card"). Tick phase 9, after the boss flow: the tick the floor's boss dies (BossFlow.opened_tick), a
## legendary altar (RewardStore.Kind.LEGENDARY, free) appears where the boss rose (FloorLayout.boss_spawn, a clear
## spot). Opening it offers a pick of 3 from the legendary tier only (Offers.roll_legendary, the loot stream); a
## cancel keeps it for later like any altar. One per floor (World.legendary_id stays set after the pick). No
## legendary table, no altar. v0.8.0 RR (owner O33, "Infinite loops should eventually allow players to accumulate
## extremely powerful combinations"): on loop L the altar gives LegendaryTable.extra_picks(L) more picks: after a
## pick it stays, its offer cleared, and the next open rolls a fresh one (its own Legendary chance).


static func advance(w: World) -> void:
	if w.legendary_table == null or w.legendary_id != -1 or w.boss_flow == null:
		return
	if w.boss_flow.opened_tick < 0 or w.floor_layout == null or w.floor_layout.boss_room < 0:
		return
	w.legendary_id = w.add_reward(RewardStore.Kind.LEGENDARY, w.floor_layout.boss_spawn, 0)
	w.legendary_picks = w.legendary_table.extra_picks(w.loop)  # v0.8.0 RR


## v0.8.0 RR: a card was just taken from reward i. True when it is the legendary altar with picks left: one is used,
## the offer is cleared (its other cards back in the pool) and the altar stays for the next open (Rewards.choose then
## keeps it). No draw.
static func another_pick(w: World, i: int) -> bool:
	if not is_legendary(w, i) or w.legendary_picks <= 0:
		return false
	w.legendary_picks -= 1
	w.rewards.set_offer(i, PackedInt32Array())
	w.rewards.rolled[i] = 0
	return true


static func is_legendary(w: World, i: int) -> bool:
	return w.rewards.kind[i] == RewardStore.Kind.LEGENDARY


## v0.6.5 WN5b (WAND.md: "The legendary tier offers level-5 versions"): card `code` was just taken from reward i. On
## the legendary altar a wand card goes to the tier's wand_level (a held one rises to it; never down).
static func on_pick(w: World, i: int, code: int) -> void:
	var t := w.legendary_table
	if t == null or t.wand_level <= 0 or not is_legendary(w, i):
		return
	if Offers.type_of(code) != Offers.MOD or not CardLevels.is_card(w, code):
		return
	if CardLevels.level(w, code) < t.wand_level:
		CardLevels.set_level(w, code, level_after(w, i, code, CardLevels.level(w, code)))


## v0.8.0 N8: the level wand card `code` ends at when taken from reward i with `lvl` after the take: the tier's
## wand_level on the legendary altar (never down), else `lvl` (on_pick's rule, and CardForecast's). Pure.
static func level_after(w: World, i: int, code: int, lvl: int) -> int:
	var t := w.legendary_table
	if t == null or t.wand_level <= 0 or i < 0 or not is_legendary(w, i):
		return lvl
	if Offers.type_of(code) != Offers.MOD or not CardLevels.is_card(w, code):
		return lvl
	return maxi(lvl, t.wand_level)
