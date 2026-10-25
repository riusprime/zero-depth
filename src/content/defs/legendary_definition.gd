class_name LegendaryDefinition
extends ContentDef
## The boss-only legendary tier (v0.5.5 AR; owner X1b: "Pick a legendary card"; CONTENT_SCHEMA). Killing a floor's
## boss leaves a legendary altar: a pick of 3 from this pool only. Until the modifier engine (Step MX) swaps the pool
## for legendary modifiers, it is built from the current cards: stat cards at the legendary rarity (the epic amount x
## stat_multiplier) and the strongest mods. Every number is a starting value the owner tunes after playing.

## Stat card ids offered at the legendary rarity, and mod (item) ids.
@export var stat_cards: Array[StringName] = []
@export var mods: Array[StringName] = []
## Draw weights of the two kinds, and the cards per offer.
@export var stat_weight := 60
@export var mod_weight := 40
@export var offer_size := 3
## A legendary stat card's amount: its epic amount x this.
@export var stat_multiplier := 1.6
## v0.9.0 LG (owner Q12: "Power/Haste ×1.3"): a stat card's own multiplier in place of stat_multiplier (its id: one of
## stat_cards; at least 1). Cards not named keep stat_multiplier.
@export var stat_multiplier_by_card: Dictionary[StringName, float] = {}
## Retired by v0.8.0 FL (owner O91: "remove automatic level-5 grants"): it was v0.6.5 WN5b's level every wand card
## was taken at from this altar. Kept so an older file still loads; it must be 0 (the upgrade choice below replaced it).
@export var wand_level := 0
## v0.8.0 FL (owner O91: "boss offers an upgrade or advanced choice"; BALANCE_PASS.md "FL"): the altar's choices, in
## card order. With `upgrade_choice`, one held wand card one level up, up to the next floor's level ceiling
## (LootPacing.next_ceiling). With `card_categories` (ItemDefinition.LOOT_CATEGORIES), one card of those categories
## from the item pool (never a Legendary card: those come only by the Legendary chance below, which takes this choice's
## place when it hits; so the legendary ×2 triggers stay the boss's). The rest are legendary stat cards (and `mods`)
## by the weights below. A choice with nothing to offer leaves its place to the rest.
@export var upgrade_choice := false
@export var card_categories: Array[StringName] = []
## v0.8.0 RR (owner O33: "Legendary items and spells could be obtained from bosses"; "Infinite loops should eventually
## allow players to accumulate extremely powerful combinations"; docs/roadmap/v0.8.0/evidence/RARITY.md): the chance
## that a boss altar's offer holds one Legendary card (an item of rarity LEGENDARY), and what each loop past the first
## adds (both 0..1); the picks a boss altar gives past the first, per loop past the first, and at most. Starting
## values set by the odds script (scripts/checks/rarity_odds.gd).
@export var legendary_chance := 0.0
@export var legendary_chance_per_loop := 0.0
@export var extra_picks_per_loop := 0
@export var extra_picks_max := 0


func category() -> StringName:
	return &"legendary"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if (
		stat_cards.is_empty()
		and mods.is_empty()
		and not upgrade_choice
		and card_categories.is_empty()
	):
		issues.append(ValidationIssue.new(&"missing", resource_path, "the pool needs cards"))
	for c in card_categories:  # v0.8.0 FL
		if not c in ItemDefinition.LOOT_CATEGORIES or c == &"other":
			issues.append(ValidationIssue.new(&"range", resource_path, "unknown category %s" % c))
	if stat_multiplier < 1.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "stat_multiplier is at least 1"))
	for id: StringName in stat_multiplier_by_card:  # v0.9.0 LG
		if not stat_cards.has(id):
			issues.append(
				ValidationIssue.new(
					&"unknown_item", resource_path, "%s is not a legendary stat card" % id
				)
			)
		if stat_multiplier_by_card[id] < 1.0:
			issues.append(
				ValidationIssue.new(
					&"range", resource_path, "%s: its multiplier is at least 1" % id
				)
			)
	if wand_level != 0:  # v0.8.0 FL: the level-5 grant is gone (upgrade_choice)
		issues.append(ValidationIssue.new(&"range", resource_path, "wand_level is retired: 0"))
	if offer_size < 1 or offer_size > 3:
		issues.append(ValidationIssue.new(&"range", resource_path, "offer_size is 1..3"))
	if legendary_chance < 0.0 or legendary_chance > 1.0:  # v0.8.0 RR
		issues.append(ValidationIssue.new(&"range", resource_path, "legendary_chance is 0..1"))
	if legendary_chance_per_loop < 0.0 or legendary_chance_per_loop > 1.0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "legendary_chance_per_loop is 0..1")
		)
	if extra_picks_per_loop < 0 or extra_picks_max < 0 or extra_picks_max > 8:
		issues.append(ValidationIssue.new(&"range", resource_path, "extra picks are 0..8"))
	if stat_weight < 0 or mod_weight < 0 or stat_weight + mod_weight <= 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "weights are >= 0, not both 0"))
	return issues


## v0.9.0 LG: the legendary multiplier of stat card `id` (its own, or stat_multiplier).
func multiplier_of(id: StringName) -> float:
	return float(stat_multiplier_by_card.get(id, stat_multiplier))
