class_name BladeState
extends RefCounted
## v0.6.5 WN4: the Blade pool's state in play (World.blade; BladeForms), per floor. Copied by WorldSnapshot like every
## state class; hashed by BladeForms.hash_into once touched (worlds that never use a Blade card hash as before).

## The tick the last dash ended (-1 = none: Counter's window opens there), and the tick of the last slash that
## countered (-1 = none: its WHEN_COUNTER hooks fire on that tick only).
var dash_end := -1
var counter_tick := -1
## Enemies pushed by Heavy's hits (parallel arrays): their ids, the way (unit), metres per tick, ticks left.
var k_ids := PackedInt32Array()
var k_dirs := PackedVector2Array()
var k_step := PackedFloat32Array()
var k_left := PackedInt32Array()
## Orbit Blades' blades (parallel arrays): the spec's AttackBook key, the tick it was thrown and the tick it ends, its
## first angle (1/4096 turns), damage, base damage, root, hook level (depth, proc), its orbit radius and blade radius,
## and the tick it may hit again.
var o_key := PackedStringArray()
var o_start := PackedInt32Array()
var o_end := PackedInt32Array()
var o_phase := PackedInt32Array()
var o_damage := PackedInt32Array()
var o_root := PackedInt32Array()
var o_depth := PackedInt32Array()
var o_proc := PackedInt32Array()
var o_reach := PackedFloat32Array()
var o_radius := PackedFloat32Array()
var o_ready := PackedInt32Array()
## Enemy shots Parry Edge cut, in all (the tests and the HUD read it).
var parried := 0
## What the view draws (BladeForms.FX_*; newest last, at most BladeForms.FX_MAX): the kind, tick, where, which way
## (1/4096 turns) and two sizes (an arc's half width and reach, a line's length and width, a burst's radius).
var fx_kind := PackedInt32Array()
var fx_tick := PackedInt32Array()
var fx_pos := PackedVector2Array()
var fx_angle := PackedInt32Array()
var fx_a := PackedFloat32Array()
var fx_b := PackedFloat32Array()


func touched() -> bool:
	return (
		dash_end != -1
		or counter_tick != -1
		or parried != 0
		or not k_ids.is_empty()
		or not o_key.is_empty()
		or not fx_kind.is_empty()
	)


func remove_knock(j: int) -> void:
	k_ids.remove_at(j)
	k_dirs.remove_at(j)
	k_step.remove_at(j)
	k_left.remove_at(j)


## (Packed arrays are values in GDScript: each column is removed by name.)
func remove_orbit(j: int) -> void:
	o_key.remove_at(j)
	o_start.remove_at(j)
	o_end.remove_at(j)
	o_phase.remove_at(j)
	o_damage.remove_at(j)
	o_root.remove_at(j)
	o_depth.remove_at(j)
	o_proc.remove_at(j)
	o_reach.remove_at(j)
	o_radius.remove_at(j)
	o_ready.remove_at(j)


func remove_fx(j: int) -> void:
	fx_kind.remove_at(j)
	fx_tick.remove_at(j)
	fx_pos.remove_at(j)
	fx_angle.remove_at(j)
	fx_a.remove_at(j)
	fx_b.remove_at(j)


func hash_into(h: StateHasher) -> void:
	for v in [dash_end, counter_tick, parried]:
		h.add_int(v)
	h.add_ints(k_ids)
	h.add_ints(k_left)
	for d in k_dirs:
		h.add_f32(d.x)
		h.add_f32(d.y)
	for f in k_step:
		h.add_f32(f)
	h.add_string(",".join(o_key))
	for arr: PackedInt32Array in [o_start, o_end, o_phase, o_damage, o_root, o_depth, o_proc, o_ready]:
		h.add_ints(arr)
	for f in o_reach:
		h.add_f32(f)
	for f in o_radius:
		h.add_f32(f)
	h.add_ints(fx_kind)
	h.add_ints(fx_tick)
	h.add_ints(fx_angle)
