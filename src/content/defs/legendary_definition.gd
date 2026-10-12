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
## v0.6.5 WN5b (WAND.md "The legendary tier offers level-5 versions"): 0, or every wand card (an item tagged wand, of
## the run's pool) joins the mods, and the legendary pick takes it at this level (1..5; a held one rises to it).
@export var wand_level := 0


func category() -> StringName:
	return &"legendary"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if stat_cards.is_empty() and mods.is_empty() and wand_level == 0:
		issues.append(ValidationIssue.new(&"missing", resource_path, "the pool needs cards"))
	if stat_multiplier < 1.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "stat_multiplier is at least 1"))
	if wand_level < 0 or wand_level > 5:  # v0.6.5 WN5b: CardLevels.MAX_LEVEL
		issues.append(ValidationIssue.new(&"range", resource_path, "wand_level is 0..5"))
	if offer_size < 1 or offer_size > 3:
		issues.append(ValidationIssue.new(&"range", resource_path, "offer_size is 1..3"))
	if stat_weight < 0 or mod_weight < 0 or stat_weight + mod_weight <= 0:
		issues.append(ValidationIssue.new(&"range", resource_path, "weights are >= 0, not both 0"))
	return issues
