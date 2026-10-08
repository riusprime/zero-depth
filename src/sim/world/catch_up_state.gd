class_name CatchUpState
extends RefCounted
## The floor's hidden catch-up (v0.5.5 DS; CatchUp), all per mille: what the build's power P read at floor entry,
## the expected power E, the cap and the multiplier m (1000 = ×1); the same for the boss, read when it spawned (0
## until then). Hashed only in a world whose loadout has the catch-up table (World.catch_up_table), so older worlds
## keep their hashes. Never shown to the player (owner: "Yes, but hidden"); only the dev panel reads it.

var power := 1000
var expected := 1000
var cap := 1000
var enemy := 1000
var boss_power := 0
var boss_expected := 0
var boss_cap := 0
var boss := 1000


func hash_into(h: StateHasher) -> void:
	for v in [power, expected, cap, enemy, boss_power, boss_expected, boss_cap, boss]:
		h.add_int(v)
