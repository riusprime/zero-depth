class_name BatchRows
extends RefCounted
## The batched avatars' rows (BatchAvatars): one row of packed doubles per slot, laid out as native/src/zd_avatar.h
## lays it out (the same field numbers), and the copies between a row and its avatar's fields that change after setup
## (AvatarBase's, then its kind's: HordeAvatar's, ChargerAvatar's, StoneThrowerAvatar's here, the solo model kinds'
## in their row files). The native calls take `st` and give it back; every write into it from GDScript goes through
## this object so the array is changed in place. Presentation only (EI-07).

## A row's fields (native/src/zd_avatar.h, the same numbers).
const STRIDE := 124
const T := 0
const FLINCH_T := 1
const FLINCH_S := 2
const FLINCH_D := 3
const FLINCH_KNOCK := 5
const HOLD := 6
const STRIKE_S := 7
const STRIKE_END := 8
const FRESH := 9
const LAST_TICK := 10
const LAST_POS := 11
const VEL := 13
const HIT := 15
const REST_XF := 19
const XF := 31
const H_GLOW := 43
const H_MUZZLE := 44
const H_TELL := 45
const H_STATE := 46
const H_STATE_TICK := 47
const H_TICKS_IN := 48
const H_HEALING := 49
const H_RISE := 50
const H_WIND := 51
const H_STRIKE := 52
const H_WALK := 53
const H_WALK_T := 54
const H_LAST_AT := 55
const H_DIE := 58
const H_LIFT := 59
const H_BODY := 60
const H_D := 72
const H_IS_MODEL := 76
const H_MODEL_SCALE := 77
const H_HEIGHT := 78
const H_WALK_Z := 79
const C_VISOR := 43
const C_TELL := 44
const C_STATE := 45
const C_SPEED := 46
const C_WALK := 47
const C_PHASE := 48
const C_WIND := 49
const C_LUNGE := 50
const C_DAZE := 51
const C_RISE := 52
const C_RISE_NOW := 53
const C_LUNGE_NOW := 54
const C_CROUCH_NOW := 55
const C_Y_NOW := 56
const C_LIFT := 57
const C_DIE := 58
const S_VISOR := 43
const S_STATE := 44
const S_STATE_TICKS := 45
const S_TICKS := 46
const S_ATK := 49
const S_ATK_SIM := 50
const S_WALK := 51
const S_PHASE := 52
const S_SPEED := 53
const S_FWD := 54
const S_RISE := 56
const S_PUFF := 57
const S_DIE := 58
const S_DROP := 59
const S_DROP_FROM := 60
const S_ROCK_SHOWN := 63
const S_LIFT := 64
const S_SCALE := 65
const S_OFF := 66
const S_VD := 84
## The Stone Thrower's joint offsets in its row (S_OFF, three floats each).
const S_OFF_KEYS := ["pelvis", "neck", "shoulder", "elbow", "wrist", "hip"]

## The rows, STRIDE doubles per slot.
var st := PackedFloat64Array()


func count() -> int:
	return st.size() / STRIDE


## One more row (zeros until its avatar is exported).
func grow() -> void:
	st.resize(st.size() + STRIDE)


## The last row copied over row `to`, then dropped (a slot's removal: the last one takes its place).
func move_last(to: int) -> void:
	var last := count() - 1
	if to != last:
		for q in STRIDE:
			st[to * STRIDE + q] = st[last * STRIDE + q]
	st.resize(last * STRIDE)


## The hit look `v` into row `k`.
func set_hit(k: int, v: Vector4) -> void:
	var o := k * STRIDE + HIT
	st[o] = v.x
	st[o + 1] = v.y
	st[o + 2] = v.z
	st[o + 3] = v.w


## Row `k`'s value at `field`.
func value(k: int, field: int) -> float:
	return st[k * STRIDE + field]


## Row `k`'s avatar transform.
func transform_of(k: int) -> Transform3D:
	return _get_xf(k * STRIDE + XF)


## Avatar `a`'s fields into row `k`.
func from_avatar(k: int, a: AvatarBase) -> void:
	var o := k * STRIDE
	st[o + T] = a._t
	st[o + FLINCH_T] = a._flinch_t
	st[o + FLINCH_S] = a._flinch_s
	st[o + FLINCH_D] = a._flinch_dir.x
	st[o + FLINCH_D + 1] = a._flinch_dir.y
	st[o + FLINCH_KNOCK] = a._flinch_knock
	st[o + HOLD] = a._hold
	st[o + STRIKE_S] = a._strike_s
	st[o + STRIKE_END] = a._strike_end_s
	st[o + FRESH] = 1.0 if a._fresh else 0.0
	st[o + LAST_TICK] = a._last_tick
	st[o + LAST_POS] = a._last_pos.x
	st[o + LAST_POS + 1] = a._last_pos.y
	st[o + VEL] = a._vel.x
	st[o + VEL + 1] = a._vel.y
	for q in 4:
		st[o + HIT + q] = a._hit[q]
	_put_xf(o + REST_XF, a._rest_xf)
	_put_xf(o + XF, a.transform)
	var h := a as HordeAvatar
	if h != null:
		st[o + H_GLOW] = h._glow_e
		st[o + H_MUZZLE] = 0.0  # (the native row's muzzle column: no batched kind has one now)
		st[o + H_TELL] = h._tell_p
		st[o + H_STATE] = h._state
		st[o + H_STATE_TICK] = h._state_tick
		st[o + H_TICKS_IN] = h._ticks_in
		st[o + H_HEALING] = 1.0 if h._healing else 0.0
		st[o + H_RISE] = h._rise
		st[o + H_WIND] = h._wind
		st[o + H_STRIKE] = h._strike
		st[o + H_WALK] = h._walk
		st[o + H_WALK_T] = h._walk_t
		st[o + H_WALK_Z] = h._walk_z
		st[o + H_LAST_AT] = h._last_at.x
		st[o + H_LAST_AT + 1] = h._last_at.y
		st[o + H_LAST_AT + 2] = h._last_at.z
		st[o + H_DIE] = h._die_t
		st[o + H_LIFT] = h._vat_lift
		_put_xf(o + H_BODY, h._vat_body)
		for q in 4:
			st[o + H_D + q] = h._vat_d[q]
		st[o + H_IS_MODEL] = 1.0 if h._is_model else 0.0
		st[o + H_MODEL_SCALE] = h._model_scale
		st[o + H_HEIGHT] = h.height
		return
	var th := a as StoneThrowerAvatar
	if th != null:
		_export_thrower(o, th)
		return
	if _export_solo(o, a):
		return
	var c := a as ChargerAvatar
	st[o + C_VISOR] = c._visor_e
	st[o + C_TELL] = c._tell_p
	st[o + C_STATE] = c._state
	st[o + C_SPEED] = c._speed
	st[o + C_WALK] = c._walk
	st[o + C_PHASE] = c._phase
	st[o + C_WIND] = c._wind
	st[o + C_LUNGE] = c._lunge
	st[o + C_DAZE] = c._daze
	st[o + C_RISE] = c._rise
	st[o + C_RISE_NOW] = c._rise_now
	st[o + C_LUNGE_NOW] = c._lunge_now
	st[o + C_CROUCH_NOW] = c._crouch_now
	st[o + C_Y_NOW] = c._y_now
	st[o + C_LIFT] = c._vat_lift
	st[o + C_DIE] = c._die_t


## Row `k` into avatar `a`'s fields.
func to_avatar(k: int, a: AvatarBase) -> void:
	var o := k * STRIDE
	a._t = st[o + T]
	a._flinch_t = st[o + FLINCH_T]
	a._flinch_s = st[o + FLINCH_S]
	a._flinch_dir = Vector2(st[o + FLINCH_D], st[o + FLINCH_D + 1])
	a._flinch_knock = st[o + FLINCH_KNOCK]
	a._hold = st[o + HOLD]
	a._strike_s = st[o + STRIKE_S]
	a._strike_end_s = st[o + STRIKE_END]
	a._fresh = st[o + FRESH] != 0.0
	a._last_tick = int(st[o + LAST_TICK])
	a._last_pos = Vector2(st[o + LAST_POS], st[o + LAST_POS + 1])
	a._vel = Vector2(st[o + VEL], st[o + VEL + 1])
	a._hit = Vector4(st[o + HIT], st[o + HIT + 1], st[o + HIT + 2], st[o + HIT + 3])
	a._rest_xf = _get_xf(o + REST_XF)
	a.transform = _get_xf(o + XF)
	var h := a as HordeAvatar
	if h != null:
		h._glow_e = st[o + H_GLOW]
		h._tell_p = st[o + H_TELL]
		h._state = int(st[o + H_STATE])
		h._state_tick = int(st[o + H_STATE_TICK])
		h._ticks_in = int(st[o + H_TICKS_IN])
		h._healing = st[o + H_HEALING] != 0.0
		h._rise = st[o + H_RISE]
		h._wind = st[o + H_WIND]
		h._strike = st[o + H_STRIKE]
		h._walk = st[o + H_WALK]
		h._walk_t = st[o + H_WALK_T]
		h._walk_z = st[o + H_WALK_Z]
		h._last_at = Vector3(st[o + H_LAST_AT], st[o + H_LAST_AT + 1], st[o + H_LAST_AT + 2])
		h._die_t = st[o + H_DIE]
		h._vat_lift = st[o + H_LIFT]
		h._vat_body = _get_xf(o + H_BODY)
		h._vat_d = Vector4(st[o + H_D], st[o + H_D + 1], st[o + H_D + 2], st[o + H_D + 3])
		return
	var th := a as StoneThrowerAvatar
	if th != null:
		_import_thrower(o, th)
		return
	if _import_solo(o, a):
		return
	var c := a as ChargerAvatar
	c._visor_e = st[o + C_VISOR]
	c._tell_p = st[o + C_TELL]
	c._state = int(st[o + C_STATE])
	c._speed = st[o + C_SPEED]
	c._walk = st[o + C_WALK]
	c._phase = st[o + C_PHASE]
	c._wind = st[o + C_WIND]
	c._lunge = st[o + C_LUNGE]
	c._daze = st[o + C_DAZE]
	c._rise = st[o + C_RISE]
	c._rise_now = st[o + C_RISE_NOW]
	c._lunge_now = st[o + C_LUNGE_NOW]
	c._crouch_now = st[o + C_CROUCH_NOW]
	c._y_now = st[o + C_Y_NOW]
	c._vat_lift = st[o + C_LIFT]
	c._die_t = st[o + C_DIE]


## A Stone Thrower's own fields into its row at `o` (its model's scale and joint offsets too: they never change).
func _export_thrower(o: int, th: StoneThrowerAvatar) -> void:
	st[o + S_VISOR] = th._visor_mat.emission_energy_multiplier
	st[o + S_STATE] = th._state
	st[o + S_STATE_TICKS] = th._state_ticks
	st[o + S_TICKS] = th._ticks.x
	st[o + S_TICKS + 1] = th._ticks.y
	st[o + S_TICKS + 2] = th._ticks.z
	st[o + S_ATK] = th._atk
	st[o + S_ATK_SIM] = th._atk_sim
	st[o + S_WALK] = th._walk
	st[o + S_PHASE] = th._phase
	st[o + S_SPEED] = th._speed
	st[o + S_FWD] = th._fwd.x
	st[o + S_FWD + 1] = th._fwd.y
	st[o + S_RISE] = th._rise
	st[o + S_PUFF] = th._puff
	st[o + S_DIE] = th._die_t
	st[o + S_DROP] = 1.0 if th._drop else 0.0
	st[o + S_DROP_FROM] = th._drop_from.x
	st[o + S_DROP_FROM + 1] = th._drop_from.y
	st[o + S_DROP_FROM + 2] = th._drop_from.z
	st[o + S_ROCK_SHOWN] = th._rock_shown
	st[o + S_LIFT] = th._lift
	st[o + S_SCALE] = th._scale
	for j in S_OFF_KEYS.size():
		var v: Vector3 = th._off[S_OFF_KEYS[j]]
		st[o + S_OFF + j * 3] = v.x
		st[o + S_OFF + j * 3 + 1] = v.y
		st[o + S_OFF + j * 3 + 2] = v.z
	for q in th._vd.size():
		st[o + S_VD + q] = th._vd[q]


## A solo model kind's own fields (its row file's: from its first field on) into the row at `o`; false for the others.
func _export_solo(o: int, a: AvatarBase) -> bool:
	var first := 0
	var row := PackedFloat64Array()
	if a is NeedleAvatar:
		first = BatchNeedleRow.FIRST
		row = BatchNeedleRow.fields(a as NeedleAvatar)
	elif a is RockLurkerAvatar:
		first = BatchLurker.FIRST
		row = BatchLurker.fields(a as RockLurkerAvatar)
	elif a is WardenAvatar:
		first = BatchWarden.W_CRACK
		row = BatchWarden.export_row(a as WardenAvatar)
	elif a is SniperAvatar:
		first = BatchSniperRow.FIRST
		row = BatchSniperRow.fields(a as SniperAvatar)
	elif a is ArcCasterAvatar:
		first = BatchArcCaster.FIRST
		row = BatchArcCaster.fields(a as ArcCasterAvatar)
	elif a is LensDroneAvatar:
		first = BatchLensDrone.FIRST
		row = BatchLensDrone.fields(a as LensDroneAvatar)
	elif a is BombDroneAvatar:
		first = BatchBombDrone.FIRST
		row = BatchBombDrone.fields(a as BombDroneAvatar)
	else:
		return false
	for q in row.size():
		st[o + first + q] = row[q]
	return true


## The row at `o` into a solo model kind's own fields (its row file's); false for the others.
func _import_solo(o: int, a: AvatarBase) -> bool:
	if a is NeedleAvatar:
		BatchNeedleRow.load(a as NeedleAvatar, st.slice(o + BatchNeedleRow.FIRST, o + STRIDE))
	elif a is RockLurkerAvatar:
		BatchLurker.take(a as RockLurkerAvatar, st, o)
	elif a is WardenAvatar:
		BatchWarden.import_row(a as WardenAvatar, st.slice(o + BatchWarden.W_CRACK, o + STRIDE))
	elif a is SniperAvatar:
		BatchSniperRow.load(
			a as SniperAvatar, st.slice(o + BatchSniperRow.FIRST, o + BatchSniperRow.END)
		)
	elif a is ArcCasterAvatar:
		BatchArcCaster.take(a as ArcCasterAvatar, st, o)
	elif a is LensDroneAvatar:
		BatchLensDrone.load(a as LensDroneAvatar, st, o)
	elif a is BombDroneAvatar:
		BatchBombDrone.take(a as BombDroneAvatar, st, o)
	else:
		return false
	return true


## A Stone Thrower's row at `o` into its fields (the visor's material only when its glow changed).
func _import_thrower(o: int, th: StoneThrowerAvatar) -> void:
	var visor := st[o + S_VISOR]
	if th._visor_mat.emission_energy_multiplier != visor:
		th._visor_mat.emission_energy_multiplier = visor
	th._state = int(st[o + S_STATE])
	th._state_ticks = int(st[o + S_STATE_TICKS])
	th._ticks = Vector3i(int(st[o + S_TICKS]), int(st[o + S_TICKS + 1]), int(st[o + S_TICKS + 2]))
	th._atk = st[o + S_ATK]
	th._atk_sim = st[o + S_ATK_SIM]
	th._walk = st[o + S_WALK]
	th._phase = st[o + S_PHASE]
	th._speed = st[o + S_SPEED]
	th._fwd = Vector2(st[o + S_FWD], st[o + S_FWD + 1])
	th._rise = st[o + S_RISE]
	th._puff = st[o + S_PUFF]
	th._die_t = st[o + S_DIE]
	th._drop = st[o + S_DROP] != 0.0
	th._drop_from = Vector3(st[o + S_DROP_FROM], st[o + S_DROP_FROM + 1], st[o + S_DROP_FROM + 2])
	th._rock_shown = st[o + S_ROCK_SHOWN]
	th._lift = st[o + S_LIFT]
	for q in th._vd.size():
		th._vd[q] = st[o + S_VD + q]


func _put_xf(o: int, xf: Transform3D) -> void:
	var b := xf.basis
	st[o] = b.x.x
	st[o + 1] = b.y.x
	st[o + 2] = b.z.x
	st[o + 3] = xf.origin.x
	st[o + 4] = b.x.y
	st[o + 5] = b.y.y
	st[o + 6] = b.z.y
	st[o + 7] = xf.origin.y
	st[o + 8] = b.x.z
	st[o + 9] = b.y.z
	st[o + 10] = b.z.z
	st[o + 11] = xf.origin.z


func _get_xf(o: int) -> Transform3D:
	return Transform3D(
		Vector3(st[o], st[o + 4], st[o + 8]),
		Vector3(st[o + 1], st[o + 5], st[o + 9]),
		Vector3(st[o + 2], st[o + 6], st[o + 10]),
		Vector3(st[o + 3], st[o + 7], st[o + 11])
	)
