class_name LootPacingDefinition
extends ContentDef
## v0.8.0 FL (owner O91, "floor-paced loot"; docs/roadmap/v0.8.0/BALANCE_PASS.md "FL"): one pacing table for every
## card source (altars, chests, the shop and its rerolls, events, stolen cores, the boss's altar). Per stage (floor 1,
## floor 2, floor 3, and the Deep floors and later loops) it holds a draw-weight multiplier per card category
## (ItemDefinition.loot_category), the level ceiling a held wand card can be offered up to, and how many of the floor's
## first regular altars guarantee a card compatible with the wand. A jackpot per regular offer lets one card past the
## ceiling (or one mutation in). Every number is a starting value the owner tunes after playing (the dev panel's
## economy group shows them).

## The stages, in the order of every per-stage array below.
const STAGES := 4
## The categories a weight row holds, in order (ItemDefinition.LOOT_CATEGORIES after "other").
const WEIGHTED := 5

## Draw-weight multipliers, per mille, per category [form, element, advanced, trigger, mutation], one row per stage.
@export var floor_1_weights_permille := PackedInt32Array([1400, 1400, 400, 600, 20])
@export var floor_2_weights_permille := PackedInt32Array([1000, 1000, 1000, 1200, 100])
@export var floor_3_weights_permille := PackedInt32Array([900, 900, 1200, 1200, 300])
@export var deep_weights_permille := PackedInt32Array([800, 800, 1300, 1200, 600])
## The highest level a held wand card can be offered up to, per stage [floor 1, floor 2, floor 3, deep/loops]. A held
## card at the ceiling isn't offered as a duplicate there; the boss's upgrade reaches the next stage's ceiling.
@export var level_ceilings := PackedInt32Array([2, 3, 5, 5])
## Per stage: the floor's first N regular altars each show at least one modifier compatible with the wand.
@export var guaranteed_altars := PackedInt32Array([2, 0, 0, 0])
## The chance, per mille, that a regular offer (an altar's or a chest's) holds a jackpot card: a held wand card one
## level past the ceiling, or a mutation.
@export var jackpot_permille := 15


func category() -> StringName:
	return &"loot_pacing"


## The weight rows in stage order.
func weight_rows() -> Array[PackedInt32Array]:
	return [
		floor_1_weights_permille,
		floor_2_weights_permille,
		floor_3_weights_permille,
		deep_weights_permille
	]


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for row in weight_rows():
		if row.size() != WEIGHTED:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "a weight row holds %d" % WEIGHTED)
			)
		for v in row:
			if v < 0 or v > 10000:
				issues.append(ValidationIssue.new(&"range", resource_path, "weights are 0..10000"))
	if level_ceilings.size() != STAGES or guaranteed_altars.size() != STAGES:
		issues.append(
			ValidationIssue.new(&"range", resource_path, "ceilings and guarantees: one per stage")
		)
	var last := 1
	for c in level_ceilings:
		if c < 1 or c > 5:  # CardLevels.MAX_LEVEL
			issues.append(ValidationIssue.new(&"range", resource_path, "a ceiling is 1..5"))
		if c < last:
			issues.append(
				ValidationIssue.new(&"range", resource_path, "ceilings never fall stage to stage")
			)
		last = maxi(last, c)
	for g in guaranteed_altars:
		if g < 0 or g > 8:
			issues.append(ValidationIssue.new(&"range", resource_path, "guarantees are 0..8"))
	if jackpot_permille < 0 or jackpot_permille > 1000:
		issues.append(ValidationIssue.new(&"range", resource_path, "jackpot_permille 0..1000"))
	return issues
