class_name ModifierState
extends RefCounted
## v0.6.0 MX4: the modifier engine's state in play (World.mx; ModifierRuntime), per floor: the launches waiting for
## their tick (Twin Cast's repeats, a delayed hook's child: Long Shadow's afterimage), the counters of the every-N
## rules (an EVERY_NTH hook's launches, an inherited every-N status's hits on a form), and the moments' and body
## rules' marks (the dash's start, the walk since the last trail drop, the last attack for Ascension, the last absorb
## of Aether Shell). Copied by WorldSnapshot like every state class; hashed by ModifierRuntime.hash_into once the
## build has a modifier.

## A queued launch's flags: a repeat (it never repeats again), launched from where the player is when it fires.
const FLAG_REPEAT := 1
const FLAG_AT_PLAYER := 2

## The queued launches, oldest first (parallel arrays): the spec's AttackBook key, the tick it fires, where from and
## which way, its damage and base damage, root, SimEvent tags, effect id, hook level (depth, proc), flags, the hook id
## its chain carries (ancestry; "" for a repeat), a burst radius set at run time (0 = the spec's), and a bolt's muzzle.
var q_key := PackedStringArray()
var q_tick := PackedInt32Array()
var q_pos := PackedVector2Array()
var q_angle := PackedInt32Array()
var q_damage := PackedInt32Array()
var q_base := PackedInt32Array()
var q_root := PackedInt32Array()
var q_tags := PackedInt32Array()
var q_effect := PackedStringArray()
var q_depth := PackedInt32Array()
var q_proc := PackedInt32Array()
var q_flags := PackedInt32Array()
var q_hook := PackedStringArray()
var q_radius := PackedFloat32Array()
var q_muzzle := PackedFloat32Array()
## The every-N counters, by name (ModifierRuntime.count).
var counts := {}
## The dash's start (Long Shadow's afterimage stands there), the walk's last trail drop (and whether one is set), the
## tick of the last root attack (Ascension's charge waits charge_ticks after it), the last charged attack, the last
## hit Aether Shell absorbed, the last trail drop (the views).
var dash_from := Vector2.ZERO
var trail_at := Vector2.ZERO
var trail_on := false
var last_attack := 0
var charge_tick := -1
var shell_tick := -1
var trail_tick := -1


func touched() -> bool:
	return (
		not q_key.is_empty()
		or not counts.is_empty()
		or trail_on
		or last_attack != 0
		or charge_tick != -1
		or shell_tick != -1
		or trail_tick != -1
	)


func remove_at(k: int) -> void:
	q_key.remove_at(k)
	q_tick.remove_at(k)
	q_pos.remove_at(k)
	q_angle.remove_at(k)
	q_damage.remove_at(k)
	q_base.remove_at(k)
	q_root.remove_at(k)
	q_tags.remove_at(k)
	q_effect.remove_at(k)
	q_depth.remove_at(k)
	q_proc.remove_at(k)
	q_flags.remove_at(k)
	q_hook.remove_at(k)
	q_radius.remove_at(k)
	q_muzzle.remove_at(k)


func hash_into(h: StateHasher) -> void:
	h.add_string(",".join(q_key))
	for arr: PackedInt32Array in [
		q_tick, q_angle, q_damage, q_base, q_root, q_tags, q_depth, q_proc, q_flags
	]:
		h.add_ints(arr)
	h.add_string(",".join(q_effect))
	h.add_string(",".join(q_hook))
	h.add_f32s(q_radius)
	h.add_f32s(q_muzzle)
	h.add_int(q_pos.size())
	for p in q_pos:
		h.add_f32(p.x)
		h.add_f32(p.y)
	var keys := counts.keys()
	keys.sort()
	for k: String in keys:
		h.add_string(k)
		h.add_int(int(counts[k]))
	for p: Vector2 in [dash_from, trail_at]:
		h.add_f32(p.x)
		h.add_f32(p.y)
	for v in [1 if trail_on else 0, last_attack, charge_tick, shell_tick, trail_tick]:
		h.add_int(v)
