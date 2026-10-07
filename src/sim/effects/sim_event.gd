class_name SimEvent
extends RefCounted
## One gameplay consequence with its provenance (SIM_CONTRACTS §7). The whole Kind enum is declared now;
## new kinds are appended, never inserted, because kinds are hashed.

## PICKUP (v0.2.0): the player took an item; amount = the item's index in World.item_tables.
## COMBO_UNLOCKED (v0.3.0 G): owning both items unlocked a combo; amount = its index in World.combo_tables.
## Run flow (v0.3.0 B): BOSS_DEFEATED (the boss died; the boss contract, C), BOSS_ROOM_SEALED (the boss door shut
## behind the player), PORTAL_OPENED (the gate is active), FLOOR_EXIT (the player walked into the active gate).
enum Kind {
	HIT,
	DAMAGE,
	HEAL,
	BARRIER,
	KILL,
	STATUS_APPLY,
	STATUS_TICK,
	SPAWN,
	LIMIT,
	PICKUP,
	COMBO_UNLOCKED,
	BOSS_DEFEATED,
	BOSS_ROOM_SEALED,
	PORTAL_OPENED,
	FLOOR_EXIT,
}

const TAG_MELEE := 1
const TAG_PROJECTILE := 2
const TAG_DOT := 4
const TAG_AREA := 8
const TAG_CRIT := 16
## The hit was fully blocked (a multiplier of 0). Unused since the Warden lost its block (2026-10-07); kept so bits
## never renumber.
const TAG_BLOCKED := 32
## The hit was reduced by the target's guard.
const TAG_GUARDED := 64
## A fully charged bolt. Unused since the charged shot was dropped (2026-10-07); kept so bits never renumber.
const TAG_FULL_CHARGE := 128
## A Kinetic Dash body hit (v0.2.0 items).
const TAG_DASH := 256
## A Static Chain jump (v0.2.0 J).
const TAG_CHAIN := 512
## Executioner raised this hit (v0.2.0 J).
const TAG_EXECUTE := 1024
## A Thorn Mantle ring bolt (v0.2.0 J).
const TAG_THORN := 2048
## The hit struck a Warden's armoured front (its front multiplier, under 1000; owner, 2026-10-07).
const TAG_ARMOURED := 4096
## The hit struck a Warden from behind (its rear multiplier, over 1000; owner, 2026-10-07).
const TAG_WEAK_SPOT := 8192
## A Shrapnel Storm shard (v0.3.0 G): it never bursts again.
const TAG_SHRAPNEL := 16384

var seq := 0
var tick := 0
var kind: Kind = Kind.HIT
var root_id := 0
var parent_seq := -1
var depth := 0
var source_id := 0
var owner_id := 0
var target_id := 0
var amount := 0
var amount_applied := 0
var proc_pct := 0
var tags := 0
var effect_id := &""
var ancestry := PackedStringArray()
var pos := Vector2.ZERO
