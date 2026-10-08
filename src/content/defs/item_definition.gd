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
}

## How rare an item is (v0.3.0 E): chests weight rare items higher. Appended, never renumbered.
enum Rarity { COMMON, RARE }

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
]

## The closed set of item tags (v0.3.0 G): engines (fire, shock, frost, bleed, guard) and attack families.
## v0.3.0 L18: &"heat" marks the Overclock heat items (offered only when the run has heat).
## v0.5.0 CP: &"ability" marks the ability mods (each needs its ability: requires_ability).
const TAGS: Array[StringName] = [
	&"fire", &"shock", &"frost", &"bleed", &"blade", &"bolt", &"dash", &"guard", &"heat", &"ability"
]

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
# --- Ability mods (v0.5.0 CP; AbilityMods).
## Cluster Payload: a thrown bomb splits into this many bomblets at its edge, each landing this long after it, for
## this share of its damage in this share of its radius.
@export var bomblets := 0
@export var bomblet_damage_permille := 0
@export var bomblet_radius_permille := 0
@export var bomblet_delay_seconds := 0.0
## Overclocked Drone: drone fire rate + this per mille for each heat point held.
@export var drone_rate_per_heat_permille := 0
## Razor Orbit: a blade's touch adds stacks_per_hit bleed (with the bleed fields, like Serrated Edge).
## Afterimage: a blink's echo bursts this long after for this damage in this radius.
@export var afterimage_damage := 0
@export var afterimage_radius_m := 0.0
@export var afterimage_delay_seconds := 0.0


func category() -> StringName:
	return &"items"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	if String(name_key).is_empty() or String(desc_key).is_empty():
		issues.append(
			ValidationIssue.new(&"missing", resource_path, "name_key and desc_key are required")
		)
	if rarity < Rarity.COMMON or rarity > Rarity.RARE:
		issues.append(ValidationIssue.new(&"range", resource_path, "rarity is common or rare"))
	if not requires_utility in [&"", &"guard", &"blink"]:
		issues.append(
			ValidationIssue.new(
				&"range", resource_path, "requires_utility is empty, guard or blink"
			)
		)
	if not requires_weapon in [&"", &"blade", &"gun"]:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "requires_weapon is empty, blade or gun")
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


## The ability mods (v0.5.0 CP).
func _validate_ability_mods(issues: Array[ValidationIssue]) -> void:
	match kind:
		Kind.CLUSTER_PAYLOAD:
			check_positive(issues, "bomblets", bomblets)
			check_positive(issues, "bomblet_damage_permille", bomblet_damage_permille)
			check_positive(issues, "bomblet_radius_permille", bomblet_radius_permille)
			check_positive(issues, "bomblet_delay_seconds", bomblet_delay_seconds)
			check_duration(issues, "bomblet_delay_seconds", bomblet_delay_seconds)
		Kind.OVERCLOCKED_DRONE:
			check_positive(issues, "drone_rate_per_heat_permille", drone_rate_per_heat_permille)
		Kind.RAZOR_ORBIT:
			_check_bleed(issues)
		Kind.AFTERIMAGE:
			check_positive(issues, "afterimage_damage", afterimage_damage)
			check_positive(issues, "afterimage_radius_m", afterimage_radius_m)
			check_positive(issues, "afterimage_delay_seconds", afterimage_delay_seconds)
			check_duration(issues, "afterimage_delay_seconds", afterimage_delay_seconds)


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
