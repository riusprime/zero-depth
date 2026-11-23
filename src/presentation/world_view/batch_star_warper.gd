class_name BatchStarWarper
extends RefCounted
## The Star Warper in the enemy batch (EnemyBatch, BatchAvatars): its own fields in its batch row (the SW_* columns,
## native/src/zd_avatar.h: the same numbers; ZdCrowd runs its sync, frame step and pose in zd_avatar_star_warper.cpp),
## its sync run on the object, and its ground disc kept in the tree. The disc is the one node of a VAT Warper's that is
## drawn as a node (SoloVat.LIVE): it hangs from the avatar's copy in BatchHeld's holder (the root's place, the facing,
## the avatar), so the engine draws it where it drew the node Warper's. Presentation only (EI-07).

const SHARD_GLOW := 43
const SHADOW := 44
const LIFT := 45
const STATE := 46
const WIND := 47
const STUN := 48
const HP := 49
const GONE := 50
const SLASH := 51
const RISE := 52
const REEL := 53
const GLIDE := 54
const DIR := 55
const WAVE := 57
const ORBIT := 58
const OMEGA := 59
const HURT_T := 60
const HURT_SIDE := 61
const DIE := 62
const LAST_FY := 63
const HAVE_FY := 64
const VD := 65
## The first of them in the row, and how many.
const FIRST := SHARD_GLOW
const COUNT := VD + 21 - FIRST


## The Warper's fields from FIRST on, in the row's order.
static func fields(a: StarWarperAvatar) -> PackedFloat64Array:
	var r := PackedFloat64Array()
	r.resize(COUNT)
	r[SHARD_GLOW - FIRST] = a._shard_glow
	r[SHADOW - FIRST] = a.shadow.scale.x
	r[LIFT - FIRST] = a._lift
	r[STATE - FIRST] = a._state
	r[WIND - FIRST] = a._wind
	r[STUN - FIRST] = 1.0 if a._stun else 0.0
	r[HP - FIRST] = a._hp
	r[GONE - FIRST] = a._gone
	r[SLASH - FIRST] = a._slash_s
	r[RISE - FIRST] = a._rise
	r[REEL - FIRST] = a._reel
	r[GLIDE - FIRST] = a._glide
	r[DIR - FIRST] = a._dir.x
	r[DIR + 1 - FIRST] = a._dir.y
	r[WAVE - FIRST] = a._wave
	r[ORBIT - FIRST] = a._orbit
	r[OMEGA - FIRST] = a._omega
	r[HURT_T - FIRST] = a._hurt_t
	r[HURT_SIDE - FIRST] = a._hurt_side
	r[DIE - FIRST] = a._die_t
	r[LAST_FY - FIRST] = a._last_fy
	r[HAVE_FY - FIRST] = 1.0 if a._have_fy else 0.0
	for q in a._vd.size():
		r[VD - FIRST + q] = a._vd[q]
	return r


## Row `st` at `o` into the Warper's fields, its glows' materials and its ground disc's scale (each only when it
## changed).
static func take(a: StarWarperAvatar, st: PackedFloat64Array, o: int) -> void:
	var glow := st[o + SHARD_GLOW]
	a._shard_glow = glow
	if a._shard_mat.emission_energy_multiplier != glow:
		a._shard_mat.emission_energy_multiplier = glow
	var visor := st[o + VD + StarWarperAvatar.VISOR]
	if a._visor_mat.emission_energy_multiplier != visor:
		a._visor_mat.emission_energy_multiplier = visor
	var sh := Vector3(st[o + SHADOW], 1, st[o + SHADOW])
	if is_instance_valid(a.shadow) and a.shadow.scale != sh:
		a.shadow.scale = sh
	a._lift = st[o + LIFT]
	a._state = int(st[o + STATE])
	a._wind = st[o + WIND]
	a._stun = st[o + STUN] != 0.0
	a._hp = int(st[o + HP])
	a._gone = st[o + GONE]
	a._slash_s = st[o + SLASH]
	a._rise = st[o + RISE]
	a._reel = st[o + REEL]
	a._glide = st[o + GLIDE]
	a._dir = Vector2(st[o + DIR], st[o + DIR + 1])
	a._wave = st[o + WAVE]
	a._orbit = st[o + ORBIT]
	a._omega = st[o + OMEGA]
	a._hurt_t = st[o + HURT_T]
	a._hurt_side = st[o + HURT_SIDE]
	a._die_t = st[o + DIE]
	a._last_fy = st[o + LAST_FY]
	a._have_fy = st[o + HAVE_FY] != 0.0
	var vd := PackedFloat32Array()
	vd.resize(StarWarperAvatar.VAT_DRIVES.size())
	for q in vd.size():
		vd[q] = st[o + VD + q]
	a._vd = vd


## The Warper's sync inputs past the common ones (BatchAvatars.note_sync, at `o` of `more`): its HP, whether it is
## stunned.
static func note(reader: WorldReader, i: int, more: PackedFloat64Array, o: int) -> void:
	more[o] = reader.actor_hp(i)
	more[o + 1] = 1.0 if reader.warper_stunned(i) else 0.0


## StarWarperAvatar.sync's values from the batch's inputs (its HP and its stun the first MORE values), run on the
## object (the rows turned off with a sync pending).
static func apply_in_script(
	a: StarWarperAvatar,
	tick: int,
	pos: Vector2,
	state: int,
	windup: float,
	more: PackedFloat64Array,
	o: int
) -> void:
	var s := {
		"tick": tick,
		"state": state,
		"pos": pos,
		"hp": int(more[o]),
		"stunned": more[o + 1] != 0.0,
	}
	if state == WorldReader.STATE_WINDUP:
		s["windup"] = windup
	a.apply_state(s)


## Batched Warper `id`'s ground disc into the tree, under the avatar's copy in its holder (BatchHeld.hold).
static func hold(
	batch: EnemyBatch, id: int, a: StarWarperAvatar, root: Node3D, facing: Node3D
) -> Array:
	var h := BatchHeld.hold(batch, id, a, root, facing)
	a.remove_child(a.shadow)
	(h[BatchHeld.BODY] as Node3D).add_child(a.shadow)
	BatchHeld.follow(h)
	return h


## After the avatars' frame step (batched Warper `id`, slot `k` of the batch's avatars): the root's place now, the
## disc's scale from the row (the native rows: the avatar's own pose sets it otherwise) and the avatar's transform now
## (a flinch leans the disc with the body).
static func show(h: Array, batch: EnemyBatch, id: int, k: int) -> void:
	var a: StarWarperAvatar = h[BatchHeld.AVATAR]
	if not is_instance_valid(a) or not is_instance_valid(a.shadow):
		return
	BatchHeld.place(h, batch, id)
	var avatars := batch.avatars
	if avatars.on:
		var s := avatars.row_value(k, SHADOW)
		var sh := Vector3(s, 1, s)
		if a.shadow.scale != sh:
			a.shadow.scale = sh
	BatchHeld.lean(h, avatars, k)
