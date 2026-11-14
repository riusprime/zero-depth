class_name SurgeDefinition
extends ContentDef
## PLAN H1; owner Q15: "Surges but not during an overrun or lockdown"; CONTENT_SCHEMA §7: the horde
## surges. Once or twice a floor the spawner sends a burst of the floor's biome critter (BiomeDefinition.critter_id):
## size_min..size_max of them over duration_seconds, announced by a sound and a HUD line, never while the hero is in an
## Overrun room, a Lockdown, a sealed arena or the boss room (Surges). A floor has surges_min..surges_max of them; the
## first begins first_seconds_min..max into the floor, each next one gap_seconds_min..max after the last one's end
## (all drawn from the `ai:surge` stream). While a surge runs, enemies alive may reach alive_cap (above the floor's
## normal cap, never above the spawner's cap_max: the hard 120). Starting values; alive_cap is the owner's Q16 gate (a
## 120-enemy surge measured on the owner's PC; lowered here if it drops under 144 fps). v0.11.0 O9b (Q16-b: "Optimise,
## then cap"): surge.tres sets 50, the most that held 144 fps with the crowd full on every idle run on the owner's PC
## (60 held in two of four). Q16-c: "Batch now": with the critters batched, surge.tres sets 120 (idle
## owner's PC, crowd full: 161.1 and 161.4 fps average).

## The most enemies alive any surge may bring the floor to (the spawner's hard cap, SpawnDirectorDefinition.cap_max).
const HARD_CAP := 120

@export var surges_min := 1
@export var surges_max := 2
@export var first_seconds_min := 40.0
@export var first_seconds_max := 80.0
@export var gap_seconds_min := 60.0
@export var gap_seconds_max := 120.0
@export var size_min := 30
@export var size_max := 60
@export var duration_seconds := 10.0
@export var alive_cap := 120


func category() -> StringName:
	return &"surge"


func validate() -> Array[ValidationIssue]:
	var issues := super.validate()
	for row: Array in [
		["surges_min", surges_min, 0, 4],
		["surges_max", surges_max, 1, 4],
		["size_min", size_min, 1, HARD_CAP],
		["size_max", size_max, 1, HARD_CAP],
		["alive_cap", alive_cap, 1, HARD_CAP],
	]:
		if int(row[1]) < int(row[2]) or int(row[1]) > int(row[3]):
			issues.append(
				ValidationIssue.new(
					&"surge_range", resource_path, "%s is outside %d..%d" % [row[0], row[2], row[3]]
				)
			)
	for row: Array in [
		["surges", surges_min, surges_max],
		["size", size_min, size_max],
		["first_seconds", first_seconds_min, first_seconds_max],
		["gap_seconds", gap_seconds_min, gap_seconds_max],
	]:
		if float(row[1]) > float(row[2]):
			issues.append(
				ValidationIssue.new(
					&"surge_order", resource_path, "%s_min is above %s_max" % [row[0], row[0]]
				)
			)
	for row: Array in [
		["first_seconds_min", first_seconds_min],
		["gap_seconds_min", gap_seconds_min],
		["duration_seconds", duration_seconds],
	]:
		if float(row[1]) <= 0.0:
			issues.append(
				ValidationIssue.new(&"not_positive", resource_path, "%s must be > 0" % row[0])
			)
	return issues
