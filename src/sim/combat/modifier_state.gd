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
## v0.8.0 MR (owner O91): a secondary attack (an Echo's repeat, a Double Slash echo: SecondaryProc).
const FLAG_SECONDARY := 4

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
## The walk's last trail drop (and whether one is set), the tick of the last root attack (Ascension's charge waits
## charge_ticks after it), the last charged attack, the last hit Aether Shell absorbed, the last trail drop (the
## views). (The dash's start was kept here too, written and hashed but never read: gone, audit G-15.)
var trail_at := Vector2.ZERO
var trail_on := false
var last_attack := 0
var charge_tick := -1
var shell_tick := -1
var trail_tick := -1
## v0.6.5 WN3 (GunForms, G13 Charge): the ticks the shot in the barrel has charged (0 = none).
var hold_t := 0
## v0.6.5 WN5a (WandCasts): the small spells cast for the views (parallel arrays, oldest first): the tick, the child
## spec's book key, where from, which way, and 1 for a trigger's cast. View data only: not hashed, not in touched().
var cast_tick := PackedInt32Array()
var cast_key := PackedStringArray()
var cast_pos := PackedVector2Array()
var cast_angle := PackedInt32Array()
var cast_flag := PackedInt32Array()
## v0.8.0 P2 (owner O24, Void; BlackHoles): the black holes standing, oldest first (parallel arrays): where, the tick it
## opened, and each pulse's damage. Hashed only while one stands (older digests unchanged).
var hole_pos := PackedVector2Array()
var hole_from := PackedInt32Array()
var hole_dmg := PackedInt32Array()
## v0.8.0 MR (owner O91; FireRhythm): Rapid Fire's ramp (the consecutive shots so far, the tick of the last shot) and
## Flurry's burst (the swing's place in its burst, 1 = the first after a pause; the tick its last swing ends); and
## SecondaryProc's carry (per mille of a status stack a secondary hit owes, so halved stacks are exact on average).
## Hashed only when set (older digests unchanged).
var ramp_n := 0
var ramp_tick := 0
var burst_n := 0
var burst_free := 0
var sec_carry := 0


func touched() -> bool:
	return (
		not q_key.is_empty()
		or not counts.is_empty()
		or trail_on
		or last_attack != 0
		or charge_tick != -1
		or shell_tick != -1
		or trail_tick != -1
		or hold_t != 0
		or not hole_pos.is_empty()
		or ramp_n != 0
		or burst_n != 0
		or sec_carry != 0
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
	h.add_f32(trail_at.x)
	h.add_f32(trail_at.y)
	for v in [1 if trail_on else 0, last_attack, charge_tick, shell_tick, trail_tick]:
		h.add_int(v)
	if hold_t != 0:  # v0.6.5 WN3: only while a shot charges (older digests unchanged)
		h.add_int(hold_t)
	if not hole_pos.is_empty():  # v0.8.0 P2: only while a black hole stands (older digests unchanged)
		h.add_string("holes")
		h.add_int(hole_pos.size())
		for p in hole_pos:
			h.add_f32(p.x)
			h.add_f32(p.y)
		h.add_ints(hole_from)
		h.add_ints(hole_dmg)
	if ramp_n != 0 or burst_n != 0 or sec_carry != 0:  # v0.8.0 MR: only once a rhythm or a carry is set
		h.add_string("mr")
		for v in [ramp_n, ramp_tick, burst_n, burst_free, sec_carry]:
			h.add_int(v)
