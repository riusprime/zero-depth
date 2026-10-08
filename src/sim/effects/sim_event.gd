class_name SimEvent
extends RefCounted
## One gameplay consequence with its provenance (SIM_CONTRACTS §7). The whole Kind enum is declared now;
## new kinds are appended, never inserted, because kinds are hashed.

## PICKUP (v0.2.0): the player took an item; amount = the item's index in World.item_tables.
## COMBO_UNLOCKED (v0.3.0 G): owning both items unlocked a combo; amount = its index in World.combo_tables.
## BOSS_DEFEATED (v0.3.0 C): a boss died, once per boss, after its KILL; target_id = the boss's id, amount = its
## index in World.boss_tables, pos = where it fell.
## v0.3.0 E: PICKUP is also a card taken from an altar or chest (source = the reward's id). SHARDS: a kill paid
## shards; amount = how many, pos = the body, source = the dead actor's id.
## Run flow (v0.3.0 B): BOSS_ROOM_SEALED (the boss door shut behind the player), PORTAL_OPENED (the gate is
## active), FLOOR_EXIT (the player walked into the active gate).
## Boss challenge (v0.3.0 BX, L20): ENEMY_DISSOLVED: summoning the boss removed a normal enemy from the floor (no
## kill, no shards); target_id = its id, amount = its kind, pos = where it stood.
## Kit (v0.3.5 K): SKILL_USED: the build's skill started (amount = SkillTable.Kind, root = the skill's root, pos =
## where it started). VENT: the Vent button vented (amount = heat points vented). VENT_COLD: the Vent button under
## Hot did nothing (the cold click).
## v0.5.0 SH: SHOP_BUY: shards spent at the shop (amount = the price, effect_id = the card's id, or &"shop_heal" /
## &"shop_reroll"; a bought card also emits PICKUP from the terminal). SHOP_SALVAGE: shards back for a mod, a stat
## card or an ability (amount = the refund, effect_id = its id, target_id = the card code).
## v0.4.0 BS: PICKUP's amount is a card code (Offers): under 1000 an item (as before), 1000 + i ability i, 2000 + stat
## x 10 + rarity a stat card. A HIT with TAG_CRIT was a critical hit.
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
	SHARDS,
	BOSS_ROOM_SEALED,
	PORTAL_OPENED,
	FLOOR_EXIT,
	ENEMY_DISSOLVED,
	SKILL_USED,
	VENT,
	VENT_COLD,
	SHOP_BUY,
	SHOP_SALVAGE,
}

const TAG_MELEE := 1
const TAG_PROJECTILE := 2
const TAG_DOT := 4
const TAG_AREA := 8
## A critical hit (v0.4.0 BS, owner F9; Stats.outgoing): reserved since v0.0.1, first emitted in v0.4.0.
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
## Overclock heat (v0.3.0 L18): the hit was raised by Overclock; a Hot bolt that still pierces one enemy.
const TAG_OVERCLOCK := 32768
const TAG_PIERCE := 65536
## Boss challenge (v0.3.0 BX, L17): the player hit a boss from farther than its ranged armour allows (less damage).
const TAG_DEFLECTED := 131072
## Boss challenge (v0.3.0 BX, L17): the player hit a boss's open weak point up close (more damage and stagger).
const TAG_EXPOSED := 262144
## Kit (v0.3.5 K): a hit from the build's skill (the Lunge Cleave, a Scatter Blast pellet). Bit 21, leaving 19 and 20
## for the step that ran in parallel.
const TAG_SKILL := 2097152
## v0.4.0 BS: a hit from an ability (a bomb, a drone bolt or its chain, an orbit blade, the blink's landing shock,
## Combo Sword's finisher shockwave). Bit 24, clear of the bits a parallel step may take.
const TAG_ABILITY := 16777216

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
