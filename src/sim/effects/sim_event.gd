class_name SimEvent
extends RefCounted
## One gameplay consequence with its provenance (SIM_CONTRACTS §7). The whole Kind enum is declared now;
## new kinds are appended, never inserted, because kinds are hashed.

enum Kind { HIT, DAMAGE, HEAL, BARRIER, KILL, STATUS_APPLY, STATUS_TICK, SPAWN, LIMIT }

const TAG_MELEE := 1
const TAG_PROJECTILE := 2
const TAG_DOT := 4
const TAG_AREA := 8
const TAG_CRIT := 16
## The hit was fully blocked (a shield or guard multiplier of 0).
const TAG_BLOCKED := 32
## The hit was reduced by the target's guard.
const TAG_GUARDED := 64

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
