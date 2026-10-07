class_name BossStore
extends RefCounted
## The live bosses' own state (v0.3.0 C), beside their actor entry (which holds the position, HP, the AI state and
## its locks). Parallel arrays in ascending actor-id order; an entry leaves when its boss dies (World._remove_dead).
## Hashed only in a world that has boss tables, so the kernel golden is unchanged.

## Points a move may lock per boss (lanes' lengths, egg and shell spots).
const MAX_PTS := 8
const INT_FIELDS: Array[StringName] = [
	&"ids",
	&"table",
	&"phase",
	&"meter",
	&"stagger_t",
	&"attack",
	&"step",
	&"last_attack",
	&"entry",
	&"hit",
	&"span",
	&"far_t",
	&"exposed_t",
	&"chained",
	&"fight_t",
	&"close_t",
	&"hazard_cd"
]

## The boss's actor id, and its index in World.boss_tables.
var ids := PackedInt32Array()
var table := PackedInt32Array()
## Current phase (index into the table's phases).
var phase := PackedInt32Array()
## Stagger meter in milli-points, and ticks of stagger left (0 = not staggered).
var meter := PackedInt32Array()
var stagger_t := PackedInt32Array()
## The attack in progress (-1 = none), its stage (a leap's count, a burrow's stage), and the last attack started.
var attack := PackedInt32Array()
var step := PackedInt32Array()
var last_attack := PackedInt32Array()
## The entry attack waiting to start (-1 = none), set when a phase begins.
var entry := PackedInt32Array()
## 1 once this attack (or this leap) has hit the player: one hit per attack.
var hit := PackedInt32Array()
## A rail sweep's signed span (1/4096 turns), from its start angle (the actor's lock_a).
var span := PackedInt32Array()
## Boss challenge (v0.3.0 BX; BossChallenge): ticks the player has stayed beyond the punish distance; ticks the weak
## point stays open; 1 while the attack in progress is a follow-up (it can't chain again); ticks fought (after the
## rise); ticks since the arena began closing (0 = not yet); ticks until the closing band may hurt again.
var far_t := PackedInt32Array()
var exposed_t := PackedInt32Array()
var chained := PackedInt32Array()
var fight_t := PackedInt32Array()
var close_t := PackedInt32Array()
var hazard_cd := PackedInt32Array()
## The boss room's interior (wall face to wall face) the closing band creeps in from; empty = no closing arena (the
## run flow sets it when the door seals).
var arena := Rect2()
## Locked points, MAX_PTS per boss: [x, y] spots, or a lane's length in x.
var pts_x := PackedFloat32Array()
var pts_y := PackedFloat32Array()


func size() -> int:
	return ids.size()


func add(id: int, table_index: int) -> int:
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.append(0)
		set(f, ai)
	for k in MAX_PTS:
		pts_x.append(0.0)
		pts_y.append(0.0)
	var b := ids.size() - 1
	ids[b] = id
	table[b] = table_index
	attack[b] = -1
	last_attack[b] = -1
	entry[b] = -1
	return b


## The entry for an actor id, or -1.
func index_of(id: int) -> int:
	return ids.bsearch(id) if ids.has(id) else -1


func pt(b: int, k: int) -> Vector2:
	return Vector2(pts_x[b * MAX_PTS + k], pts_y[b * MAX_PTS + k])


func set_pt(b: int, k: int, p: Vector2) -> void:
	pts_x[b * MAX_PTS + k] = p.x
	pts_y[b * MAX_PTS + k] = p.y


func remove(b: int) -> void:
	for f in INT_FIELDS:
		var ai: PackedInt32Array = get(f)
		ai.remove_at(b)
		set(f, ai)
	for k in MAX_PTS:
		pts_x.remove_at(b * MAX_PTS)
		pts_y.remove_at(b * MAX_PTS)


func hash_into(h: StateHasher) -> void:
	for f in INT_FIELDS:
		h.add_ints(get(f))
	h.add_f32s(pts_x)
	h.add_f32s(pts_y)
	for v in [arena.position.x, arena.position.y, arena.size.x, arena.size.y]:
		h.add_f32(v)
