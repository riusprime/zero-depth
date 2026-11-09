class_name HazardTable
extends RefCounted
## v0.11.0 F8 (owner 4.2: "environmental hazards that progressively occupy parts of the arena ... accumulate during the
## fight but have a strict maximum cap"; BossHazard): a boss's arena hazards in sim units (ticks, m, per mille),
## compiled from BossDefinition.hazard (HazardRules.SPEC). DAMAGE burns the hero standing in it; SLOW only drags (a
## rock's zone). Any kind may also drag (slow_permille < 1000) or land on a hit (impact_damage > 0).

enum Kind { DAMAGE, SLOW }

var kind := Kind.DAMAGE
## What it looks like (HazardRules.LOOKS): &"lava", &"venom", &"rock".
var look := &"lava"
var radius_m := 2.0
## How long it stays once armed, and the visible warning before that.
var life_ticks := 1200
var warn_ticks := 48
## The strict cap: this many at once, and at most this share of the arena's floor (per mille).
var max_count := 6
var max_cover_permille := 250
var damage := 0
var burn_ticks := 30
var slow_permille := 1000
var impact_damage := 0
## How many a lane attack leaves at once (the Foundry's flood); the egg and rock hooks leave one each.
var per_attack := 1
## The attacks (BossTable.attacks indices) that leave one.
var attacks := PackedInt32Array()
var cause_key := &""
