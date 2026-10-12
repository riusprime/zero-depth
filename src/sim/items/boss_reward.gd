class_name BossReward
extends RefCounted
## The boss's reward (v0.5.5 AR; owner X1: "we are also missing a big reward from killing the boss", X1b: "Pick a
## legendary card"). Tick phase 9, after the boss flow: the tick the floor's boss dies (BossFlow.opened_tick), a
## legendary altar (RewardStore.Kind.LEGENDARY, free) appears where the boss rose (FloorLayout.boss_spawn, a clear
## spot). Opening it offers a pick of 3 from the legendary tier only (Offers.roll_legendary, the loot stream); a
## cancel keeps it for later like any altar. One per floor (World.legendary_id stays set after the pick). No
## legendary table, no altar.


static func advance(w: World) -> void:
	if w.legendary_table == null or w.legendary_id != -1 or w.boss_flow == null:
		return
	if w.boss_flow.opened_tick < 0 or w.floor_layout == null or w.floor_layout.boss_room < 0:
		return
	w.legendary_id = w.add_reward(RewardStore.Kind.LEGENDARY, w.floor_layout.boss_spawn, 0)


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
		CardLevels.set_level(w, code, t.wand_level)
