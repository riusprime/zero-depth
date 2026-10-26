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
## v0.9.5 BH1 (H2, Q2): 1 while the boss's m above was read at the door (BossFlow.interact) and waits for the spawn;
## CatchUp.on_boss uses it and clears it. 0 otherwise (an older save, a floor without the door: read at the spawn).
var boss_read := 0


func hash_into(h: StateHasher) -> void:
	for v in [power, expected, cap, enemy, boss_power, boss_expected, boss_cap, boss]:
		h.add_int(v)
	if boss_read != 0:  # v0.9.5 BH1: only while a door-read m waits, so every other world hashes as before
		h.add_int(boss_read)
