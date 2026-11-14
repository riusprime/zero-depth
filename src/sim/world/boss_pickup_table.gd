class_name BossPickupTable
extends RefCounted
## One kind of floor pickup a boss places (BossPickups), in sim units (ticks, m, per mille): the hero takes it by
## walking through it.

## What taking one does. RESTORE_ATTACK_SPEED: returns `amount` per mille of the attack speed a boss took
## (BossSlow.give_back).
enum Kind { RESTORE_ATTACK_SPEED }

var kind := Kind.RESTORE_ATTACK_SPEED
## The effect's size (RESTORE_ATTACK_SPEED: per mille of attack speed returned).
var amount := 250
## The hero's circle touching this disc takes it.
var radius_m := 0.8
## How long it lies there (0 = until taken or its fight ends).
var life_ticks := 0
## At most this many of one boss's lie at once: one more removes the oldest.
var max_count := 3
