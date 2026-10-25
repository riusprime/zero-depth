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
## v0.9.0 AF1b (Lance): the Lance release's push back still to come (ticks) and its step a tick (m). Hashed only
## while one runs (older digests unchanged).
var recoil_t := 0
var recoil_step := Vector2.ZERO
## v0.6.5 WN5a (WandCasts): the small spells cast for the views (parallel arrays, oldest first): the tick, the child
## spec's book key, where from, which way, and 1 for a trigger's cast. View data only: not hashed, not in touched().
var cast_tick := PackedInt32Array()
var cast_key := PackedStringArray()
var cast_pos := PackedVector2Array()
var cast_angle := PackedInt32Array()
var cast_flag := PackedInt32Array()
## v0.9.0 VP (owner Q10, the Void form; VoidShots): an enemy a Void shot's aura hit waits for its next tick of that
## shot (parallel arrays: the shot's projectile id, the enemy's actor id, the first tick it may be hit again). An entry
## leaves once its tick comes. Hashed only while one waits (older digests unchanged).
var void_shot := PackedInt32Array()
var void_foe := PackedInt32Array()
var void_next := PackedInt32Array()
## v0.8.0 MR (owner O91; FireRhythm): Rapid Fire's ramp (the consecutive shots so far, the tick of the last shot) and
## Flurry's burst (the swing's place in its burst, 1 = the first after a pause; the tick its last swing ends); and
## SecondaryProc's carry (per mille of a status stack a secondary hit owes, so halved stacks are exact on average).
## Hashed only when set (older digests unchanged).
var ramp_n := 0
var ramp_tick := 0
var burst_n := 0
var burst_free := 0
var sec_carry := 0
## v0.8.0 RM (owner O91; Remnants, SIM_CONTRACTS §8l): the remnants alive, oldest first (parallel arrays): a uid (from
## rem_next), the kind (RemnantRule.Kind), the card that left it, its cast's book key (AttackBook.remnant_hook), its
## card's slot and trigger section, its activation's hook level (depth, proc) and the root that left it, the tick it
## was left, its life (ticks), hit gap (ticks), charges left (-1: until its life ends) and the damage of the hit that
## left it; where (a segment's two ends, an anchor's point in rem_a; a mark's or a fragment's enemy's last place), its
## direction (1/4096 turns), its enemy (an actor id; a thread's first projectile id) and second projectile (-1), and
## its count (a fragment's). Hit gaps: per remnant uid and enemy id, the tick of the last hit. The activations this
## tick (rem_act_tick, rem_act_n); Threadline's last bolt (projectile id, the tick, its key); Grand Finale's last
## release; Dodge Imprint's point and the tick it lapses (-1: none). Hashed only once a remnant card acted (older
## digests unchanged).
var rem_uid := PackedInt32Array()
var rem_kind := PackedInt32Array()
var rem_card := PackedStringArray()
var rem_key := PackedStringArray()
var rem_slot := PackedInt32Array()
var rem_section := PackedInt32Array()
var rem_depth := PackedInt32Array()
var rem_proc := PackedInt32Array()
var rem_root := PackedInt32Array()
var rem_born := PackedInt32Array()
var rem_life := PackedInt32Array()
var rem_gap := PackedInt32Array()
var rem_charges := PackedInt32Array()
var rem_basis := PackedInt32Array()
var rem_a := PackedVector2Array()
var rem_b := PackedVector2Array()
var rem_dir := PackedInt32Array()
var rem_target := PackedInt32Array()
var rem_target2 := PackedInt32Array()
var rem_count := PackedInt32Array()
## v0.8.0 RM: the path a remnant belongs to (the uid of its first segment: a slash's arc replays as one; its own uid
## otherwise): its hit gaps are kept per path.
var rem_group := PackedInt32Array()
var rem_next := 0
var gap_uid := PackedInt32Array()
var gap_target := PackedInt32Array()
var gap_tick := PackedInt32Array()
var rem_act_tick := -1
var rem_act_n := 0
var link_id := -1
var link_tick := 0
var link_key := ""
var finale_tick := 0
var imprint_at := Vector2.ZERO
var imprint_until := -1


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
		or recoil_t != 0
		or not void_shot.is_empty()
		or ramp_n != 0
		or burst_n != 0
		or sec_carry != 0
		or remnants_touched()
	)


## v0.8.0 RM: a remnant card has acted (Remnants): its block is hashed from then on.
func remnants_touched() -> bool:
	return rem_next != 0 or link_id != -1 or imprint_until != -1 or finale_tick != 0


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
	if recoil_t != 0:  # v0.9.0 AF1b: only while the Lance's push back runs
		h.add_string("recoil")
		h.add_int(recoil_t)
		h.add_f32(recoil_step.x)
		h.add_f32(recoil_step.y)
	if not void_shot.is_empty():  # v0.9.0 VP: only while a Void shot's aura waits on an enemy
		h.add_string("void")
		h.add_ints(void_shot)
		h.add_ints(void_foe)
		h.add_ints(void_next)
	if ramp_n != 0 or burst_n != 0 or sec_carry != 0:  # v0.8.0 MR: only once a rhythm or a carry is set
		h.add_string("mr")
		for v in [ramp_n, ramp_tick, burst_n, burst_free, sec_carry]:
			h.add_int(v)
	if remnants_touched():  # v0.8.0 RM: only once a remnant card acted (older digests unchanged)
		_hash_remnants(h)


func _hash_remnants(h: StateHasher) -> void:
	h.add_string("rm")
	for arr: PackedInt32Array in [
		rem_uid,
		rem_kind,
		rem_slot,
		rem_section,
		rem_depth,
		rem_proc,
		rem_root,
		rem_born,
		rem_life,
		rem_gap,
		rem_charges,
		rem_basis,
		rem_dir,
		rem_target,
		rem_target2,
		rem_count,
		rem_group,
		gap_uid,
		gap_target,
		gap_tick,
	]:
		h.add_ints(arr)
	h.add_string(",".join(rem_card))
	h.add_string(",".join(rem_key))
	for arr: PackedVector2Array in [rem_a, rem_b]:
		h.add_int(arr.size())
		for p in arr:
			h.add_f32(p.x)
			h.add_f32(p.y)
	for v in [rem_next, rem_act_tick, rem_act_n, link_id, link_tick, finale_tick, imprint_until]:
		h.add_int(v)
	h.add_string(link_key)
	h.add_f32(imprint_at.x)
	h.add_f32(imprint_at.y)
