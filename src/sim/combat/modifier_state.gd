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
## v0.9.5 FC0 (RuneExplosion): the rune bursts alive, oldest first (parallel arrays): a uid (from rune_next), the spec's
## book key, the tick it starts, its full radius (m), its damage and root, SimEvent tags. The enemies each burst hit
## (burst uid, actor id) and the enemies being shoved (actor id, direction, ticks left). Hashed only while any is set
## (older digests unchanged).
var rune_uid := PackedInt32Array()
var rune_key := PackedStringArray()
var rune_born := PackedInt32Array()
var rune_radius := PackedFloat32Array()
var rune_damage := PackedInt32Array()
var rune_root := PackedInt32Array()
var rune_next := 0
var rune_hit_uid := PackedInt32Array()
var rune_hit_foe := PackedInt32Array()
var rune_push_id := PackedInt32Array()
var rune_push_dir := PackedVector2Array()
var rune_push_left := PackedInt32Array()
## v0.9.5 FC1 (LaserMods): the Laser cards' state. lz_aim: the beam's own aim while Homing or Big Shot lag it (-1: the
## player's); lz_hold: ticks the beam has been held (Rapid Fire's ramp); lz_targets: Homing's actor ids, nearest first;
## lz_mine_*: the mines alive (place, tick dropped, damage) and the tick the next drops (0: not yet set);
## lz_echo_*: Echo's waiting strikes, one row a main leg (tick due, from, to, width, damage). Hashed only while any is
## set (older digests unchanged).
var lz_aim := -1
var lz_hold := 0
var lz_targets := PackedInt32Array()
var lz_mine_next := 0
var lz_mine_at := PackedVector2Array()
var lz_mine_born := PackedInt32Array()
var lz_mine_dmg := PackedInt32Array()
var lz_echo_due := PackedInt32Array()
var lz_echo_from := PackedVector2Array()
var lz_echo_to := PackedVector2Array()
var lz_echo_r := PackedFloat32Array()
var lz_echo_dmg := PackedInt32Array()
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
		or not rune_uid.is_empty()
		or not rune_push_id.is_empty()
		or ramp_n != 0
		or burst_n != 0
		or sec_carry != 0
		or lz_touched()
		or remnants_touched()
	)


## v0.9.5 FC1: a Laser card's state is set.
func lz_touched() -> bool:
	return (
		lz_aim != -1
		or lz_hold != 0
		or lz_mine_next != 0
		or not lz_targets.is_empty()
		or not lz_mine_at.is_empty()
		or not lz_echo_due.is_empty()
	)


func lz_clear() -> void:
	lz_aim = -1
	lz_hold = 0
	lz_mine_next = 0
	lz_targets = PackedInt32Array()
	lz_mine_at = PackedVector2Array()
	lz_mine_born = PackedInt32Array()
	lz_mine_dmg = PackedInt32Array()
	lz_echo_due = PackedInt32Array()
	lz_echo_from = PackedVector2Array()
	lz_echo_to = PackedVector2Array()
	lz_echo_r = PackedFloat32Array()
	lz_echo_dmg = PackedInt32Array()


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
	if not rune_uid.is_empty() or not rune_push_id.is_empty():  # v0.9.5 FC0: only while a rune burst lives
		h.add_string("rune")
		h.add_string(",".join(rune_key))
		for arr: PackedInt32Array in [
			rune_uid,
			rune_born,
			rune_damage,
			rune_root,
			rune_hit_uid,
			rune_hit_foe,
			rune_push_id,
			rune_push_left
		]:
			h.add_ints(arr)
		h.add_f32s(rune_radius)
		h.add_int(rune_next)
		for d in rune_push_dir:
			h.add_f32(d.x)
			h.add_f32(d.y)
	if lz_touched():  # v0.9.5 FC1: only while a Laser card's state is set
		h.add_string("lz")
		for v in [lz_aim, lz_hold, lz_mine_next]:
			h.add_int(v)
		for arr: PackedInt32Array in [
			lz_targets, lz_mine_born, lz_mine_dmg, lz_echo_due, lz_echo_dmg
		]:
			h.add_ints(arr)
		h.add_f32s(lz_echo_r)
		for arr: PackedVector2Array in [lz_mine_at, lz_echo_from, lz_echo_to]:
			h.add_int(arr.size())
			for p in arr:
				h.add_f32(p.x)
				h.add_f32(p.y)
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
