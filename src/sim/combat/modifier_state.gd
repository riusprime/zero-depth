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
## v0.9.5 FC2 (BombMods): the Bomb cards' rows, one a bomb waiting or a ring growing (kind, place, tick due, tick born,
## blast in mm, damage, aim, root, id) and Ring's hits (id * 65536 + actor). Hashed only while any row is set (older
## digests unchanged).
var bm_next := 0
var bm_id := PackedInt32Array()
var bm_kind := PackedInt32Array()
var bm_at := PackedVector2Array()
var bm_due := PackedInt32Array()
var bm_born := PackedInt32Array()
var bm_r := PackedInt32Array()
var bm_dmg := PackedInt32Array()
var bm_ang := PackedInt32Array()
var bm_root := PackedInt32Array()
var bm_hit := PackedInt32Array()
## v0.9.5 FC3 (VoidMods): the Void cards' rows, one a live void's state, a void to open or a ring growing (kind and
## flags, the void's projectile id, place or target, mine stop, tick due, tick born, aim, aura and pull in mm, damage,
## life, ring radius in mm, root) and Ring's hits (id * 65536 + actor). Hashed only while any row is set.
var vm_next := 0
var vm_id := PackedInt32Array()
var vm_kind := PackedInt32Array()
var vm_pid := PackedInt32Array()
var vm_at := PackedVector2Array()
var vm_stop := PackedVector2Array()
var vm_due := PackedInt32Array()
var vm_born := PackedInt32Array()
var vm_ang := PackedInt32Array()
var vm_aura := PackedInt32Array()
var vm_pull := PackedInt32Array()
var vm_dmg := PackedInt32Array()
var vm_life := PackedInt32Array()
var vm_r := PackedInt32Array()
var vm_root := PackedInt32Array()
var vm_hit := PackedInt32Array()
## v0.9.5 FC6 (GlaiveMods): the Glaive cards' rows, one a live disc's state or a disc to open (kind and flags, the
## disc's projectile id, place, tick due, tick born, angle, damage, radius in mm, aux and aux2 (see GlaiveMods), root)
## and the per-enemy hit gaps of Ring and Mine (row id, actor id, the tick the gap ends). Hashed only while set.
var gm_next := 0
var gm_id := PackedInt32Array()
var gm_kind := PackedInt32Array()
var gm_pid := PackedInt32Array()
var gm_at := PackedVector2Array()
var gm_due := PackedInt32Array()
var gm_born := PackedInt32Array()
var gm_ang := PackedInt32Array()
var gm_dmg := PackedInt32Array()
var gm_r := PackedInt32Array()
var gm_aux := PackedInt32Array()
var gm_aux2 := PackedInt32Array()
var gm_root := PackedInt32Array()
var gm_hit_row := PackedInt32Array()
var gm_hit_actor := PackedInt32Array()
var gm_hit_until := PackedInt32Array()
## v0.9.5 FC4 (LanceMods): the Lance cards' rows, one a live lance's state, a ghost lance to open, a ring growing or a
## split shard (kind and flags, the lance's projectile id, place, tick due, tick born, angle, damage, radius in mm,
## aux (bounces of a ghost, enemies a lance has split on), root) and Ring's hits (id * 65536 + actor). Hashed only
## while any row is set.
var lm_next := 0
var lm_id := PackedInt32Array()
var lm_kind := PackedInt32Array()
var lm_pid := PackedInt32Array()
var lm_at := PackedVector2Array()
var lm_due := PackedInt32Array()
var lm_born := PackedInt32Array()
var lm_ang := PackedInt32Array()
var lm_dmg := PackedInt32Array()
var lm_r := PackedInt32Array()
var lm_aux := PackedInt32Array()
var lm_root := PackedInt32Array()
var lm_hit := PackedInt32Array()

## v0.9.5 FC5 (RuneMods): the Rune Explosion cards' rows, one a burst's meta (kind and flags, the burst's uid in rm_ref,
## its fixed centre), a held lightning ring, a shrinking shield, a trap or a shard (kind and flags, uid, place, tick
## born, life in ticks, damage, root, radius in mm, the source actor or burst, aim) and the hits (row uid, actor id).
## Hashed only while any row is set (older digests unchanged).
var rm_next := 0
var rm_id := PackedInt32Array()
var rm_kind := PackedInt32Array()
var rm_at := PackedVector2Array()
var rm_born := PackedInt32Array()
var rm_life := PackedInt32Array()
var rm_dmg := PackedInt32Array()
var rm_root := PackedInt32Array()
var rm_r := PackedInt32Array()
var rm_ref := PackedInt32Array()
var rm_ang := PackedInt32Array()
var rm_hit_row := PackedInt32Array()
var rm_hit_foe := PackedInt32Array()
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
		or bm_touched()
		or vm_touched()
		or gm_touched()
		or lm_touched()
		or rm_touched()
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


## v0.9.5 FC2: a Bomb card's row is set.
func bm_touched() -> bool:
	return bm_next != 0 or not bm_kind.is_empty()


func bm_clear() -> void:
	bm_next = 0
	bm_id = PackedInt32Array()
	bm_kind = PackedInt32Array()
	bm_at = PackedVector2Array()
	bm_due = PackedInt32Array()
	bm_born = PackedInt32Array()
	bm_r = PackedInt32Array()
	bm_dmg = PackedInt32Array()
	bm_ang = PackedInt32Array()
	bm_root = PackedInt32Array()
	bm_hit = PackedInt32Array()


## v0.9.5 FC3: a Void card's row is set.
func vm_touched() -> bool:
	return vm_next != 0 or not vm_kind.is_empty()


func vm_clear() -> void:
	vm_next = 0
	vm_id = PackedInt32Array()
	vm_kind = PackedInt32Array()
	vm_pid = PackedInt32Array()
	vm_at = PackedVector2Array()
	vm_stop = PackedVector2Array()
	vm_due = PackedInt32Array()
	vm_born = PackedInt32Array()
	vm_ang = PackedInt32Array()
	vm_aura = PackedInt32Array()
	vm_pull = PackedInt32Array()
	vm_dmg = PackedInt32Array()
	vm_life = PackedInt32Array()
	vm_r = PackedInt32Array()
	vm_root = PackedInt32Array()
	vm_hit = PackedInt32Array()


## v0.9.5 FC6: a Glaive card's row is set.
func gm_touched() -> bool:
	return gm_next != 0 or not gm_kind.is_empty()


func gm_clear() -> void:
	gm_next = 0
	gm_id = PackedInt32Array()
	gm_kind = PackedInt32Array()
	gm_pid = PackedInt32Array()
	gm_at = PackedVector2Array()
	gm_due = PackedInt32Array()
	gm_born = PackedInt32Array()
	gm_ang = PackedInt32Array()
	gm_dmg = PackedInt32Array()
	gm_r = PackedInt32Array()
	gm_aux = PackedInt32Array()
	gm_aux2 = PackedInt32Array()
	gm_root = PackedInt32Array()
	gm_hit_row = PackedInt32Array()
	gm_hit_actor = PackedInt32Array()
	gm_hit_until = PackedInt32Array()


## v0.9.5 FC4: a Lance card's row is set.
func lm_touched() -> bool:
	return lm_next != 0 or not lm_kind.is_empty()


func lm_clear() -> void:
	lm_next = 0
	lm_id = PackedInt32Array()
	lm_kind = PackedInt32Array()
	lm_pid = PackedInt32Array()
	lm_at = PackedVector2Array()
	lm_due = PackedInt32Array()
	lm_born = PackedInt32Array()
	lm_ang = PackedInt32Array()
	lm_dmg = PackedInt32Array()
	lm_r = PackedInt32Array()
	lm_aux = PackedInt32Array()
	lm_root = PackedInt32Array()
	lm_hit = PackedInt32Array()


## v0.9.5 FC5: a Rune Explosion card's row is set.
func rm_touched() -> bool:
	return rm_next != 0 or not rm_kind.is_empty()


func rm_clear() -> void:
	rm_next = 0
	rm_id = PackedInt32Array()
	rm_kind = PackedInt32Array()
	rm_born = PackedInt32Array()
	rm_life = PackedInt32Array()
	rm_dmg = PackedInt32Array()
	rm_root = PackedInt32Array()
	rm_r = PackedInt32Array()
	rm_ref = PackedInt32Array()
	rm_ang = PackedInt32Array()
	rm_hit_row = PackedInt32Array()
	rm_hit_foe = PackedInt32Array()
	rm_at = PackedVector2Array()


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
	if bm_touched():  # v0.9.5 FC2: only while a Bomb card's row is set
		h.add_string("bm")
		h.add_int(bm_next)
		for arr: PackedInt32Array in [
			bm_id, bm_kind, bm_due, bm_born, bm_r, bm_dmg, bm_ang, bm_root, bm_hit
		]:
			h.add_ints(arr)
		h.add_int(bm_at.size())
		for p in bm_at:
			h.add_f32(p.x)
			h.add_f32(p.y)
	if vm_touched():  # v0.9.5 FC3: only while a Void card's row is set
		h.add_string("vm")
		h.add_int(vm_next)
		for arr: PackedInt32Array in [
			vm_id,
			vm_kind,
			vm_pid,
			vm_due,
			vm_born,
			vm_ang,
			vm_aura,
			vm_pull,
			vm_dmg,
			vm_life,
			vm_r,
			vm_root,
			vm_hit
		]:
			h.add_ints(arr)
		for arr: PackedVector2Array in [vm_at, vm_stop]:
			h.add_int(arr.size())
			for p in arr:
				h.add_f32(p.x)
				h.add_f32(p.y)
	if gm_touched():  # v0.9.5 FC6: only while a Glaive card's row is set
		h.add_string("gm")
		h.add_int(gm_next)
		for arr: PackedInt32Array in [
			gm_id,
			gm_kind,
			gm_pid,
			gm_due,
			gm_born,
			gm_ang,
			gm_dmg,
			gm_r,
			gm_aux,
			gm_aux2,
			gm_root,
			gm_hit_row,
			gm_hit_actor,
			gm_hit_until
		]:
			h.add_ints(arr)
		h.add_int(gm_at.size())
		for p in gm_at:
			h.add_f32(p.x)
			h.add_f32(p.y)
	if lm_touched():  # v0.9.5 FC4: only while a Lance card's row is set
		h.add_string("lm")
		h.add_int(lm_next)
		for arr: PackedInt32Array in [
			lm_id, lm_kind, lm_pid, lm_due, lm_born, lm_ang, lm_dmg, lm_r, lm_aux, lm_root, lm_hit
		]:
			h.add_ints(arr)
		h.add_int(lm_at.size())
		for p in lm_at:
			h.add_f32(p.x)
			h.add_f32(p.y)
	if rm_touched():  # v0.9.5 FC5: only while a Rune Explosion card's row is set
		h.add_string("rmx")
		h.add_int(rm_next)
		for arr: PackedInt32Array in [
			rm_id,
			rm_kind,
			rm_born,
			rm_life,
			rm_dmg,
			rm_root,
			rm_r,
			rm_ref,
			rm_ang,
			rm_hit_row,
			rm_hit_foe
		]:
			h.add_ints(arr)
		h.add_int(rm_at.size())
		for p in rm_at:
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
