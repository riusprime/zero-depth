class_name KitState
extends RefCounted
## The Vent and Skill buttons' state (v0.3.5 K, owner F1 and F18; World.kit). Hashed only once touched, so worlds
## that never press them (the kernel goldens) keep their hash. PlayerSkill runs it; views read it through
## WorldReader.

## Buffered presses (ticks left, as World.input_buffer).
var skill_buffer := 0
var vent_buffer := 0
## Ticks until the skill may start again, and the tick of the current skill (0 = none running; it counts from 1).
var skill_cd := 0
var skill_t := 0
## The current (or last) skill: its angle (1/4096 turns), root, start tick and where it started.
var skill_angle := 0
var skill_root := 0
var skill_tick := -1
var skill_from := Vector2.ZERO
## The last cleave or blast: its tick and where it went off; a blast's pellet end points, in pellet order.
var hit_tick := -1
var hit_pos := Vector2.ZERO
var pellet_ends := PackedVector2Array()
## Enemies being knocked back: their ids, directions (unit) and ticks left.
var knock_ids := PackedInt32Array()
var knock_dirs := PackedVector2Array()
var knock_left := PackedInt32Array()
## The last Vent press under Hot (the cold click), as a tick.
var cold_tick := -1


func touched() -> bool:
	return (
		skill_buffer != 0
		or vent_buffer != 0
		or skill_cd != 0
		or skill_t != 0
		or skill_tick != -1
		or hit_tick != -1
		or cold_tick != -1
		or not knock_ids.is_empty()
	)


func hash_into(h: StateHasher) -> void:
	for v in [skill_buffer, vent_buffer, skill_cd, skill_t, skill_angle, skill_root, skill_tick]:
		h.add_int(v)
	for v in [hit_tick, cold_tick]:
		h.add_int(v)
	for p: Vector2 in [skill_from, hit_pos]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_int(pellet_ends.size())
	for p in pellet_ends:
		h.add_f32(p.x)
		h.add_f32(p.y)
	h.add_ints(knock_ids)
	h.add_ints(knock_left)
	for d in knock_dirs:
		h.add_f32(d.x)
		h.add_f32(d.y)
