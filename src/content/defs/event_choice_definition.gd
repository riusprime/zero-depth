class_name EventChoiceDefinition
extends Resource
## One choice of an event room (v0.5.0 EV, PLAN R3; CONTENT_SCHEMA §9): a cost and a reward, and optionally a curse
## (R4). The panel shows all three before you take it (BLUEPRINT §H). "Leave" is never data: every panel ends with it.

## What the choice costs (Events.Cost mirrors the order; appended, never renumbered):
## none; hp (lose `cost_amount` % of max HP now, never below 1 HP); max_hp (the max HP stat falls by `cost_amount` %
## for the run); shards (`cost_amount` x the floor number); overheat (Overclock heat jumps to max: the stall);
## fight (an elite pack of `cost_amount` enemies arrives in the room); defend (stay within the rules' defend radius
## for `cost_amount` seconds while spawns come twice as fast).
const COSTS: Array[StringName] = [
	&"none", &"hp", &"max_hp", &"shards", &"overheat", &"fight", &"defend"
]
## What it gives (Events.Reward order): stat_epic (an epic stat card, rolled when the panel first opens); stat_echo
## (a rare card of the stat you raised most); mod (a random mod from the pool); chest (a free chest at the pedestal
## once the fight is won); overclock (+`reward_amount` % Overclock damage for the rest of the floor); ability_level
## (one owned ability levels up); shards (`reward_amount` x the floor number); cleanse (your latest curse is lifted).
const REWARDS: Array[StringName] = [
	&"stat_epic",
	&"stat_echo",
	&"mod",
	&"chest",
	&"overclock",
	&"ability_level",
	&"shards",
	&"cleanse",
]
## The rewards that wait for their cost to finish (a fight, a defence).
const DEFERRED: Array[StringName] = [&"chest", &"shards"]

@export var label_key: StringName
@export var cost: StringName = &"none"
@export var cost_amount := 0.0
@export var reward: StringName = &"stat_epic"
@export var reward_amount := 0.0
## &"" (none), &"random" (one you don't have, rolled when the panel first opens) or a curse id.
@export var curse: StringName = &""


func validate_into(issues: Array[ValidationIssue], path: String) -> void:
	if String(label_key).is_empty():
		issues.append(ValidationIssue.new(&"missing", path, "a choice needs a label_key"))
	if not COSTS.has(cost):
		issues.append(ValidationIssue.new(&"unknown", path, "unknown cost %s" % cost))
	if not REWARDS.has(reward):
		issues.append(ValidationIssue.new(&"unknown", path, "unknown reward %s" % reward))
	var needs_cost_amount := cost in [&"hp", &"max_hp", &"shards", &"fight", &"defend"]
	if needs_cost_amount and cost_amount <= 0.0:
		issues.append(ValidationIssue.new(&"range", path, "cost %s needs a cost_amount" % cost))
	if cost in [&"hp", &"max_hp"] and cost_amount >= 100.0:
		issues.append(ValidationIssue.new(&"range", path, "an HP cost is below 100 %"))
	if reward in [&"overclock", &"shards"] and reward_amount <= 0.0:
		issues.append(ValidationIssue.new(&"range", path, "reward %s needs an amount" % reward))
	if reward == &"chest" and cost != &"fight":
		issues.append(ValidationIssue.new(&"range", path, "a chest reward follows a fight"))
	if cost == &"none" and String(curse).is_empty():
		issues.append(ValidationIssue.new(&"free", path, "a choice costs something"))
