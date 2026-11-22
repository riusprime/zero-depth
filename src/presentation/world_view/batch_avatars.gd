class_name BatchAvatars
extends RefCounted
## The batched enemies' avatars (EnemyBatch) run by the native library: each avatar's state (AvatarBase's,
## HordeAvatar's, ChargerAvatar's, StoneThrowerAvatar's, NeedleAvatar's (BatchNeedleRow), RockLurkerAvatar's
## (BatchLurker), WardenAvatar's (BatchWarden), SniperAvatar's (BatchSniperRow), ArcCasterAvatar's (BatchArcCaster),
## LensDroneAvatar's (BatchLensDrone), BombDroneAvatar's (BatchBombDrone), ScrapHoundAvatar's (BatchScrapHound) or
## CinderPriestAvatar's (BatchCinderPriest) fields that change after setup) is a row of packed doubles here, and ZdCrowd
## (native/src/zd_avatar*, the same arithmetic in the same order) applies each sync, steps each frame and writes
## VatCrowd's body and shadow instances from the rows: one call each, none per enemy.
## The rows hold the state while `on`; the avatar objects then hold old numbers, except around an event:
## - an event on an avatar (a flinch, a hold, a death, a sync or a step called on it: AvatarBase._touch) first copies
##   its row into it (pull) and marks it the holder (dirty); its own GDScript runs the event as before, and the batch
##   copies it back (push) before its next native call;
## - a read (a test's, a tool's: AvatarBase._peek) pulls the row without taking the state;
## - the hit look (show_hit) is written into the row straight away.
## The sync's inputs come from EnemyBatch.update (note_sync) and are applied in one call at the end of the views'
## sync (flush), with the catch-up steps of the enemies that came on screen (warm). Without the library, with
## EnemyBatch.native off, or with any avatar no native class covers, `on` is false and every avatar runs its own code.
## Presentation only (EI-07).

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
## A Stone Thrower's sync inputs past the common ones, a slot (zd_avatar.h MORE): its ticks into the state, its
## facing (x, y), the sim's lift, flight and recovery ticks; a Needle's and a Sniper's: its HP (the first); a Rock
## Lurker's: disguised, rumbling. A Warden's: its HP, the telegraph's slam radius, whether it gave one
## (BatchWarden.note). A Scrap Hound's: its HP, whether a hit stopped it (BatchScrapHound.note). A Cinder Priest's:
## its vent's numbers (BatchCinderPriest.note).
const MORE := 6
## The native classes (zd_avatar.h Class) by kind; 0: none.
const CHARGER_CLASS := 8
const STONE_THROWER_CLASS := 10
const NEEDLE_CLASS := 11
const WARDEN_CLASS := 12
const ROCK_LURKER_CLASS := 13
const SNIPER_CLASS := 14
const ARC_CASTER_CLASS := 15
const LENS_DRONE_CLASS := 17
const BOMB_DRONE_CLASS := 16
const SCRAP_HOUND_CLASS := 18
const CINDER_PRIEST_CLASS := 20
const CLASS_OF := {
	WorldReader.KIND_SWARMER: 1,
	WorldReader.KIND_SPLITTER: 2,
	WorldReader.KIND_SPLITLING: 3,
	WorldReader.KIND_SHIELD_BEARER: 4,
	WorldReader.KIND_MENDER: 5,
	WorldReader.KIND_MINE_LAYER: 6,
	WorldReader.KIND_CHARGER: 8,
	WorldReader.KIND_HATCHLING: 9,
	WorldReader.KIND_STONE_THROWER: STONE_THROWER_CLASS,
	WorldReader.KIND_NEEDLE: NEEDLE_CLASS,
	WorldReader.KIND_ROCK_LURKER: ROCK_LURKER_CLASS,
	WorldReader.KIND_WARDEN: WARDEN_CLASS,
	WorldReader.KIND_RUBBLE_WARDEN: WARDEN_CLASS,
	WorldReader.KIND_SNIPER: SNIPER_CLASS,
	WorldReader.KIND_ARC_CASTER: ARC_CASTER_CLASS,
	WorldReader.KIND_LENS_DRONE: LENS_DRONE_CLASS,
	WorldReader.KIND_BOMB_DRONE: BOMB_DRONE_CLASS,
	WorldReader.KIND_SCRAP_HOUND: SCRAP_HOUND_CLASS,
	WorldReader.KIND_CINDER_PRIEST: CINDER_PRIEST_CLASS,
}
## The owner's model kinds: native only with the model (their code bodies are never VAT-drawn).
const MODEL_CLASSES := [2, 3, 4, 5, 6]

## Whether the rows hold the state now.
var on := false
## The rows' serial: each native call that changes them moves it on (a row pulled at an older serial is old).
var serial := 0

var _st := PackedFloat64Array()
var _cls := PackedInt32Array()
var _avatars: Array[AvatarBase] = []
var _ids := PackedInt32Array()
## Add order (VatCrowd's entries are in it), and each slot's VatCrowd body and shadow set (-1: none).
var _seq := PackedInt64Array()
var _next_seq := 0
var _body_of := PackedInt32Array()
var _shadow_of := PackedInt32Array()
## The facing: its rotation.y, and (mode 1, once leaned by the Void) its whole transform.
var _fyaw := PackedFloat32Array()
var _fmode := PackedByteArray()
var _fx := PackedFloat32Array()
## The sync's inputs (note_sync) waiting for flush, and the catch-up steps.
var _pending := PackedByteArray()
var _in_state := PackedInt32Array()
var _in_heal := PackedByteArray()
var _in_windup := PackedFloat64Array()
var _in_x := PackedFloat32Array()
var _in_y := PackedFloat32Array()
var _in_more := PackedFloat64Array()
var _warm := PackedByteArray()
var _tick := 0
var _any_pending := false
## Whether each avatar processes (its set_process; the batch steps it) and holds the state (dirty), and the serial
## its object was last pulled at.
var _proc := PackedByteArray()
var _dirty := PackedByteArray()
var _pulled := PackedInt64Array()
var _any_dirty := false
var _none := 0
var _slot_of := {}


## The native class of `avatar` (0: none: its GDScript runs it).
static func class_of(avatar: AvatarBase) -> int:
	var h := avatar as HordeAvatar
	if h != null:
		if not h.vat:
			return 0
		var c: int = CLASS_OF.get(h.kind, 0)
		if c >= CHARGER_CLASS or (MODEL_CLASSES.has(c) and not h.has_model()):
			return 0
		return c
	var ch := avatar as ChargerAvatar
	if ch != null and ch.vat:
		return CLASS_OF.get(ch.kind, 0)
	var st := avatar as StoneThrowerAvatar
	if st != null and st.vat:
		return STONE_THROWER_CLASS
	var nd := avatar as NeedleAvatar
	if nd != null and nd.vat:
		return NEEDLE_CLASS
	var lk := avatar as RockLurkerAvatar
	if lk != null and lk.vat:
		return ROCK_LURKER_CLASS
	var wd := avatar as WardenAvatar
	if wd != null and wd.vat:
		return WARDEN_CLASS
	var sn := avatar as SniperAvatar
	if sn != null and sn.vat:
		return SNIPER_CLASS
	var ac := avatar as ArcCasterAvatar
	if ac != null and ac.vat:
		return ARC_CASTER_CLASS
	var ld := avatar as LensDroneAvatar
	if ld != null and ld.vat:
		return LENS_DRONE_CLASS
	var bd := avatar as BombDroneAvatar
	if bd != null and bd.vat:
		return BOMB_DRONE_CLASS
	if avatar is ScrapHoundAvatar and (avatar as ScrapHoundAvatar).vat:
		return SCRAP_HOUND_CLASS
	if avatar is CinderPriestAvatar and (avatar as CinderPriestAvatar).vat:
		return CINDER_PRIEST_CLASS
	return 0


## Whether every slot has a native class (else the whole batch runs in GDScript).
func all_native() -> bool:
	return _none == 0


func count() -> int:
	return _ids.size()


func add(id: int, avatar: AvatarBase, facing: Node3D, sets: Vector2i) -> void:
	var k := _ids.size()
	_slot_of[id] = k
	_ids.append(id)
	_avatars.append(avatar)
	avatar.set_meta(&"batch_id", id)
	var c := class_of(avatar)
	_cls.append(c)
	if c == 0:
		_none += 1
	_seq.append(_next_seq)
	_next_seq += 1
	_body_of.append(sets.x)
	_shadow_of.append(sets.y)
	_fyaw.append(facing.rotation.y)
	_fmode.append(0)
	for q in 12:
		_fx.append(0.0)
	_pending.append(0)
	_in_state.append(0)
	_in_heal.append(0)
	_in_windup.append(0.0)
	_in_x.append(0.0)
	_in_y.append(0.0)
	for q in MORE:
		_in_more.append(0.0)
	_warm.append(0)
	_proc.append(1 if avatar.is_processing() else 0)
	_dirty.append(0)
	_pulled.append(-1)
	_st.resize(_st.size() + STRIDE)
	if on:
		_export(k)
		avatar.native_owner = self


## Slot `k` goes (the last one takes its place, as EnemyBatch's columns do).
func remove(k: int) -> void:
	var last := _ids.size() - 1
	var a: Variant = _avatars[k]
	if on and is_instance_valid(a):
		if _dirty[k] == 0:  # The object keeps the latest numbers (a falling body's root may still be read)
			_import(k)
		a.native_owner = null
	if _cls[k] == 0:
		_none -= 1
	_slot_of.erase(_ids[k])
	if k != last:
		_ids[k] = _ids[last]
		_slot_of[_ids[k]] = k
		_avatars[k] = _avatars[last]
		for q in STRIDE:
			_st[k * STRIDE + q] = _st[last * STRIDE + q]
		for q in 12:
			_fx[k * 12 + q] = _fx[last * 12 + q]
		for q in MORE:
			_in_more[k * MORE + q] = _in_more[last * MORE + q]
	_ids.resize(last)
	_avatars.resize(last)
	_st.resize(last * STRIDE)
	_fx.resize(last * 12)
	_in_more.resize(last * MORE)
	for col: StringName in [
		&"_cls",
		&"_seq",
		&"_body_of",
		&"_shadow_of",
		&"_fyaw",
		&"_fmode",
		&"_pending",
		&"_in_state",
		&"_in_heal",
		&"_in_windup",
		&"_in_x",
		&"_in_y",
		&"_warm",
		&"_proc",
		&"_dirty",
		&"_pulled",
	]:
		var arr: Variant = get(col)
		if k != last:
			arr[k] = arr[last]
		arr.resize(last)
		set(col, arr)


## Turns the rows on (each avatar's state copied in) or off (copied back), as `want` says.
func set_on(want: bool) -> void:
	if want == on:
		return
	if want:
		for k in _ids.size():
			if not is_instance_valid(_avatars[k]):
				continue
			_export(k)
			_dirty[k] = 0
			_pulled[k] = -1
			_avatars[k].native_owner = self
			_proc[k] = 1 if _avatars[k].is_processing() else 0
	else:
		_flush_inputs_in_script()
		for k in _ids.size():
			if not is_instance_valid(_avatars[k]):
				continue
			if _dirty[k] == 0:
				_import(k)
			_dirty[k] = 0
			_avatars[k].native_owner = null
		_any_dirty = false
	on = want


## AvatarBase._touch: the event about to run on `avatar` runs on its row's numbers, and the object holds the state
## until the next native call.
func touch(avatar: AvatarBase) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0 or _dirty[k] == 1:
		return
	if _pulled[k] != serial:
		_import(k)
	_dirty[k] = 1
	_any_dirty = true


## AvatarBase._peek: the object gets its row's numbers (the rows keep the state).
func peek(avatar: AvatarBase) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0 or _dirty[k] == 1 or _pulled[k] == serial:
		return
	_import(k)


## AvatarBase.show_hit: the hit look `v` on `avatar`'s row (and its object).
func show_hit(avatar: AvatarBase, v: Vector4) -> void:
	var k: int = _slot_of.get(avatar.get_meta(&"batch_id", -1), -1)
	if k < 0:
		return
	var o := k * STRIDE + HIT
	_st[o] = v.x
	_st[o + 1] = v.y
	_st[o + 2] = v.z
	_st[o + 3] = v.w


## EnemyBatch.update: slot `k`'s sync from actor row `i` (the avatar's sync(), its inputs kept for flush).
func note_sync(k: int, reader: WorldReader, i: int) -> void:
	var state := reader.actor_state(i)
	_tick = reader.tick()
	_in_state[k] = state
	var c := _cls[k]
	if c == STONE_THROWER_CLASS:  # (its sync reads no windup: its own ticks into the state, its facing, the ticks)
		var o := k * MORE
		var fwd := Kin.dir(reader.actor_facing(i))
		var ticks := reader.thrower_ticks(i)
		_in_more[o] = reader.actor_state_ticks(i)
		_in_more[o + 1] = fwd.x
		_in_more[o + 2] = fwd.y
		_in_more[o + 3] = ticks.x
		_in_more[o + 4] = ticks.y
		_in_more[o + 5] = ticks.z
	elif c == ROCK_LURKER_CLASS:  # (its sync reads the windup in any state, and its disguise)
		var o := k * MORE
		_in_windup[k] = float(reader.telegraph(i).get("progress", 0)) / 1000.0
		_in_more[o] = 1.0 if RockLurkerAvatar.disguised(reader, i) else 0.0
		_in_more[o + 1] = 1.0 if reader.lurker_rumbling(i) else 0.0
	elif c == WARDEN_CLASS:
		var v := BatchWarden.note(reader, i)
		var o := k * MORE
		_in_windup[k] = v[0]
		_in_more[o] = v[1]
		_in_more[o + 1] = v[2]
		_in_more[o + 2] = v[3]
	else:
		_in_windup[k] = (
			float(reader.telegraph(i).get("progress", 0)) / 1000.0
			if state == WorldReader.STATE_WINDUP
			else 0.0
		)
		if c == NEEDLE_CLASS or c == SNIPER_CLASS or c == BOMB_DRONE_CLASS:  # (its HP: a hit's flinch)
			_in_more[k * MORE] = reader.actor_hp(i)
		elif c == SCRAP_HOUND_CLASS:  # (and whether a hit stopped it: the yelp)
			BatchScrapHound.note(reader, i, _in_more, k * MORE)
		elif c == CINDER_PRIEST_CLASS:  # (its vent's pulse, eruption and place, and its facing)
			BatchCinderPriest.note(reader, i, _in_more, k * MORE)
	if c >= CHARGER_CLASS:
		var p := reader.actor_pos(i)
		_in_x[k] = p.x
		_in_y[k] = p.y
	else:
		_in_heal[k] = 1 if c == 5 and reader.actor_heal_target(i) >= 0 else 0
	_pending[k] = 1
	_any_pending = true


## The facing of slot `k` turned to `yaw` (EnemyBatch.update), or leaned (`facing` given: its whole transform kept).
func facing_moved(k: int, facing: Node3D, leaned: bool) -> void:
	_fyaw[k] = facing.rotation.y
	if leaned:
		_fmode[k] = 1
	if _fmode[k] == 1:
		_put_fx(k * 12, facing.transform)


func set_processing(k: int, p_on: bool) -> void:
	_proc[k] = 1 if p_on else 0


## ActorViews' catch-up as slot `k` comes on screen (four 0.05 s steps after its sync).
func warm(k: int) -> void:
	_warm[k] = 1
	_any_pending = true


## The syncs noted since the last flush, applied in one native call (then the catch-ups).
func flush(crowd: Object, frame: Array) -> void:
	if not _any_pending:
		return
	_push()
	_st = crowd.call(
		&"apply_sync",
		_st,
		_cls,
		frame,
		_pending,
		_tick,
		_in_state,
		_in_heal,
		_in_windup,
		_in_x,
		_in_y,
		_in_more,
		_warm,
		_consts()
	)
	_pending.fill(0)
	_warm.fill(0)
	_any_pending = false
	serial += 1


## The frame step of every processing avatar not added this frame, in one native call.
func step(crowd: Object, frame: Array, born: PackedInt32Array, delta: float) -> void:
	_push()
	_st = crowd.call(
		&"step_avatars",
		_st,
		_cls,
		frame,
		_proc,
		born,
		Engine.get_process_frames(),
		delta,
		_consts()
	)
	serial += 1


## VatCrowd's sets `sets` ([index, body, period, drive floats, capacity] each) written natively: by set, [count,
## capacity, buffer, drive buffer].
func write_bodies(crowd: Object, frame: Array, bo: PackedVector3Array, sets: Array) -> Array:
	_push()
	var index := PackedInt32Array()
	var body := PackedByteArray()
	var period := PackedFloat64Array()
	var dn := PackedInt32Array()
	var caps := PackedInt32Array()
	for s: Array in sets:
		index.append(s[0])
		body.append(1 if s[1] else 0)
		period.append(s[2])
		dn.append(s[3])
		caps.append(s[4])
	return crowd.call(
		&"write_bodies",
		_st,
		_cls,
		frame,
		_body_of,
		_shadow_of,
		_seq,
		bo,
		index,
		body,
		period,
		dn,
		caps,
		_consts()
	)


## Slot `k`'s row's value at `field` (BatchWarden).
func row_value(k: int, field: int) -> float:
	return _st[k * STRIDE + field]


## Slot `k`'s avatar's own transform now (its row's while the rows hold the state).
func avatar_xf(k: int) -> Transform3D:
	if on and _dirty[k] == 0:
		return _get_xf(k * STRIDE + XF)
	return _avatars[k].transform


## The frame columns the native calls read beside the rows (the root at the batch's latest place).
func frame_columns(x1: PackedFloat32Array, y1: PackedFloat32Array, z1: PackedFloat32Array) -> Array:
	return [x1, y1, z1, _fyaw, _fmode, _fx]


## The pending syncs run on the objects (the rows are being turned off with syncs not yet applied).
func _flush_inputs_in_script() -> void:
	if not _any_pending:
		return
	_push()
	for k in _ids.size():
		if (_pending[k] == 0 and _warm[k] == 0) or not is_instance_valid(_avatars[k]):
			continue
		_import(k)
		var a := _avatars[k]
		a.native_owner = null
		if _pending[k] == 1:
			var o := k * MORE
			if _cls[k] == STONE_THROWER_CLASS:
				(
					(a as StoneThrowerAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"state_ticks": int(_in_more[o]),
							"facing": Vector2(_in_more[o + 1], _in_more[o + 2]),
							"ticks":
							Vector3i(
								int(_in_more[o + 3]), int(_in_more[o + 4]), int(_in_more[o + 5])
							),
						}
					)
				)
			elif _cls[k] == NEEDLE_CLASS:
				(
					(a as NeedleAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"windup": _in_windup[k],
							"hp": int(_in_more[o]),
						}
					)
				)
			elif _cls[k] == ROCK_LURKER_CLASS:
				(
					(a as RockLurkerAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"windup": _in_windup[k],
							"hidden": _in_more[o] != 0.0,
							"rumbling": _in_more[o + 1] != 0.0,
						}
					)
				)
			elif _cls[k] == WARDEN_CLASS:
				BatchWarden.apply_in_script(
					a as WardenAvatar,
					_tick,
					Vector2(_in_x[k], _in_y[k]),
					_in_state[k],
					_in_windup[k],
					_in_more,
					o
				)
			elif _cls[k] == SNIPER_CLASS:
				(
					(a as SniperAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"windup": _in_windup[k],
							"hp": int(_in_more[o]),
						}
					)
				)
			elif _cls[k] == LENS_DRONE_CLASS:
				BatchLensDrone.apply_in_script(a as LensDroneAvatar, _tick, _in_state[k])
			elif _cls[k] == ARC_CASTER_CLASS:
				(
					(a as ArcCasterAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"windup": _in_windup[k],
						}
					)
				)
			elif _cls[k] == BOMB_DRONE_CLASS:
				BatchBombDrone.apply_in_script(
					a as BombDroneAvatar,
					_tick,
					Vector2(_in_x[k], _in_y[k]),
					_in_state[k],
					_in_more,
					o
				)
			elif _cls[k] == SCRAP_HOUND_CLASS:
				BatchScrapHound.apply_in_script(a as ScrapHoundAvatar, self, k)
			elif _cls[k] == CINDER_PRIEST_CLASS:
				BatchCinderPriest.apply_in_script(a as CinderPriestAvatar, self, k)
			elif _cls[k] >= CHARGER_CLASS:
				(
					(a as ChargerAvatar)
					. apply_state(
						{
							"tick": _tick,
							"pos": Vector2(_in_x[k], _in_y[k]),
							"state": _in_state[k],
							"windup": _in_windup[k],
						}
					)
				)
			else:
				(
					(a as HordeAvatar)
					. apply_state(
						{
							"tick": _tick,
							"state": _in_state[k],
							"healing": _in_heal[k] == 1,
							"windup": _in_windup[k],
						}
					)
				)
		if _warm[k] == 1:
			for q in 4:
				a.advance(0.05)
		_export(k)
		a.native_owner = self
	_pending.fill(0)
	_warm.fill(0)
	_any_pending = false


func _consts() -> PackedFloat64Array:
	return PackedFloat64Array(
		[
			1.0 if ViewPrefs.reduced_motion else 0.0,
			WorldReader.STATE_SPAWN,
			WorldReader.STATE_MOVE,
			WorldReader.STATE_WINDUP,
			WorldReader.STATE_ACTIVE,
			WorldReader.STATE_RECOVER,
		]
	)


## The objects that held the state since the last native call copied back into their rows.
func _push() -> void:
	if not _any_dirty:
		return
	for k in _ids.size():
		if _dirty[k] == 1 and is_instance_valid(_avatars[k]):
			_export(k)
			_dirty[k] = 0
	_any_dirty = false


## Slot `k`'s avatar's fields into its row.
func _export(k: int) -> void:
	var a := _avatars[k]
	var o := k * STRIDE
	_st[o + T] = a._t
	_st[o + FLINCH_T] = a._flinch_t
	_st[o + FLINCH_S] = a._flinch_s
	_st[o + FLINCH_D] = a._flinch_dir.x
	_st[o + FLINCH_D + 1] = a._flinch_dir.y
	_st[o + FLINCH_KNOCK] = a._flinch_knock
	_st[o + HOLD] = a._hold
	_st[o + STRIKE_S] = a._strike_s
	_st[o + STRIKE_END] = a._strike_end_s
	_st[o + FRESH] = 1.0 if a._fresh else 0.0
	_st[o + LAST_TICK] = a._last_tick
	_st[o + LAST_POS] = a._last_pos.x
	_st[o + LAST_POS + 1] = a._last_pos.y
	_st[o + VEL] = a._vel.x
	_st[o + VEL + 1] = a._vel.y
	for q in 4:
		_st[o + HIT + q] = a._hit[q]
	_put_xf(o + REST_XF, a._rest_xf)
	_put_xf(o + XF, a.transform)
	var h := a as HordeAvatar
	if h != null:
		_st[o + H_GLOW] = h._glow_e
		_st[o + H_MUZZLE] = 0.0  # (the native row's muzzle column: no batched kind has one now)
		_st[o + H_TELL] = h._tell_p
		_st[o + H_STATE] = h._state
		_st[o + H_STATE_TICK] = h._state_tick
		_st[o + H_TICKS_IN] = h._ticks_in
		_st[o + H_HEALING] = 1.0 if h._healing else 0.0
		_st[o + H_RISE] = h._rise
		_st[o + H_WIND] = h._wind
		_st[o + H_STRIKE] = h._strike
		_st[o + H_WALK] = h._walk
		_st[o + H_WALK_T] = h._walk_t
		_st[o + H_WALK_Z] = h._walk_z
		_st[o + H_LAST_AT] = h._last_at.x
		_st[o + H_LAST_AT + 1] = h._last_at.y
		_st[o + H_LAST_AT + 2] = h._last_at.z
		_st[o + H_DIE] = h._die_t
		_st[o + H_LIFT] = h._vat_lift
		_put_xf(o + H_BODY, h._vat_body)
		for q in 4:
			_st[o + H_D + q] = h._vat_d[q]
		_st[o + H_IS_MODEL] = 1.0 if h._is_model else 0.0
		_st[o + H_MODEL_SCALE] = h._model_scale
		_st[o + H_HEIGHT] = h.height
		return
	var st := a as StoneThrowerAvatar
	if st != null:
		_export_thrower(o, st)
		return
	if _export_solo(o, a):
		return
	var c := a as ChargerAvatar
	_st[o + C_VISOR] = c._visor_e
	_st[o + C_TELL] = c._tell_p
	_st[o + C_STATE] = c._state
	_st[o + C_SPEED] = c._speed
	_st[o + C_WALK] = c._walk
	_st[o + C_PHASE] = c._phase
	_st[o + C_WIND] = c._wind
	_st[o + C_LUNGE] = c._lunge
	_st[o + C_DAZE] = c._daze
	_st[o + C_RISE] = c._rise
	_st[o + C_RISE_NOW] = c._rise_now
	_st[o + C_LUNGE_NOW] = c._lunge_now
	_st[o + C_CROUCH_NOW] = c._crouch_now
	_st[o + C_Y_NOW] = c._y_now
	_st[o + C_LIFT] = c._vat_lift
	_st[o + C_DIE] = c._die_t


## Slot `k`'s row into its avatar's fields (then the object is as new as the row).
func _import(k: int) -> void:
	_pulled[k] = serial
	var a := _avatars[k]
	var o := k * STRIDE
	a._t = _st[o + T]
	a._flinch_t = _st[o + FLINCH_T]
	a._flinch_s = _st[o + FLINCH_S]
	a._flinch_dir = Vector2(_st[o + FLINCH_D], _st[o + FLINCH_D + 1])
	a._flinch_knock = _st[o + FLINCH_KNOCK]
	a._hold = _st[o + HOLD]
	a._strike_s = _st[o + STRIKE_S]
	a._strike_end_s = _st[o + STRIKE_END]
	a._fresh = _st[o + FRESH] != 0.0
	a._last_tick = int(_st[o + LAST_TICK])
	a._last_pos = Vector2(_st[o + LAST_POS], _st[o + LAST_POS + 1])
	a._vel = Vector2(_st[o + VEL], _st[o + VEL + 1])
	a._hit = Vector4(_st[o + HIT], _st[o + HIT + 1], _st[o + HIT + 2], _st[o + HIT + 3])
	a._rest_xf = _get_xf(o + REST_XF)
	a.transform = _get_xf(o + XF)
	var h := a as HordeAvatar
	if h != null:
		h._glow_e = _st[o + H_GLOW]
		h._tell_p = _st[o + H_TELL]
		h._state = int(_st[o + H_STATE])
		h._state_tick = int(_st[o + H_STATE_TICK])
		h._ticks_in = int(_st[o + H_TICKS_IN])
		h._healing = _st[o + H_HEALING] != 0.0
		h._rise = _st[o + H_RISE]
		h._wind = _st[o + H_WIND]
		h._strike = _st[o + H_STRIKE]
		h._walk = _st[o + H_WALK]
		h._walk_t = _st[o + H_WALK_T]
		h._walk_z = _st[o + H_WALK_Z]
		h._last_at = Vector3(_st[o + H_LAST_AT], _st[o + H_LAST_AT + 1], _st[o + H_LAST_AT + 2])
		h._die_t = _st[o + H_DIE]
		h._vat_lift = _st[o + H_LIFT]
		h._vat_body = _get_xf(o + H_BODY)
		h._vat_d = Vector4(_st[o + H_D], _st[o + H_D + 1], _st[o + H_D + 2], _st[o + H_D + 3])
		return
	var st := a as StoneThrowerAvatar
	if st != null:
		_import_thrower(o, st)
		return
	if _import_solo(o, a):
		return
	var c := a as ChargerAvatar
	c._visor_e = _st[o + C_VISOR]
	c._tell_p = _st[o + C_TELL]
	c._state = int(_st[o + C_STATE])
	c._speed = _st[o + C_SPEED]
	c._walk = _st[o + C_WALK]
	c._phase = _st[o + C_PHASE]
	c._wind = _st[o + C_WIND]
	c._lunge = _st[o + C_LUNGE]
	c._daze = _st[o + C_DAZE]
	c._rise = _st[o + C_RISE]
	c._rise_now = _st[o + C_RISE_NOW]
	c._lunge_now = _st[o + C_LUNGE_NOW]
	c._crouch_now = _st[o + C_CROUCH_NOW]
	c._y_now = _st[o + C_Y_NOW]
	c._vat_lift = _st[o + C_LIFT]
	c._die_t = _st[o + C_DIE]


## A Stone Thrower's own fields into its row at `o` (its model's scale and joint offsets too: they never change).
func _export_thrower(o: int, st: StoneThrowerAvatar) -> void:
	_st[o + S_VISOR] = st._visor_mat.emission_energy_multiplier
	_st[o + S_STATE] = st._state
	_st[o + S_STATE_TICKS] = st._state_ticks
	_st[o + S_TICKS] = st._ticks.x
	_st[o + S_TICKS + 1] = st._ticks.y
	_st[o + S_TICKS + 2] = st._ticks.z
	_st[o + S_ATK] = st._atk
	_st[o + S_ATK_SIM] = st._atk_sim
	_st[o + S_WALK] = st._walk
	_st[o + S_PHASE] = st._phase
	_st[o + S_SPEED] = st._speed
	_st[o + S_FWD] = st._fwd.x
	_st[o + S_FWD + 1] = st._fwd.y
	_st[o + S_RISE] = st._rise
	_st[o + S_PUFF] = st._puff
	_st[o + S_DIE] = st._die_t
	_st[o + S_DROP] = 1.0 if st._drop else 0.0
	_st[o + S_DROP_FROM] = st._drop_from.x
	_st[o + S_DROP_FROM + 1] = st._drop_from.y
	_st[o + S_DROP_FROM + 2] = st._drop_from.z
	_st[o + S_ROCK_SHOWN] = st._rock_shown
	_st[o + S_LIFT] = st._lift
	_st[o + S_SCALE] = st._scale
	for j in S_OFF_KEYS.size():
		var v: Vector3 = st._off[S_OFF_KEYS[j]]
		_st[o + S_OFF + j * 3] = v.x
		_st[o + S_OFF + j * 3 + 1] = v.y
		_st[o + S_OFF + j * 3 + 2] = v.z
	for q in st._vd.size():
		_st[o + S_VD + q] = st._vd[q]


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
	elif a is ScrapHoundAvatar:
		first = BatchScrapHound.FIRST
		row = BatchScrapHound.fields(a as ScrapHoundAvatar)
	elif a is CinderPriestAvatar:
		first = BatchCinderPriest.FIRST
		row = BatchCinderPriest.fields(a as CinderPriestAvatar)
	else:
		return false
	for q in row.size():
		_st[o + first + q] = row[q]
	return true


## The row at `o` into a solo model kind's own fields (its row file's); false for the others.
func _import_solo(o: int, a: AvatarBase) -> bool:
	if a is NeedleAvatar:
		BatchNeedleRow.load(a as NeedleAvatar, _st.slice(o + BatchNeedleRow.FIRST, o + STRIDE))
	elif a is RockLurkerAvatar:
		BatchLurker.take(a as RockLurkerAvatar, _st, o)
	elif a is WardenAvatar:
		BatchWarden.import_row(a as WardenAvatar, _st.slice(o + BatchWarden.W_CRACK, o + STRIDE))
	elif a is SniperAvatar:
		BatchSniperRow.load(
			a as SniperAvatar, _st.slice(o + BatchSniperRow.FIRST, o + BatchSniperRow.END)
		)
	elif a is ArcCasterAvatar:
		BatchArcCaster.take(a as ArcCasterAvatar, _st, o)
	elif a is LensDroneAvatar:
		BatchLensDrone.load(a as LensDroneAvatar, _st, o)
	elif a is BombDroneAvatar:
		BatchBombDrone.take(a as BombDroneAvatar, _st, o)
	elif a is ScrapHoundAvatar:
		BatchScrapHound.take(a as ScrapHoundAvatar, _st, o)
	elif a is CinderPriestAvatar:
		BatchCinderPriest.take(a as CinderPriestAvatar, _st, o)
	else:
		return false
	return true


## A Stone Thrower's row at `o` into its fields (the visor's material only when its glow changed).
func _import_thrower(o: int, st: StoneThrowerAvatar) -> void:
	var visor := _st[o + S_VISOR]
	if st._visor_mat.emission_energy_multiplier != visor:
		st._visor_mat.emission_energy_multiplier = visor
	st._state = int(_st[o + S_STATE])
	st._state_ticks = int(_st[o + S_STATE_TICKS])
	st._ticks = Vector3i(
		int(_st[o + S_TICKS]), int(_st[o + S_TICKS + 1]), int(_st[o + S_TICKS + 2])
	)
	st._atk = _st[o + S_ATK]
	st._atk_sim = _st[o + S_ATK_SIM]
	st._walk = _st[o + S_WALK]
	st._phase = _st[o + S_PHASE]
	st._speed = _st[o + S_SPEED]
	st._fwd = Vector2(_st[o + S_FWD], _st[o + S_FWD + 1])
	st._rise = _st[o + S_RISE]
	st._puff = _st[o + S_PUFF]
	st._die_t = _st[o + S_DIE]
	st._drop = _st[o + S_DROP] != 0.0
	st._drop_from = Vector3(
		_st[o + S_DROP_FROM], _st[o + S_DROP_FROM + 1], _st[o + S_DROP_FROM + 2]
	)
	st._rock_shown = _st[o + S_ROCK_SHOWN]
	st._lift = _st[o + S_LIFT]
	for q in st._vd.size():
		st._vd[q] = _st[o + S_VD + q]


func _put_xf(o: int, xf: Transform3D) -> void:
	var b := xf.basis
	_st[o] = b.x.x
	_st[o + 1] = b.y.x
	_st[o + 2] = b.z.x
	_st[o + 3] = xf.origin.x
	_st[o + 4] = b.x.y
	_st[o + 5] = b.y.y
	_st[o + 6] = b.z.y
	_st[o + 7] = xf.origin.y
	_st[o + 8] = b.x.z
	_st[o + 9] = b.y.z
	_st[o + 10] = b.z.z
	_st[o + 11] = xf.origin.z


func _get_xf(o: int) -> Transform3D:
	return Transform3D(
		Vector3(_st[o], _st[o + 4], _st[o + 8]),
		Vector3(_st[o + 1], _st[o + 5], _st[o + 9]),
		Vector3(_st[o + 2], _st[o + 6], _st[o + 10]),
		Vector3(_st[o + 3], _st[o + 7], _st[o + 11])
	)


func _put_fx(o: int, xf: Transform3D) -> void:
	var b := xf.basis
	var v := [
		b.x.x,
		b.y.x,
		b.z.x,
		xf.origin.x,
		b.x.y,
		b.y.y,
		b.z.y,
		xf.origin.y,
		b.x.z,
		b.y.z,
		b.z.z,
		xf.origin.z
	]
	for q in 12:
		_fx[o + q] = v[q]
