class_name ItemDefinition
extends ContentDef
## An item that changes one attack (v0.2.0 PLAN, Items). `kind` picks the effect; only that kind's fields are
## read and validated. Values are starting values the owner tunes after playing.

## Appended, never renumbered (the compiler maps each to a sim kind).
enum Kind {
	LONG_EDGE,
	TWIN_ARC,
	EMBER_EDGE,
	SPLINTER_SHOT,
	RAPID_COIL,
	RICOCHET_CORE,
	KINETIC_DASH,
	OVERCHARGE,
	VAMPIRIC_CORE,
	STATIC_CHAIN,
	MOMENTUM,
	FROST_CORE,
	THORN_MANTLE,
	EXECUTIONER,
	SWIFT_FEET,
	PHASE_STRIKE,
	CINDER_SHOT,
	WILDFIRE,
	CONDUCTOR,
	SERRATED_EDGE,
	BARBED_BOLTS,
	GLACIAL_EDGE,
	COLD_SNAP,
	BULWARK,
	HEAT_SINK,
	THERMAL_EDGE,
	MELTDOWN,
	CLUSTER_PAYLOAD,
	OVERCLOCKED_DRONE,
	RAZOR_ORBIT,
	AFTERIMAGE,
	MODIFIER,
	TRIGGER,  # v0.6.5 WN1: a wand trigger card (its modifier is a TRIGGER op; not offered until WN5)
	WAND,  # v0.6.5 WN3: a wand card of a weapon's pool (tag wand: levels 1–5; requires_weapon: its pool)
}

## How rare an item is (v0.3.0 E): chests weight rare items higher. Appended, never renumbered. v0.6.0 MX4:
## LEGENDARY, the boss's tier. v0.8.0 RR (owner O33; docs/roadmap/v0.8.0/evidence/RARITY.md): EPIC appended, so the
## four tiers read Common < Rare < Epic < Legendary (ItemTable.tier maps this enum onto that order). Every tier's
## weight in an altar's, a chest's and the shop's draw is RewardsDefinition's; a Legendary card is mostly the boss's
## (LegendaryDefinition.card_permille), rarely an altar's or a chest's.
enum Rarity { COMMON, RARE, LEGENDARY, EPIC }

## v0.6.0 MX1: the kinds whose attack effects live in their modifiers (each must name at least one).
const MODIFIER_KINDS: Array[Kind] = [
	Kind.LONG_EDGE,
	Kind.TWIN_ARC,
	Kind.EMBER_EDGE,
	Kind.SPLINTER_SHOT,
	Kind.RAPID_COIL,
	Kind.RICOCHET_CORE,
	Kind.OVERCHARGE,
	Kind.STATIC_CHAIN,
	Kind.FROST_CORE,
	Kind.CINDER_SHOT,
	Kind.CONDUCTOR,
	Kind.SERRATED_EDGE,
	Kind.BARBED_BOLTS,
	Kind.GLACIAL_EDGE,
	# v0.6.0 MX4: the ability mods' effects are modifiers now, and the M-list's cards are all modifier cards.
	Kind.CLUSTER_PAYLOAD,
	Kind.OVERCLOCKED_DRONE,
	Kind.AFTERIMAGE,
	Kind.MODIFIER,
	Kind.TRIGGER,  # v0.6.5 WN1
	Kind.WAND,  # v0.6.5 WN3
]

## The closed set of item tags (v0.3.0 G): engines (fire, shock, frost, bleed, guard) and attack families.
## v0.3.0 L18: &"heat" marks the Overclock heat items (offered only when the run has heat).
## v0.5.0 CP: &"ability" marks the ability mods (each needs its ability: requires_ability).
## v0.6.0 MX4: &"venom" (Venom Core's poison engine).
const TAGS: Array[StringName] = [
	&"fire",
	&"shock",
	&"frost",
	&"bleed",
	&"blade",
	&"bolt",
	&"dash",
	&"guard",
	&"heat",
	&"ability",
	&"venom",
	&"trigger",  # v0.6.5 WN1: a wand trigger card (Kind.TRIGGER)
	&"wand",  # v0.6.5 WN3: a wand card that levels up 1–5 (CardLevels)
	&"mutation",  # v0.8.0 RM (owner O91): a rare mutation card (its own category; offer_weight_permille keeps it rare)
]

## v0.8.0 FL: the pacing categories, in LootPacing.Category's order (ItemTable.loot_category is the index).
const LOOT_CATEGORIES: Array[StringName] = [
	&"other", &"form", &"element", &"advanced", &"trigger", &"mutation"
]
## v0.9.0 AS (owner Q2–Q4, PLAN C37–C45): the wand's slot categories, in AttackSlots' order (ItemTable.slot_category is
## the index; empty = free). Not loot_category (that only paces loot, and its "form" means something else).
const SLOT_CATEGORIES: Array[StringName] = [&"free", &"form", &"pattern", &"secondary", &"element"]

@export var kind := Kind.LONG_EDGE
@export var rarity := Rarity.COMMON
## The utility the item needs to do anything (v0.3.0 E): a UtilityDefinition id (&"guard", &"blink"), or empty for
## any. Altars and chests never offer an item whose utility you didn't choose.
@export var requires_utility: StringName = &""
## The weapon the item feeds (v0.3.0 L15): a BuildDefinition weapon id (&"blade", &"gun"), or empty for any. A run
## whose build lacks that weapon is never offered it.
@export var requires_weapon: StringName = &""
## v0.5.0 CP: the ability the mod changes (an AbilityDefinition.Kind in lower case, e.g. &"bomb_lobber"), or
## empty. Altars and chests offer it only while you own that ability; an ability mod (tag &"ability") names one.
@export var requires_ability: StringName = &""
@export var name_key: StringName
@export var desc_key: StringName
## v0.6.0 MX1 (docs/design/MODIFIER_ENGINE.md): the modifiers (ModifierDefinition ids, data/modifiers/) this item
## brings into the build, in order. What an item does to the Blade's steps, the Gun's bolt and the Skills lives
## there; the item keeps its card fields and its engine numbers (burn, shock, bleed, frost, slow, guard, heat).
@export var modifiers: Array[StringName] = []
## Ember Edge: damage per burn stack per period, the burn's length (refreshed by each new stack), the stack cap.
@export var burn_damage := 0
@export var burn_period_seconds := 0.0
@export var burn_duration_seconds := 0.0
@export var burn_max_stacks := 0
## Kinetic Dash: damage to each enemy the dash passes through (once per dash).
@export var dash_hit_damage := 0
## Vampiric Core: HP healed per kill, at most heal_cap HP in each heal_window_seconds.
@export var heal_per_kill := 0
@export var heal_cap := 0
@export var heal_window_seconds := 0.0
## Momentum: a swing started within the window after a dash ends deals × (1 + bonus / 1000).
@export var momentum_window_seconds := 0.0
@export var momentum_bonus_permille := 0
## Frost Core: a bolt hit slows the enemy to slow_permille / 1000 of its speed (refreshed, never stacked).
@export var slow_permille := 0
@export var slow_seconds := 0.0
## Thorn Mantle: taking damage releases a ring of thorn_bolts bolts of thorn_damage each.
@export var thorn_bolts := 0
@export var thorn_damage := 0
## Executioner: your hits on enemies below threshold / 1000 of their max HP deal × (1 + bonus / 1000).
@export var execute_threshold_permille := 0
@export var execute_bonus_permille := 0
## Swift Feet: move speed × (1 + bonus / 1000); dash cooldown × (1 − cut / 1000).
@export var move_speed_bonus_permille := 0
@export var dash_cooldown_cut_permille := 0
## Phase Strike: a blink's arrival, or the first guarded hit in each window, deals phase_damage in a ring.
@export var phase_damage := 0
@export var phase_radius_m := 0.0
@export var phase_guard_window_seconds := 0.0
# --- Engines (v0.3.0 G). An engine's numbers live in each item that feeds it; owning several takes the strongest.
## v0.9.5 CLV (CARD_LEVELS.md): how many levels this wand card has (1..5); 0 = the default, CardLevels.MAX_LEVEL. A
## card with 1 is offered once and never again while held.
@export var level_max := 0
## v0.9.5 SM (Stress Mark): a nonzero radius makes this the Stress Mark card: enemies within it show a weak side
## (half_angle_deg wide), a hit from it multiplies by mult_permille, then waits cooldown_seconds; a boss carries
## boss_marks sides.
@export var mark_radius_m := 0.0
@export var mark_half_angle_deg := 45.0
@export var mark_mult_permille := 1000
@export var mark_cooldown_seconds := 8.0
@export var mark_boss_marks := 1
## Tags from TAGS: at least one, no repeats.
@export var tags: PackedStringArray = PackedStringArray()
## Stacks one qualifying hit of a source that is not a weapon attack adds (Static Chain's jumps, Overcharge's
## shockwave, Cold Snap's dash, Razor Orbit's blades), or the stacks Wildfire spreads. v0.6.0 MX1: the stacks a
## Blade or Gun hit feeds (Conductor, Serrated Edge, Glacial Edge, Cinder Shot, Barbed Bolts, Frost Core, Static
## Chain's bolts) moved into each item's modifier (a STATUS op with its stacks and every).
@export var stacks_per_hit := 0
## Shock: stacks that discharge, how long stacks last (refreshed by each new one), the discharge's damage, how many
## other enemies it jumps to, and how far each jump reaches.
@export var shock_threshold := 0
@export var shock_seconds := 0.0
@export var shock_damage := 0
@export var shock_jumps := 0
@export var shock_range_m := 0.0
## Bleed: damage per stack per period, how long stacks last (refreshed), the stack cap, and the extra damage per
## stack a dash through the enemy bursts.
@export var bleed_damage := 0
@export var bleed_period_seconds := 0.0
@export var bleed_seconds := 0.0
@export var bleed_max_stacks := 0
@export var bleed_burst_per_stack := 0
## Frost: stacks that freeze, how long stacks last (refreshed), and how long a freeze holds.
@export var frost_threshold := 0
@export var frost_seconds := 0.0
@export var freeze_seconds := 0.0
## Wildfire: a kill spreads burn stacks to enemies within this radius.
@export var spread_radius_m := 0.0
## Cold Snap: your hits on chilled (frost stacks) and frozen enemies deal × (1 + bonus / 1000).
@export var chill_bonus_permille := 0
@export var frozen_bonus_permille := 0
## Bulwark: guard charges stored at most, and the swing bonus per charge spent.
@export var charge_max := 0
@export var charge_bonus_permille := 0
# --- Overclock heat (v0.3.0 L18; Heat).
## Heat Sink: vent blasts deal × (1 + bonus / 1000) and reach × (1 + radius bonus / 1000).
@export var vent_damage_bonus_permille := 0
@export var vent_radius_bonus_permille := 0
## Thermal Edge: the Hot threshold (heat points) drops to this.
@export var heat_hot_threshold := 0
## Meltdown: reaching the overheat point blows up as a full-heat vent blast at this share (per mille), no stall.
@export var meltdown_damage_permille := 0
# --- Ability mods (v0.5.0 CP; AbilityMods). Razor Orbit: a blade's touch adds bleed (its modifier's STATUS op; the
## bleed fields here, like Serrated Edge). v0.6.0 MX4: Cluster Payload's bomblets, Overclocked Drone's heat rate and
## Afterimage's echo are their modifiers' ops (data/modifiers/), no longer fields here.
# --- v0.6.0 MX4: Venom Core's poison engine (Venom): damage per stack per period, how long stacks last (refreshed by
# each new one), the stack cap, and the radius a poisoned enemy's death spreads its stacks over.
@export var poison_damage := 0
@export var poison_period_seconds := 0.0
@export var poison_seconds := 0.0
@export var poison_max_stacks := 0
@export var poison_spread_m := 0.0
# --- v0.6.5 WN5a (docs/design/WAND.md, the shared pool and the triggers).
## S5 Bleed: the bleed's period while you move (walking or dashing; 0 = the same as standing). Shorter: it ticks
## faster while you move.
@export var bleed_move_period_seconds := 0.0
## T4: the card's face on a Gun run when it differs (On Finisher with the Blade, On Crit with the Gun); empty = the
## same face on both weapons. Both or neither.
@export var name_key_gun: StringName = &""
@export var desc_key_gun: StringName = &""
## v0.8.0 BL (saves name items by index): 0 for every card that shipped before v0.8.0. A card added later takes the
## next wave (v0.8.0 BL's Blade Storm and Riposte Chain: 1); its index comes after every earlier wave's
## (ModifierCompiler.item_defs), so no index an older save holds moves.
@export var index_wave := 0
## v0.8.0 RM (owner O91: mutations "exceptionally rare"): the card's draw weight × this per mille in an altar's, a
## chest's and the shop's draw (ItemPool.card_weight); a card under 1000 never fills the boss's legendary chance slot
## (Offers.legendary_cards). The floor pacing step (FL) tunes when such a card is eligible. 1000 = as its tier.
@export var offer_weight_permille := 1000
## v0.8.0 FL (owner O91; docs/roadmap/v0.8.0/BALANCE_PASS.md "FL"): the card's pacing category, one of
## LOOT_CATEGORIES (empty = other): `form` changes the attack's shape or path on its own, `element` is a shared status
## card (S1–S7), `advanced` multiplies, repeats or builds on other cards (and the legendary ×2 triggers), `trigger` is
## T1–T4, `mutation` a mutation. Every wand card and trigger card names one; LootPacing weighs its draws by the floor.
@export var loot_category: StringName = &""
## v0.9.0 AS (owner Q2: "1 Form and 1 Pattern (a new one replaces the old), N Secondary, M Elements; trigger, mutation
## and stat cards stay free"): the card's wand slot category, one of SLOT_CATEGORIES (empty = free). The limits per
## category and the form × card compatibility table are data/wand/attack_slots.tres (AttackSlotsDefinition, whose
## cross_check makes every live slot card name one). A trigger card and a mutation are free.
@export var slot_category: StringName = &""


func category() -> StringName:
	return &"items"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if offer_weight_permille < 0 or offer_weight_permille > 10000:  # v0.8.0 RM
		issues.append(
			ValidationIssue.new(&"range", resource_path, "offer_weight_permille 0..10000")
		)
	if tags.has("mutation") and offer_weight_permille >= 1000:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "a mutation weighs under 1000 per mille")
		)
	_check_loot_category(issues)  # v0.8.0 FL
	if slot_category != &"" and not slot_category in SLOT_CATEGORIES:  # v0.9.0 AS
		issues.append(
			ValidationIssue.new(&"range", resource_path, "unknown slot_category %s" % slot_category)
		)
	if (kind == Kind.TRIGGER or tags.has("mutation")) and not slot_category in [&"", &"free"]:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "a trigger or mutation card is free")
		)
	if index_wave < 0 or index_wave > 64:
		issues.append(ValidationIssue.new(&"range", resource_path, "index_wave is 0..64"))
	if rarity < Rarity.COMMON or rarity > Rarity.EPIC:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "rarity is common, rare, epic or legendary"
			)
		)
	if not requires_utility in [&"", &"guard", &"blink"]:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "requires_utility is empty, guard or blink"
			)
		)
	if requires_weapon != &"" and not BuildDefinition.WEAPON_IDS.has(requires_weapon):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "requires_weapon is empty, blade or gun")
		)
	# v0.6.5 WN4: a Blade pool card is offered only in Blade runs
	if kind == Kind.WAND and tags.has("blade") != (requires_weapon == &"blade"):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "a blade pool card requires the blade")
		)
	if requires_ability != &"" and ability_kind(requires_ability) < 0:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "unknown ability %s" % requires_ability)
		)
	if tags.has("ability") != (requires_ability != &""):
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "an ability mod (tag ability) names requires_ability"
			)
		)
	_check_tags(issues)
	if level_max < 0 or level_max > 5:
		issues.append(ValidationIssue.new(&"range", resource_path, "level_max is 0..5"))
	if mark_radius_m < 0.0 or mark_radius_m > 20.0 or mark_boss_marks < 1 or mark_boss_marks > 4:
		issues.append(ValidationIssue.new(&"range", resource_path, "mark_* out of range"))
	if mark_radius_m > 0.0 and (mark_half_angle_deg <= 0.0 or mark_half_angle_deg > 90.0):
		issues.append(ValidationIssue.new(&"range", resource_path, "mark_half_angle_deg is 0..90"))
	if kind == Kind.WAND and not tags.has("wand"):
		issues.append(ValidationIssue.new(&"tags", resource_path, "a WAND card is tagged wand"))
	if tags.has("wand") and modifiers.is_empty():
		issues.append(ValidationIssue.new(&"missing", resource_path, "a wand card names modifiers"))
	_check_wand_extras(issues)  # v0.6.5 WN5a
	if kind in MODIFIER_KINDS and modifiers.is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "this kind names its modifiers")
		)
	match kind:
		Kind.EMBER_EDGE:
			_check_burn(issues)
		Kind.KINETIC_DASH:
			check_positive(issues, "dash_hit_damage", dash_hit_damage)
		Kind.OVERCHARGE:
			_check_shock(issues)
		Kind.VAMPIRIC_CORE:
			check_positive(issues, "heal_per_kill", heal_per_kill)
			check_positive(issues, "heal_cap", heal_cap)
			check_positive(issues, "heal_window_seconds", heal_window_seconds)
			check_duration(issues, "heal_window_seconds", heal_window_seconds)
		Kind.STATIC_CHAIN:
			_check_shock(issues)
		Kind.MOMENTUM:
			check_positive(issues, "momentum_window_seconds", momentum_window_seconds)
			check_duration(issues, "momentum_window_seconds", momentum_window_seconds)
			check_positive(issues, "momentum_bonus_permille", momentum_bonus_permille)
		Kind.FROST_CORE:
			_check_slow(issues)
			_check_frost(issues, false)
		Kind.THORN_MANTLE:
			check_positive(issues, "thorn_bolts", thorn_bolts)
			check_positive(issues, "thorn_damage", thorn_damage)
		Kind.EXECUTIONER:
			_check_permille_below_1000(
				issues, "execute_threshold_permille", execute_threshold_permille
			)
			check_positive(issues, "execute_bonus_permille", execute_bonus_permille)
		Kind.SWIFT_FEET:
			check_positive(issues, "move_speed_bonus_permille", move_speed_bonus_permille)
			_check_permille_below_1000(
				issues, "dash_cooldown_cut_permille", dash_cooldown_cut_permille
			)
		Kind.PHASE_STRIKE:
			check_positive(issues, "phase_damage", phase_damage)
			check_positive(issues, "phase_radius_m", phase_radius_m)
			check_positive(issues, "phase_guard_window_seconds", phase_guard_window_seconds)
			check_duration(issues, "phase_guard_window_seconds", phase_guard_window_seconds)
		_:
			_validate_engines(issues)
	return issues


## The eight engine items (v0.3.0 G).
func _validate_engines(issues: Array[ValidationIssue]) -> void:
	match kind:
		Kind.CINDER_SHOT:
			_check_burn(issues)
		Kind.WILDFIRE:
			_check_burn(issues)
			check_positive(issues, "stacks_per_hit", stacks_per_hit)
			check_positive(issues, "spread_radius_m", spread_radius_m)
		Kind.CONDUCTOR:
			_check_shock(issues, false)
		Kind.SERRATED_EDGE:
			_check_bleed(issues, false)
		Kind.BARBED_BOLTS:
			_check_bleed(issues, false)
		Kind.GLACIAL_EDGE:
			_check_slow(issues)
			_check_frost(issues, false)
		Kind.COLD_SNAP:
			_check_slow(issues)
			_check_frost(issues)
			check_positive(issues, "chill_bonus_permille", chill_bonus_permille)
			check_positive(issues, "frozen_bonus_permille", frozen_bonus_permille)
		Kind.BULWARK:
			check_positive(issues, "charge_max", charge_max)
			check_positive(issues, "charge_bonus_permille", charge_bonus_permille)
		Kind.HEAT_SINK:
			check_positive(issues, "vent_damage_bonus_permille", vent_damage_bonus_permille)
			check_positive(issues, "vent_radius_bonus_permille", vent_radius_bonus_permille)
		Kind.THERMAL_EDGE:
			check_positive(issues, "heat_hot_threshold", heat_hot_threshold)
		Kind.MELTDOWN:
			check_positive(issues, "meltdown_damage_permille", meltdown_damage_permille)
		_:
			_validate_ability_mods(issues)


## v0.5.0 CP: the AbilityDefinition.Kind named `id` in lower case (&"bomb_lobber"), or -1.
static func ability_kind(id: StringName) -> int:
	return -1 if id == &"" else AbilityDefinition.Kind.keys().find(String(id).to_upper())


## The ability mods (v0.5.0 CP; v0.6.0 MX4: Cluster Payload, Overclocked Drone and Afterimage are their modifiers),
## and the M-list's modifier cards (v0.6.0 MX4): the engine numbers a card's modifier feeds are checked when present.
func _validate_ability_mods(issues: Array[ValidationIssue]) -> void:
	match kind:
		Kind.RAZOR_ORBIT:
			_check_bleed(issues)
		Kind.MODIFIER, Kind.WAND:  # v0.6.5 WN5a: a shared wand card brings its engine's numbers too
			if burn_max_stacks > 0:
				_check_burn(issues)
			if poison_max_stacks > 0 or poison_damage > 0:
				_check_poison(issues)
			if bleed_max_stacks > 0:
				_check_bleed_engine(issues)


## v0.6.0 MX4: Venom Core's poison engine.
func _check_poison(issues: Array[ValidationIssue]) -> void:
	check_positive(issues, "poison_damage", poison_damage)
	check_positive(issues, "poison_period_seconds", poison_period_seconds)
	check_duration(issues, "poison_period_seconds", poison_period_seconds)
	check_positive(issues, "poison_seconds", poison_seconds)
	check_duration(issues, "poison_seconds", poison_seconds)
	check_positive(issues, "poison_max_stacks", poison_max_stacks)
	if poison_spread_m < 0.0:
		issues.append(ValidationIssue.new(&"range", resource_path, "poison_spread_m >= 0"))


func _check_tags(issues: Array[ValidationIssue]) -> void:
	if tags.is_empty():
		issues.append(ValidationIssue.new(&"tags", resource_path, "at least one tag"))
	var seen := {}
	for t in tags:
		if not StringName(t) in TAGS:
			issues.append(ValidationIssue.new(&"tags", resource_path, "unknown tag %s" % t))
		elif seen.has(t):
			issues.append(ValidationIssue.new(&"tags", resource_path, "tag %s twice" % t))
		seen[t] = true


func _check_burn(issues: Array[ValidationIssue]) -> void:
	check_positive(issues, "burn_damage", burn_damage)
	check_positive(issues, "burn_period_seconds", burn_period_seconds)
	check_duration(issues, "burn_period_seconds", burn_period_seconds)
	check_positive(issues, "burn_duration_seconds", burn_duration_seconds)
	check_duration(issues, "burn_duration_seconds", burn_duration_seconds)
	check_positive(issues, "burn_max_stacks", burn_max_stacks)


## `feeds`: the item feeds the status from a source of its own (stacks_per_hit); false when its modifier's STATUS
## op carries the stacks (v0.6.0 MX1).
func _check_shock(issues: Array[ValidationIssue], feeds: bool = true) -> void:
	if feeds:
		check_positive(issues, "stacks_per_hit", stacks_per_hit)
	if shock_threshold < 2:
		issues.append(ValidationIssue.new(&"range", resource_path, "shock_threshold is >= 2"))
	check_positive(issues, "shock_seconds", shock_seconds)
	check_duration(issues, "shock_seconds", shock_seconds)
	check_positive(issues, "shock_damage", shock_damage)
	check_positive(issues, "shock_jumps", shock_jumps)
	check_positive(issues, "shock_range_m", shock_range_m)


func _check_bleed(issues: Array[ValidationIssue], feeds: bool = true) -> void:
	if feeds:
		check_positive(issues, "stacks_per_hit", stacks_per_hit)
	check_positive(issues, "bleed_damage", bleed_damage)
	check_positive(issues, "bleed_period_seconds", bleed_period_seconds)
	check_duration(issues, "bleed_period_seconds", bleed_period_seconds)
	check_positive(issues, "bleed_seconds", bleed_seconds)
	check_duration(issues, "bleed_seconds", bleed_seconds)
	check_positive(issues, "bleed_max_stacks", bleed_max_stacks)
	check_positive(issues, "bleed_burst_per_stack", bleed_burst_per_stack)


func _check_frost(issues: Array[ValidationIssue], feeds: bool = true) -> void:
	if feeds:
		check_positive(issues, "stacks_per_hit", stacks_per_hit)
	if frost_threshold < 2:
		issues.append(ValidationIssue.new(&"range", resource_path, "frost_threshold is >= 2"))
	check_positive(issues, "frost_seconds", frost_seconds)
	check_duration(issues, "frost_seconds", frost_seconds)
	check_positive(issues, "freeze_seconds", freeze_seconds)
	check_duration(issues, "freeze_seconds", freeze_seconds)


func _check_slow(issues: Array[ValidationIssue]) -> void:
	_check_permille_below_1000(issues, "slow_permille", slow_permille)
	check_positive(issues, "slow_seconds", slow_seconds)
	check_duration(issues, "slow_seconds", slow_seconds)


## A per-mille share strictly between 0 and 1000.
func _check_permille_below_1000(issues: Array[ValidationIssue], field: String, v: int) -> void:
	if v <= 0 or v >= 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "%s is in 1..999" % field))


## v0.6.5 WN5a: a shared card's bleed (S5): the engine's numbers (no dash burst needed).
func _check_bleed_engine(issues: Array[ValidationIssue]) -> void:
	check_positive(issues, "bleed_damage", bleed_damage)
	check_positive(issues, "bleed_period_seconds", bleed_period_seconds)
	check_duration(issues, "bleed_period_seconds", bleed_period_seconds)
	check_positive(issues, "bleed_seconds", bleed_seconds)
	check_duration(issues, "bleed_seconds", bleed_seconds)
	check_positive(issues, "bleed_max_stacks", bleed_max_stacks)


## v0.8.0 FL: a known category; every wand card and trigger card names one (not other); a mutation is tagged so and
## only it; a trigger card is a trigger (T1–T4) or, legendary (the ×2 triggers), advanced, and only a trigger card is.
func _check_loot_category(issues: Array[ValidationIssue]) -> void:
	if loot_category != &"" and not loot_category in LOOT_CATEGORIES:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "unknown loot_category %s" % loot_category)
		)
		return
	var named := loot_category != &"" and loot_category != &"other"
	if (tags.has("wand") or kind == Kind.TRIGGER) and not named:
		issues.append(
			ValidationIssue.new(
				&"missing", resource_path, "a wand or trigger card names a category"
			)
		)
	if tags.has("mutation") != (loot_category == &"mutation"):
		issues.append(
			ValidationIssue.new(&"range", resource_path, "a mutation, and only it, is a mutation")
		)
	if kind == Kind.TRIGGER and named:
		var want := &"advanced" if rarity == Rarity.LEGENDARY else &"trigger"
		if loot_category != want:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "this trigger card is %s" % want)
			)
	elif loot_category == &"trigger":
		issues.append(
			ValidationIssue.new(&"range", resource_path, "only a trigger card is a trigger")
		)


## v0.6.5 WN5a: the moving bleed is shorter than the standing one; a Gun face has both keys.
func _check_wand_extras(issues: Array[ValidationIssue]) -> void:
	if (
		bleed_move_period_seconds < 0.0
		or (bleed_move_period_seconds > 0.0 and bleed_move_period_seconds >= bleed_period_seconds)
	):
		issues.append(
			ValidationIssue.new(
				&"range",
				resource_path,
				"bleed_move_period_seconds is 0 or under the bleed's period"
			)
		)
	if String(name_key_gun).is_empty() != String(desc_key_gun).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key_gun and desc_key_gun together")
		)
