class_name BatchWarden
extends RefCounted
## The Warden in the enemy batch (EnemyBatch, BatchAvatars): its own fields in its batch row (the W_* columns,
## native/src/zd_avatar.h: the same numbers; ZdCrowd runs its sync, frame step and pose in zd_avatar_warden.cpp), its
## sync's extra inputs, and its slam's dust ring kept in the tree. The ring is the one node of a VAT Warden's that is
## drawn as a node (SoloVat.LIVE): it hangs from the avatar's copy in BatchHeld's holder (the root's place, the facing,
## the avatar), so the engine draws it where it drew the node Warden's. The Rubble Warden's crust (VariantLooks.dress:
## a node under its facing) hangs from the facing's copy the same way. Presentation only (EI-07).

## The Warden's fields in its row (zd_avatar.h W_*), from W_CRACK on.
const W_CRACK := 43
const W_DUST_T := 63
const W_SLAM_R := 62
const W_PIV := 66
const W_VD := 99
## The joints' pivots in the row (W_PIV, three floats each), zd_avatar_warden.cpp's order.
const PIVOT_KEYS: Array[StringName] = [
	&"head",
	&"arm_r_u",
	&"arm_r_l",
	&"arm_l_u",
	&"arm_l_l",
	&"leg_r_u",
	&"leg_r_l",
	&"leg_r_f",
	&"leg_l_u",
	&"leg_l_l",
	&"leg_l_f",
]


## A Warden's own fields (W_CRACK to the row's end), in row order (its pivots and scale too: they never change).
static func export_row(w: WardenAvatar) -> PackedFloat64Array:
	var out := PackedFloat64Array(
		[
			w._crack,
			w._state,
			w._state_ticks,
			w._windup,
			w._hp,
			w._speed,
			w._dir.x,
			w._dir.y,
			w._omega,
			w._phase,
			w._stride,
			w._raise,
			w._slam,
			w._rise,
			w._shake,
			w._hurt_t,
			w._die_t,
			w._last_fy,
			1.0 if w._have_fy else 0.0,
			w._slam_r,
			w._dust_t,
			w._lift,
			w._scale,
		]
	)
	for key in PIVOT_KEYS:
		var v: Vector3 = w._pivots[key]
		out.append(v.x)
		out.append(v.y)
		out.append(v.z)
	for q in w._vd.size():
		out.append(w._vd[q])
	return out


## A Warden's row from W_CRACK on (`r`, export_row's order) into its fields; its glows' materials only when they
## changed.
static func import_row(w: WardenAvatar, r: PackedFloat64Array) -> void:
	w._crack = r[0]
	w._state = int(r[1])
	w._state_ticks = int(r[2])
	w._windup = r[3]
	w._hp = int(r[4])
	w._speed = r[5]
	w._dir = Vector2(r[6], r[7])
	w._omega = r[8]
	w._phase = r[9]
	w._stride = r[10]
	w._raise = r[11]
	w._slam = r[12]
	w._rise = r[13]
	w._shake = r[14]
	w._hurt_t = r[15]
	w._die_t = r[16]
	w._last_fy = r[17]
	w._have_fy = r[18] != 0.0
	w._slam_r = r[19]
	w._dust_t = r[20]
	w._lift = r[21]
	var vd := W_VD - W_CRACK
	for q in w._vd.size():
		w._vd[q] = r[vd + q]
	var eye := w._vd[WardenAvatar.EYE]
	if w._eye_mat.emission_energy_multiplier != eye:
		w._eye_mat.emission_energy_multiplier = eye
	if w._crack_mat.emission_energy_multiplier != w._crack:
		w._crack_mat.emission_energy_multiplier = w._crack


## The sync's inputs: its windup (the telegraph's progress in any state, as WardenAvatar.sync reads it), then its
## MORE values (BatchAvatars.MORE a slot): its HP, the telegraph's slam radius and whether it gave one.
static func note(reader: WorldReader, i: int) -> Array:
	var tg := reader.telegraph(i)
	return [
		float(tg.get("progress", 0)) / 1000.0,
		reader.actor_hp(i),
		float(tg.get("radius", 0.0)),
		1.0 if tg.has("radius") else 0.0,
	]


## WardenAvatar.sync's values from those inputs, run on the object (the rows turned off with a sync pending).
static func apply_in_script(
	w: WardenAvatar,
	tick: int,
	pos: Vector2,
	state: int,
	windup: float,
	more: PackedFloat64Array,
	o: int
) -> void:
	(
		w
		. apply_state(
			{
				"tick": tick,
				"pos": pos,
				"state": state,
				"windup": windup,
				"radius": more[o + 1] if more[o + 2] != 0.0 else w._slam_r,
				"hp": int(more[o]),
			}
		)
	)


## Batched Warden `id`'s dust ring into the tree, under the avatar's copy in its holder (BatchHeld.hold), and the
## Rubble Warden's crust under the facing's copy.
static func hold(
	batch: EnemyBatch, id: int, w: WardenAvatar, root: Node3D, facing: Node3D
) -> Array:
	var h := BatchHeld.hold(batch, id, w, root, facing)
	w.remove_child(w.dust)
	(h[BatchHeld.BODY] as Node3D).add_child(w.dust)
	if root.has_meta(&"crust"):  # The Rubble Warden's, where it hung from the facing
		var crust: Node3D = root.get_meta(&"crust")
		facing.remove_child(crust)
		(h[BatchHeld.TURN] as Node3D).add_child(crust)
	BatchHeld.follow(h)
	return h


## After the avatars' frame step (batched Warden `id`, slot `k` of the batch's avatars): the root's place now, the ring
## shown from the row's clock (the native rows: the avatar's own step shows it otherwise), and while it shows, the
## avatar's transform now.
static func show(h: Array, batch: EnemyBatch, id: int, k: int) -> void:
	var w: WardenAvatar = h[BatchHeld.AVATAR]
	if not is_instance_valid(w) or not is_instance_valid(w.dust):
		return
	BatchHeld.place(h, batch, id)
	var avatars := batch.avatars
	if avatars.on:
		var t := avatars.row_value(k, W_DUST_T)
		if t >= 0.0 or w.dust.visible:
			w.dust.show_at(t, avatars.row_value(k, W_SLAM_R))
	if w.dust.visible:
		BatchHeld.lean(h, avatars, k)
